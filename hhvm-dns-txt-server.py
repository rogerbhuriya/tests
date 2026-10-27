import socket
import struct


def question_end(query: bytes) -> int:
    offset = 12
    while True:
        label_length = query[offset]
        offset += 1
        if label_length == 0:
            return offset + 4
        offset += label_length


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("0.0.0.0", 53))
print("ready", flush=True)

while True:
    query, peer = sock.recvfrom(65535)
    end = question_end(query)
    question = query[12:end]
    rdata = b"".join(bytes([30]) + bytes([letter]) * 30 for letter in range(65, 73))
    header = query[:2] + b"\x81\x80" + struct.pack("!HHHH", 1, 1, 0, 0)
    answer = b"\xc0\x0c" + struct.pack("!HHIH", 16, 1, 0, len(rdata)) + rdata
    sock.sendto(header + question + answer, peer)
    print(f"answered peer={peer[0]}:{peer[1]} rdata={len(rdata)}", flush=True)
