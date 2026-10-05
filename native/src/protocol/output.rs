//! Keep brief pauses in Ruby's reader off the render thread. Backpressure starts
//! after 2 MiB of queued bytes, regardless of the size of an individual message.
use std::io::Write;
use std::sync::{atomic::{AtomicBool, Ordering}, mpsc, Arc};
use std::thread::JoinHandle;
use std::time::Duration;

const CHUNK_BYTES: usize = 64 * 1024;
const QUEUED_CHUNKS: usize = 32;
const DRAIN_TIMEOUT: Duration = Duration::from_secs(2);

pub(super) struct OutputWriter {
    sender: Option<mpsc::SyncSender<Vec<u8>>>,
    thread: Option<JoinHandle<()>>,
    finished: mpsc::Receiver<()>,
    broken: Arc<AtomicBool>,
}

impl OutputWriter {
    pub(super) fn new(mut writer: impl Write + Send + 'static) -> Self {
        let (sender, receiver) = mpsc::sync_channel::<Vec<u8>>(QUEUED_CHUNKS);
        let (done, finished) = mpsc::channel();
        let broken = Arc::new(AtomicBool::new(false));
        let failed = broken.clone();
        let thread = std::thread::spawn(move || {
            for bytes in receiver {
                if writer.write_all(&bytes).and_then(|_| writer.flush()).is_err() {
                    failed.store(true, Ordering::Relaxed);
                    break;
                }
            }
            drop(writer);
            let _ = done.send(());
        });
        Self { sender: Some(sender), thread: Some(thread), finished, broken }
    }

    pub(super) fn failed(&self) -> bool { self.broken.load(Ordering::Relaxed) }

    pub(super) fn send(&self, bytes: &[u8]) -> bool {
        let Some(sender) = &self.sender else { return false };
        // Byte chunks may split a JSON line or UTF-8 character; their ordered
        // concatenation is exactly the original stream.
        bytes.chunks(CHUNK_BYTES).all(|chunk| sender.send(chunk.to_vec()).is_ok())
    }

    fn finish(&mut self, timeout: Duration) {
        let Some(thread) = self.thread.take() else { return };
        self.sender.take();
        if self.finished.recv_timeout(timeout).is_ok() {
            let _ = thread.join();
        }
        // A parent that stays connected but stops reading must not prevent exit.
        // A blocked OS write cannot be portably cancelled; detach after the grace
        // period. The renderer process owns this thread and is exiting now.
    }
}

impl Drop for OutputWriter {
    fn drop(&mut self) { self.finish(DRAIN_TIMEOUT); }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;
    use std::sync::Mutex;

    struct GatedWriter {
        started: mpsc::Sender<()>,
        release: Option<mpsc::Receiver<()>>,
        bytes: Arc<Mutex<Vec<u8>>>,
    }

    impl Write for GatedWriter {
        fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
            if let Some(release) = self.release.take() {
                self.started.send(()).unwrap();
                release.recv().unwrap();
            }
            // Force write_all to handle partial writes, including split UTF-8.
            let n = bytes.len().min(7919);
            self.bytes.lock().unwrap().extend_from_slice(&bytes[..n]);
            Ok(n)
        }
        fn flush(&mut self) -> io::Result<()> { Ok(()) }
    }

    type GatedOutput = (OutputWriter, mpsc::Receiver<()>, mpsc::Sender<()>, Arc<Mutex<Vec<u8>>>);

    fn gated() -> GatedOutput {
        let (started, waiting) = mpsc::channel();
        let (release, gate) = mpsc::channel();
        let bytes = Arc::new(Mutex::new(Vec::new()));
        let writer = OutputWriter::new(GatedWriter { started, release: Some(gate), bytes: bytes.clone() });
        (writer, waiting, release, bytes)
    }

    #[test]
    fn a_busy_reader_does_not_block_short_batches_and_shutdown_drains_in_order() {
        let (writer, waiting, release, bytes) = gated();
        assert!(writer.send(b"event\n"));
        waiting.recv_timeout(Duration::from_secs(2)).unwrap();
        let unicode = "العِلْم 👩‍💻\n".repeat(10_000);
        assert!(writer.send(unicode.as_bytes()));
        assert!(writer.send(b"reply\n"));
        release.send(()).unwrap();
        drop(writer);
        assert_eq!(*bytes.lock().unwrap(), format!("event\n{unicode}reply\n").as_bytes());
    }

    #[test]
    fn queue_capacity_is_bounded_in_bytes_even_for_a_large_batch() {
        let (writer, waiting, release, bytes) = gated();
        writer.send(b"first\n");
        waiting.recv_timeout(Duration::from_secs(2)).unwrap();
        let batch = vec![b'x'; CHUNK_BYTES * QUEUED_CHUNKS];
        assert!(writer.send(&batch));
        assert!(matches!(writer.sender.as_ref().unwrap().try_send(vec![b'y']), Err(mpsc::TrySendError::Full(_))));
        release.send(()).unwrap();
        drop(writer);
        let bytes = bytes.lock().unwrap();
        assert_eq!(&bytes[..6], b"first\n");
        assert_eq!(&bytes[6..], batch);
    }

    #[test]
    fn a_disconnected_reader_marks_failure_and_releases_blocked_senders() {
        struct Broken;
        impl Write for Broken {
            fn write(&mut self, _: &[u8]) -> io::Result<usize> { Err(io::ErrorKind::BrokenPipe.into()) }
            fn flush(&mut self) -> io::Result<()> { Ok(()) }
        }
        let writer = OutputWriter::new(Broken);
        assert!(!writer.send(&vec![b'x'; CHUNK_BYTES * (QUEUED_CHUNKS + 2)]));
        assert!(writer.failed());
        assert!(!writer.send(b"another reply\n"));
    }

    #[test]
    fn shutdown_has_a_deadline_when_the_parent_never_drains() {
        let (mut writer, waiting, release, bytes) = gated();
        writer.send(b"queued\n");
        waiting.recv_timeout(Duration::from_secs(2)).unwrap();
        writer.finish(Duration::from_millis(10));
        assert!(writer.thread.is_none());
        assert!(!writer.send(b"closed\n"));
        // Clean up the detached test worker; a real renderer exits instead.
        release.send(()).unwrap();
        writer.finished.recv_timeout(Duration::from_secs(2)).unwrap();
        assert_eq!(*bytes.lock().unwrap(), b"queued\n");
    }
}
