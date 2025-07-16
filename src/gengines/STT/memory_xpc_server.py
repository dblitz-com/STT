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
from vision_service import VisionService, detect_visual_references, analyze_spatial_command
from continuous_vision_service import (
    start_continuous_vision, stop_continuous_vision, query_visual_context,
    continuous_vision, detect_workflow, summarize_recent_activity,
    query_temporal, get_workflow_status
)

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Initialize Flask app for HTTP-based XPC simulation
app = Flask(__name__)

# Global service instances
memory_xpc_service = MemoryXPCService()
vision_service = VisionService(disable_langfuse=True)

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

@app.route('/detect_visual_references', methods=['POST'])
def detect_visual_references_endpoint():
    """
    Check if a voice command contains visual/spatial references
    
    Expected JSON:
    {
        "command": "make this formal"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        command = data.get('command', '')
        if not command:
            return jsonify({"error": "Command is required"}), 400
        
        start_time = time.time()
        
        # Check if command needs vision analysis
        needs_vision = detect_visual_references(command)
        
        result = {
            "needs_vision": needs_vision,
            "command": command,
            "latency_ms": (time.time() - start_time) * 1000
        }
        
        logger.info(f"🔍 Visual reference check for '{command}': {needs_vision}")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Visual reference detection failed: {e}")
        return jsonify({
            "needs_vision": False,
            "error": str(e)
        }), 500

@app.route('/analyze_spatial_command', methods=['POST'])
def analyze_spatial_command_endpoint():
    """
    Analyze spatial voice command using vision
    
    Expected JSON:
    {
        "command": "make this formal",
        "image_path": "/path/to/screenshot.png",
        "context": "optional context from memory"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        command = data.get('command', '')
        image_path = data.get('image_path', '')
        context = data.get('context')
        
        if not command:
            return jsonify({"error": "Command is required"}), 400
        if not image_path:
            return jsonify({"error": "Image path is required"}), 400
        
        start_time = time.time()
        
        logger.info(f"🔍 Analyzing spatial command: '{command}' with image: {image_path}")
        
        # Analyze spatial command with vision
        result = analyze_spatial_command(image_path, command, context)
        
        # Add timing information
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"✅ Spatial analysis complete in {result['latency_ms']:.1f}ms - Target: {result.get('target_text', 'None')}")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Spatial command analysis failed: {e}")
        return jsonify({
            "target_text": None,
            "spatial_relationship": None,
            "confidence": 0.0,
            "bounds": {},
            "full_analysis": f"Error: {str(e)}",
            "error": str(e)
        }), 500

@app.route('/vision_health', methods=['GET'])
def vision_health():
    """Check vision service health"""
    try:
        # Test vision service with a simple check
        health_status = {
            "vision_service_available": vision_service is not None,
            "continuous_vision_running": continuous_vision.running,
            "gpt41_mini_configured": True,  # Assuming it's configured if service exists
            "timestamp": time.time()
        }
        
        return jsonify(health_status)
        
    except Exception as e:
        logger.error(f"Vision health check failed: {e}")
        return jsonify({
            "vision_service_available": False,
            "continuous_vision_running": False,
            "error": str(e)
        }), 500

@app.route('/start_continuous_vision', methods=['POST'])
def start_continuous_vision_endpoint():
    """Start continuous vision monitoring"""
    try:
        result = start_continuous_vision()
        logger.info("🔍 Started continuous vision monitoring via XPC")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Failed to start continuous vision: {e}")
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 500

@app.route('/stop_continuous_vision', methods=['POST'])  
def stop_continuous_vision_endpoint():
    """Stop continuous vision monitoring"""
    try:
        result = stop_continuous_vision()
        logger.info("⏹️ Stopped continuous vision monitoring via XPC")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Failed to stop continuous vision: {e}")
        return jsonify({
            "status": "error", 
            "error": str(e)
        }), 500

@app.route('/query_visual_context', methods=['POST'])
def query_visual_context_endpoint():
    """Query visual context for voice commands"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        command = data.get('command', '')
        limit = data.get('limit', 5)
        
        if not command:
            return jsonify({"error": "Command is required"}), 400
        
        start_time = time.time()
        
        # Query visual context from continuous monitoring
        result = query_visual_context(command, limit)
        
        # Add timing
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"🔍 Visual context query for '{command}': {result['count']} contexts")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Visual context query failed: {e}")
        return jsonify({
            "contexts": [],
            "count": 0,
            "error": str(e)
        }), 500

# PILLAR 1: Always-On Vision Workflow Understanding Endpoints

@app.route('/detect_workflow', methods=['POST'])
def detect_workflow_endpoint():
    """Detect workflow patterns from screen capture"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        image_path = data.get('image_path', '')
        if not image_path:
            return jsonify({"error": "Image path is required"}), 400
        
        start_time = time.time()
        
        # Detect workflow patterns
        result = detect_workflow(image_path)
        
        # Add timing
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"🔍 Workflow detection for {image_path}: {result.get('workflow_result', {}).get('event', 'Unknown')}")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Workflow detection failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/summarize_activity', methods=['POST'])
def summarize_activity_endpoint():
    """Generate activity summary for specified time window"""
    try:
        data = request.get_json()
        time_window = data.get('time_window', 30) if data else 30
        
        start_time = time.time()
        
        # Generate activity summary
        result = summarize_recent_activity(time_window)
        
        # Add timing
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"📊 Activity summary for {time_window}s: {result.get('summary', 'No summary')[:50]}...")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Activity summarization failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/query_temporal', methods=['POST'])
def query_temporal_endpoint():
    """Answer temporal queries about past activities"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        query = data.get('query', '')
        if not query:
            return jsonify({"error": "Query is required"}), 400
        
        start_time = time.time()
        
        # Process temporal query
        result = query_temporal(query)
        
        # Add timing
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"🕐 Temporal query '{query}': {result.get('response', 'No response')[:50]}...")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Temporal query failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/workflow_status', methods=['GET'])
def workflow_status_endpoint():
    """Get current workflow status and statistics"""
    try:
        start_time = time.time()
        
        # Get workflow status
        result = get_workflow_status()
        
        # Add timing
        result['latency_ms'] = (time.time() - start_time) * 1000
        
        logger.info(f"📊 Workflow status: {result.get('current_workflow', {}).get('state', 'Unknown')}")
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Workflow status failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/pillar1_health', methods=['GET'])
def pillar1_health_endpoint():
    """Health check for PILLAR 1 components"""
    try:
        health_status = {
            "pillar1_available": True,
            "workflow_detection": True,
            "activity_summarization": True,
            "temporal_queries": True,
            "pattern_learning": True,
            "mem0_weaviate": continuous_vision.mem0_client is not None,
            "graphiti_neo4j": continuous_vision.graphiti_client is not None,
            "current_workflow_state": continuous_vision.current_workflow['state'].name,
            "current_app": continuous_vision.current_workflow['app'],
            "transitions_tracked": len(continuous_vision.transition_history),
            "activity_buffer_size": len(continuous_vision.activity_deque),
            "timestamp": time.time()
        }
        
        return jsonify(health_status)
        
    except Exception as e:
        logger.error(f"PILLAR 1 health check failed: {e}")
        return jsonify({
            "pillar1_available": False,
            "error": str(e)
        }), 500

# Glass UI State Management
glass_ui_state = {
    "active": False,
    "current_mode": "hidden",
    "last_update": None,
    "content": {}
}

@app.route('/glass_update', methods=['POST'])
def glass_update():
    """Send updates to Glass UI"""
    global glass_ui_state
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({"success": False, "error": "No data provided"}), 400
            
        # Update Glass UI state
        glass_ui_state["last_update"] = time.time()
        glass_ui_state["active"] = True
        
        # Handle different update types
        update_type = data.get("type", "vision_summary")
        
        if update_type == "vision_summary":
            glass_ui_state["current_mode"] = "visionSummary"
            glass_ui_state["content"] = {
                "visionSummary": data.get("summary", ""),
                "visionConfidence": data.get("confidence", 0.0)
            }
            
        elif update_type == "temporal_query":
            glass_ui_state["current_mode"] = "temporalQuery"
            glass_ui_state["content"] = {
                "temporalQuery": data.get("query", ""),
                "temporalResult": data.get("result", "")
            }
            
        elif update_type == "workflow_feedback":
            glass_ui_state["current_mode"] = "workflowFeedback"
            glass_ui_state["content"] = {
                "workflowTransition": data.get("transition", ""),
                "relationshipType": data.get("relationship_type", ""),
                "relationshipConfidence": data.get("confidence", 0.0)
            }
            
        elif update_type == "health_status":
            glass_ui_state["current_mode"] = "healthStatus"
            glass_ui_state["content"] = {
                "memoryUsage": data.get("memory_mb", 0),
                "cpuUsage": data.get("cpu_percent", 0),
                "latency": data.get("latency_ms", 0)
            }
            
        return jsonify({
            "success": True,
            "glass_ui_state": glass_ui_state,
            "timestamp": time.time()
        })
        
    except Exception as e:
        logger.error(f"Glass UI update failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/glass_query', methods=['GET'])
def glass_query():
    """Query current Glass UI state"""
    global glass_ui_state
    
    try:
        # Check if Glass UI is stale (no updates for 30 seconds)
        if glass_ui_state["last_update"]:
            time_since_update = time.time() - glass_ui_state["last_update"]
            if time_since_update > 30:
                glass_ui_state["active"] = False
                glass_ui_state["current_mode"] = "hidden"
                
        return jsonify({
            "success": True,
            "glass_ui_state": glass_ui_state,
            "timestamp": time.time()
        })
        
    except Exception as e:
        logger.error(f"Glass UI query failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/glass_health', methods=['GET'])
def glass_health():
    """Check Glass UI health and connectivity"""
    global glass_ui_state
    
    try:
        # Basic health metrics
        current_time = time.time()
        time_since_update = None
        
        if glass_ui_state["last_update"]:
            time_since_update = current_time - glass_ui_state["last_update"]
            
        health_status = {
            "success": True,
            "glass_ui_available": True,
            "active": glass_ui_state["active"],
            "current_mode": glass_ui_state["current_mode"],
            "last_update": glass_ui_state["last_update"],
            "time_since_update": time_since_update,
            "is_stale": time_since_update > 30 if time_since_update else False,
            "content_keys": list(glass_ui_state["content"].keys()) if glass_ui_state["content"] else [],
            "timestamp": current_time
        }
        
        return jsonify(health_status)
        
    except Exception as e:
        logger.error(f"Glass UI health check failed: {e}")
        return jsonify({
            "success": False,
            "glass_ui_available": False,
            "error": str(e)
        }), 500

def main():
    """Run the memory XPC server"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Zeus_STT Memory XPC Server")
    parser.add_argument('--port', type=int, default=5000, help='Server port (default: 5000)')
    parser.add_argument('--host', default='localhost', help='Server host (default: localhost)')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    
    args = parser.parse_args()
    
    logger.info(f"🚀 Starting Zeus VLA Memory + Vision + PILLAR 1 XPC Server on {args.host}:{args.port}")
    logger.info(f"📡 Memory endpoints:")
    logger.info(f"   POST /resolve_context - Resolve voice command context")
    logger.info(f"   POST /add_context - Add text interaction context")
    logger.info(f"   GET  /health - Health check")
    logger.info(f"   GET  /memory_stats - Memory system statistics")
    logger.info(f"🔍 Vision endpoints:")
    logger.info(f"   POST /detect_visual_references - Check if command needs vision")
    logger.info(f"   POST /analyze_spatial_command - Analyze spatial command with GPT-4.1-mini")
    logger.info(f"   GET  /vision_health - Vision service health check")
    logger.info(f"🎥 Continuous Vision endpoints:")
    logger.info(f"   POST /start_continuous_vision - Start always-on vision monitoring")
    logger.info(f"   POST /stop_continuous_vision - Stop continuous vision monitoring")
    logger.info(f"   POST /query_visual_context - Query visual context for voice commands")
    logger.info(f"🧠 PILLAR 1: Always-On Vision Workflow Understanding endpoints:")
    logger.info(f"   POST /detect_workflow - Detect workflow patterns from screen")
    logger.info(f"   POST /summarize_activity - Generate activity summary (30s windows)")
    logger.info(f"   POST /query_temporal - Answer temporal queries about past activities")
    logger.info(f"   GET  /workflow_status - Get current workflow status and stats")
    logger.info(f"   GET  /pillar1_health - Health check for PILLAR 1 components")
    logger.info(f"🥽 Glass UI endpoints:")
    logger.info(f"   POST /glass_update - Send updates to Glass UI (vision, temporal, workflow, health)")
    logger.info(f"   GET  /glass_query - Query current Glass UI state")
    logger.info(f"   GET  /glass_health - Check Glass UI health and connectivity")
    
    # Run Flask server
    app.run(
        host=args.host,
        port=args.port,
        debug=args.debug,
        threaded=True  # Handle concurrent requests
    )

if __name__ == "__main__":
    main()