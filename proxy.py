import http.server
import urllib.request

class Proxy(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_POST(self):
        length = int(self.headers['Content-Length'])
        body = self.rfile.read(length)
        req = urllib.request.Request('https://api.mainnet-beta.solana.com',
            data=body, headers={'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req) as res:
                data = res.read()
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(data)
        except Exception as e:
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(str(e).encode())

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8081), Proxy)
    print("Proxy running on port 8081")
    server.serve_forever()
