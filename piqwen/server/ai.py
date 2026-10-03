"""AI Module - Handles llama.cpp inference for Qwen3.5 2B
Optimized for Raspberry Pi 5 4GB RAM"""
import os
import time
import logging
from typing import Optional, Generator, Dict, Any
from dataclasses import dataclass

from config import config, ModelConfig

logger = logging.getLogger(__name__)

# Try to import llama_cpp_python
try:
    from llama_cpp import Llama
    LLAMA_CPP_AVAILABLE = True
except ImportError:
    LLAMA_CPP_AVAILABLE = False
    Llama = None


@dataclass
class InferenceResult:
    """Result of an inference request"""
    text: str
    tokens_generated: int
    duration_seconds: float
    tokens_per_second: float


class AIEngine:
    """Manages llama.cpp model and inference"""
    
    def __init__(self, model_config: Optional[ModelConfig] = None):
        self.model_config = model_config or config.model
        self.llm: Optional[Llama] = None
        self._initialized = False
        self._init_error: Optional[str] = None
    
    def initialize(self) -> bool:
        """Initialize the llama.cpp model"""
        if self._initialized:
            return True
            
        if not LLAMA_CPP_AVAILABLE:
            self._init_error = "llama-cpp-python not installed. Run: pip install llama-cpp-python"
            logger.error(self._init_error)
            return False
        
        model_path = self.model_config.model_path
        if not os.path.exists(model_path):
            self._init_error = f"Model not found at {model_path}"
            logger.error(self._init_error)
            return False
        
        try:
            logger.info(f"Loading model from {model_path}")
            logger.info(f"Config: n_ctx={self.model_config.n_ctx}, n_threads={self.model_config.n_threads}, "
                       f"n_batch={self.model_config.n_batch}, n_gpu_layers={self.model_config.n_gpu_layers}")
            
            start_time = time.time()
            
            self.llm = Llama(
                model_path=model_path,
                n_ctx=self.model_config.n_ctx,
                n_threads=self.model_config.n_threads,
                n_batch=self.model_config.n_batch,
                n_gpu_layers=self.model_config.n_gpu_layers,
                use_mmap=self.model_config.use_mmap,
                use_mlock=self.model_config.use_mlock,
                embedding=self.model_config.embedding,
                verbose=self.model_config.verbose,
                # Additional memory optimization
                offload_kqv=True,  # Offload KQV to CPU (saves VRAM, not applicable but safe)
                flash_attn=False,  # Disable flash attention for compatibility
            )
            
            load_time = time.time() - start_time
            logger.info(f"Model loaded in {load_time:.2f} seconds")
            self._initialized = True
            return True
            
        except Exception as e:
            self._init_error = f"Failed to initialize model: {str(e)}"
            logger.exception(self._init_error)
            return False
    
    def is_ready(self) -> bool:
        """Check if model is ready for inference"""
        return self._initialized and self.llm is not None
    
    def get_init_error(self) -> Optional[str]:
        """Get initialization error if any"""
        return self._init_error
    
    def _build_prompt(self, user_message: str, system_prompt: Optional[str] = None) -> str:
        """Build chat prompt for Qwen2.5-Instruct format"""
        # Qwen2.5 uses ChatML format
        if system_prompt is None:
            system_prompt = ("You are a helpful, concise AI assistant running locally on a Raspberry Pi. "
                           "Keep responses brief and to the point.")
        
        prompt = f"<|im_start|>system\n{system_prompt}<|im_end|>\n"
        prompt += f"<|im_start|>user\n{user_message}<|im_end|>\n"
        prompt += f"<|im_start|>assistant\n"
        return prompt
    
    def generate(self, user_message: str, system_prompt: Optional[str] = None,
                 max_tokens: Optional[int] = None, temperature: Optional[float] = None,
                 top_p: Optional[float] = None, top_k: Optional[int] = None) -> InferenceResult:
        """Generate a complete response (non-streaming)"""
        if not self.is_ready():
            raise RuntimeError(f"Model not initialized: {self._init_error}")
        
        prompt = self._build_prompt(user_message, system_prompt)
        
        # Use config defaults if not overridden
        max_tokens = max_tokens or self.model_config.max_tokens
        temperature = temperature if temperature is not None else self.model_config.temperature
        top_p = top_p if top_p is not None else self.model_config.top_p
        top_k = top_k if top_k is not None else self.model_config.top_k
        
        start_time = time.time()
        
        try:
            logger.info(f"Generating response for: {user_message[:50]}...")
            
            output = self.llm(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                top_k=top_k,
                repeat_penalty=self.model_config.repeat_penalty,
                stop=["<|im_end|>", "<|im_start|>"],
                echo=False,
            )
            
            duration = time.time() - start_time
            
            # Extract generated text
            generated_text = output["choices"][0]["text"].strip()
            
            # Count tokens (approximate)
            tokens_generated = len(generated_text.split()) * 1.3  # rough estimate
            
            result = InferenceResult(
                text=generated_text,
                tokens_generated=int(tokens_generated),
                duration_seconds=duration,
                tokens_per_second=tokens_generated / duration if duration > 0 else 0
            )
            
            logger.info(f"Generated {result.tokens_generated} tokens in {duration:.2f}s "
                       f"({result.tokens_per_second:.1f} tok/s)")
            
            return result
            
        except Exception as e:
            logger.exception("Generation failed")
            raise RuntimeError(f"Generation failed: {str(e)}")
    
    def generate_stream(self, user_message: str, system_prompt: Optional[str] = None,
                        max_tokens: Optional[int] = None, temperature: Optional[float] = None,
                        top_p: Optional[float] = None, top_k: Optional[int] = None) -> Generator[str, None, None]:
        """Generate streaming response"""
        if not self.is_ready():
            raise RuntimeError(f"Model not initialized: {self._init_error}")
        
        prompt = self._build_prompt(user_message, system_prompt)
        
        max_tokens = max_tokens or self.model_config.max_tokens
        temperature = temperature if temperature is not None else self.model_config.temperature
        top_p = top_p if top_p is not None else self.model_config.top_p
        top_k = top_k if top_k is not None else self.model_config.top_k
        
        try:
            logger.info(f"Streaming response for: {user_message[:50]}...")
            
            stream = self.llm(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                top_k=top_k,
                repeat_penalty=self.model_config.repeat_penalty,
                stop=["<|im_end|>", "<|im_start|>"],
                echo=False,
                stream=True,
            )
            
            for chunk in stream:
                if chunk["choices"][0]["text"]:
                    yield chunk["choices"][0]["text"]
                    
        except Exception as e:
            logger.exception("Streaming generation failed")
            raise RuntimeError(f"Streaming failed: {str(e)}")
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get model information for health endpoint"""
        return {
            "model": "Qwen2.5 2B Instruct",
            "model_path": self.model_config.model_path,
            "n_ctx": self.model_config.n_ctx,
            "max_tokens": self.model_config.max_tokens,
            "temperature": self.model_config.temperature,
            "n_threads": self.model_config.n_threads,
            "n_gpu_layers": self.model_config.n_gpu_layers,
            "initialized": self._initialized,
            "error": self._init_error,
        }


# Global AI engine instance
_ai_engine: Optional[AIEngine] = None


def get_ai_engine() -> AIEngine:
    """Get or create the global AI engine instance"""
    global _ai_engine
    if _ai_engine is None:
        _ai_engine = AIEngine()
    return _ai_engine


def initialize_ai() -> bool:
    """Initialize the global AI engine"""
    engine = get_ai_engine()
    return engine.initialize()