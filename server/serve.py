#!/usr/bin/env python3
"""HTTP server for ~/listenkids: GET static files, POST /report for bad transcripts."""
import http.server, socketserver, os, sys, json
from datetime import datetime

ROOT = os.path.expanduser("~/listenkids")
PORT = 18000
REPORTS = os.path.join(ROOT, "bad_transcripts.log")
os.chdir(ROOT)


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path.startswith("/report"):
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8") if length else ""
            try:
                data = json.loads(body)
            except json.JSONDecodeError:
                data = {}
            ep_id = (data.get("episodeID") or "").strip()
            audio_url = (data.get("audioURL") or "").strip()
            transcript_url = (data.get("transcriptURL") or "").strip()
            current_time = data.get("currentTime", 0)
            if ep_id or audio_url:
                rec = {
                    "ts": datetime.now().isoformat(timespec="seconds"),
                    "episodeID": ep_id,
                    "audioURL": audio_url,
                    "transcriptURL": transcript_url,
                    "currentTime": current_time,
                }
                with open(REPORTS, "a", encoding="utf-8") as f:
                    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                print(f"REPORT: {ep_id or audio_url} @ {current_time:.1f}s", flush=True)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"status":"ok"}')
                return
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error":"missing episodeID or audioURL"}')
            return
        self.send_response(404)
        self.end_headers()


socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"listening 0.0.0.0:{PORT} root={ROOT}", flush=True)
    httpd.serve_forever()
