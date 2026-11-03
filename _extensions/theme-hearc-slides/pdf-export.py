#!/usr/bin/env python3
"""Imprime une présentation Reveal.js après sa mise en page PDF asynchrone."""

import base64
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def read_exact(sock, size):
    data = bytearray()
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise RuntimeError("le navigateur a fermé la connexion DevTools")
        data.extend(chunk)
    return bytes(data)


def send_frame(sock, payload, opcode=1):
    data = payload.encode() if isinstance(payload, str) else payload
    mask = os.urandom(4)
    size = len(data)
    header = bytearray((0x80 | opcode,))
    if size < 126:
        header.append(0x80 | size)
    elif size < 65536:
        header.append(0x80 | 126)
        header.extend(struct.pack("!H", size))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack("!Q", size))
    sock.sendall(header + mask + bytes(value ^ mask[i % 4] for i, value in enumerate(data)))


def receive_frame(sock):
    first, second = read_exact(sock, 2)
    size = second & 0x7F
    if size == 126:
        size = struct.unpack("!H", read_exact(sock, 2))[0]
    elif size == 127:
        size = struct.unpack("!Q", read_exact(sock, 8))[0]
    mask = read_exact(sock, 4) if second & 0x80 else None
    data = read_exact(sock, size)
    if mask:
        data = bytes(value ^ mask[i % 4] for i, value in enumerate(data))
    return first & 0x0F, bool(first & 0x80), data


class DevTools:
    def __init__(self, address):
        parsed = urlsplit(address)
        self.socket = socket.create_connection((parsed.hostname, parsed.port), timeout=10)
        self.socket.settimeout(120)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET {parsed.path} HTTP/1.1\r\n"
            f"Host: {parsed.hostname}:{parsed.port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "Origin: http://localhost\r\n\r\n"
        )
        self.socket.sendall(request.encode("ascii"))
        response = bytearray()
        while b"\r\n\r\n" not in response:
            chunk = self.socket.recv(4096)
            if not chunk:
                raise RuntimeError("le navigateur a fermé la connexion DevTools")
            response.extend(chunk)
        if not response.startswith(b"HTTP/1.1 101"):
            raise RuntimeError("impossible d'ouvrir la connexion DevTools")
        self.command_id = 0

    def command(self, method, params=None):
        self.command_id += 1
        command_id = self.command_id
        send_frame(
            self.socket,
            json.dumps({"id": command_id, "method": method, "params": params or {}}),
        )
        while True:
            opcode, final, payload = receive_frame(self.socket)
            if opcode == 9:
                send_frame(self.socket, payload, opcode=10)
                continue
            if opcode == 8:
                raise RuntimeError("la connexion DevTools a été fermée")
            if opcode != 1 or not final:
                continue
            message = json.loads(payload)
            if message.get("id") != command_id:
                continue
            if "error" in message:
                raise RuntimeError(message["error"].get("message", "erreur DevTools"))
            return message["result"]

    def close(self):
        self.socket.close()


def close_browser(port, process):
    if process.poll() is None:
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version", timeout=2) as response:
                address = json.load(response)["webSocketDebuggerUrl"]
            browser = DevTools(address)
            try:
                browser.command("Browser.close")
            finally:
                browser.close()
        except (OSError, KeyError, ValueError, RuntimeError):
            process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def page_target(port, expected_url, process):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("le navigateur s'est arrêté avant d'ouvrir la présentation")
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=1) as response:
                targets = json.load(response)
            target = next(
                (
                    item
                    for item in targets
                    if item.get("type") == "page"
                    and item.get("url", "").startswith(expected_url)
                ),
                None,
            )
            if target:
                return target
        except (OSError, ValueError):
            pass
        time.sleep(0.1)
    raise RuntimeError("le navigateur n'a pas ouvert la présentation")


def wait_for_layout(devtools):
    deadline = time.monotonic() + 60
    state = {}
    expression = (
        "({pages: document.querySelectorAll('.pdf-page').length, "
        "loading: document.body.classList.contains('loading-scroll-mode')})"
    )
    while time.monotonic() < deadline:
        result = devtools.command(
            "Runtime.evaluate",
            {"expression": expression, "returnByValue": True},
        )
        state = result.get("result", {}).get("value", {})
        if state.get("pages", 0) > 0 and not state.get("loading", True):
            return state
        time.sleep(0.1)
    raise RuntimeError(f"la mise en page PDF de Reveal.js n'est pas terminée : {state}")


def export(browser, html, pdf):
    html = Path(html).resolve()
    pdf = Path(pdf).resolve()
    url = f"{html.as_uri()}?print-pdf"
    port = free_port()
    with tempfile.TemporaryDirectory(prefix="hearc-pdf-") as profile:
        process = subprocess.Popen(
            [
                browser,
                "--headless",
                "--disable-gpu",
                "--no-first-run",
                f"--user-data-dir={profile}",
                f"--remote-debugging-port={port}",
                "--remote-allow-origins=http://localhost",
                url,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        devtools = None
        try:
            target = page_target(port, url, process)
            devtools = DevTools(target["webSocketDebuggerUrl"])
            devtools.command("Runtime.enable")
            state = wait_for_layout(devtools)
            result = devtools.command(
                "Page.printToPDF",
                {"printBackground": True, "preferCSSPageSize": True},
            )
            data = base64.b64decode(result["data"], validate=True)
            if not data.startswith(b"%PDF-"):
                raise RuntimeError("le navigateur a retourné un contenu qui n'est pas un PDF")
            pdf.write_bytes(data)
            print(f"{state['pages']} pages imprimées dans {pdf}", file=sys.stderr)
        finally:
            if devtools:
                devtools.close()
            close_browser(port, process)


def main():
    if len(sys.argv) != 4:
        raise RuntimeError("usage: pdf-export.py NAVIGATEUR FICHIER_HTML FICHIER_PDF")
    export(sys.argv[1], sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"pdf-export : {error}", file=sys.stderr)
        sys.exit(1)
