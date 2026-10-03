#!/bin/bash
# PiQwen Installation Script for Raspberry Pi 5 4GB RAM
# Run with: sudo ./install.sh

set -e  # Exit on error

echo "========================================"
echo "PiQwen Installation Script"
echo "Raspberry Pi 5 4GB RAM Optimized"
echo "========================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Check Raspberry Pi model
PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
echo "Detected hardware: $PI_MODEL"

# Check RAM
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
echo "Total RAM: ${TOTAL_RAM_GB}GB"

if [[ $TOTAL_RAM_GB -lt 4 ]]; then
    echo "WARNING: Less than 4GB RAM detected. Performance may be limited."
fi

# Update system
echo ""
echo "[1/8] Updating system packages..."
apt-get update
apt-get upgrade -y

# Install system dependencies
echo ""
echo "[2/8] Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    hostapd \
    dnsmasq \
    iptables \
    net-tools \
    wireless-tools \
    iw \
    libopenblas-dev \
    libomp-dev \
    pkg-config

# Create piqwen user if not exists
echo ""
echo "[3/8] Setting up piqwen user and directories..."
id -u piqwen &>/dev/null || useradd -r -s /bin/bash -m -d /home/piqwen piqwen
usermod -a -G dialout,gpio,i2c,spi,video piqwen

# Create directories
mkdir -p /home/piqwen/piqwen/{models,scripts,logs,data}
mkdir -p /var/log/piqwen
chown -R piqwen:piqwen /home/piqwen/piqwen
chown -R piqwen:piqwen /var/log/piqwen

# Create Python virtual environment
echo ""
echo "[4/8] Creating Python virtual environment..."
sudo -u piqwen python3 -m venv /home/piqwen/piqwen/venv
sudo -u piqwen /home/piqwen/piqwen/venv/bin/pip install --upgrade pip setuptools wheel

# Install llama-cpp-python with optimizations for Raspberry Pi 5
echo ""
echo "[5/8] Installing llama-cpp-python (optimized for Pi 5)..."
# Use BLAS=ON for better CPU performance on Pi 5
sudo -u piqwen /home/piqwen/piqwen/venv/bin/pip install \
    --no-cache-dir \
    llama-cpp-python==0.3.4

# Install Python dependencies
echo ""
echo "[6/8] Installing Python dependencies..."
sudo -u piqwen /home/piqwen/piqwen/venv/bin/pip install --no-cache-dir -r /home/piqwen/piqwen/server/requirements.txt

# Download Qwen2.5 2B Instruct GGUF model
echo ""
echo "[7/8] Downloading Qwen2.5 2B Instruct Q4_K_M model..."
MODEL_DIR="/home/piqwen/piqwen/models"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-2B-Instruct-GGUF/resolve/main/qwen2.5-2b-instruct-q4_k_m.gguf"
MODEL_PATH="$MODEL_DIR/qwen2.5-2b-instruct-q4_k_m.gguf"

if [[ -f "$MODEL_PATH" ]]; then
    echo "Model already exists at $MODEL_PATH"
else
    echo "Downloading model (approx 1.5GB)..."
    sudo -u piqwen wget --progress=bar:force:noscroll -O "$MODEL_PATH" "$MODEL_URL"
    echo "Model downloaded successfully"
fi

# Verify model
if [[ -f "$MODEL_PATH" ]]; then
    MODEL_SIZE=$(stat -c%s "$MODEL_PATH")
    MODEL_SIZE_MB=$((MODEL_SIZE / 1024 / 1024))
    echo "Model size: ${MODEL_SIZE_MB}MB"
    
    # Quick test
    echo "Testing model load..."
    sudo -u piqwen /home/piqwen/piqwen/venv/bin/python3 -c "
from llama_cpp import Llama
llm = Llama(model_path='$MODEL_PATH', n_ctx=2048, n_threads=3, verbose=False)
print('Model load test successful!')
"
else
    echo "ERROR: Model download failed!"
    exit 1
fi

# Configure Wi-Fi hotspot
echo ""
echo "[8/8] Configuring Wi-Fi hotspot..."
# This will be done by setup_wifi.sh

# Copy server files to piqwen home
echo ""
echo "Copying server files..."
cp -r /home/piqwen/piqwen/server /home/piqwen/piqwen/
cp -r /home/piqwen/piqwen/scripts /home/piqwen/piqwen/
cp -r /home/piqwen/piqwen/systemd /home/piqwen/piqwen/
chown -R piqwen:piqwen /home/piqwen/piqwen

# Setup WiFi hotspot
echo ""
echo "Setting up Wi-Fi hotspot..."
/home/piqwen/piqwen/scripts/setup_wifi.sh

# Install systemd service
echo ""
echo "Installing systemd service..."
cp /home/piqwen/piqwen/systemd/piqwen.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable piqwen.service

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Configure Wi-Fi password: sudo /home/piqwen/piqwen/scripts/setup_wifi.sh"
echo "2. Start the service: sudo systemctl start piqwen"
echo "3. Check status: sudo systemctl status piqwen"
echo "4. View logs: sudo journalctl -u piqwen -f"
echo ""
echo "The server will be available at:"
echo "  http://192.168.4.1:8000/health"
echo "  http://192.168.4.1:8000/chat"
echo ""
echo "Wi-Fi hotspot:"
echo "  SSID: PiQwen"
echo "  Password: (set during setup_wifi.sh)"
echo ""
echo "After testing, disconnect from internet and reboot to verify offline operation."