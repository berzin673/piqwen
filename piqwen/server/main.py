"""PiQwen FastAPI Server - Main entry point
Optimized for Raspberry Pi 5 4GB RAM"""
import os
import time
import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException, Request, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel, Field

from config import config, load_config_from_env
from ai import get_ai_engine, initialize_ai, InferenceResult

# Configure logging
logging.basicConfig(
    level=getattr(logging, config.log_level),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(config.log_file) if os.path.exists(os.path.dirname(config.log_file)) else logging.NullHandler(),
    ]
)
logger = logging.getLogger(__name__)

# Load config from environment
app_config = load_config_from_env()


# Pydantic models for API
class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000, description="User message")
    system_prompt: Optional[str] = Field(None, description="Optional system prompt")
    max_tokens: Optional[int] = Field(None, ge=1, le=2048, description="Max tokens to generate")
    temperature: Optional[float] = Field(None, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: Optional[float] = Field(None, ge=0.0, le=1.0, description="Top-p sampling")
    top_k: Optional[int] = Field(None, ge=1, le=100, description="Top-k sampling")
    stream: bool = Field(False, description="Stream response")


class ChatResponse(BaseModel):
    answer: str
    tokens_generated: int
    duration_seconds: float
    tokens_per_second: float


class HealthResponse(BaseModel):
    status: str
    model: str
    device: str
    version: str = "1.0.0"
    uptime_seconds: float
    memory_usage_mb: Optional[float] = None


class ConfigResponse(BaseModel):
    model: str
    n_ctx: int
    max_tokens: int
    temperature: float
    n_threads: int
    server_port: int
    wifi_ssid: str


class TestResponse(BaseModel):
    message: str


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None


# Track server start time
_start_time = time.time()


def get_memory_usage() -> Optional[float]:
    """Get current memory usage in MB"""
    try:
        with open("/proc/self/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) / 1024  # Convert KB to MB
    except Exception:
        pass
    return None


# API Key dependency
async def verify_api_key(x_api_key: Optional[str] = Header(None)):
    """Verify API key if configured"""
    if app_config.server.api_key:
        if not x_api_key or x_api_key != app_config.server.api_key:
            raise HTTPException(status_code=401, detail="Invalid API key")
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting PiQwen AI Server...")
    logger.info(f"Config: host={app_config.server.host}, port={app_config.server.port}")
    logger.info(f"Model: {app_config.model.model_path}")
    
    # Initialize AI engine
    success = initialize_ai()
    if not success:
        engine = get_ai_engine()
        logger.error(f"Failed to initialize AI: {engine.get_init_error()}")
        # Don't fail startup - let health endpoint report the error
    else:
        logger.info("AI engine initialized successfully")
    
    yield
    
    # Shutdown
    logger.info("Shutting down PiQwen AI Server...")


# Create FastAPI app
app = FastAPI(
    title="PiQwen AI Server",
    description="Local AI server for Qwen2.5 2B on Raspberry Pi 5",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=app_config.server.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    client_ip = request.client.host if request.client else "unknown"
    
    logger.info(f"Request: {request.method} {request.url.path} from {client_ip}")
    
    response = await call_next(request)
    
    duration = time.time() - start
    logger.info(f"Response: {response.status_code} in {duration:.3f}s")
    
    return response


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Health check endpoint for Apple Watch connectivity test"""
    engine = get_ai_engine()
    model_info = engine.get_model_info()
    
    status = "ok" if engine.is_ready() else "degraded"
    
    return HealthResponse(
        status=status,
        model=model_info["model"],
        device="Raspberry Pi 5",
        uptime_seconds=time.time() - _start_time,
        memory_usage_mb=get_memory_usage(),
    )


@app.get("/test", response_model=TestResponse, tags=["Health"])
async def test_endpoint():
    """Simple test endpoint"""
    return TestResponse(message="PiQwen server works")


@app.get("/config", response_model=ConfigResponse, tags=["Config"])
async def get_config(_: bool = Depends(verify_api_key)):
    """Get server configuration"""
    return ConfigResponse(
        model="Qwen2.5 2B Instruct",
        n_ctx=app_config.model.n_ctx,
        max_tokens=app_config.model.max_tokens,
        temperature=app_config.model.temperature,
        n_threads=app_config.model.n_threads,
        server_port=app_config.server.port,
        wifi_ssid=app_config.wifi.ssid,
    )


@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest, _: bool = Depends(verify_api_key)):
    """Chat endpoint - non-streaming"""
    engine = get_ai_engine()
    
    if not engine.is_ready():
        error_msg = engine.get_init_error() or "Model not initialized"
        logger.error(f"Chat request failed: {error_msg}")
        raise HTTPException(status_code=503, detail=f"AI server unavailable: {error_msg}")
    
    try:
        result: InferenceResult = engine.generate(
            user_message=request.message,
            system_prompt=request.system_prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
            top_k=request.top_k,
        )
        
        return ChatResponse(
            answer=result.text,
            tokens_generated=result.tokens_generated,
            duration_seconds=result.duration_seconds,
            tokens_per_second=result.tokens_per_second,
        )
        
    except Exception as e:
        logger.exception("Chat generation failed")
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")


@app.post("/chat/stream", tags=["Chat"])
async def chat_stream(request: ChatRequest, _: bool = Depends(verify_api_key)):
    """Chat endpoint - streaming response"""
    engine = get_ai_engine()
    
    if not engine.is_ready():
        error_msg = engine.get_init_error() or "Model not initialized"
        logger.error(f"Stream request failed: {error_msg}")
        raise HTTPException(status_code=503, detail=f"AI server unavailable: {error_msg}")
    
    if not request.stream:
        # If streaming not requested, fall back to regular chat
        return await chat(request)
    
    async def generate_stream():
        try:
            start_time = time.time()
            token_count = 0
            
            for chunk in engine.generate_stream(
                user_message=request.message,
                system_prompt=request.system_prompt,
                max_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                top_k=request.top_k,
            ):
                token_count += len(chunk.split()) * 1.3
                yield f"data: {chunk}\n\n"
            
            duration = time.time() - start_time
            logger.info(f"Stream completed: ~{int(token_count)} tokens in {duration:.2f}s")
            yield "data: [DONE]\n\n"
            
        except Exception as e:
            logger.exception("Streaming failed")
            yield f"data: [ERROR] {str(e)}\n\n"
    
    return StreamingResponse(
        generate_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering if used
        },
    )


# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(error=exc.detail, detail=str(exc.status_code)).model_dump(),
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception")
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(error="Internal server error", detail=str(exc)).model_dump(),
    )


if __name__ == "__main__":
    import uvicorn
    
    # Ensure log directory exists
    os.makedirs(os.path.dirname(config.log_file), exist_ok=True)
    
    uvicorn.run(
        "main:app",
        host=app_config.server.host,
        port=app_config.server.port,
        log_level=config.log_level.lower(),
        access_log=True,
    )