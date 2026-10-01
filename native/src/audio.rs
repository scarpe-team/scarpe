//! Shoes::Audio (audio("pop.wav").play, and a video of an audio file): sound files played
//! through the system's output device with rodio, each sound a Player of its own so several
//! play at once.
//!
//! SCARPE_AUDIO_FILE names a file that stands in for the speakers: every command is written
//! there as a line ("play /path/pop.wav") and nothing is heard. Headless runs never open a
//! device either. Either way a played sound ends at once, so Ruby hears `audio_ended` for it
//! right after the reply.

use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::PathBuf;

use rodio::{Decoder, MixerDeviceSink, Player};

pub struct Audio {
    backend: Backend,
    /// The sounds playing or paused on the device, by Ruby's id.
    players: HashMap<String, Player>,
    /// Sounds that have ended since Ruby last heard, in the order they ended.
    ended: Vec<String>,
}

enum Backend {
    /// The device, opened on the first sound: most apps never make one.
    Device(Option<MixerDeviceSink>),
    /// No device would open: say so once, then stay quiet.
    Unavailable,
    File(PathBuf),
    Silent,
}

impl Audio {
    pub fn for_run(headless: bool) -> Self {
        let backend = match std::env::var_os("SCARPE_AUDIO_FILE").filter(|f| !f.is_empty()) {
            Some(file) => Backend::File(PathBuf::from(file)),
            None if headless => Backend::Silent,
            None => Backend::Device(None),
        };
        Audio { backend, players: HashMap::new(), ended: Vec::new() }
    }

    /// One of Ruby's commands: play (from the start), pause, resume, stop, or volume (0 to 1, the
    /// level a play starts at too). The stand-in file hears all but volume.
    pub fn command(&mut self, cmd: &str, id: &str, path: &str, volume: f32) -> Result<(), String> {
        if !matches!(cmd, "play" | "pause" | "resume" | "stop" | "volume") {
            return Err(format!("unknown audio command `{cmd}`"));
        }
        match &mut self.backend {
            Backend::File(_) | Backend::Silent | Backend::Unavailable if cmd == "volume" => Ok(()),
            Backend::File(file) => {
                let mut f = OpenOptions::new().create(true).append(true).open(&*file).map_err(|e| format!("{}: {e}", file.display()))?;
                writeln!(f, "{cmd} {path}").map_err(|e| e.to_string())?;
                if cmd == "play" {
                    self.ended.push(id.to_string());
                }
                Ok(())
            }
            Backend::Silent | Backend::Unavailable => {
                if cmd == "play" {
                    self.ended.push(id.to_string());
                }
                Ok(())
            }
            Backend::Device(_) => self.on_device(cmd, id, path, volume),
        }
    }

    fn on_device(&mut self, cmd: &str, id: &str, path: &str, volume: f32) -> Result<(), String> {
        match cmd {
            "play" => {
                self.players.remove(id); // a Player dropped is a Player stopped
                // A sound that cannot play has ended, so Ruby does not wait for it.
                let source = match File::open(path).map_err(|e| format!("{path}: {e}")).and_then(|file| {
                    Decoder::try_from(file).map_err(|e| format!("{path}: cannot decode it ({e}); WAV, MP3, Ogg Vorbis and FLAC play"))
                }) {
                    Ok(source) => source,
                    Err(e) => {
                        self.ended.push(id.to_string());
                        return Err(e);
                    }
                };
                if !self.open_device() {
                    self.ended.push(id.to_string());
                    return Ok(());
                }
                let Backend::Device(Some(sink)) = &self.backend else { unreachable!("open_device said so") };
                let player = Player::connect_new(sink.mixer());
                player.set_volume(volume);
                player.append(source);
                self.players.insert(id.to_string(), player);
            }
            "pause" => {
                if let Some(player) = self.players.get(id) {
                    player.pause();
                }
            }
            "resume" => match self.players.get(id) {
                Some(player) => player.play(),
                None => return self.on_device("play", id, path, volume),
            },
            "volume" => {
                if let Some(player) = self.players.get(id) {
                    player.set_volume(volume);
                }
            }
            _ => {
                self.players.remove(id);
            }
        }
        Ok(())
    }

    /// Opens the output device the first time it is wanted. False, after a warning on stderr,
    /// when there is none to open (a machine with no sound card, a CI runner).
    fn open_device(&mut self) -> bool {
        if let Backend::Device(None) = self.backend {
            match rodio::DeviceSinkBuilder::open_default_sink() {
                Ok(mut sink) => {
                    sink.log_on_drop(false);
                    self.backend = Backend::Device(Some(sink));
                }
                Err(e) => {
                    eprintln!("[scarpe-native] audio: no output device ({e}); sounds will not be heard");
                    self.backend = Backend::Unavailable;
                }
            }
        }
        matches!(self.backend, Backend::Device(Some(_)))
    }

    /// Whether a sound is playing on the device, so the event loop keeps checking for its end.
    pub fn playing(&self) -> bool {
        self.players.values().any(|p| !p.is_paused() && !p.empty())
    }

    /// The ids of sounds that have ended since the last call: played to their end on the
    /// device, or ended at once without one.
    pub fn take_ended(&mut self) -> Vec<String> {
        let done: Vec<String> = self.players.iter().filter(|(_, p)| p.empty()).map(|(id, _)| id.clone()).collect();
        for id in &done {
            self.players.remove(id);
        }
        let mut ended = std::mem::take(&mut self.ended);
        ended.extend(done);
        ended
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn headless_sounds_end_at_once_and_are_never_heard() {
        let mut audio = Audio { backend: Backend::Silent, players: HashMap::new(), ended: Vec::new() };
        audio.command("play", "audio-1", "/nowhere/pop.wav", 1.0).unwrap();
        audio.command("stop", "audio-1", "/nowhere/pop.wav", 1.0).unwrap();
        assert_eq!(audio.take_ended(), vec!["audio-1".to_string()]);
        assert!(audio.take_ended().is_empty());
        assert!(!audio.playing());
    }

    #[test]
    fn the_stand_in_file_gets_a_line_a_command() {
        let dir = std::env::temp_dir().join(format!("scarpe-audio-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = dir.join("audio.txt");
        let mut audio = Audio { backend: Backend::File(file.clone()), players: HashMap::new(), ended: Vec::new() };
        audio.command("play", "audio-1", "/tmp/a b.wav", 1.0).unwrap();
        audio.command("volume", "audio-1", "/tmp/a b.wav", 0.5).unwrap();
        audio.command("pause", "audio-1", "/tmp/a b.wav", 0.5).unwrap();
        audio.command("stop", "audio-1", "/tmp/a b.wav", 0.5).unwrap();
        assert_eq!(std::fs::read_to_string(&file).unwrap(), "play /tmp/a b.wav\npause /tmp/a b.wav\nstop /tmp/a b.wav\n");
        assert_eq!(audio.take_ended(), vec!["audio-1".to_string()]);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn an_unknown_command_is_refused() {
        let mut audio = Audio { backend: Backend::Silent, players: HashMap::new(), ended: Vec::new() };
        assert!(audio.command("rewind", "audio-1", "x.wav", 1.0).is_err());
    }
}
