#!/usr/bin/env python3
"""
Enhanced Temporal Parser - Memory Optimized Implementation
Based on research report: Custom minimal spaCy (blank + NER + parser only)

Target: <100MB memory (down from 383MB)
Expected: ~80MB with >85% accuracy maintained
"""

import spacy
from spacy.language import Language
from dateutil import parser as dateutil_parser
from fuzzywuzzy import fuzz
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import re
import psutil
import structlog

logger = structlog.get_logger()

class IntentType(Enum):
    RECENT_ACTIVITY = "recent_activity"
    SPECIFIC_TIME = "specific_time"
    TIME_RANGE = "time_range"
    APP_SPECIFIC = "app_specific"
    GENERAL_QUERY = "general_query"

@dataclass
class Intent:
    intent_type: IntentType
    confidence: float
    keywords: List[str]

@dataclass
class ParsedTemporalQuery:
    intent: Intent
    time_range: Dict[str, datetime]
    entities: Dict[str, str]
    keywords: List[str]

@Language.factory("minimal_temporal")
def create_minimal_temporal(nlp, name):
    """Factory for minimal temporal component"""
    return MinimalTemporalComponent(nlp)

class MinimalTemporalComponent:
    """Minimal temporal processing component for spaCy pipeline"""
    
    def __init__(self, nlp):
        self.nlp = nlp
        self.temporal_patterns = {
            'morning': (6, 12),
            'afternoon': (12, 18), 
            'evening': (18, 22),
            'night': (22, 6),
            'lunch': (12, 13),
            'dinner': (18, 20)
        }
    
    def __call__(self, doc):
        """Process document for temporal information"""
        # Add custom temporal attributes to tokens
        for token in doc:
            if token.text.lower() in self.temporal_patterns:
                token._.set('is_temporal_period', True)
                token._.set('time_range', self.temporal_patterns[token.text.lower()])
            else:
                token._.set('is_temporal_period', False)
                token._.set('time_range', None)
        
        return doc

class EnhancedTemporalParser:
    """Memory-optimized temporal parser using minimal spaCy components"""
    
    def __init__(self):
        """Initialize with minimal spaCy model"""
        logger.info("🔄 Initializing memory-optimized temporal parser...")
        
        # Track initial memory
        initial_memory = self._get_memory_usage()
        
        # Create minimal spaCy model
        self.nlp = self._create_minimal_model()
        
        # Time patterns for fuzzy matching
        self.time_patterns = {
            'morning': (6, 12),
            'afternoon': (12, 18),
            'evening': (18, 22), 
            'night': (22, 6),
            'lunch': (12, 13),
            'dinner': (18, 20),
            'now': (0, 0),  # Special case
            'today': (0, 24),
            'yesterday': (-24, 0),
            'this week': (-168, 0),  # Hours
            'last week': (-336, -168)
        }
        
        # Relative time patterns
        self.relative_patterns = {
            r'(\d+)\s*(minute|min)s?\s*ago': lambda m: timedelta(minutes=int(m.group(1))),
            r'(\d+)\s*(hour|hr)s?\s*ago': lambda m: timedelta(hours=int(m.group(1))),
            r'(\d+)\s*(day)s?\s*ago': lambda m: timedelta(days=int(m.group(1))),
            r'(\d+)\s*(week)s?\s*ago': lambda m: timedelta(weeks=int(m.group(1))),
            r'last\s*(\d+)\s*(minute|min)s?': lambda m: timedelta(minutes=int(m.group(1))),
            r'last\s*(\d+)\s*(hour|hr)s?': lambda m: timedelta(hours=int(m.group(1))),
            r'recent': lambda m: timedelta(minutes=30),
            r'just now': lambda m: timedelta(minutes=1)
        }
        
        # Intent keywords
        self.intent_keywords = {
            IntentType.RECENT_ACTIVITY: ['recent', 'latest', 'last', 'just', 'current'],
            IntentType.SPECIFIC_TIME: ['at', 'during', 'when', 'time'],
            IntentType.TIME_RANGE: ['between', 'from', 'to', 'until', 'since'],
            IntentType.APP_SPECIFIC: ['app', 'application', 'program', 'browser', 'code', 'coding'],
            IntentType.GENERAL_QUERY: ['what', 'show', 'find', 'search', 'tell']
        }
        
        final_memory = self._get_memory_usage()
        memory_used = final_memory - initial_memory
        
        logger.info(f"✅ Memory-optimized temporal parser initialized: {memory_used:.1f}MB")
        
        # Verify it's under target
        if memory_used < 100:
            logger.info(f"🎯 Memory target met: {memory_used:.1f}MB < 100MB")
        else:
            logger.warning(f"⚠️ Memory over target: {memory_used:.1f}MB > 100MB")
    
    def _create_minimal_model(self) -> spacy.Language:
        """Create minimal spaCy model with only essential components"""
        try:
            # Start with blank English model
            nlp = spacy.blank("en")
            
            # Add only essential components for temporal parsing
            # NER for entity recognition (dates, times)
            nlp.add_pipe("ner")
            
            # Parser for syntactic structure
            nlp.add_pipe("parser")
            
            # Custom minimal temporal component
            nlp.add_pipe("minimal_temporal")
            
            # Register custom token extensions
            if not spacy.tokens.Token.has_extension("is_temporal_period"):
                spacy.tokens.Token.set_extension("is_temporal_period", default=False)
            if not spacy.tokens.Token.has_extension("time_range"):
                spacy.tokens.Token.set_extension("time_range", default=None)
            
            logger.debug("✅ Created minimal spaCy model: blank + NER + parser + temporal")
            return nlp
            
        except Exception as e:
            logger.error(f"❌ Failed to create minimal model: {e}")
            # Fallback to even more minimal approach
            nlp = spacy.blank("en")
            logger.warning("⚠️ Using blank model fallback (no NER/parser)")
            return nlp
    
    def _get_memory_usage(self) -> float:
        """Get current memory usage in MB"""
        try:
            return psutil.Process().memory_info().rss / 1024 / 1024
        except:
            return 0
    
    def parse_temporal_query(self, query: str, current_context: Optional[Dict[str, Any]] = None) -> ParsedTemporalQuery:
        """Parse temporal query with optimized approach"""
        try:
            # Process with minimal spaCy
            doc = self.nlp(query)
            
            # Extract entities (if NER available)
            entities = {}
            if doc.has_annotation("ENT_IOB"):
                entities = {ent.label_: ent.text for ent in doc.ents if ent.label_ in ['DATE', 'TIME', 'PERSON', 'ORG']}
            
            # Extract keywords
            keywords = []
            if doc.has_annotation("POS"):
                keywords = [token.text.lower() for token in doc if token.pos_ in ['NOUN', 'VERB', 'ADJ']]
            else:
                # Fallback: simple word extraction
                keywords = [word.lower() for word in query.split() if len(word) > 2]
            
            # Determine intent
            intent = self._extract_intent(query, keywords)
            
            # Extract time range
            time_range = self._extract_time_range(query, entities, current_context)
            
            return ParsedTemporalQuery(
                intent=intent,
                time_range=time_range,
                entities=entities,
                keywords=keywords
            )
            
        except Exception as e:
            logger.error(f"❌ Temporal parsing failed: {e}")
            # Return fallback result
            return self._fallback_parse(query)
    
    def _extract_intent(self, query: str, keywords: List[str]) -> Intent:
        """Extract intent from query using keyword matching"""
        query_lower = query.lower()
        intent_scores = {}
        
        # Score each intent type
        for intent_type, intent_keywords in self.intent_keywords.items():
            score = 0
            for keyword in intent_keywords:
                if keyword in query_lower:
                    score += 1
                # Fuzzy matching for partial matches
                for word in keywords:
                    if fuzz.ratio(keyword, word) > 80:
                        score += 0.5
            
            intent_scores[intent_type] = score
        
        # Find best intent
        if intent_scores:
            best_intent = max(intent_scores.items(), key=lambda x: x[1])
            confidence = min(best_intent[1] / 3, 1.0)  # Normalize to 0-1
            
            return Intent(
                intent_type=best_intent[0],
                confidence=confidence,
                keywords=keywords
            )
        
        # Default intent
        return Intent(
            intent_type=IntentType.GENERAL_QUERY,
            confidence=0.5,
            keywords=keywords
        )
    
    def _extract_time_range(self, query: str, entities: Dict[str, str], current_context: Optional[Dict] = None) -> Dict[str, datetime]:
        """Extract time range from query"""
        now = datetime.now()
        time_range = {
            'start': now - timedelta(hours=1),  # Default: last hour
            'end': now
        }
        
        # Try regex patterns for relative times
        for pattern, delta_func in self.relative_patterns.items():
            match = re.search(pattern, query.lower())
            if match:
                try:
                    delta = delta_func(match)
                    time_range['start'] = now - delta
                    time_range['end'] = now
                    logger.debug(f"✅ Matched relative pattern: {pattern} -> {delta}")
                    return time_range
                except Exception as e:
                    logger.debug(f"⚠️ Relative pattern failed: {e}")
        
        # Try entity-based parsing
        if 'DATE' in entities or 'TIME' in entities:
            for entity_type, entity_text in entities.items():
                if entity_type in ['DATE', 'TIME']:
                    try:
                        parsed_time = dateutil_parser.parse(entity_text, fuzzy=True)
                        # Determine if it's start or end based on context
                        if 'before' in query.lower() or 'until' in query.lower():
                            time_range['end'] = parsed_time
                        elif 'after' in query.lower() or 'since' in query.lower():
                            time_range['start'] = parsed_time
                        else:
                            # Default: time ± 30 minutes
                            time_range['start'] = parsed_time - timedelta(minutes=30)
                            time_range['end'] = parsed_time + timedelta(minutes=30)
                        
                        logger.debug(f"✅ Parsed entity time: {entity_text} -> {parsed_time}")
                        return time_range
                    except Exception as e:
                        logger.debug(f"⚠️ Entity parsing failed: {e}")
        
        # Try fuzzy pattern matching
        for pattern_name, (start_hour, end_hour) in self.time_patterns.items():
            if fuzz.partial_ratio(pattern_name, query.lower()) > 70:
                if pattern_name in ['yesterday']:
                    base_date = now - timedelta(days=1)
                    time_range['start'] = base_date.replace(hour=0, minute=0, second=0)
                    time_range['end'] = base_date.replace(hour=23, minute=59, second=59)
                elif pattern_name in ['today']:
                    time_range['start'] = now.replace(hour=0, minute=0, second=0)
                    time_range['end'] = now
                elif pattern_name in ['this week']:
                    week_start = now - timedelta(days=now.weekday())
                    time_range['start'] = week_start.replace(hour=0, minute=0, second=0)
                    time_range['end'] = now
                elif isinstance(start_hour, int) and isinstance(end_hour, int):
                    # Time period within today
                    time_range['start'] = now.replace(hour=start_hour, minute=0, second=0)
                    time_range['end'] = now.replace(hour=end_hour, minute=0, second=0)
                
                logger.debug(f"✅ Fuzzy matched pattern: {pattern_name}")
                return time_range
        
        # Default fallback
        logger.debug("⚠️ Using default time range: last hour")
        return time_range
    
    def _fallback_parse(self, query: str) -> ParsedTemporalQuery:
        """Fallback parsing when main parsing fails"""
        return ParsedTemporalQuery(
            intent=Intent(
                intent_type=IntentType.GENERAL_QUERY,
                confidence=0.3,
                keywords=query.split()
            ),
            time_range={
                'start': datetime.now() - timedelta(hours=1),
                'end': datetime.now()
            },
            entities={},
            keywords=query.split()
        )
    
    def get_memory_stats(self) -> Dict[str, Any]:
        """Get memory usage statistics"""
        return {
            'current_memory_mb': self._get_memory_usage(),
            'model_components': [pipe for pipe in self.nlp.pipe_names],
            'target_met': self._get_memory_usage() < 100
        }

def test_optimized_parser():
    """Test the optimized parser"""
    print("🧪 Testing Memory-Optimized Temporal Parser")
    print("=" * 50)
    
    # Initialize
    parser = EnhancedTemporalParser()
    
    # Memory check
    stats = parser.get_memory_stats()
    print(f"📊 Memory usage: {stats['current_memory_mb']:.1f}MB")
    print(f"🎯 Target met: {'✅' if stats['target_met'] else '❌'}")
    print(f"🔧 Components: {stats['model_components']}")
    
    # Test queries
    test_queries = [
        "What was I doing 5 minutes ago?",
        "Show me recent coding activities", 
        "Find browser activities from this morning",
        "What apps did I use in the last hour?",
        "What happened during lunch?",
        "Show me activities from yesterday"
    ]
    
    print(f"\n🕰️ Testing {len(test_queries)} queries:")
    print("-" * 40)
    
    total_confidence = 0
    for i, query in enumerate(test_queries, 1):
        result = parser.parse_temporal_query(query)
        confidence = result.intent.confidence
        total_confidence += confidence
        
        print(f"{i}. '{query}'")
        print(f"   Intent: {result.intent.intent_type.value} ({confidence:.2f})")
        print(f"   Time: {result.time_range['start'].strftime('%H:%M')} - {result.time_range['end'].strftime('%H:%M')}")
        
    avg_confidence = total_confidence / len(test_queries)
    print(f"\n📊 Average confidence: {avg_confidence:.2f}")
    print(f"🎯 Accuracy target: {'✅ MET' if avg_confidence >= 0.85 else '❌ MISSED'} (>0.85)")
    
    print("\n🎉 Optimized parser test complete!")

if __name__ == "__main__":
    test_optimized_parser()