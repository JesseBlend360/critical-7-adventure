#!/usr/bin/env python3
"""Serve the Web export with the headers Godot needs.

We exported with thread_support=false, so Cross-Origin-Isolation is not
strictly required — but we set the headers anyway, which makes it safe to
flip thread_support on later without changing the server.

Usage:  tools/serve_web.py [port]
        (default port 8060)
"""

import http.server
import os
import socketserver
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060


class GodotHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # Godot's SharedArrayBuffer-using builds need these. Harmless otherwise.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # Disable caching during dev so re-exports are picked up immediately.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        super().end_headers()


def main():
    if not os.path.isdir(ROOT):
        print(f"No build directory at {ROOT}. Run tools/export_web.sh first.")
        sys.exit(1)

    if not os.path.isfile(os.path.join(ROOT, "index.html")):
        print(f"No index.html in {ROOT}. Re-run tools/export_web.sh.")
        sys.exit(1)

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), GodotHandler) as httpd:
        print(f"Serving {ROOT} at http://127.0.0.1:{PORT}/")
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down.")


if __name__ == "__main__":
    main()
