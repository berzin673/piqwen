"""Configuration for PiQwen AI Server - Optimized for Raspberry Pi 5 4GB RAM"""
import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class ModelConfig:
    """Model configuration optimized for 4GB RAM"""
    # Model path - will be set during installation
    model_path: str = "/home/pi/piqwen/models/qwen2.5-2b-instruct-q4_k_m.gguf"
    
    # Context size - conservative for 4GB RAM
    # 2048 tokens = ~8KB for context, leaves plenty of RAM for OS and inference
    n_ctx: int = 2048
    
    # Maximum tokens to generate per response
    # 256 tokens keeps responses concise and memory usage low
    max_tokens: int = 256
    
    # Temperature for generation
    temperature: float = 0.7
    
    # Top-p sampling
    top_p: float = 0.9
    
    # Top-k sampling
    top_k: int = 40
    
    # Repeat penalty
    repeat_penalty: float = 1.1
    
    # Number of threads - leave 1-2 cores for OS
    # Raspberry Pi 5 has 4 cores, use 3 for inference
    n_threads: int = 3
    
    # Batch size for prompt processing
    # Smaller batch = less memory, slower prompt processing
    n_batch: int = 512
    
    # Use metal/GPU acceleration if available (not on Pi 5)
    n_gpu_layers: int = 0
    
    # Use mmap for model loading (faster startup, uses virtual memory)
    use_mmap: bool = True
    
    # Use mlock to keep model in RAM (prevents swapping, uses more RAM)
    # Disabled for 4GB to allow OS to manage memory
    use_mlock: bool = False
    
    # Embedding mode (not used for chat)
    embedding: bool = False
    
    # Verbose llama.cpp output
    verbose: bool = False


@dataclass
class ServerConfig:
    """FastAPI server configuration"""
    host: str = "0.0.0.0"
    port: int = 8000
    
    # Request timeout in seconds
    # 60 seconds allows for slower inference on 4GB Pi
    request_timeout: int = 60
    
    # Streaming timeout (longer for streaming responses)
    stream_timeout: int = 120
    
    # API key for simple auth (optional)
    api_key: Optional[str] = None
    
    # CORS origins (empty = allow all for local network)
    cors_origins: list = None
    
    def __post_init__(self):
        if self.cors_origins is None:
            self.cors_origins = ["*"]


@dataclass
class WiFiConfig:
    """Wi-Fi hotspot configuration"""
    ssid: str = "PiQwen"
    password: str = "piqwen2024"  # Change during setup
    interface: str = "wlan0"
    ip: str = "192.168.4.1"
    netmask: str = "255.255.255.0"
    dhcp_start: str = "192.168.4.10"
    dhcp_end: str = "192.168.4.100"


@dataclass
class AppConfig:
    """Main application configuration"""
    model: ModelConfig = ModelConfig()
    server: ServerConfig = ServerConfig()
    wifi: WiFiConfig = WiFiConfig()
    
    # Logging
    log_level: str = "INFO"
    log_file: str = "/var/log/piqwen/server.log"
    
    # Paths
    model_dir: str = "/home/pi/piqwen/models"
    data_dir: str = "/home/pi/piqwen/data"


# Global config instance
config = AppConfig()


def load_config_from_env() -> AppConfig:
    """Load configuration from environment variables"""
    cfg = AppConfig()
    
    # Model config from env
    if os.getenv("PIQWEN_MODEL_PATH"):
        cfg.model.model_path = os.getenv("PIQWEN_MODEL_PATH")
    if os.getenv("PIQWEN_N_CTX"):
        cfg.model.n_ctx = int(os.getenv("PIQWEN_N_CTX"))
    if os.getenv("PIQWEN_MAX_TOKENS"):
        cfg.model.max_tokens = int(os.getenv("PIQWEN_MAX_TOKENS"))
    if os.getenv("PIQWEN_TEMPERATURE"):
        cfg.model.temperature = float(os.getenv("PIQWEN_TEMPERATURE"))
    if os.getenv("PIQWEN_N_THREADS"):
        cfg.model.n_threads = int(os.getenv("PIQWEN_N_THREADS"))
    
    # Server config from env
    if os.getenv("PIQWEN_HOST"):
        cfg.server.host = os.getenv("PIQWEN_HOST")
    if os.getenv("PIQWEN_PORT"):
        cfg.server.port = int(os.getenv("PIQWEN_PORT"))
    if os.getenv("PIQWEN_API_KEY"):
        cfg.server.api_key = os.getenv("PIQWEN_API_KEY")
    
    # WiFi config from env
    if os.getenv("PIQWEN_SSID"):
        cfg.wifi.ssid = os.getenv("PIQWEN_SSID")
    if os.getenv("PIQWEN_PASSWORD"):
        cfg.wifi.password = os.getenv("PIQWEN_PASSWORD")
    
    return cfg