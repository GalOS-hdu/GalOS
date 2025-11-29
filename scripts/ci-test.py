#!/usr/bin/env python3
import argparse, subprocess, sys, threading, socket, time, datetime, re, os

parser = argparse.ArgumentParser()
parser.add_argument("arch")
parser.add_argument("--prompt", default=None, help="expected shell prompt (optional)")
parser.add_argument("--start-timeout", type=int, default=60, help="seconds to wait for qemu to start listening")
parser.add_argument("--boot-timeout", type=int, default=120, help="seconds to wait for shell prompt")
parser.add_argument("--port", type=int, default=4444)
args = parser.parse_args()
arch = args.arch

# build command; keep text mode
cmd = [
    "make",
    f"ARCH={arch}",
    "ACCEL=n",
    "justrun",
    f"QEMU_ARGS=-monitor none -serial tcp::{args.port},server=on",
]

print("Running:", " ".join(cmd), file=sys.stderr)
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

ready = threading.Event()
output_lines = []
lock = threading.Lock()

def reader():
    for line in p.stdout:
        # thread-safe collect and print
        with lock:
            output_lines.append(line)
        print(line, end="", file=sys.stderr)
        # tolerant match for qemu listening message; accept variants
        if ("QEMU waiting for connection" in line) or ("listening on" in line) or ("serial: Listening on" in line) or ("tcp::" in line and "server" in line):
            ready.set()
    # don't set ready here - let main handle process exit

t = threading.Thread(target=reader, daemon=True)
t.start()

# wait for qemu to announce listening, with retries and fallback
start_time = time.time()
if not ready.wait(timeout=args.start_timeout):
    # maybe process exited; check return code
    rc = p.poll()
    if rc is not None:
        print(f"Process exited early with code {rc}", file=sys.stderr)
        raise SystemExit(1)
    # fallback: try to connect repeatedly for a short period
    print("Did not see explicit listening message; attempting to connect directly...", file=sys.stderr)

# try connect with retries
connected = False
sock = None
connect_deadline = time.time() + args.start_timeout
while time.time() < connect_deadline:
    try:
        sock = socket.create_connection(("localhost", args.port), timeout=5)
        connected = True
        break
    except Exception as e:
        # connection refused or not ready yet
        time.sleep(0.5)
if not connected:
    print("Unable to connect to QEMU serial port after retries.", file=sys.stderr)
    # print recent output for debugging
    with lock:
        print("--- last output ---", file=sys.stderr)
        for ln in output_lines[-200:]:
            print(ln, end="", file=sys.stderr)
    raise SystemExit(1)

# read until prompt or timeout
if args.prompt:
    pattern = re.compile(re.escape(args.prompt))
else:
    # permissive prompt: look for '#' or '$' at line end (common for root/shell)
    pattern = re.compile(r"(?m)(?:^|\n)[^\n]*[#\$]\s*$")

buf = ""
sock.settimeout(1.0)
boot_deadline = datetime.datetime.now() + datetime.timedelta(seconds=args.boot_timeout)
sent = False
try:
    while datetime.datetime.now() < boot_deadline:
        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            chunk = b""
        if not chunk:
            # may be no data momentarily; check process state
            if p.poll() is not None:
                raise Exception(f"QEMU process exited with code {p.returncode} before prompt")
            time.sleep(0.1)
            continue
        text = chunk.decode("utf-8", errors="ignore")
        print(text, end="", file=sys.stderr)
        buf += text
        if pattern.search(buf) and not sent:
            # send exit
            sock.sendall(b"exit\r\n")
            sent = True
            # continue to read until socket closes or we see expected behavior
        # if we've sent exit and socket closed, break
        if sent and p.poll() is not None:
            break
    else:
        raise Exception("Timeout waiting for shell prompt")
    print("\x1b[32m✔ Boot into BusyBox shell (detected)\x1b[0m")
except Exception as e:
    print("\x1b[31m❌ Boot failed or timed out\x1b[0m", file=sys.stderr)
    print("Error:", e, file=sys.stderr)
    with lock:
        print("--- recent output for debugging ---", file=sys.stderr)
        for ln in output_lines[-400:]:
            print(ln, end="", file=sys.stderr)
    raise
finally:
    try:
        sock.close()
    except:
        pass
    # let process exit gracefully (longer wait)
    try:
        p.wait(5)
    except subprocess.TimeoutExpired:
        p.terminate()
        p.wait()
