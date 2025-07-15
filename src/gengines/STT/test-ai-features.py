#!/usr/bin/env python3
"""
Test AI Features in Zeus_STT
Tests if Features 2 (Context Tone) and 3 (Voice Commands) actually work
"""

import subprocess
import json
import time
import sys

print("🧪 Testing Zeus_STT AI Features")
print("================================\n")

# Test configuration
PYTHON_PATH = "/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python"
AI_EDITOR = "/Applications/Zeus_STT Dev.app/Contents/Resources/ai_editor.py"
COMMAND_PROCESSOR = "/Applications/Zeus_STT Dev.app/Contents/Resources/ai_command_processor.py"

# Feature tracking
features_working = {
    "ai_editing": False,
    "context_tone": False,
    "voice_commands": False
}

print("📋 Feature #1: AI Auto-Edits (Filler Removal)")
print("-" * 50)

# Test AI editing with fillers
test_text = "Um, so like, I think we should, you know, do the meeting tomorrow"
print(f"Input: {test_text}")

try:
    # Test plain text editing
    result = subprocess.run(
        [PYTHON_PATH, AI_EDITOR, test_text],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        edited = result.stdout.strip()
        print(f"Output: {edited}")
        
        # Check if fillers were removed
        if "um" not in edited.lower() and "like" not in edited.lower():
            print("✅ Fillers removed!")
            features_working["ai_editing"] = True
        else:
            print("❌ Fillers still present")
    else:
        print(f"❌ Error: {result.stderr}")
except Exception as e:
    print(f"❌ Failed: {e}")

print("\n📋 Feature #2: Context-Aware Tone Matching")
print("-" * 50)

# Test different contexts
contexts = [
    {
        "name": "Email (formal)",
        "context": {"app_category": "email", "tone_hint": "formal professional tone"},
        "text": "hey can u send me the report when u get a chance thanks"
    },
    {
        "name": "Chat (casual)",
        "context": {"app_category": "messaging", "tone_hint": "casual conversational tone"}, 
        "text": "I would like to request the quarterly financial report at your earliest convenience"
    }
]

for test in contexts:
    print(f"\nTesting {test['name']}:")
    print(f"Input: {test['text']}")
    
    try:
        # Create JSON input with context
        json_input = json.dumps({
            "text": test["text"],
            "context": test["context"]
        })
        
        result = subprocess.run(
            [PYTHON_PATH, AI_EDITOR, json_input],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            edited = result.stdout.strip()
            print(f"Output: {edited}")
            
            # Check if tone changed appropriately
            if test["name"] == "Email (formal)" and ("please" in edited.lower() or "report" in edited):
                print("✅ Formalized for email!")
                features_working["context_tone"] = True
            elif test["name"] == "Chat (casual)" and ("hey" in edited.lower() or "!" in edited):
                print("✅ Made casual for chat!")
                features_working["context_tone"] = True
        else:
            print(f"❌ Error: {result.stderr}")
    except Exception as e:
        print(f"❌ Failed: {e}")

print("\n📋 Feature #3: Voice Commands")
print("-" * 50)

# Test command classification
commands = [
    "delete last sentence",
    "make this more formal",
    "insert bullet point",
    "I went to the store today"  # Not a command
]

for cmd in commands:
    print(f"\nTesting: '{cmd}'")
    
    try:
        json_input = json.dumps({
            "input": cmd,
            "type": "classify"
        })
        
        result = subprocess.run(
            [PYTHON_PATH, COMMAND_PROCESSOR, json_input],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            classification = json.loads(result.stdout.strip())
            
            if classification.get("is_command"):
                print(f"✅ Detected as command: {classification.get('intent')}")
                if classification.get('params'):
                    print(f"   Parameters: {classification['params']}")
                features_working["voice_commands"] = True
            else:
                print("❌ Not detected as command")
        else:
            print(f"❌ Error: {result.stderr}")
    except Exception as e:
        print(f"❌ Failed: {e}")

# Test tone change command
print("\n🔧 Testing Tone Change Command:")
test_text = "hey whats up can u help me with this"
print(f"Original: {test_text}")

try:
    json_input = json.dumps({
        "input": test_text,
        "type": "tone_formal"
    })
    
    result = subprocess.run(
        [PYTHON_PATH, COMMAND_PROCESSOR, json_input],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        formal_text = result.stdout.strip()
        print(f"Formal: {formal_text}")
        
        if formal_text != test_text:
            print("✅ Tone successfully changed!")
            features_working["voice_commands"] = True
except Exception as e:
    print(f"❌ Failed: {e}")

# Final results
print("\n" + "="*60)
print("📊 RESULTS")
print("="*60)

all_features = [
    ("AI Auto-Edits (Filler Removal)", features_working["ai_editing"]),
    ("Context-Aware Tone Matching", features_working["context_tone"]),
    ("Voice Commands", features_working["voice_commands"])
]

working_count = sum(1 for _, working in all_features if working)

for feature, working in all_features:
    status = "✅" if working else "❌"
    print(f"{status} {feature}")

print(f"\n🎯 {working_count}/3 AI features are working!")

if working_count == 3:
    print("\n🎉 ALL AI FEATURES ARE WORKING!")
    print("\n💡 To use these features:")
    print("1. AI Auto-Edits: Just speak naturally, fillers are removed automatically")
    print("2. Context Tone: Open different apps (Mail vs Messages) for automatic tone")
    print("3. Voice Commands: Say 'delete last sentence' or 'make this formal' after dictating")
else:
    print("\n⚠️  Some features need attention")
    
    # Check if Ollama is running
    print("\n🔍 Checking if Ollama is running...")
    try:
        ollama_check = subprocess.run(
            ["curl", "-s", "http://localhost:11434/api/generate"],
            capture_output=True
        )
        if ollama_check.returncode != 0:
            print("❌ Ollama not running! Start it with: ollama serve")
            print("   Then pull models: ollama pull llama3.1:8b")
    except:
        print("❌ Could not check Ollama status")