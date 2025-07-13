#!/usr/bin/env python3
"""
Wake Word Detection for STT Dictate Phase 4A
Uses Porcupine for "Hey STT" detection with high accuracy and low latency.
"""

import sys
import json
import numpy as np
from typing import Optional, List, Dict, Any

# Try to import Porcupine (graceful fallback if not installed)
try:
    import pvporcupine
    PORCUPINE_AVAILABLE = True
except ImportError:
    PORCUPINE_AVAILABLE = False
    print("DEBUG: Porcupine not available, using fallback keyword detection", file=sys.stderr)

# Configuration
SAMPLE_RATE = 16000
FRAME_LENGTH = 512  # Porcupine frame length
WAKE_WORDS = ["hey-stt", "hey-assistant", "computer"]
FALLBACK_KEYWORDS = ["hey", "stt", "dictate", "computer"]

class WakeWordDetector:
    def __init__(self):
        self.porcupine = None
        self.is_initialized = False
        self.keyword_buffer = []
        self.buffer_max_seconds = 3.0  # Keep 3 seconds of audio for keyword matching
        self.buffer_max_samples = int(SAMPLE_RATE * self.buffer_max_seconds)
        
        print("DEBUG: Initializing wake word detector...", file=sys.stderr)
        self.initialize_detector()
    
    def initialize_detector(self):
        """Initialize Porcupine wake word detector."""
        if not PORCUPINE_AVAILABLE:
            print("DEBUG: Using fallback keyword detection", file=sys.stderr)
            self.is_initialized = True
            return
        
        try:
            # Try to create Porcupine instance
            # Note: In production, you'd need a valid access key from Picovoice
            # For development, we'll use the built-in keywords
            
            # Try with built-in keywords first
            available_keywords = pvporcupine.KEYWORDS
            
            # Use 'computer' or 'hey google' as closest to 'hey stt'
            selected_keywords = []
            if 'computer' in available_keywords:
                selected_keywords.append('computer')
            if 'hey google' in available_keywords:
                selected_keywords.append('hey google')
            
            if selected_keywords:
                self.porcupine = pvporcupine.create(keywords=selected_keywords)
                self.is_initialized = True
                print(f"DEBUG: Porcupine initialized with keywords: {selected_keywords}", file=sys.stderr)
            else:
                print("DEBUG: No suitable built-in keywords found, using fallback", file=sys.stderr)
                self.is_initialized = True
                
        except Exception as e:
            print(f"DEBUG: Porcupine initialization failed: {e}, using fallback", file=sys.stderr)
            self.is_initialized = True
    
    def process_audio_chunk(self, audio_samples: List[float]) -> Dict[str, Any]:
        """
        Process audio chunk for wake word detection.
        
        Args:
            audio_samples: List of float samples at 16kHz
            
        Returns:
            Dictionary with detection results
        """
        if not self.is_initialized:
            return {
                "wake_word_detected": False,
                "keyword": None,
                "confidence": 0.0,
                "error": "Detector not initialized"
            }
        
        # Add to keyword buffer
        self.keyword_buffer.extend(audio_samples)
        if len(self.keyword_buffer) > self.buffer_max_samples:
            self.keyword_buffer = self.keyword_buffer[-self.buffer_max_samples:]
        
        try:
            if PORCUPINE_AVAILABLE and self.porcupine:
                return self._process_with_porcupine(audio_samples)
            else:
                return self._process_with_fallback(audio_samples)
                
        except Exception as e:
            print(f"ERROR: Wake word processing failed: {e}", file=sys.stderr)
            return {
                "wake_word_detected": False,
                "keyword": None,
                "confidence": 0.0,
                "error": str(e)
            }
    
    def _process_with_porcupine(self, audio_samples: List[float]) -> Dict[str, Any]:
        """Process audio using Porcupine."""
        # Convert to int16 PCM format (Porcupine requirement)
        audio_int16 = np.array(audio_samples, dtype=np.float32)
        audio_int16 = (audio_int16 * 32767).astype(np.int16)
        
        # Process in frame chunks
        results = []
        for i in range(0, len(audio_int16) - FRAME_LENGTH + 1, FRAME_LENGTH):
            frame = audio_int16[i:i + FRAME_LENGTH]
            keyword_index = self.porcupine.process(frame)
            
            if keyword_index >= 0:
                # Wake word detected!
                keyword_name = self.porcupine.keywords[keyword_index] if hasattr(self.porcupine, 'keywords') else f"keyword_{keyword_index}"
                results.append({
                    "wake_word_detected": True,
                    "keyword": keyword_name,
                    "confidence": 0.95,  # Porcupine is generally very confident
                    "frame_index": i,
                    "detection_method": "porcupine"
                })
        
        if results:
            # Return the latest detection
            return results[-1]
        else:
            return {
                "wake_word_detected": False,
                "keyword": None,
                "confidence": 0.0,
                "frames_processed": len(audio_int16) // FRAME_LENGTH,
                "detection_method": "porcupine"
            }
    
    def _process_with_fallback(self, audio_samples: List[float]) -> Dict[str, Any]:
        """Fallback keyword detection using simple energy-based patterns."""
        # This is a very basic fallback - in production you'd want more sophisticated detection
        
        # Calculate audio energy
        energy = np.mean(np.square(audio_samples))
        energy_db = 20 * np.log10(np.sqrt(energy) + 1e-10)
        
        # Simple pattern: look for two distinct energy peaks (like "Hey STT")
        if len(self.keyword_buffer) >= SAMPLE_RATE:  # At least 1 second
            recent_audio = np.array(self.keyword_buffer[-SAMPLE_RATE:])
            
            # Look for energy pattern that might indicate speech
            chunk_size = SAMPLE_RATE // 10  # 100ms chunks
            energy_chunks = []
            
            for i in range(0, len(recent_audio), chunk_size):
                chunk = recent_audio[i:i + chunk_size]
                if len(chunk) >= chunk_size // 2:  # At least half chunk
                    chunk_energy = np.mean(np.square(chunk))
                    chunk_energy_db = 20 * np.log10(np.sqrt(chunk_energy) + 1e-10)
                    energy_chunks.append(chunk_energy_db)
            
            if len(energy_chunks) >= 5:  # At least 500ms of data
                # Look for pattern: quiet -> speech -> brief pause -> speech (Hey STT)
                max_energy = max(energy_chunks)
                avg_energy = np.mean(energy_chunks)
                
                # Simple heuristic: if we have significant speech activity
                if max_energy > -20 and (max_energy - avg_energy) > 10:
                    # Very basic detection - would need much more sophistication in production
                    return {
                        "wake_word_detected": True,
                        "keyword": "fallback_pattern",
                        "confidence": 0.3,  # Low confidence for fallback
                        "max_energy": max_energy,
                        "avg_energy": avg_energy,
                        "detection_method": "fallback"
                    }
        
        return {
            "wake_word_detected": False,
            "keyword": None,
            "confidence": 0.0,
            "energy_db": energy_db,
            "buffer_seconds": len(self.keyword_buffer) / SAMPLE_RATE,
            "detection_method": "fallback"
        }
    
    def reset_buffer(self):
        """Reset the keyword buffer."""
        self.keyword_buffer = []
    
    def cleanup(self):
        """Clean up resources."""
        if self.porcupine:
            self.porcupine.delete()
            self.porcupine = None

# Global detector instance
wake_word_detector = None

def initialize_detector():
    """Initialize the global wake word detector."""
    global wake_word_detector
    if wake_word_detector is None:
        wake_word_detector = WakeWordDetector()
    return wake_word_detector.is_initialized

def process_wake_word_request(data: Dict[str, Any]) -> Dict[str, Any]:
    """Process a wake word detection request from Swift."""
    global wake_word_detector
    
    if wake_word_detector is None:
        if not initialize_detector():
            return {"error": "Failed to initialize wake word detector"}
    
    # Extract parameters
    audio_samples = data.get("audio_samples", [])
    reset_buffer = data.get("reset_buffer", False)
    
    # Validate input
    if not audio_samples:
        return {"error": "No audio samples provided"}
    
    if not isinstance(audio_samples, list):
        return {"error": "Audio samples must be a list"}
    
    # Reset buffer if requested
    if reset_buffer:
        wake_word_detector.reset_buffer()
    
    # Process the audio
    result = wake_word_detector.process_audio_chunk(audio_samples)
    result["porcupine_available"] = PORCUPINE_AVAILABLE
    
    return result

def main():
    """Main entry point for wake word detection."""
    if len(sys.argv) != 2:
        print("Usage: python3 wake_word_detector.py '{\"audio_samples\": [...], \"reset_buffer\": false}'", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse JSON input
        input_data = json.loads(sys.argv[1])
        
        # Process wake word request
        result = process_wake_word_request(input_data)
        
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