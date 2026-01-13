#!/usr/bin/env python3
"""
Minimal HTTP proxy server for logging traffic.

Usage:
    proxy.py --output-path <path> [--port <port>]

Examples:
    proxy.py --output-path /tmp/traffic.log
    proxy.py --output-path /var/log/proxy.log --port 9000
    proxy.py -o /tmp/traffic.log -p 9000
"""

import argparse
import json
import sys
from mitmproxy import http
from mitmproxy.tools.main import mitmdump


class TrafficLogger:
    def __init__(self, log_file):
        self.log_file = open(log_file, 'w')

    def response(self, flow: http.HTTPFlow) -> None:
        """Log each completed request as a single JSON line."""
        log_entry = {
            "method": flow.request.method,
            "url": flow.request.url,
            "response": flow.response.status_code
        }

        self.log_file.write(json.dumps(log_entry) + ',\n')
        self.log_file.flush()


def main():
    parser = argparse.ArgumentParser(
        description='Minimal proxy server with traffic logging',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --output-path /tmp/traffic.log
  %(prog)s --output-path /var/log/proxy.log --port 9000
  %(prog)s -o /tmp/traffic.log -p 9000
        """
    )
    parser.add_argument('-o', '--output-path', required=True, help='Full path to the log file')
    parser.add_argument('-p', '--port', type=int, default=8080, help='Port to listen on (default: 8080)')
    args = parser.parse_args()

    log_path = args.output_path
    print(f"Starting proxy server on 127.0.0.1:{args.port}")
    print(f"Logging traffic to: {log_path}")
    print(f"Usage: curl -x http://127.0.0.1:{args.port} http://example.com\n")

    # Start mitmproxy with the logger addon
    sys.argv = [
        'mitmdump',
        '-s', __file__,
        '--listen-port', str(args.port),
        '--set', f'logfile={log_path}'
    ]
    mitmdump()

addons = [TrafficLogger(sys.argv[sys.argv.index('--set') + 1].split('=')[1])] if '--set' in sys.argv else []

if __name__ == '__main__':
    main()