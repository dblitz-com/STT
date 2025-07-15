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
MODEL_NAME = "qwen2.5:7b-instruct-q4_0"  # Excellent for text editing and instruction following
FALLBACK_MODEL = "mistral:7b"  # Good backup model
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

def get_context_specific_rules(app_category: str) -> str:
    """
    Get context-specific editing rules based on app category.
    """
    rules = {
        'email': """- Use formal, professional language appropriate for business emails
- Structure with clear paragraphs for longer content
- Be concise and direct in subject lines
- Use complete sentences and avoid contractions""",
        
        'messaging': """- Keep natural, conversational tone
- Use contractions and casual language where appropriate  
- Preserve emoji mentions as text (e.g., "thumbs up")
- Keep responses brief unless explicitly detailed""",
        
        'coding': """- Preserve technical terminology and code-related language
- Format code comments clearly and concisely
- Use precise technical language
- Structure documentation with clear explanations""",
        
        'document': """- Use clear, structured prose suitable for formal documents
- Organize content with proper paragraph breaks
- Maintain professional but accessible tone
- Ensure logical flow between ideas""",
        
        'meeting': """- Format as natural conversation flow
- Preserve important names and technical terms
- Use clear, professional language
- Structure action items as bullet points if mentioned""",
        
        'notes': """- Keep natural note-taking style
- Format lists and bullet points clearly
- Preserve key information and details
- Use concise but complete thoughts"""
    }
    
    return rules.get(app_category, "- Use appropriate tone for the context")

def call_ollama_api(text: str, model: str, context: dict = None) -> Optional[str]:
    """
    Call Ollama API to edit the text with context-aware prompts.
    """
    # Phase 3: Context-aware prompt generation
    tone_hint = context.get('tone_hint', 'neutral balanced tone') if context else 'neutral balanced tone'
    app_category = context.get('app_category', 'general') if context else 'general'
    
    # Base editing rules
    base_rules = """- Remove filler words (um, uh, like, you know, sort of, kind of)
- Correct grammar and sentence structure  
- Add proper punctuation and capitalization
- Format bullet points as lists with - if mentioned
- Preserve meaning and technical terms"""
    
    # Context-specific adaptations
    context_rules = get_context_specific_rules(app_category)
    
    prompt = f"""You are a precise transcript editor. Your task is to refine spoken text into polished written text using {tone_hint}.

Rules:
{base_rules}
{context_rules}
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

def edit_text(raw_text: str, context: dict = None) -> str:
    """
    Main function to edit raw transcript text with context awareness.
    Tries LLM first, falls back to simple processing.
    """
    if not raw_text or not raw_text.strip():
        return raw_text
    
    app_category = context.get('app_category', 'general') if context else 'general'
    print(f"DEBUG: Editing with context: {app_category}", file=sys.stderr)
    
    # Try primary model with context
    edited = call_ollama_api(raw_text, MODEL_NAME, context)
    if edited:
        print(f"DEBUG: Used {MODEL_NAME} for context-aware editing", file=sys.stderr)
        return edited
    
    # Try fallback model with context
    edited = call_ollama_api(raw_text, FALLBACK_MODEL, context)
    if edited:
        print(f"DEBUG: Used {FALLBACK_MODEL} for context-aware editing", file=sys.stderr)
        return edited
    
    # Fallback to simple regex processing
    print("DEBUG: Using simple regex fallback", file=sys.stderr)
    processed = simple_filler_removal(raw_text)
    processed = basic_punctuation(processed)
    
    return processed

def main():
    """
    Main entry point. Handles both legacy text input and Phase 3 JSON context input.
    """
    if len(sys.argv) != 2:
        print("Usage: python3 ai_editor.py 'raw text to edit' OR JSON context", file=sys.stderr)
        sys.exit(1)
    
    input_arg = sys.argv[1]
    
    # Phase 3: Try to parse as JSON for context-aware editing
    try:
        data = json.loads(input_arg)
        if isinstance(data, dict) and 'text' in data:
            # New JSON format with context
            raw_text = data['text']
            context = data.get('context', {})
            edited_text = edit_text(raw_text, context)
            print(f"DEBUG: Processed with context: {context.get('app_category', 'unknown')}", file=sys.stderr)
        else:
            # Invalid JSON structure, treat as plain text
            edited_text = edit_text(input_arg)
            print("DEBUG: Invalid JSON structure, treated as plain text", file=sys.stderr)
    except (json.JSONDecodeError, TypeError):
        # Not JSON, treat as legacy plain text input
        edited_text = edit_text(input_arg)
        print("DEBUG: Processed as legacy plain text input", file=sys.stderr)
    
    # Output only the edited text to stdout
    print(edited_text)

if __name__ == "__main__":
    main()