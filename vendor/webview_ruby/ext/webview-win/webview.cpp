// Windows build of webview-ext: webview 0.12.0 with the WebView2 backend.
// The header is webview/core/include/webview/webview.h from
// https://github.com/webview/webview/tree/0.12.0, with one patch marked "Scarpe patch":
// the Win32 run loop stops on terminate even while messages keep arriving.
#include "webview/webview.h"
