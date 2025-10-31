#!/usr/bin/env python3
"""
Minimal HTTP proxy server for logging traffic.

Usage:
    proxy.py --output <logfile> [--port <port>]

Examples:
    proxy.py --output traffic.log
    proxy.py --output traffic.log --port 9000
    proxy.py -o traffic.log -p 9000
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
        content_type = flow.response.headers.get('Content-Type', 'unknown')
        # Extract just the main content type without parameters
        if ';' in content_type:
            content_type = content_type.split(';')[0].strip()

        log_entry = {
            "method": flow.request.method,
            "path": flow.request.url,
            "response": flow.response.status_code,
            "content_type": content_type
        }

        self.log_file.write(json.dumps(log_entry) + ',\n')
        self.log_file.flush()


def main():
    parser = argparse.ArgumentParser(
        description='Minimal proxy server with traffic logging',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --output traffic.log
  %(prog)s --output traffic.log --port 9000
  %(prog)s -o traffic.log -p 9000
        """
    )
    parser.add_argument('-o', '--output', required=True, help='Log file name (stored in /tmp)')
    parser.add_argument('-p', '--port', type=int, default=8080, help='Port to listen on (default: 8080)')
    args = parser.parse_args()

    log_path = f"/tmp/{args.output}"
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