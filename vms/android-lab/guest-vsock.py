import base64
import fcntl
import hashlib
import hmac
import json
import os
import re
import socket
import struct
import subprocess
import threading
import time
from collections import OrderedDict

ADB_PORT = 5555
CONTROL_PORT = 8788
REDROID_ADDRESS = ("10.99.77.2", 5555)
MAX_REQUEST = 4096
MAX_RESPONSE = 1024 * 1024
ADB_KEYS = "@rootfsPath@/misc/adb/adb_keys"
CONTROL_KEY = "/run/redroid-auth/key"
CONTROL_NONCES = OrderedDict()
CONTROL_NONCES_LOCK = threading.Lock()
CONTROL_WORKERS = threading.BoundedSemaphore(8)
ADB_WORKERS = threading.BoundedSemaphore(32)

def read_exact(sock, count, deadline):
    data = bytearray()
    while len(data) < count:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("control frame deadline expired")
        sock.settimeout(remaining)
        part = sock.recv(count - len(data))
        if not part:
            raise ConnectionError("peer closed before frame completed")
        data.extend(part)
    return bytes(data)

def receive_frame(sock):
    deadline = time.monotonic() + 10
    size = struct.unpack("!I", read_exact(sock, 4, deadline))[0]
    if size < 2 or size > MAX_REQUEST:
        raise ValueError("invalid frame size")
    return json.loads(read_exact(sock, size, deadline).decode("utf-8"))

def copy_stream(source, destination):
    try:
        while True:
            chunk = source.recv(65536)
            if not chunk:
                break
            destination.sendall(chunk)
    except OSError:
        pass
    finally:
        try:
            destination.shutdown(socket.SHUT_WR)
        except OSError:
            pass

def open_redroid_adb():
    upstream = socket.create_connection(REDROID_ADDRESS, timeout=10)
    upstream.settimeout(None)
    return upstream

def adb_relay():
    listener = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((socket.VMADDR_CID_ANY, ADB_PORT))
    listener.listen(16)
    while True:
        client, _ = listener.accept()
        if not ADB_WORKERS.acquire(blocking=False):
            client.close()
            continue
        try:
            upstream = open_redroid_adb()
        except OSError:
            client.close()
            ADB_WORKERS.release()
            continue

        def relay(local, remote):
            left = threading.Thread(target=copy_stream, args=(local, remote), daemon=True)
            right = threading.Thread(target=copy_stream, args=(remote, local), daemon=True)
            left.start()
            right.start()
            left.join()
            right.join()
            local.close()
            remote.close()
            ADB_WORKERS.release()
        threading.Thread(target=relay, args=(client, upstream), daemon=True).start()

def respond(client, request_id, value):
    value.update({"version": 1, "id": request_id})
    payload = json.dumps(value, separators=(",", ":")).encode()
    if len(payload) > MAX_RESPONSE:
        payload = json.dumps({"version": 1, "id": request_id, "ok": False, "error": "response too large"}).encode()
    client.sendall(struct.pack("!I", len(payload)) + payload)

def snapshot():
    inspect = subprocess.run(
        ["@podman@/bin/podman", "inspect", "--format", "{{.State.Status}}", "redroid"],
        capture_output=True, text=True, timeout=15,
    )
    state = inspect.stdout.strip() if inspect.returncode == 0 else "missing"
    running = state == "running"
    boot_completed = False
    if running:
        boot = subprocess.run(
            ["@podman@/bin/podman", "exec", "redroid", "/system/bin/getprop", "sys.boot_completed"],
            capture_output=True, text=True, timeout=15,
        )
        boot_completed = boot.returncode == 0 and boot.stdout.strip() == "1"
    return {"state": state, "container_running": running, "boot_completed": boot_completed}

def authorize_adb(public_key):
    if not isinstance(public_key, str) or len(public_key) > 4096 or any(ord(ch) < 32 or ord(ch) == 127 for ch in public_key):
        raise ValueError("invalid public key")
    fields = public_key.strip().split(None, 1)
    if len(fields) != 1 and (len(fields) != 2 or len(fields[1]) > 1024):
        raise ValueError("expected one Android ADB RSA public key line")
    if not re.fullmatch(r"[A-Za-z0-9+/]{600,1400}={0,2}", fields[0]):
        raise ValueError("invalid Android ADB RSA key encoding")
    blob = base64.b64decode(fields[0], validate=True)
    # ADB stores RSA public keys as its own little-endian structure:
    # words, n0inv, modulus, rr, exponent. It is not OpenSSH wire format.
    if len(blob) < 12:
        raise ValueError("invalid Android ADB RSA key blob")
    words = int.from_bytes(blob[:4], "little")
    if words not in (64, 128) or len(blob) != 12 + 8 * words:
        raise ValueError("unsupported Android ADB RSA key size")
    if int.from_bytes(blob[-4:], "little") not in (3, 65537):
        raise ValueError("invalid Android ADB RSA exponent")
    directory = os.path.dirname(ADB_KEYS)
    os.makedirs(directory, mode=0o2750, exist_ok=True)
    fd = os.open(ADB_KEYS, os.O_RDWR | os.O_APPEND | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW, 0o640)
    try:
        if not os.path.isfile(ADB_KEYS):
            raise ValueError("adb_keys is not a regular file")
        os.fchown(fd, 1000, 2000)  # Android system:shell
        os.fchmod(fd, 0o640)
        fcntl.flock(fd, fcntl.LOCK_EX)
        os.lseek(fd, 0, os.SEEK_SET)
        existing = os.read(fd, 1024 * 1024).decode("ascii", errors="ignore").splitlines()
        line = fields[0] + (" " + fields[1].strip() if len(fields) == 2 else "")
        changed = line not in existing
        if changed:
            os.write(fd, (line + "\n").encode("ascii"))
            os.fsync(fd)
    finally:
        os.close(fd)

    state = snapshot()
    if state["container_running"] and changed:
        result = subprocess.run(
            ["@podman@/bin/podman", "exec", "redroid", "/system/bin/setprop", "ctl.restart", "adbd"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            raise RuntimeError("adbd authorization reload failed")
    subprocess.run(["@coreutils@/bin/sync", "-f", "@rootfsPath@"], check=True, timeout=30)

def control_client(client):
    with client:
        try:
            request = receive_frame(client)
            request_id = request.get("id")
            if request.get("version") != 1 or not isinstance(request_id, str) or len(request_id) > 128:
                raise ValueError("unsupported protocol version or invalid request id")
            auth = request.pop("auth", None)
            nonce = request.get("nonce")
            timestamp = request.get("timestamp")
            if not isinstance(auth, str) or not re.fullmatch(r"[0-9a-f]{64}", auth):
                raise ValueError("authentication required")
            if not isinstance(nonce, str) or not re.fullmatch(r"[0-9a-f]{32}", nonce):
                raise ValueError("invalid nonce")
            if not isinstance(timestamp, int) or abs(int(time.time()) - timestamp) > 30:
                raise ValueError("expired request")
            with open(CONTROL_KEY, "rb") as secret_file:
                secret = bytes.fromhex(secret_file.read(128).decode("ascii").strip())
            if len(secret) != 32:
                raise ValueError("invalid controller key")
            canonical = json.dumps(request, sort_keys=True, separators=(",", ":")).encode()
            expected = hmac.new(secret, canonical, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(auth, expected):
                raise ValueError("authentication failed")
            with CONTROL_NONCES_LOCK:
                if nonce in CONTROL_NONCES:
                    raise ValueError("request replay rejected")
                CONTROL_NONCES[nonce] = timestamp
                while len(CONTROL_NONCES) > 4096:
                    CONTROL_NONCES.popitem(last=False)
            client.settimeout(210)
            operation = request.get("op")
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError, ConnectionError, AttributeError, OSError):
            respond(client, None, {"ok": False, "error": "invalid or unauthenticated request"})
            return

        if operation == "status":
            try:
                respond(client, request_id, {"ok": True, **snapshot()})
            except (OSError, subprocess.SubprocessError) as exc:
                respond(client, request_id, {"ok": False, "error": type(exc).__name__})
        elif operation == "wait-ready":
            timeout = request.get("timeout_seconds", 180)
            if not isinstance(timeout, int) or isinstance(timeout, bool) or timeout < 1 or timeout > 180:
                respond(client, request_id, {"ok": False, "error": "timeout_seconds must be between 1 and 180"})
                return
            deadline = time.monotonic() + timeout
            state = {"state": "unknown", "container_running": False, "boot_completed": False}
            while time.monotonic() < deadline:
                try:
                    state = snapshot()
                except (OSError, subprocess.SubprocessError):
                    pass
                if state["container_running"] and state["boot_completed"]:
                    respond(client, request_id, {"ok": True, **state})
                    return
                time.sleep(2)
            respond(client, request_id, {"ok": False, "error": "timeout", **state})
        elif operation == "shutdown":
            result = subprocess.run(
                ["@podman@/bin/podman", "stop", "--time", "60", "redroid"],
                capture_output=True, text=True, timeout=75,
            )
            if result.returncode == 0:
                subprocess.run(["@coreutils@/bin/sync", "-f", "@rootfsPath@"], check=True, timeout=30)
            respond(client, request_id, {"ok": result.returncode == 0, "error": result.stderr[-1000:]})
        elif operation == "authorize-adb":
            try:
                authorize_adb(request.get("public_key"))
                respond(client, request_id, {"ok": True})
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
                respond(client, request_id, {"ok": False, "error": str(exc)[:256]})
        elif operation == "logs":
            result = subprocess.run(
                ["@podman@/bin/podman", "logs", "--tail", "500", "redroid"],
                capture_output=True, text=True, timeout=15,
            )
            respond(client, request_id, {"ok": result.returncode == 0, "logs": (result.stdout + result.stderr)[-60000:]})
        else:
            respond(client, request_id, {"ok": False, "error": "operation not allowed"})

def control_listener():
    listener = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((socket.VMADDR_CID_ANY, CONTROL_PORT))
    listener.listen(8)
    while True:
        client, _ = listener.accept()
        if not CONTROL_WORKERS.acquire(blocking=False):
            client.close()
            continue
        def handle(connection):
            try:
                control_client(connection)
            finally:
                CONTROL_WORKERS.release()
        threading.Thread(target=handle, args=(client,), daemon=True).start()

threading.Thread(target=control_listener, daemon=True).start()
adb_relay()
