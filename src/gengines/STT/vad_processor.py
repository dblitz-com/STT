#!/usr/bin/env python3
"""
Voice Activity Detection (VAD) Processor for STT Dictate Phase 4A
Uses Silero VAD for superior accuracy and low latency hands-free activation.
"""

import sys
import json
import numpy as np
import torch
import warnings
from typing import Optional, List, Dict, Any

# Suppress torch warnings for cleaner output
warnings.filterwarnings("ignore", category=UserWarning, module="torch")

# Configuration
SAMPLE_RATE = 16000
CHUNK_SIZE = 512  # 32ms chunks at 16kHz for real-time processing
DEFAULT_THRESHOLD = 0.5
BUFFER_SECONDS = 0.5  # Buffer 500ms of audio for context

class SileroVAD:
    def __init__(self):
        self.model = None
        self.utils = None
        self.is_initialized = False
        self.audio_buffer = []
        self.buffer_size = int(SAMPLE_RATE * BUFFER_SECONDS)
        
        print("DEBUG: Initializing Silero VAD...", file=sys.stderr)
        self.initialize_model()
    
    def initialize_model(self):
        """Initialize Silero VAD model with error handling."""
        try:
            # Load Silero VAD model
            self.model, self.utils = torch.hub.load(
                repo_or_dir='snakers4/silero-vad',
                model='silero_vad',
                force_reload=False,
                verbose=False
            )
            
            # Extract utility functions (handle different versions)
            if len(self.utils) >= 6:
                self.get_speech_ts, _, self.read_audio, _, _, _ = self.utils
            else:
                self.get_speech_ts, _, self.read_audio, _, _ = self.utils
            
            self.is_initialized = True
            print("DEBUG: Silero VAD initialized successfully", file=sys.stderr)
            
        except Exception as e:
            print(f"ERROR: Failed to initialize Silero VAD: {e}", file=sys.stderr)
            self.is_initialized = False
    
    def process_audio_chunk(self, audio_samples: List[float], threshold: float = DEFAULT_THRESHOLD) -> Dict[str, Any]:
        """
        Process a chunk of audio for voice activity detection.
        
        Args:
            audio_samples: List of float samples at 16kHz
            threshold: VAD sensitivity threshold (0.0-1.0)
            
        Returns:
            Dictionary with VAD results
        """
        if not self.is_initialized:
            return {
                "voice_detected": False,
                "confidence": 0.0,
                "error": "VAD not initialized"
            }
        
        try:
            # Convert to torch tensor
            audio_tensor = torch.FloatTensor(audio_samples)
            
            # Add to buffer for context
            self.audio_buffer.extend(audio_samples)
            if len(self.audio_buffer) > self.buffer_size:
                self.audio_buffer = self.audio_buffer[-self.buffer_size:]
            
            # Use buffered audio for better context
            if len(self.audio_buffer) >= CHUNK_SIZE:
                buffer_tensor = torch.FloatTensor(self.audio_buffer)
                
                # Get speech timestamps
                speech_timestamps = self.get_speech_ts(
                    buffer_tensor, 
                    self.model, 
                    threshold=threshold,
                    min_speech_duration_ms=30,  # Minimum 30ms speech
                    min_silence_duration_ms=100,  # Minimum 100ms silence
                    window_size_samples=CHUNK_SIZE
                )
                
                # Check if current chunk contains speech
                voice_detected = len(speech_timestamps) > 0
                
                # Calculate confidence based on recent speech activity
                if voice_detected:
                    # Use the confidence from the latest speech segment
                    latest_segment = speech_timestamps[-1]
                    confidence = 1.0  # Silero doesn't provide confidence, use binary
                else:
                    confidence = 0.0
                
                # Calculate energy for additional context
                energy = float(np.mean(np.square(audio_samples)))
                energy_db = 20 * np.log10(np.sqrt(energy) + 1e-10)
                
                return {
                    "voice_detected": voice_detected,
                    "confidence": confidence,
                    "energy_db": energy_db,
                    "speech_segments": len(speech_timestamps),
                    "chunk_samples": len(audio_samples),
                    "buffer_samples": len(self.audio_buffer)
                }
            else:
                # Not enough audio yet, return no detection
                return {
                    "voice_detected": False,
                    "confidence": 0.0,
                    "energy_db": -60.0,
                    "speech_segments": 0,
                    "chunk_samples": len(audio_samples),
                    "buffer_samples": len(self.audio_buffer),
                    "status": "buffering"
                }
                
        except Exception as e:
            print(f"ERROR: VAD processing failed: {e}", file=sys.stderr)
            return {
                "voice_detected": False,
                "confidence": 0.0,
                "error": str(e)
            }
    
    def reset_buffer(self):
        """Reset the audio buffer."""
        self.audio_buffer = []
    
    def get_adaptive_threshold(self, environment: str = "office") -> float:
        """Get adaptive threshold based on environment."""
        thresholds = {
            "office": 0.5,      # Standard office environment
            "home": 0.7,        # Quieter home environment (more sensitive)
            "outdoor": 0.3,     # Noisy outdoor environment (less sensitive)
            "meeting": 0.8,     # Very sensitive for meeting environments
            "noisy": 0.2        # Very noisy environment
        }
        return thresholds.get(environment, DEFAULT_THRESHOLD)

# Global VAD instance
vad_processor = None

def initialize_vad():
    """Initialize the global VAD processor."""
    global vad_processor
    if vad_processor is None:
        vad_processor = SileroVAD()
    return vad_processor.is_initialized

def process_vad_request(data: Dict[str, Any]) -> Dict[str, Any]:
    """Process a VAD request from Swift."""
    global vad_processor
    
    if vad_processor is None:
        if not initialize_vad():
            return {"error": "Failed to initialize VAD"}
    
    # Extract parameters
    audio_samples = data.get("audio_samples", [])
    threshold = data.get("threshold", DEFAULT_THRESHOLD)
    environment = data.get("environment", "office")
    reset_buffer = data.get("reset_buffer", False)
    
    # Validate input
    if not audio_samples:
        return {"error": "No audio samples provided"}
    
    if not isinstance(audio_samples, list):
        return {"error": "Audio samples must be a list"}
    
    # Reset buffer if requested
    if reset_buffer:
        vad_processor.reset_buffer()
    
    # Use adaptive threshold if environment specified
    if environment != "office":
        threshold = vad_processor.get_adaptive_threshold(environment)
    
    # Process the audio
    result = vad_processor.process_audio_chunk(audio_samples, threshold)
    result["threshold_used"] = threshold
    result["environment"] = environment
    
    return result

def main():
    """Main entry point for VAD processing."""
    if len(sys.argv) != 2:
        print("Usage: python3 vad_processor.py '{\"audio_samples\": [...], \"threshold\": 0.5}'", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse JSON input
        input_data = json.loads(sys.argv[1])
        
        # Process VAD request
        result = process_vad_request(input_data)
        
        # Output result as JSON
        print(json.dumps(result))
        
    except json.JSONDecodeError as e:
        error_result = {"error": f"Invalid JSON input: {e}"}
        print(json.dumps(error_result))
        
    except Exception as e:
        error_result = {"error": f"Unexpected error: {e}"}
        print(json.dumps(error_result))

if __name__ == "__main__":
    main()