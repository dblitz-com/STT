#!/usr/bin/env python3
"""
Test UI-TARS-1.5 directly via HuggingFace transformers
Bypass Ollama to determine if issues are Ollama-specific or model-specific
"""

import torch
from transformers import pipeline
from PIL import Image
import time
import sys

def test_uitars_hf():
    print("🧪 Testing UI-TARS-1.5 via HuggingFace Transformers (bypassing Ollama)")
    print("=" * 70)
    
    try:
        print("📦 Loading UI-TARS-1.5 model...")
        start_time = time.time()
        
        # Load UI-TARS via transformers pipeline from local directory (correct format)
        pipe = pipeline(
            "image-text-to-text", 
            model="./ui-tars-model",
            trust_remote_code=True
        )
        
        load_time = time.time() - start_time
        print(f"✅ Model loaded in {load_time:.2f}s")
        
        # Test with our VS Code screenshot
        image_path = "/Users/devin/Desktop/vision_test_768.png"
        print(f"📸 Processing image: {image_path}")
        
        # Load and verify image
        try:
            image = Image.open(image_path)
            print(f"   Image size: {image.size}")
            print(f"   Image format: {image.format}")
            print(f"   Image mode: {image.mode}")
        except Exception as e:
            print(f"❌ Failed to load image: {e}")
            return
        
        # Test with different prompts using correct UI-TARS format
        test_prompts = [
            "Describe this image briefly.",
            "What code is visible in this VS Code editor?",
            "List all Python imports and function definitions you can see in this screenshot."
        ]
        
        for i, prompt_text in enumerate(test_prompts, 1):
            print(f"\n🔍 Test {i}: {prompt_text}")
            print("-" * 50)
            
            try:
                start_time = time.time()
                
                # Create messages in UI-TARS format
                messages = [
                    {
                        "role": "user",
                        "content": [
                            {"type": "image", "image": image},
                            {"type": "text", "text": prompt_text}
                        ]
                    }
                ]
                
                # Generate response using correct format
                result = pipe(text=messages, max_new_tokens=200)
                
                response_time = time.time() - start_time
                
                if isinstance(result, list) and len(result) > 0:
                    response = result[0].get('generated_text', str(result))
                else:
                    response = str(result)
                
                print(f"⏱️  Response time: {response_time:.2f}s")
                print(f"📝 Response:")
                print(f"   {response}")
                
                # Basic quality check
                if len(response.strip()) < 10:
                    print("⚠️  WARNING: Very short response")
                elif '��' in response or 'científico' in response:
                    print("❌ CORRUPTION: Unicode artifacts or language bleed detected")
                elif 'vs code' in response.lower() or 'python' in response.lower() or 'import' in response.lower():
                    print("✅ GOOD: Relevant content detected")
                else:
                    print("❓ UNCERTAIN: Response needs manual evaluation")
                    
            except Exception as e:
                print(f"❌ Error during inference: {e}")
                print(f"   Error type: {type(e).__name__}")
                
        print("\n" + "=" * 70)
        print("🎯 HuggingFace UI-TARS test complete!")
        
    except Exception as e:
        print(f"❌ Failed to load UI-TARS model: {e}")
        print(f"   Error type: {type(e).__name__}")
        print("   This might indicate model compatibility issues")

if __name__ == "__main__":
    test_uitars_hf()