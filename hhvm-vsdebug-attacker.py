#!/usr/bin/env python3
import json
import socket
import time


def request(sock, seq, command, arguments):
    message = {
        "seq": seq,
        "type": "request",
        "command": command,
        "arguments": arguments,
    }
    sock.sendall(json.dumps(message, separators=(",", ":")).encode() + b"\0")


def response(sock, request_seq, pending):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        while b"\0" in pending:
            raw, pending = pending.split(b"\0", 1)
            if not raw:
                continue
            message = json.loads(raw)
            print(json.dumps(message, sort_keys=True), flush=True)
            if message.get("type") == "response" and message.get("request_seq") == request_seq:
                return message, pending
        sock.settimeout(max(0.1, deadline - time.monotonic()))
        pending += sock.recv(65536)
    raise TimeoutError(f"response {request_seq} not received")


def main():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect("/tmp/hhvm-vsdebug.sock")
    pending = b""

    request(sock, 1, "initialize", {"clientID": "cross-user-proof"})
    _, pending = response(sock, 1, pending)
    request(sock, 2, "attach", {"displayConsoleStartupMsg": False})
    _, pending = response(sock, 2, pending)
    request(sock, 3, "configurationDone", {})
    _, pending = response(sock, 3, pending)
    request(
        sock,
        4,
        "evaluate",
        {
            "expression": "\\file_put_contents('/tmp/hhvm-cross-user-proof', 'executed-as-uid='.(string)\\posix_geteuid())",
            "context": "repl",
        },
    )
    evaluate, _ = response(sock, 4, pending)
    success = evaluate.get("success") is True
    print(f"evaluate_success={str(success).lower()}", flush=True)
    if not success:
        raise RuntimeError("evaluate request failed")


if __name__ == "__main__":
    main()

