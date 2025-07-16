#!/usr/bin/env python3
"""
Continuous Vision Service for Zeus_STT
Always-on screen monitoring with Mem0 + Weaviate for persistent visual context

Implements research plan: Background monitor → GPT-4.1-mini analysis → Weaviate storage
"""

import os
import sys
import asyncio
import base64
import hashlib
import time
import json
import threading
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
import structlog

# Memory stack
import mem0
from vision_service import VisionService

# Set up logger
logger = structlog.get_logger()

@dataclass
class VisualContext:
    """Visual context stored in Mem0+Weaviate"""
    timestamp: float
    image_hash: str
    change_confidence: float
    app_context: str
    text_content: str
    spatial_elements: List[Dict]
    token_cost: int
    vlm_analysis: str

class ContinuousVisionService:
    """
    Always-on vision monitoring with Mem0+Weaviate storage
    
    Implements competitive advantages:
    - Continuous monitoring (vs. on-demand competitors)
    - Persistent memory (vs. session-only)  
    - <500ms voice response (vs. 5-10s cloud delays)
    """
    
    def __init__(self, capture_fps: float = 1.0):
        self.capture_fps = capture_fps
        self.running = False
        self.last_frame_hash = None
        self.vision_service = VisionService(disable_langfuse=True)
        self.monitor_thread = None
        
        # Initialize Mem0 with default config (use existing Qdrant from memory_service)
        # Will upgrade to Weaviate later after fixing import conflicts
        try:
            self.mem0_client = mem0.Memory()
            logger.info("✅ Mem0 initialized for continuous vision (using default Qdrant)")
        except Exception as e:
            logger.error(f"❌ Mem0 initialization failed: {e}")
            self.mem0_client = None
    
    def start_monitoring(self):
        """Start continuous vision monitoring in background thread"""
        if self.running:
            logger.warning("Vision monitoring already running")
            return
            
        self.running = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        logger.info(f"🔍 Started continuous vision monitoring at {self.capture_fps} FPS")
    
    def stop_monitoring(self):
        """Stop continuous vision monitoring"""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2.0)
        logger.info("⏹️ Stopped continuous vision monitoring")
    
    def _monitor_loop(self):
        """Main monitoring loop - runs in background thread"""
        while self.running:
            try:
                start_time = time.time()
                
                # Capture current screen (from Swift VisionCaptureManager)
                image_path = self._capture_current_screen()
                if not image_path:
                    time.sleep(1.0 / self.capture_fps)
                    continue
                
                # Check for significant changes (content diffing)
                change_confidence = self._detect_content_change(image_path)
                
                # Skip processing if no significant change (optimization)
                if change_confidence < 0.2:
                    # Adjust FPS for static periods (Cheating Daddy improvement)
                    self.capture_fps = max(0.5, self.capture_fps - 0.1)
                    time.sleep(1.0 / self.capture_fps)
                    continue
                
                # Increase FPS for active periods
                self.capture_fps = min(2.0, self.capture_fps + 0.1)
                
                # Process with VLM and store in Mem0+Weaviate
                self._process_and_store_context(image_path, change_confidence)
                
                # Maintain target FPS
                elapsed = time.time() - start_time
                sleep_time = max(0, (1.0 / self.capture_fps) - elapsed)
                time.sleep(sleep_time)
                
            except Exception as e:
                logger.error(f"❌ Vision monitoring error: {e}")
                time.sleep(1.0)  # Error recovery delay
    
    def _capture_current_screen(self) -> Optional[str]:
        """Capture current screen via XPC to Swift VisionCaptureManager"""
        try:
            # For now, use existing test image - will integrate with Swift later
            test_image = "/Users/devin/Desktop/vision_test_768.png"
            if os.path.exists(test_image):
                return test_image
            return None
        except Exception as e:
            logger.error(f"❌ Screen capture failed: {e}")
            return None
    
    def _detect_content_change(self, image_path: str) -> float:
        """Detect significant content changes using perceptual hashing"""
        try:
            with open(image_path, 'rb') as f:
                image_data = f.read()
            
            # Simple hash-based change detection (upgrade to pHash later)
            current_hash = hashlib.md5(image_data).hexdigest()
            
            if self.last_frame_hash is None:
                change_confidence = 1.0  # First frame
            else:
                # Simple comparison (upgrade to SSIM/perceptual hash later)
                change_confidence = 0.8 if current_hash != self.last_frame_hash else 0.1
            
            self.last_frame_hash = current_hash
            return change_confidence
            
        except Exception as e:
            logger.error(f"❌ Change detection failed: {e}")
            return 0.5  # Default moderate confidence
    
    def _process_and_store_context(self, image_path: str, change_confidence: float):
        """Process image with VLM and store in Mem0+Weaviate"""
        try:
            start_time = time.time()
            
            # Analyze with GPT-4.1-mini via LiteLLM
            prompt = "Describe this screen briefly. Extract all visible text and UI elements with their locations."
            context_result = self.vision_service.analyze_spatial_command(
                image_path, 
                prompt,
                context="continuous_monitoring"
            )
            
            # Calculate token cost (Cheating Daddy pattern)
            token_cost = self._calculate_token_cost(image_path)
            
            # Extract app context
            app_context = self._detect_app_context()
            
            # Handle VisionContext object (convert to dict if needed)
            if hasattr(context_result, 'to_dict'):
                context_dict = context_result.to_dict()
            else:
                context_dict = context_result
            
            # Create visual context object
            visual_context = VisualContext(
                timestamp=time.time(),
                image_hash=self.last_frame_hash,
                change_confidence=change_confidence,
                app_context=app_context,
                text_content=context_dict.get('full_analysis', ''),
                spatial_elements=context_dict.get('bounds', {}),
                token_cost=token_cost,
                vlm_analysis=context_dict.get('full_analysis', '')
            )
            
            # Store in Mem0+Weaviate for persistent memory
            if self.mem0_client:
                self._store_in_mem0(visual_context)
            
            processing_time = time.time() - start_time
            logger.debug(f"🔍 Processed visual context in {processing_time:.2f}s, confidence: {change_confidence:.2f}")
            
        except Exception as e:
            logger.error(f"❌ Context processing failed: {e}")
    
    def _store_in_mem0(self, context: VisualContext):
        """Store visual context in Mem0+Weaviate"""
        try:
            # Convert to Mem0 message format
            message = {
                "role": "system",
                "content": f"Screen context at {context.timestamp}: {context.text_content[:500]}..."
            }
            
            # Store with rich metadata
            metadata = {
                "type": "visual_context",
                "timestamp": context.timestamp,
                "app_context": context.app_context,
                "change_confidence": context.change_confidence,
                "token_cost": context.token_cost,
                "image_hash": context.image_hash
            }
            
            result = self.mem0_client.add(
                messages=[message],
                user_id="continuous_vision",
                metadata=metadata
            )
            
            logger.debug(f"✅ Stored visual context in Mem0+Weaviate")
            
        except Exception as e:
            logger.error(f"❌ Mem0 storage failed: {e}")
    
    def _calculate_token_cost(self, image_path: str) -> int:
        """Calculate token cost using Cheating Daddy's proven formula"""
        try:
            from PIL import Image
            with Image.open(image_path) as img:
                width, height = img.size
            
            # Cheating Daddy's exact formula
            BASE_IMAGE_TOKENS = 258  # Per 384px image
            if height <= 384:
                return BASE_IMAGE_TOKENS
            else:
                import math
                tiles_x = math.ceil(width / 384)
                tiles_y = math.ceil(height / 384)
                return tiles_x * tiles_y * BASE_IMAGE_TOKENS
                
        except Exception:
            return 258  # Default estimate
    
    def _detect_app_context(self) -> str:
        """Detect current active application"""
        try:
            # macOS app detection (placeholder - will integrate with Swift)
            import subprocess
            result = subprocess.run(['osascript', '-e', 'tell application "System Events" to get name of first application process whose frontmost is true'], capture_output=True, text=True)
            return result.stdout.strip() if result.returncode == 0 else "unknown"
        except Exception:
            return "unknown"
    
    def query_recent_context(self, command: str, limit: int = 5) -> List[Dict]:
        """Query recent visual context for voice command resolution"""
        if not self.mem0_client:
            return []
        
        try:
            # Query Mem0+Weaviate for relevant context
            results = self.mem0_client.search(
                query=command,
                user_id="continuous_vision",
                limit=limit
            )
            
            # Convert to context format (handle Mem0 result format)
            contexts = []
            for result in results:
                if isinstance(result, dict):
                    contexts.append({
                        "content": result.get("memory", ""),
                        "metadata": result.get("metadata", {}),
                        "timestamp": result.get("metadata", {}).get("timestamp", 0),
                        "relevance": result.get("score", 0)
                    })
                else:
                    # Handle string results from Mem0
                    contexts.append({
                        "content": str(result),
                        "metadata": {},
                        "timestamp": time.time(),
                        "relevance": 0.5
                    })
            
            logger.info(f"🔍 Found {len(contexts)} relevant visual contexts")
            return contexts
            
        except Exception as e:
            logger.error(f"❌ Context query failed: {e}")
            return []


# Global continuous vision service
continuous_vision = ContinuousVisionService()


# XPC Integration functions
def start_continuous_vision():
    """Start continuous vision monitoring (for XPC)"""
    continuous_vision.start_monitoring()
    return {"status": "started", "fps": continuous_vision.capture_fps}


def stop_continuous_vision():
    """Stop continuous vision monitoring (for XPC)"""
    continuous_vision.stop_monitoring()
    return {"status": "stopped"}


def query_visual_context(command: str, limit: int = 5) -> Dict[str, Any]:
    """Query visual context for voice command (for XPC)"""
    contexts = continuous_vision.query_recent_context(command, limit)
    return {
        "contexts": contexts,
        "count": len(contexts),
        "query": command
    }


# Test function
def test_continuous_vision():
    """Test continuous vision service"""
    print("🧪 Testing Continuous Vision Service")
    print("=" * 50)
    
    # Start monitoring
    continuous_vision.start_monitoring()
    print("✅ Started continuous monitoring")
    
    # Let it run for a few cycles
    time.sleep(5)
    
    # Query context
    test_commands = [
        "show me the code",
        "what's on screen",
        "find the text editor"
    ]
    
    for command in test_commands:
        print(f"\n🔍 Testing query: '{command}'")
        contexts = continuous_vision.query_recent_context(command)
        print(f"   Found {len(contexts)} contexts")
        for i, ctx in enumerate(contexts[:2]):
            print(f"   {i+1}. {ctx['content'][:100]}...")
    
    # Stop monitoring
    continuous_vision.stop_monitoring()
    print("\n✅ Test complete")


if __name__ == "__main__":
    test_continuous_vision()