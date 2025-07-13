#!/usr/bin/env python3
# Note: This script should be run with the venv Python: ./venv/bin/python
"""
AI Editor for STT Dictate
Transforms raw speech transcripts into polished, edited text using local LLM via Ollama.
"""

import sys
import json
import requests
import re
from typing import Optional

# Configuration
OLLAMA_API_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "llama3.1:8b"
FALLBACK_MODEL = "phi3:mini"  # Smaller model as backup
REQUEST_TIMEOUT = 2.0  # 2 second timeout for real-time performance

def simple_filler_removal(text: str) -> str:
    """
    Simple regex-based filler word removal as fallback.
    """
    # Common filler words and patterns
    fillers = [
        r'\b(um|uh|er|ah|like|you know|sort of|kind of)\b',
        r'\b(so|well|okay|alright)\s+',  # At start of phrases
        r'\s+(um|uh|er|ah)\s+',  # Mid-sentence fillers
    ]
    
    result = text
    for pattern in fillers:
        result = re.sub(pattern, ' ', result, flags=re.IGNORECASE)
    
    # Clean up extra spaces
    result = re.sub(r'\s+', ' ', result).strip()
    
    return result

def basic_punctuation(text: str) -> str:
    """
    Add basic punctuation and capitalization.
    """
    if not text:
        return text
    
    # Capitalize first letter
    text = text[0].upper() + text[1:] if len(text) > 1 else text.upper()
    
    # Add period if no ending punctuation
    if not text.endswith(('.', '!', '?')):
        text += '.'
    
    return text

def call_ollama_api(text: str, model: str) -> Optional[str]:
    """
    Call Ollama API to edit the text.
    """
    prompt = f"""You are a precise transcript editor. Your task is to refine spoken text into polished written text.

Rules:
- Remove filler words (um, uh, like, you know, sort of, kind of)
- Correct grammar and sentence structure
- Add proper punctuation and capitalization
- Format bullet points as lists with - if mentioned
- Preserve meaning and technical terms
- Output only the refined text, nothing else

Raw transcript: {text}

Refined text:"""

    try:
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,  # Low temperature for consistent edits
                "top_p": 0.9,
                "num_predict": 500   # Limit response length
            }
        }
        
        response = requests.post(
            OLLAMA_API_URL,
            json=payload,
            timeout=REQUEST_TIMEOUT
        )
        
        if response.status_code == 200:
            result = response.json()
            edited_text = result.get("response", "").strip()
            
            # Basic validation - edited text shouldn't be empty or much longer
            if edited_text and len(edited_text) <= len(text) * 1.5:
                return edited_text
                
    except (requests.RequestException, json.JSONDecodeError, KeyError) as e:
        print(f"DEBUG: Ollama API error: {e}", file=sys.stderr)
        
    return None

def edit_text(raw_text: str) -> str:
    """
    Main function to edit raw transcript text.
    Tries LLM first, falls back to simple processing.
    """
    if not raw_text or not raw_text.strip():
        return raw_text
    
    # Try primary model
    edited = call_ollama_api(raw_text, MODEL_NAME)
    if edited:
        print(f"DEBUG: Used {MODEL_NAME} for editing", file=sys.stderr)
        return edited
    
    # Try fallback model
    edited = call_ollama_api(raw_text, FALLBACK_MODEL)
    if edited:
        print(f"DEBUG: Used {FALLBACK_MODEL} for editing", file=sys.stderr)
        return edited
    
    # Fallback to simple regex processing
    print("DEBUG: Using simple regex fallback", file=sys.stderr)
    processed = simple_filler_removal(raw_text)
    processed = basic_punctuation(processed)
    
    return processed

def main():
    """
    Main entry point. Reads raw text from command line argument.
    """
    if len(sys.argv) != 2:
        print("Usage: python3 ai_editor.py 'raw text to edit'", file=sys.stderr)
        sys.exit(1)
    
    raw_text = sys.argv[1]
    edited_text = edit_text(raw_text)
    
    # Output only the edited text to stdout
    print(edited_text)

if __name__ == "__main__":
    main()