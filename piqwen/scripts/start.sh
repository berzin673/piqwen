#!/bin/bash
# PiQwen Start Script
# Starts the AI server with proper environment

set -e

# Configuration
VENV_PATH="/home/piqwen/piqwen/venv"
SERVER_PATH="/home/piqwen/piqwen/server"
LOG_DIR="/var/log/piqwen"

# Create log directory
mkdir -p "$LOG_DIR"
chown piqwen:piqwen "$LOG_DIR"

# Activate virtual environment and start server
echo "Starting PiQwen AI Server..."
echo "Virtual environment: $VENV_PATH"
echo "Server path: $SERVER_PATH"

cd "$SERVER_PATH"

# Set environment variables for optimization
export PYTHONUNBUFFERED=1
export PYTHONPATH="$SERVER_PATH:$PYTHONPATH"

# Memory optimization for 4GB Pi
export OMP_NUM_THREADS=3
export OPENBLAS_NUM_THREADS=3
export MKL_NUM_THREADS=3

# Start the server
exec "$VENV_PATH/bin/python" -m uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 1 \
    --log-level info \
    --access-log \
    --timeout-keep-alive 60