"""Add secondary ENI metadata to the shared IMDS mock without changing it."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        prefix = "/latest/meta-data/network/interfaces/macs/0e:49:61:0f:c3:11/"
        overrides = {
            "/latest/meta-data/mac": "02:00:00:00:00:01",
            prefix + "device-number": "1",
            prefix + "network-card": "0",
            prefix + "local-ipv4s": "172.16.34.44",
        }
        if self.path in overrides:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(overrides[self.path].encode())
        else:
            self.forward()

    def do_PUT(self):
        self.forward()

    def forward(self):
        request = Request(
            "http://localhost:1338" + self.path,
            headers=dict(self.headers),
            method=self.command,
        )
        try:
            response = urlopen(request, timeout=5)
        except HTTPError as error:
            response = error
        with response:
            self.send_response(response.code)
            for name, value in response.headers.items():
                if name.lower() not in ("connection", "transfer-encoding"):
                    self.send_header(name, value)
            self.end_headers()
            self.wfile.write(response.read())


ThreadingHTTPServer(("127.0.0.1", 1339), Handler).serve_forever()
