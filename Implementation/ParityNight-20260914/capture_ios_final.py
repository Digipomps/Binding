"""Capture only the uniquely identified, synthetic parity Simulator app."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import time

root = Path(__file__).resolve().parent
device, output_name = sys.argv[1:3]
assert device in {"1F9CB294-13BC-4D49-B8C7-E969D4BFFA11", "60A4509A-5AD0-42B9-A1D0-7CEBA044F514"}
assert output_name in {"phase3-final-ios26", "phase3-final-ios18"}
bundle = "org.digipomps.haven.parity-night-test"

def simctl(*args, check=True):
    return subprocess.run(["xcrun", "simctl", *args], check=check, capture_output=True, text=True)

simctl("terminate", device, bundle, check=False)
if "--install" in sys.argv:
    simctl("install", device, "/private/tmp/haven-parity-ios-products/HAVEN.app")
container = Path(simctl("get_app_container", device, bundle, "data").stdout.strip())
source = container / "Documents/parity"
start = time.time()
try:
    launch = simctl("launch", device, bundle, "--parity-capture")
    report = source / "ios-capture-report.json"
    for _ in range(40):
        if report.exists() and report.stat().st_mtime >= start:
            break
        time.sleep(0.5)
    else:
        raise RuntimeError("No fresh capture report within 20 seconds")
    records = json.loads(report.read_text())
    assert len(records) == 5 and all(r["outcome"] == "captured" for r in records), records
    destination = root / output_name
    shutil.copytree(source, destination, dirs_exist_ok=True)
    simctl("io", device, "screenshot", str(destination / "simulator-screen.png"))
    print(json.dumps({"device": device, "container": str(container), "output": str(destination), "records": records}, indent=2))
finally:
    simctl("terminate", device, bundle, check=False)
