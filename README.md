# Connect to PC VR

Wireless PC-to-VR desktop streaming prototype for standalone Android/OpenXR headsets (tested target: Meta Quest 2/3/3S).

## How it works

- **PC host:** captures the desktop, JPEG-compresses frames and sends them over the local Wi-Fi network.
- **VR client:** receives the stream and displays it on an immersive OpenXR screen.
- Both devices should be on the same 5 GHz Wi-Fi network. Ethernet from PC to the router is recommended.

> This first build is a low-latency desktop-view prototype. It does not yet provide SteamVR game injection, full 6DoF controller emulation, or audio streaming.

## Build

GitHub Actions builds the Windows host and Android APK automatically. Open **Actions → Build** and download the artifacts.

### PC

Run `ConnectToPCVR.exe`. It shows the local IP and streaming port (default `48150`). Allow it through Windows Firewall when prompted.

### Quest / Android

Install the generated APK, launch it, enter the PC IP, and connect. The headset must be on the same LAN.

## Performance

The host defaults to 1280×720 JPEG at 60 FPS with adaptive frame dropping. For a better result, use 5 GHz Wi-Fi 6 and connect the PC to the router by Ethernet.
