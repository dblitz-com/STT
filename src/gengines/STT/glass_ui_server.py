#!/usr/bin/env python3
"""
Glass UI HTTP Server - Bridge between continuous vision service and Swift Glass UI
Provides HTTP endpoints for real-time vision content communication
"""

import asyncio
import json
import time
from datetime import datetime
from typing import Dict, Any, Optional
from flask import Flask, request, jsonify
import threading
import structlog

# Configure structured logging
logger = structlog.get_logger()

class GlassUIServer:
    """HTTP server for Glass UI real-time communication"""
    
    def __init__(self, port: int = 5002):
        self.port = port
        self.app = Flask(__name__)
        self.app.logger.disabled = True  # Disable Flask logging noise
        
        # Current Glass UI state
        self.current_state = {
            "success": True,
            "glass_ui_state": {
                "active": False,
                "content": {
                    "visionSummary": "",
                    "visionConfidence": 0.0,
                    "temporalQuery": "",
                    "temporalResult": "",
                    "workflowTransition": "",
                    "relationshipType": "",
                    "relationshipConfidence": 0.0,
                    "memoryUsage": 0,
                    "cpuUsage": 0,
                    "latency": 0
                }
            },
            "timestamp": time.time()
        }
        
        # Rate limiting (reduced for real-time app switching)
        self.last_update_time = 0
        self.min_update_interval = 0.1  # Minimum 100ms between updates for real-time
        
        self._setup_routes()
        
    def _setup_routes(self):
        """Setup HTTP routes"""
        
        @self.app.route('/glass_query', methods=['GET'])
        def glass_query():
            """Serve current Glass UI state to Swift Glass Manager"""
            return jsonify(self.current_state)
            
        @self.app.route('/glass_update', methods=['POST'])
        def glass_update():
            """Receive updates from continuous vision service"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({"success": False, "error": "No JSON data"}), 400
                
                # Rate limiting
                current_time = time.time()
                if current_time - self.last_update_time < self.min_update_interval:
                    return jsonify({"success": True, "message": "Rate limited"}), 200
                
                self.last_update_time = current_time
                self._process_update(data)
                
                logger.debug(f"📱 Received update: {data.get('type', 'unknown')}")
                return jsonify({"success": True})
                
            except Exception as e:
                logger.error(f"❌ Error processing Glass UI update: {e}")
                return jsonify({"success": False, "error": str(e)}), 500
        
        @self.app.route('/health', methods=['GET'])
        def health():
            """Health check endpoint"""
            return jsonify({
                "status": "healthy",
                "timestamp": time.time(),
                "active": self.current_state["glass_ui_state"]["active"]
            })
            
    def _process_update(self, data: Dict[str, Any]):
        """Process incoming update from vision service"""
        update_type = data.get("type", "")
        
        # Update timestamp
        self.current_state["timestamp"] = time.time()
        
        # Enable Glass UI when we receive content
        self.current_state["glass_ui_state"]["active"] = True
        
        content = self.current_state["glass_ui_state"]["content"]
        
        if update_type == "vision_summary":
            content["visionSummary"] = data.get("summary", "")
            content["visionConfidence"] = data.get("confidence", 0.0)
            logger.info(f"📱 Vision update: {content['visionSummary'][:50]}...")
            
        elif update_type == "temporal_query":
            content["temporalQuery"] = data.get("query", "")
            content["temporalResult"] = data.get("result", "")
            logger.info(f"📱 Temporal update: {content['temporalQuery']}")
            
        elif update_type == "workflow_feedback":
            content["workflowTransition"] = data.get("transition", "")
            content["relationshipType"] = data.get("relationship_type", "")
            content["relationshipConfidence"] = data.get("relationship_confidence", 0.0)
            logger.info(f"📱 Workflow update: {content['workflowTransition']}")
            
        elif update_type == "health_status":
            content["memoryUsage"] = data.get("memory_mb", 0)
            content["cpuUsage"] = data.get("cpu_percent", 0)
            content["latency"] = data.get("latency_ms", 0)
            logger.debug(f"📱 Health update: {content['memoryUsage']}MB, {content['cpuUsage']}% CPU")
            
        # Auto-deactivate if no updates for a while (optional)
        # Could add logic here to set active = False after timeout
        
    def run(self):
        """Start the HTTP server"""
        logger.info(f"🌐 Starting Glass UI HTTP server on port {self.port}")
        
        # Run Flask in a separate thread to avoid blocking
        def run_flask():
            self.app.run(
                host='127.0.0.1',
                port=self.port,
                debug=False,
                use_reloader=False,
                threaded=True
            )
        
        flask_thread = threading.Thread(target=run_flask, daemon=True)
        flask_thread.start()
        
        logger.info(f"✅ Glass UI server running at http://localhost:{self.port}")
        logger.info(f"📊 Health check: http://localhost:{self.port}/health")
        logger.info(f"🔍 Glass query: http://localhost:{self.port}/glass_query") 
        logger.info(f"📝 Glass update: http://localhost:{self.port}/glass_update")
        
        return flask_thread
        
    def stop(self):
        """Stop the server (placeholder - Flask doesn't have easy stop)"""
        logger.info("🛑 Glass UI server shutdown requested")

def main():
    """Run the Glass UI server standalone"""
    import signal
    import sys
    
    server = GlassUIServer()
    flask_thread = server.run()
    
    def signal_handler(sig, frame):
        logger.info("🛑 Received shutdown signal")
        server.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Keep main thread alive
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("🛑 Keyboard interrupt received")
        server.stop()

if __name__ == "__main__":
    main()