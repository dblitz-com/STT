#!/usr/bin/env python3
"""
Memory Service for Zeus_STT - Mem0 + Graphiti Integration
Provides spatial/temporal context for voice commands using proven zQuery patterns.
"""

import time
import json
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

# Memory imports (installed dependencies)
try:
    import mem0
    MEM0_AVAILABLE = True
except ImportError as e:
    print(f"Mem0 not available: {e}")
    MEM0_AVAILABLE = False

# Note: Graphiti integration will be added later via state manager pattern
# For now, focus on getting Mem0 working (proven pattern from zQuery)
GRAPHITI_AVAILABLE = False  # Disable until proper state manager is implemented

@dataclass
class EnhancedTextState:
    """Enhanced state schema adapted from zQuery for text interaction"""
    # Existing Zeus_STT state (maintain compatibility)
    voice_command: str = ""
    wake_word_detected: bool = False
    recording_state: str = "idle"
    ocr_text_elements: List[Dict] = None  # From Apple Vision: [{'text': str, 'box': dict, 'type': str}]
    
    # Memory enhancement (proven from zQuery)
    mem0_text_context: Dict = None  # Compressed context from Mem0
    graphiti_spatial_context: Dict = None  # Spatial relationships from Graphiti
    resolved_text_target: str = ""  # What 'this' refers to
    session_id: str = "default"
    
    def __post_init__(self):
        if self.ocr_text_elements is None:
            self.ocr_text_elements = []
        if self.mem0_text_context is None:
            self.mem0_text_context = {}
        if self.graphiti_spatial_context is None:
            self.graphiti_spatial_context = {}

class MemoryService:
    """Memory service providing Mem0 + Graphiti integration for Zeus_STT"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.mem0_client = None
        self.graphiti_client = None
        
        # Initialize Mem0 (conversation compression and personalization)
        if MEM0_AVAILABLE:
            try:
                # Follow zQuery pattern for mem0 initialization
                self.mem0_client = mem0.Memory()
                self.logger.info("✅ Mem0 client initialized")
            except Exception as e:
                self.logger.error(f"❌ Mem0 initialization failed: {e}")
                if "OPENAI_API_KEY" in str(e):
                    self.logger.error("💡 Set OPENAI_API_KEY environment variable for Mem0")
        
        # Graphiti initialization disabled for now (will use state manager pattern later)
        self.graphiti_client = "mock_graphiti"  # Placeholder for testing
        self.logger.info("✅ Graphiti client initialized (mock mode - full integration pending)")
        
        if not MEM0_AVAILABLE:
            self.logger.warning("⚠️ Mem0 not available - memory features limited")

    def add_text_context(self, command: str, ocr_text: str, ocr_elements: List[Dict], 
                         session_id: str, cursor_position: Optional[Dict] = None) -> bool:
        """
        Add text interaction context to memory (adapted from zQuery pattern)
        
        Args:
            command: Voice command (e.g., "make this formal")
            ocr_text: Full OCR text from screen
            ocr_elements: OCR elements with bounding boxes
            session_id: User session identifier
            cursor_position: Current cursor location {'x': float, 'y': float}
            
        Returns:
            bool: Success status
        """
        if not self.mem0_client:
            self.logger.warning("Mem0 not available - skipping context storage")
            return False
            
        try:
            # Follow zQuery pattern for mem0.add() - convert to messages format
            message_dict = {
                "role": "user", 
                "content": f"Voice command: {command} | Screen context: {ocr_text[:200]}..."
            }
            
            # Add to Mem0 with metadata (following zQuery pattern)
            result = self.mem0_client.add(
                messages=[message_dict],  # Pass as list of message dicts
                user_id=session_id,
                metadata={
                    "command": command,
                    "timestamp": time.time(),
                    "session_id": session_id,
                    "ocr_elements_count": len(ocr_elements),
                    "has_cursor": cursor_position is not None
                }
            )
            
            # Build spatial relationships in Graphiti
            if self.graphiti_client:
                self._build_spatial_relationships(ocr_elements, session_id)
            
            self.logger.debug(f"✅ Added text context for command: {command}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Failed to add context: {e}")
            return False

    def resolve_context(self, command: str, session_id: str) -> Dict[str, Any]:
        """
        Resolve context for voice command using Mem0 + Graphiti
        
        Args:
            command: Voice command to resolve context for
            session_id: User session identifier
            
        Returns:
            Dict with resolved context and target text
        """
        result = {
            "resolved_target": "",
            "confidence": 0.0,
            "method": "fallback",
            "spatial_context": {},
            "temporal_context": {}
        }
        
        try:
            # Step 1: Mem0 search for compressed context (following zQuery pattern)
            if self.mem0_client:
                mem0_results = self.mem0_client.search(
                    query=command, 
                    user_id=session_id,
                    limit=5
                )
                
                # Handle different result formats (from zQuery pattern)
                formatted_results = []
                if isinstance(mem0_results, list):
                    for result_item in mem0_results:
                        if isinstance(result_item, dict):
                            formatted_results.append({
                                "content": result_item.get("content", result_item.get("memory", result_item.get("text", ""))),
                                "score": result_item.get("score", 0.0),
                                "metadata": result_item.get("metadata", {}),
                                "created_at": result_item.get("created_at", "")
                            })
                        elif isinstance(result_item, str):
                            formatted_results.append({
                                "content": result_item,
                                "score": 1.0,
                                "metadata": {},
                                "created_at": ""
                            })
                elif isinstance(mem0_results, dict) and "results" in mem0_results:
                    # Handle wrapped results
                    for result_item in mem0_results.get("results", []):
                        formatted_results.append({
                            "content": result_item.get("content", result_item.get("memory", "")),
                            "score": result_item.get("score", 0.0),
                            "metadata": result_item.get("metadata", {}),
                            "created_at": result_item.get("created_at", "")
                        })
                
                result["temporal_context"] = formatted_results
                result["method"] = "mem0"
                
                # Extract potential target from recent context
                if formatted_results and len(formatted_results) > 0:
                    recent_context = formatted_results[0]
                    content = recent_context.get("content", "")
                    # Extract screen context from the stored content
                    if "Screen context:" in content:
                        screen_part = content.split("Screen context:")[1].strip()
                        result["resolved_target"] = screen_part[:100]  # First 100 chars
                        result["confidence"] = 0.7
            
            # Step 2: Graphiti spatial query for relationship-based commands
            if self.graphiti_client and any(spatial_word in command.lower() for spatial_word in 
                                           ["above", "below", "next to", "before", "after", "this", "that"]):
                spatial_result = self._query_spatial_relationships(command, session_id)
                if spatial_result:
                    result["spatial_context"] = spatial_result
                    result["resolved_target"] = spatial_result.get("target_text", result["resolved_target"])
                    result["confidence"] = max(result["confidence"], 0.8)
                    result["method"] = "graphiti_spatial"
            
            self.logger.debug(f"✅ Resolved context for '{command}': {result['method']}")
            return result
            
        except Exception as e:
            self.logger.error(f"❌ Context resolution failed: {e}")
            return result

    def _build_spatial_relationships(self, ocr_elements: List[Dict], session_id: str):
        """Build spatial relationships in Graphiti from OCR elements"""
        if not self.graphiti_client or not ocr_elements:
            return
            
        try:
            # Create nodes for text elements
            nodes = []
            for i, elem in enumerate(ocr_elements):
                node = {
                    "id": f"{session_id}_{i}_{int(time.time())}",
                    "type": elem.get("type", "text"),
                    "text": elem.get("text", ""),
                    "timestamp": time.time(),
                    "session_id": session_id
                }
                nodes.append(node)
            
            # Build spatial edges based on bounding box relationships
            edges = self._compute_spatial_edges(nodes, ocr_elements)
            
            # Add to Graphiti (mock mode for now - would use actual Graphiti API)
            if self.graphiti_client == "mock_graphiti":
                # Store relationships in memory for testing
                if not hasattr(self, '_mock_graph_data'):
                    self._mock_graph_data = {}
                self._mock_graph_data[session_id] = {
                    'nodes': nodes,
                    'edges': edges,
                    'timestamp': time.time()
                }
                
            self.logger.debug(f"✅ Built {len(edges)} spatial relationships (mock mode)")
            
        except Exception as e:
            self.logger.error(f"❌ Spatial relationship building failed: {e}")

    def _compute_spatial_edges(self, nodes: List[Dict], ocr_elements: List[Dict]) -> List[Dict]:
        """Compute spatial edges between text elements (proven pattern from research)"""
        edges = []
        
        for i in range(len(nodes) - 1):
            current_box = ocr_elements[i].get('box', {})
            next_box = ocr_elements[i + 1].get('box', {})
            
            if not current_box or not next_box:
                continue
                
            # Spatial relationship: above/below based on y-coordinates
            current_y = current_box.get('max_y', 0)
            next_y = next_box.get('min_y', 0)
            
            if current_y < next_y:  # current is above next
                edge = {
                    'from': nodes[i]['id'],
                    'to': nodes[i + 1]['id'],
                    'relationship': 'above',
                    'timestamp': time.time()
                }
                edges.append(edge)
                
            # Add more relationships (contains, adjacent, etc.) as needed
            
        return edges

    def _query_spatial_relationships(self, command: str, session_id: str) -> Optional[Dict]:
        """Query Graphiti for spatial relationships (mock implementation for testing)"""
        try:
            # Check if we have mock graph data for this session
            if hasattr(self, '_mock_graph_data') and session_id in self._mock_graph_data:
                graph_data = self._mock_graph_data[session_id]
                nodes = graph_data.get('nodes', [])
                edges = graph_data.get('edges', [])
                
                # Simple spatial query logic based on command
                if "above" in command.lower() and edges:
                    # Find an "above" relationship
                    for edge in edges:
                        if edge.get('relationship') == 'above':
                            # Return the "from" node as the target
                            from_id = edge.get('from')
                            target_node = next((n for n in nodes if n['id'] == from_id), None)
                            if target_node:
                                return {
                                    "query_type": "spatial_above",
                                    "target_text": target_node.get('text', ''),
                                    "confidence": 0.8
                                }
                
                elif "this" in command.lower() and nodes:
                    # Return most recent node (highest timestamp)
                    most_recent = max(nodes, key=lambda n: n.get('timestamp', 0))
                    return {
                        "query_type": "pronoun_resolution",
                        "target_text": most_recent.get('text', ''),
                        "confidence": 0.7
                    }
            
            # Fallback to basic pattern matching
            if "above" in command.lower():
                return {
                    "query_type": "spatial_above",
                    "target_text": "placeholder text above reference",
                    "confidence": 0.6
                }
            elif "this" in command.lower():
                return {
                    "query_type": "pronoun_resolution", 
                    "target_text": "most recent text element",
                    "confidence": 0.5
                }
            
            return None
            
        except Exception as e:
            self.logger.error(f"❌ Spatial query failed: {e}")
            return None

# XPC Service Interface (placeholder for Swift integration)
class MemoryXPCService:
    """XPC service interface for Swift-Python memory bridge"""
    
    def __init__(self):
        self.memory_service = MemoryService()
    
    def resolve_context_xpc(self, command: str, ocr_text: str, session_id: str) -> str:
        """
        XPC-compatible method for Swift calls (returns JSON string)
        
        Args:
            command: Voice command
            ocr_text: Current OCR text 
            session_id: Session identifier
            
        Returns:
            JSON string with resolved context
        """
        try:
            # Add current context
            self.memory_service.add_text_context(
                command=command,
                ocr_text=ocr_text,
                ocr_elements=[],  # Would be populated by Swift
                session_id=session_id
            )
            
            # Resolve context
            result = self.memory_service.resolve_context(command, session_id)
            
            return json.dumps(result)
            
        except Exception as e:
            error_result = {
                "resolved_target": "",
                "confidence": 0.0,
                "method": "error",
                "error": str(e)
            }
            return json.dumps(error_result)

# CLI interface for testing
def main():
    """Test the memory service directly"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Zeus_STT Memory Service")
    parser.add_argument("command", help="Voice command to process")
    parser.add_argument("--session-id", default="test_session", help="Session ID")
    parser.add_argument("--ocr-text", default="", help="OCR text from screen")
    
    args = parser.parse_args()
    
    # Initialize service
    service = MemoryService()
    
    # Add and resolve context
    service.add_text_context(
        command=args.command,
        ocr_text=args.ocr_text,
        ocr_elements=[],
        session_id=args.session_id
    )
    
    result = service.resolve_context(args.command, args.session_id)
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()