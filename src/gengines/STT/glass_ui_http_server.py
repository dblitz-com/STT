#!/usr/bin/env python3
"""
Glass UI HTTP Server - Simplified HTTP-only version
Works with the hybrid approach where vision service sends HTTP updates
"""

import time
import json
from flask import Flask, request, jsonify
import structlog

logger = structlog.get_logger()

class GlassUIHTTPServer:
    def __init__(self, port: int = 5003):
        self.port = port
        self.flask_app = Flask(__name__)
        
        # Current state
        self.current_state = {
            "success": True,
            "glass_ui_state": {
                "active": False,
                "content": {
                    "visionSummary": "",
                    "visionConfidence": 0.0,
                    "currentApp": "",
                    "workflowDetected": "",
                    "temporalQuery": "",
                    "temporalResult": ""
                },
                "display_mode": "compact"
            },
            "timestamp": time.time()
        }
        
        self._setup_routes()
        logger.info("✅ Glass UI HTTP Server initialized")
    
    def _setup_routes(self):
        @self.flask_app.route('/glass_query', methods=['GET'])
        def glass_query():
            """Get current Glass UI state"""
            return jsonify(self.current_state)
            
        @self.flask_app.route('/glass_update', methods=['POST'])
        def glass_update():
            """Receive updates from vision service"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({"success": False, "error": "No JSON data"}), 400
                
                # Process update
                self._process_update(data)
                
                logger.info(f"📱 Update received: {data.get('type', 'unknown')}")
                return jsonify({"success": True})
                
            except Exception as e:
                logger.error(f"❌ Update error: {e}")
                return jsonify({"success": False, "error": str(e)}), 500
        
        @self.flask_app.route('/health', methods=['GET'])
        def health():
            """Health check endpoint"""
            return jsonify({
                "status": "healthy",
                "timestamp": time.time()
            })
    
    def _process_update(self, data):
        """Process incoming updates"""
        update_type = data.get("type", "")
        
        # Update timestamp
        self.current_state["timestamp"] = time.time()
        self.current_state["glass_ui_state"]["active"] = True
        
        content = self.current_state["glass_ui_state"]["content"]
        
        if update_type == "vision_summary":
            content["visionSummary"] = data.get("summary", "")
            content["visionConfidence"] = data.get("confidence", 0.0)
            content["currentApp"] = data.get("app_name", "")
            
        elif update_type == "app_switch":
            app_data = data.get("data", {})
            content["currentApp"] = app_data.get("to_app", "")
            
        elif update_type == "workflow_feedback":
            content["workflowDetected"] = data.get("transition", "")
    
    def run(self):
        """Run the HTTP server"""
        logger.info(f"🌐 Starting Glass UI HTTP server on http://localhost:{self.port}")
        self.flask_app.run(
            host='127.0.0.1',
            port=self.port,
            debug=False
        )

if __name__ == "__main__":
    server = GlassUIHTTPServer()
    server.run()