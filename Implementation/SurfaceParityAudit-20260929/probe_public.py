"""Read public fixture contracts and handshake routes; never send actions."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
import json
import subprocess
import uuid

OUT = Path(__file__).resolve().parent
HOSTS = ["staging.haven.digipomps.org", "haven.digipomps.org"]


def fetch(host, path, websocket=False):
    command = ["curl", "-sS", "--max-time", "12", "-w", "\n%{http_code}"]
    if websocket:
        command += ["--http1.1", "-H", "Connection: Upgrade", "-H", "Upgrade: websocket",
                    "-H", "Sec-WebSocket-Version: 13", "-H",
                    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="]
    command += [f"https://{host}{path}"]
    result = subprocess.run(command, capture_output=True, text=True)
    body, _, status = result.stdout.rpartition("\n")
    return dict(host=host, path=path, status=status, body=body, error=result.stderr,
                exit=result.returncode, kind="ws" if websocket else "http")


with ThreadPoolExecutor(max_workers=6) as pool:
    routes = ["/health/build", "/skeleton-parity/api/catalog",
              "/personal-copilot-v1/api/catalog", "/personal-copilot-v1/chat/api/configuration"]
    rows = list(pool.map(lambda args: fetch(*args), [(host, route) for host in HOSTS for route in routes]))
    jobs = []
    for row in rows:
        if row["path"] == "/skeleton-parity/api/catalog" and row["status"] == "200":
            for fixture in json.loads(row["body"]).get("fixtures", []):
                jobs.extend((row["host"], fixture[key]) for key in ["configurationRoute", "stateRoute"])
    jobs.extend((host, "/bridgehead/SkeletonParityTextFixture/" + str(uuid.uuid4()), True) for host in HOSTS)
    rows.extend(pool.map(lambda args: fetch(*args), jobs))

(OUT / "http-probes.json").write_text(json.dumps(dict(
    observedAt=datetime.now(timezone.utc).isoformat(),
    scope="Unauthenticated public GET and WebSocket handshake only; no user state or actions",
    responses=rows), indent=2))
for row in rows:
    note = ""
    if row["status"] not in ["200", "101"]:
        try:
            note = json.loads(row["body"]).get("reason", "")
        except (ValueError, AttributeError):
            note = row["error"][:100]
    if row["path"] == "/health/build":
        note = row["body"]
    print(row["host"], row["status"], row["path"], note)
