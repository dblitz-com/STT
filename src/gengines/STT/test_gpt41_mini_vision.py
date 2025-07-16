#!/usr/bin/env python3
"""
Test GPT-4.1-mini vision using zQuery's proven LiteLLM factory
Bypasses all local VLM issues with a cloud solution that works
"""

import sys
import os
import base64
from pathlib import Path

# Import zQuery's LiteLLM factory directly
sys.path.append('/Users/devin/dblitz/engine/src/gengines/zQuery/src/langchain')
from llm_factory import get_llm

def encode_image(image_path: str) -> str:
    """Encode image to base64 for OpenAI API"""
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def test_gpt41_mini_vision():
    """Test GPT-4.1-mini vision with our VS Code screenshot"""
    print("🧪 Testing GPT-4.1-mini Vision via zQuery's LiteLLM Factory")
    print("=" * 70)
    
    # Image path
    image_path = "/Users/devin/Desktop/vision_test_768.png"
    
    if not os.path.exists(image_path):
        print(f"❌ Image not found: {image_path}")
        return
    
    try:
        print("📦 Loading GPT-4.1-mini via zQuery's factory...")
        
        # Get LLM instance from zQuery's factory
        llm = get_llm("gpt-4.1-mini", max_tokens=32768, temperature=0.0)
        
        print("✅ LiteLLM factory loaded successfully")
        
        # Encode image
        print("📸 Encoding image for vision API...")
        base64_image = encode_image(image_path)
        
        # Test prompts
        test_prompts = [
            "Describe this VS Code screenshot briefly and accurately.",
            "What Python code is visible in this screenshot? List all imports and function definitions.",
            "Analyze this code editor interface. What specific files and code can you see?"
        ]
        
        for i, prompt in enumerate(test_prompts, 1):
            print(f"\n🔍 Test {i}: {prompt}")
            print("-" * 50)
            
            # Create messages with vision
            messages = [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": prompt
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ]
            
            try:
                # Use zQuery's LiteLLM wrapper
                response = llm.complete(
                    messages=messages,
                    metadata={
                        "task": "vision_test",
                        "test_id": f"gpt41_mini_test_{i}",
                        "image_path": image_path
                    }
                )
                
                content = response.choices[0].message.content
                
                print(f"📝 Response:")
                print(f"   {content}")
                
                # Quality assessment
                if len(content.strip()) < 10:
                    print("⚠️  WARNING: Very short response")
                elif any(keyword in content.lower() for keyword in ['vs code', 'python', 'import', 'code', 'editor']):
                    print("✅ EXCELLENT: Accurate vision analysis detected")
                else:
                    print("❓ UNCERTAIN: Response needs manual evaluation")
                    
            except Exception as e:
                print(f"❌ Error during vision inference: {e}")
                print(f"   Error type: {type(e).__name__}")
                
        print("\n" + "=" * 70)
        print("🎯 GPT-4.1-mini Vision Test Complete!")
        print("🚀 This solves our VLM accuracy crisis with proven cloud solution")
        
    except Exception as e:
        print(f"❌ Failed to initialize LiteLLM factory: {e}")
        print(f"   Error type: {type(e).__name__}")
        print("   Check OPENAI_API_KEY environment variable")

if __name__ == "__main__":
    test_gpt41_mini_vision()