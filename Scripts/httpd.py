import http.server
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.log_message("GET %s", str(self.path))
        self.write_response()

    def do_POST(self):
        self.log_message("POST %s", str(self.path))
        body = self.rfile.read(int(self.headers["Content-Length"]))
        print(body.decode("utf-8"))
        self.write_response()

    def write_response(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"")

    def send_response(self, code, message=None):
        self.send_response_only(code, message)


def run(port):
    httpd = http.server.HTTPServer(("", port), Handler)
    print(f"[+] HTTP server listening on: http://0.0.0.0:{port}\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        httpd.server_close()
        print("\n\n[!] HTTP server stopped.")


if __name__ == "__main__":
    run(port=int(sys.argv[1]))
