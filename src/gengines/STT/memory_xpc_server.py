#!/usr/bin/env python3
"""
Memory XPC Server for Zeus_STT
Simple HTTP server that provides memory services to Swift via HTTP (simulating XPC)
Implements proven zQuery memory patterns for <50ms response times
"""

import json
import time
import logging
from typing import Dict, Any
from flask import Flask, request, jsonify
from memory_service import MemoryService, MemoryXPCService

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Initialize Flask app for HTTP-based XPC simulation
app = Flask(__name__)

# Global memory service instance
memory_xpc_service = MemoryXPCService()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        # Basic health check - verify memory service is available
        is_healthy = memory_xpc_service.memory_service.mem0_client is not None
        return jsonify({
            "status": "healthy" if is_healthy else "degraded",
            "timestamp": time.time(),
            "mem0_available": memory_xpc_service.memory_service.mem0_client is not None,
            "graphiti_available": memory_xpc_service.memory_service.graphiti_client is not None
        })
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

@app.route('/resolve_context', methods=['POST'])
def resolve_context():
    """
    Resolve context for voice command - main memory endpoint
    
    Expected JSON:
    {
        "command": "make this formal",
        "ocr_text": "Hello world this is a test",
        "session_id": "user_session_123"
    }
    """
    start_time = time.time()
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        command = data.get('command', '')
        ocr_text = data.get('ocr_text', '')
        session_id = data.get('session_id', 'default')
        
        if not command:
            return jsonify({"error": "Command is required"}), 400
        
        # Use XPC service to resolve context
        result_json = memory_xpc_service.resolve_context_xpc(command, ocr_text, session_id)
        result = json.loads(result_json)
        
        # Add timing information
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"✅ Resolved context for '{command}' in {result['latency_ms']:.1f}ms")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Context resolution failed: {e}")
        return jsonify({
            "resolved_target": "",
            "confidence": 0.0,
            "method": "error",
            "error": str(e),
            "latency_ms": (time.time() - start_time) * 1000
        }), 500

@app.route('/add_context', methods=['POST'])
def add_context():
    """
    Add text context to memory system
    
    Expected JSON:
    {
        "command": "make this formal",
        "ocr_text": "Hello world",
        "ocr_elements": [{"text": "Hello", "box": {"x": 10, "y": 20}}, ...],
        "session_id": "user_session_123",
        "cursor_position": {"x": 100, "y": 200}
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        command = data.get('command', '')
        ocr_text = data.get('ocr_text', '')
        ocr_elements = data.get('ocr_elements', [])
        session_id = data.get('session_id', 'default')
        cursor_position = data.get('cursor_position')
        
        # Add context to memory
        success = memory_xpc_service.memory_service.add_text_context(
            command=command,
            ocr_text=ocr_text,
            ocr_elements=ocr_elements,
            session_id=session_id,
            cursor_position=cursor_position
        )
        
        result = {
            "success": success,
            "timestamp": time.time()
        }
        
        if success:
            logger.info(f"✅ Added context for command: {command}")
        else:
            logger.warning(f"⚠️ Failed to add context for command: {command}")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Add context failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/memory_stats', methods=['GET'])
def memory_stats():
    """Get memory system statistics"""
    try:
        stats = {
            "service_uptime": time.time(),
            "mem0_status": "available" if memory_xpc_service.memory_service.mem0_client else "unavailable",
            "graphiti_status": "available" if memory_xpc_service.memory_service.graphiti_client else "unavailable",
            "total_requests": getattr(app, 'request_count', 0)
        }
        return jsonify(stats)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Request counting middleware
@app.before_request
def count_requests():
    if not hasattr(app, 'request_count'):
        app.request_count = 0
    app.request_count += 1

# CORS headers for development
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

def main():
    """Run the memory XPC server"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Zeus_STT Memory XPC Server")
    parser.add_argument('--port', type=int, default=5000, help='Server port (default: 5000)')
    parser.add_argument('--host', default='localhost', help='Server host (default: localhost)')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    
    args = parser.parse_args()
    
    logger.info(f"🚀 Starting Zeus_STT Memory XPC Server on {args.host}:{args.port}")
    logger.info(f"📡 Memory endpoints:")
    logger.info(f"   POST /resolve_context - Resolve voice command context")
    logger.info(f"   POST /add_context - Add text interaction context")
    logger.info(f"   GET  /health - Health check")
    logger.info(f"   GET  /memory_stats - Memory system statistics")
    
    # Run Flask server
    app.run(
        host=args.host,
        port=args.port,
        debug=args.debug,
        threaded=True  # Handle concurrent requests
    )

if __name__ == "__main__":
    main()