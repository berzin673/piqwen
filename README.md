# PiQwen - Local AI Assistant for Apple Watch + Raspberry Pi 5

A complete, offline AI system where an Apple Watch communicates directly with a Raspberry Pi 5 running Qwen2.5 2B locally via llama.cpp.

## Architecture

```
Apple Watch → Local Wi-Fi → Raspberry Pi 5 → Qwen2.5 2B (llama.cpp) → Raspberry Pi 5 → Local Wi-Fi → Apple Watch
```

## Features

- **Completely Offline**: No internet required during operation, no iPhone needed
- **Apple Watch Native App**: Independent watchOS app with SwiftUI
- **Local AI Inference**: Qwen2.5 2B runs on Raspberry Pi 5 4GB RAM via llama.cpp
- **FastAPI Server**: RESTful API with health check, chat, and streaming endpoints
- **Wi-Fi Hotspot**: Raspberry Pi creates its own access point (SSID: PiQwen)
- **Chat History**: Local storage on Apple Watch
- **Voice Input**: Uses watchOS built-in dictation (offline where supported)
- **Streaming Responses**: Progressive token display
- **Connection Monitoring**: Real-time status with auto-reconnect

## Hardware Requirements

- Raspberry Pi 5 (4GB RAM model)
- Apple Watch (Series 6 or later recommended for offline dictation)
- iPhone (only for initial app installation via Xcode)
- MicroSD card (32GB+ recommended)
- Power supply for Pi 5 (5V 5A USB-C)

## Raspberry Pi Setup

### 1. Install Raspberry Pi OS (64-bit)
Download and flash Raspberry Pi OS Lite (64-bit) to SD card.

### 2. Connect to Internet Temporarily
Connect Pi to internet via Ethernet for initial setup.

### 3. Run Installation Script
```bash
git clone https://github.com/yourusername/piqwen.git
cd piqwen
sudo ./piqwen/scripts/install.sh
```

The script will:
- Update system packages
- Install Python, llama.cpp dependencies, hostapd, dnsmasq
- Create virtual environment and install Python packages
- Download Qwen2.5 2B Q4_K_M model (~1.5GB)
- Configure Wi-Fi hotspot
- Install systemd service

### 4. Configure Wi-Fi Hotspot
```bash
sudo ./piqwen/scripts/setup_wifi.sh
```
Set your desired SSID and password (min 8 characters).

### 5. Start Service
```bash
sudo systemctl start piqwen
sudo systemctl status piqwen
```

### 6. Verify Operation
```bash
# Check health endpoint
curl http://192.168.4.1:8000/health

# Test chat
curl -X POST http://192.168.4.1:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello Qwen"}'
```

### 7. Go Offline
Disconnect Pi from internet. Reboot to verify fully offline operation:
```bash
sudo reboot
```

## Apple Watch App Setup

### 1. Open in Xcode
Open `PiQwen/PiQwen.xcodeproj` in Xcode 15+.

### 2. Configure Signing
- Select your Apple Developer Team
- Ensure "Watch Only App" target is selected
- Bundle Identifier: `com.yourname.piqwen`

### 3. Build and Install
- Connect Apple Watch to iPhone
- Select Watch target in Xcode
- Build and run (Cmd+R)
- App installs on Apple Watch

### 4. Configure on Watch
1. Open PiQwen app on Apple Watch
2. Go to Settings tab
3. Verify Server IP: `192.168.4.1`, Port: `8000`
4. Tap "Test Connection"
5. Connect Apple Watch to "PiQwen" Wi-Fi network

## Usage

1. Power on Raspberry Pi (wait ~60 seconds for boot)
2. On Apple Watch, connect to "PiQwen" Wi-Fi
3. Open PiQwen app
4. Tap "Ask Qwen" or use voice input
5. Type or dictate your question
6. Press Send
7. View response on Apple Watch

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/test` | GET | Simple test |
| `/chat` | POST | Chat completion |
| `/chat/stream` | POST | Streaming chat |
| `/config` | GET | Server configuration |

### Chat Request
```json
{
  "message": "What is 25 * 4?",
  "system_prompt": "You are a helpful assistant.",
  "max_tokens": 256,
  "temperature": 0.7,
  "top_p": 0.9,
  "stream": false
}
```

### Chat Response
```json
{
  "answer": "25 × 4 = 100.",
  "tokens_generated": 8,
  "duration_seconds": 1.2,
  "tokens_per_second": 6.7
}
```

## Configuration

### Raspberry Pi (config.py / environment variables)
```bash
PIQWEN_MODEL_PATH=/home/piqwen/piqwen/models/qwen2.5-2b-instruct-q4_k_m.gguf
PIQWEN_N_CTX=2048
PIQWEN_MAX_TOKENS=256
PIQWEN_TEMPERATURE=0.7
PIQWEN_N_THREADS=3
PIQWEN_API_KEY=your-secret-key  # optional
PIQWEN_SSID=PiQwen
PIQWEN_PASSWORD=your-password
```

### Apple Watch (Settings App)
- Server IP: `192.168.4.1`
- Port: `8000`
- Timeout: `60` seconds
- API Key: (if configured on Pi)

## Memory Optimization (4GB Pi)

The system is optimized for 4GB RAM:

- **Model**: Q4_K_M quantization (~1.5GB)
- **Context**: 2048 tokens (~8MB)
- **Max Output**: 256 tokens
- **Threads**: 3 of 4 cores (1 reserved for OS)
- **Batch Size**: 512
- **No GPU Offload**: CPU-only inference
- **Memory Limit**: 3GB via systemd

Expected RAM usage: ~2.5GB total (model + OS + inference)

## Performance

On Raspberry Pi 5 4GB:
- **First token latency**: ~2-4 seconds
- **Generation speed**: ~5-8 tokens/second
- **Memory usage**: ~2.5GB
- **Power consumption**: ~8-12W under load

## Troubleshooting

### Pi Not Accessible
- Check Pi is fully booted (green LED blinking)
- Verify Wi-Fi hotspot: `systemctl status hostapd dnsmasq`
- Check logs: `journalctl -u piqwen -f`

### Watch Can't Connect
- Ensure Watch is on "PiQwen" Wi-Fi (not iPhone hotspot)
- Check Settings → Server IP matches Pi (192.168.4.1)
- Try "Test Connection" in Settings

### Slow Responses
- First request loads model into memory (~5-10s)
- Subsequent requests faster
- Increase timeout in Settings if needed

### Out of Memory
- Reduce `n_ctx` in config.py
- Reduce `max_tokens`
- Ensure no other heavy processes running

## Project Structure

```
piqwen/
├── server/
│   ├── main.py          # FastAPI server
│   ├── ai.py            # llama.cpp integration
│   ├── config.py        # Configuration
│   └── requirements.txt
├── scripts/
│   ├── install.sh       # Full installation
│   ├── setup_wifi.sh    # Wi-Fi hotspot config
│   └── start.sh         # Service entry point
├── systemd/
│   └── piqwen.service   # Systemd service
└── models/              # GGUF models (downloaded)

PiQwen/
├── PiQwenApp.swift      # App entry point
├── Models/
│   ├── ChatMessage.swift
│   └── AppSettings.swift
├── Services/
│   ├── APIClient.swift
│   ├── ConnectionManager.swift
│   ├── SpeechManager.swift
│   └── HistoryManager.swift
└── Views/
    ├── ContentView.swift
    ├── ChatView.swift
    ├── ResponseView.swift
    ├── HistoryView.swift
    ├── SettingsView.swift
    └── StatusView.swift
```

## License

MIT License - See LICENSE file for details.

## Acknowledgments

- [Qwen](https://github.com/QwenLM/Qwen) by Alibaba Cloud
- [llama.cpp](https://github.com/ggerganov/llama.cpp) by Georgi Gerganov
- [FastAPI](https://fastapi.tiangolo.com/) by Sebastián Ramírez