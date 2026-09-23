#!/usr/bin/env python3
import ast
import pathlib
import socket
import threading
import time
from types import SimpleNamespace


source_path = pathlib.Path("vms/android-lab/guest-vsock.py")
source = source_path.read_text()
compile(source, str(source_path), "exec")
tree = ast.parse(source, filename=str(source_path))
functions = [
    node
    for node in tree.body
    if isinstance(node, ast.FunctionDef)
    and node.name in {"copy_stream", "open_redroid_adb"}
]
if {node.name for node in functions} != {"copy_stream", "open_redroid_adb"}:
    raise SystemExit("missing Android ADB relay functions")
namespace = {
    "socket": SimpleNamespace(
        create_connection=lambda *_args, **_kwargs: upstream,
        SHUT_WR=socket.SHUT_WR,
    ),
    "REDROID_ADDRESS": ("127.0.0.1", 5555),
    "OSError": OSError,
}
upstream, remote = socket.socketpair()
destination, receiver = socket.socketpair()
upstream.settimeout(0.05)
exec(compile(ast.Module(body=functions, type_ignores=[]), str(source_path), "exec"), namespace)
connected = namespace["open_redroid_adb"]()
if connected.gettimeout() is not None:
    raise SystemExit("ADB relay retained its connection timeout")

worker = threading.Thread(
    target=namespace["copy_stream"], args=(connected, destination), daemon=True
)
worker.start()
time.sleep(0.15)
if not worker.is_alive():
    raise SystemExit("idle ADB relay closed before data arrived")
remote.sendall(b"relay-still-open")
if receiver.recv(64) != b"relay-still-open":
    raise SystemExit("ADB relay did not forward data after an idle interval")
remote.close()
worker.join(timeout=2)
if worker.is_alive():
    raise SystemExit("ADB relay did not finish after upstream EOF")
receiver.close()
destination.close()
