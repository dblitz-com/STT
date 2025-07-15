#!/usr/bin/env python3
"""
AI Command Processor for STT Dictate
Handles voice command detection, classification, and processing using local LLM via Ollama.
"""

import sys
import json
import requests
import re
from typing import Optional, Dict, Any

# Configuration
OLLAMA_API_URL = "http://localhost:11434/api/generate"
COMMAND_MODEL = "qwen2.5:7b-instruct-q4_0"  # Excellent for command classification and text editing
FALLBACK_MODEL = "mistral:7b"  # Good fallback model
REQUEST_TIMEOUT = 3.0  # 3 second timeout for command processing

# Command classification prompt
CLASSIFY_PROMPT = """You are a voice command classifier. Determine if the input is a voice command or regular dictation content.

Voice commands typically:
- Start with action words: delete, remove, insert, add, make, turn, select, replace
- Reference text positions: last word, last sentence, previous paragraph
- Request formatting: bold, italic, bullet points
- Request tone changes: formal, casual, professional

Examples:
- "delete last sentence" → {"is_command": true, "intent": "delete", "params": {"target": "last_sentence"}}
- "make this more formal" → {"is_command": true, "intent": "tone_change", "params": {"tone": "formal"}}
- "insert bullet point" → {"is_command": true, "intent": "insert", "params": {"content": "bullet_point"}}
- "I went to the store today" → {"is_command": false}

Text: "{input_text}"

Output ONLY valid JSON with is_command, intent, and params fields:"""

# Command processing prompts
COMMAND_PROMPTS = {
    "tone_formal": "Rewrite this text in a formal, professional tone while preserving the original meaning:\n\n{input_text}\n\nRewritten text:",
    "tone_casual": "Rewrite this text in a casual, conversational tone while preserving the original meaning:\n\n{input_text}\n\nRewritten text:",
    "tone_professional": "Rewrite this text in a professional business tone while preserving the original meaning:\n\n{input_text}\n\nRewritten text:",
    "summarize": "Provide a concise summary of this text:\n\n{input_text}\n\nSummary:",
    "expand": "Expand and elaborate on this text with more detail:\n\n{input_text}\n\nExpanded text:",
    "bullet_points": "Convert this text into bullet points:\n\n{input_text}\n\nBullet points:",
    "paragraph": "Convert this text into a well-structured paragraph:\n\n{input_text}\n\nParagraph:",
    "fix_grammar": "Fix any grammar errors in this text while preserving the original meaning:\n\n{input_text}\n\nCorrected text:"
}

def regex_command_check(text: str) -> Optional[Dict[str, Any]]:
    """
    Fast regex-based command detection for common patterns.
    Returns command structure if detected, None otherwise.
    """
    text_lower = text.lower().strip()
    
    # Delete commands
    if re.match(r'delete\s+(last\s+)?(word|sentence|paragraph)', text_lower):
        match = re.match(r'delete\s+(last\s+)?(\w+)', text_lower)
        target = f"last_{match.group(2)}" if match else "last_word"
        return {"is_command": True, "intent": "delete", "params": {"target": target}}
    
    # Insert commands
    if re.match(r'(insert|add)\s+(bullet\s+point|new\s+line|paragraph)', text_lower):
        if "bullet" in text_lower:
            return {"is_command": True, "intent": "insert", "params": {"content": "bullet_point"}}
        elif "line" in text_lower:
            return {"is_command": True, "intent": "insert", "params": {"content": "new_line"}}
        elif "paragraph" in text_lower:
            return {"is_command": True, "intent": "insert", "params": {"content": "new_paragraph"}}
    
    # Select commands
    if re.match(r'select\s+(last\s+)?(word|sentence|paragraph)', text_lower):
        match = re.match(r'select\s+(last\s+)?(\w+)', text_lower)
        target = f"last_{match.group(2)}" if match else "last_word"
        return {"is_command": True, "intent": "select", "params": {"target": target}}
    
    # Tone commands
    if re.match(r'make\s+(this\s+)?(more\s+)?(formal|casual|professional)', text_lower):
        match = re.search(r'(formal|casual|professional)', text_lower)
        tone = match.group(1) if match else "formal"
        return {"is_command": True, "intent": "tone_change", "params": {"tone": tone}}
    
    return None

def call_ollama_api(prompt: str, model: str) -> Optional[str]:
    """
    Call Ollama API with the given prompt and model.
    """
    try:
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.1,  # Low temperature for consistent classification
                "top_p": 0.9,
                "num_predict": 200   # Limit response length for classification
            }
        }
        
        response = requests.post(
            OLLAMA_API_URL,
            json=payload,
            timeout=REQUEST_TIMEOUT
        )
        
        if response.status_code == 200:
            result = response.json()
            return result.get("response", "").strip()
                
    except (requests.RequestException, json.JSONDecodeError, KeyError) as e:
        print(f"DEBUG: Ollama API error with {model}: {e}", file=sys.stderr)
        
    return None

def classify_text(text: str) -> Dict[str, Any]:
    """
    Classify if text is a command or content using LLM.
    """
    # First try fast regex detection
    regex_result = regex_command_check(text)
    if regex_result:
        print(f"DEBUG: Regex detected command: {regex_result}", file=sys.stderr)
        return regex_result
    
    # Fall back to LLM classification
    prompt = CLASSIFY_PROMPT.format(input_text=text)
    
    # Try primary model
    response = call_ollama_api(prompt, COMMAND_MODEL)
    if not response:
        # Try fallback model
        response = call_ollama_api(prompt, FALLBACK_MODEL)
    
    if response:
        try:
            # Try to extract JSON from response
            json_start = response.find('{')
            json_end = response.rfind('}') + 1
            if json_start >= 0 and json_end > json_start:
                json_str = response[json_start:json_end]
                result = json.loads(json_str)
                
                # Validate required fields
                if "is_command" in result:
                    print(f"DEBUG: LLM classified: {result}", file=sys.stderr)
                    return result
                    
        except json.JSONDecodeError as e:
            print(f"DEBUG: JSON parse error: {e}", file=sys.stderr)
    
    # Default to content if classification fails
    return {"is_command": False}

def process_command(command_type: str, input_text: str) -> str:
    """
    Process advanced commands that require LLM rewriting.
    """
    if command_type not in COMMAND_PROMPTS:
        return input_text
    
    prompt = COMMAND_PROMPTS[command_type].format(input_text=input_text)
    
    # Try primary model
    response = call_ollama_api(prompt, COMMAND_MODEL)
    if not response:
        # Try fallback model
        response = call_ollama_api(prompt, FALLBACK_MODEL)
    
    if response:
        # Clean up response (remove prompt echoes, etc.)
        cleaned = response.strip()
        if len(cleaned) > 0 and len(cleaned) <= len(input_text) * 3:  # Sanity check
            return cleaned
    
    print(f"DEBUG: Command processing failed for {command_type}", file=sys.stderr)
    return input_text

def main():
    """
    Main entry point. Processes JSON input from Swift.
    """
    if len(sys.argv) != 2:
        print("Usage: python3 ai_command_processor.py '{\"input\": \"text\", \"type\": \"classify\"}'", file=sys.stderr)
        sys.exit(1)
    
    try:
        data = json.loads(sys.argv[1])
        input_text = data.get("input", "")
        process_type = data.get("type", "classify")
        
        if process_type == "classify":
            # Command classification
            result = classify_text(input_text)
            print(json.dumps(result))
            
        elif process_type.startswith("tone_") or process_type in COMMAND_PROMPTS:
            # Command processing
            result = process_command(process_type, input_text)
            print(result)
            
        else:
            # Unknown type, return input
            print(input_text)
            
    except (json.JSONDecodeError, KeyError) as e:
        print(f"ERROR: Invalid input JSON: {e}", file=sys.stderr)
        print('{"is_command": false}')  # Safe fallback for classification
        
    except Exception as e:
        print(f"ERROR: Unexpected error: {e}", file=sys.stderr)
        print('{"is_command": false}')  # Safe fallback

if __name__ == "__main__":
    main()