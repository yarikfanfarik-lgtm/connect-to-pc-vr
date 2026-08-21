import socket
import struct
import time
import threading
import tkinter as tk
from tkinter import ttk

import cv2
import mss
import numpy as np

PORT = 48150
WIDTH, HEIGHT = 1280, 720
FPS = 60
JPEG_QUALITY = 70
MAGIC = b"PCVR1"


def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


class Host:
    def __init__(self, status):
        self.status = status
        self.running = False
        self.client = None
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("0.0.0.0", PORT))
        self.sock.settimeout(0.1)
        self.seq = 0

    def listen(self):
        while self.running:
            try:
                data, addr = self.sock.recvfrom(256)
                if data.startswith(b"HELLO"):
                    self.client = addr
                    self.status.set(f"Connected: {addr[0]}:{addr[1]}")
                    self.sock.sendto(b"WELCOME PCVR1", addr)
            except socket.timeout:
                pass

    def stream(self):
        interval = 1.0 / FPS
        next_frame = time.perf_counter()
        with mss.mss() as sct:
            monitor = sct.monitors[1]
            while self.running:
                now = time.perf_counter()
                if now < next_frame:
                    time.sleep(min(0.002, next_frame - now))
                    continue
                next_frame += interval
                if self.client is None:
                    continue
                raw = np.array(sct.grab(monitor))[:, :, :3]
                frame = cv2.cvtColor(raw, cv2.COLOR_BGR2RGB)
                frame = cv2.resize(frame, (WIDTH, HEIGHT), interpolation=cv2.INTER_AREA)
                ok, encoded = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY])
                if not ok:
                    continue
                payload = encoded.tobytes()
                # UDP packet framing. Frames larger than the network MTU are split into chunks.
                chunk_size = 60000
                count = (len(payload) + chunk_size - 1) // chunk_size
                self.seq = (self.seq + 1) & 0xFFFFFFFF
                for index in range(count):
                    chunk = payload[index * chunk_size:(index + 1) * chunk_size]
                    header = MAGIC + struct.pack("!IHH", self.seq, index, count)
                    try:
                        self.sock.sendto(header + chunk, self.client)
                    except OSError:
                        self.client = None
                        break

    def start(self):
        if self.running:
            return
        self.running = True
        self.status.set(f"Waiting for headset on {local_ip()}:{PORT}")
        threading.Thread(target=self.listen, daemon=True).start()
        threading.Thread(target=self.stream, daemon=True).start()

    def stop(self):
        self.running = False
        self.client = None
        self.status.set("Stopped")


def main():
    root = tk.Tk()
    root.title("Connect to PC VR")
    root.geometry("430x190")
    root.resizable(False, False)
    status = tk.StringVar(value="Ready")
    host = Host(status)

    ttk.Label(root, text="Connect to PC VR", font=("Segoe UI", 18, "bold")).pack(pady=(18, 5))
    ttk.Label(root, text=f"PC IP: {local_ip()}    Port: {PORT}").pack()
    ttk.Label(root, textvariable=status).pack(pady=12)
    buttons = ttk.Frame(root)
    buttons.pack()
    ttk.Button(buttons, text="Start", command=host.start).pack(side="left", padx=6)
    ttk.Button(buttons, text="Stop", command=host.stop).pack(side="left", padx=6)
    ttk.Button(buttons, text="Exit", command=lambda: (host.stop(), root.destroy())).pack(side="left", padx=6)
    root.protocol("WM_DELETE_WINDOW", lambda: (host.stop(), root.destroy()))
    root.mainloop()


if __name__ == "__main__":
    main()
