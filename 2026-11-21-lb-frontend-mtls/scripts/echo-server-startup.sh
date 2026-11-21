#!/bin/bash
# Header-echo backend for the mTLS lab. Debian 12 ships python3.
cat > /usr/local/bin/echo-headers.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            body = b"ok\n"
        else:
            lines = [f"{k}: {v}" for k, v in self.headers.items() if k.lower().startswith("x-client-cert")]
            body = ("backend saw these mTLS headers:\n" + "\n".join(lines or ["(none)"]) + "\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

HTTPServer(("0.0.0.0", 8080), H).serve_forever()
PY
cat > /etc/systemd/system/echo-headers.service <<'UNIT'
[Unit]
Description=mTLS lab header echo
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/echo-headers.py
Restart=always
DynamicUser=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now echo-headers.service
