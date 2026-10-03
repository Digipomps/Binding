#!/usr/bin/env python3
"""Fullfører et ekte websocket-håndtrykk og observerer hva serveren gjør etterpå.
101 i statuslinja betyr bare at oppgraderingen ble akseptert — Vapor oppgraderer
alltid når ruten mangler shouldUpgrade, og validerer så inne i handleren.
Spørsmålet som betyr noe: blir forbindelsen stående, eller lukkes den?"""
import socket, ssl, base64, os, struct, sys, time

def parse_close(payload):
    if len(payload) >= 2:
        code = struct.unpack("!H", payload[:2])[0]
        return code, payload[2:].decode("utf-8", "replace")
    return None, ""

def probe(host, path, label, timeout=6.0):
    key = base64.b64encode(os.urandom(16)).decode()
    req = (f"GET {path} HTTP/1.1\r\nHost: {host}\r\nUpgrade: websocket\r\n"
           f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
           f"Sec-WebSocket-Version: 13\r\n\r\n")
    ctx = ssl.create_default_context()
    result = {"label": label, "path": path}
    try:
        raw = socket.create_connection((host, 443), timeout=timeout)
        s = ctx.wrap_socket(raw, server_hostname=host)
        s.settimeout(timeout)
        s.sendall(req.encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = s.recv(4096)
            if not chunk: break
            buf += chunk
        status = buf.split(b"\r\n", 1)[0].decode("latin-1")
        result["status"] = status
        if "101" not in status:
            result["outcome"] = "ingen oppgradering"
            s.close(); return result
        # Oppgradert. Hva skjer nå?
        t0 = time.time()
        frames = []
        try:
            while time.time() - t0 < timeout:
                data = s.recv(4096)
                if not data:
                    frames.append(("EOF", ""))
                    break
                op = data[0] & 0x0F
                ln = data[1] & 0x7F
                off = 2
                if ln == 126: ln = struct.unpack("!H", data[2:4])[0]; off = 4
                elif ln == 127: ln = struct.unpack("!Q", data[2:10])[0]; off = 10
                payload = data[off:off+ln]
                if op == 0x8:
                    code, reason = parse_close(payload)
                    frames.append(("CLOSE", f"kode={code} {reason}"))
                    break
                elif op in (0x1, 0x2):
                    frames.append(("DATA", payload[:180].decode("utf-8", "replace")))
                else:
                    frames.append((f"op{op}", ""))
        except socket.timeout:
            frames.append(("TIMEOUT", f"ingenting på {timeout:.0f}s — forbindelsen står åpen"))
        result["frames"] = frames
        elapsed = time.time() - t0
        if any(f[0] == "CLOSE" for f in frames):
            result["outcome"] = f"LUKKET etter {elapsed:.2f}s"
        elif any(f[0] == "EOF" for f in frames):
            result["outcome"] = f"EOF etter {elapsed:.2f}s"
        elif any(f[0] == "TIMEOUT" for f in frames):
            result["outcome"] = f"ÅPEN og taus i {elapsed:.0f}s"
        else:
            result["outcome"] = f"data mottatt etter {elapsed:.2f}s"
        s.close()
    except Exception as e:
        result["outcome"] = f"feil: {type(e).__name__}: {e}"
    return result

import uuid
targets = []
for h in ["staging.haven.digipomps.org", "haven.digipomps.org"]:
    u = str(uuid.uuid4())
    targets += [
        (h, f"/v1/resolver/native-porthole/Porthole/{u}", "native-porthole UTEN kontrakt"),
        (h, f"/v1/resolver/native-porthole/IkkeTillatt/{u}", "native-porthole, ikke-tillatt publisher"),
        (h, f"/bridgehead/ConfigurationCatalog/{u}", "generell bro"),
    ]
for host, path, label in targets:
    r = probe(host, path, label)
    print(f"{host:32} {r['label']:42} {r.get('status','-'):26} -> {r['outcome']}")
    for kind, detail in r.get("frames", []):
        if detail: print(f"{'':32} {'':42} {kind}: {detail[:150]}")
