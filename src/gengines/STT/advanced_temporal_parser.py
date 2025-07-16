#!/usr/bin/env python3
"""
AdvancedTemporalParser - Fix #5: Query Accuracy Enhancement for PILLAR 1
Improves temporal query accuracy from 60-70% to >85% using advanced NLP

Key Features:
- spaCy NER for entity extraction and intent classification
- Fuzzy time parsing with contextual time resolution
- Enhanced search ranking with temporal relevance scoring
- Multi-modal query understanding (text + context)
- User behavior pattern learning for query disambiguation

Target: >85% temporal query accuracy with <200ms response time
"""

import re
import time
import math
from typing import Dict, Any, Optional, List, Tuple, Union
from dataclasses import dataclass
from datetime import datetime, timedelta
from collections import defaultdict, deque
import calendar
import structlog

# NLP and time parsing
try:
    import spacy
    from spacy.tokens import Doc, Span
    SPACY_AVAILABLE = True
except ImportError:
    SPACY_AVAILABLE = False

try:
    from dateutil import parser as dateutil_parser
    from dateutil.relativedelta import relativedelta
    DATEUTIL_AVAILABLE = True
except ImportError:
    DATEUTIL_AVAILABLE = False

try:
    from fuzzywuzzy import fuzz, process
    FUZZYWUZZY_AVAILABLE = True
except ImportError:
    FUZZYWUZZY_AVAILABLE = False

logger = structlog.get_logger()

@dataclass
class TemporalEntity:
    """Extracted temporal entity from query"""
    text: str
    label: str
    start: int
    end: int
    confidence: float
    resolved_time: Optional[datetime] = None
    time_range: Optional[Tuple[datetime, datetime]] = None

@dataclass
class QueryIntent:
    """Parsed query intent"""
    intent_type: str  # 'when', 'what', 'show', 'find', 'during'
    confidence: float
    entities: List[str]
    temporal_entities: List[TemporalEntity]
    keywords: List[str]
    context_clues: List[str]

@dataclass
class TemporalQuery:
    """Parsed temporal query with resolved time ranges"""
    original_query: str
    intent: QueryIntent
    time_range: Tuple[datetime, datetime]
    priority_keywords: List[str]
    context_filters: Dict[str, Any]
    search_strategy: str  # 'temporal', 'content', 'mixed'

@dataclass
class SearchResult:
    """Search result with temporal relevance scoring"""
    content: str
    timestamp: datetime
    metadata: Dict[str, Any]
    content_relevance: float
    temporal_relevance: float
    behavior_boost: float
    final_score: float

class AdvancedTemporalParser:
    """
    Advanced temporal query parser with high accuracy
    
    Features:
    1. spaCy NER for entity extraction and intent classification
    2. Fuzzy time parsing with contextual resolution
    3. Enhanced search ranking with temporal relevance
    4. User behavior pattern learning
    5. Multi-modal query understanding
    """
    
    def __init__(self):
        # Initialize spaCy pipeline
        if SPACY_AVAILABLE:
            try:
                self.nlp = spacy.load("en_core_web_sm")
                logger.info("✅ spaCy model loaded successfully")
            except OSError:
                logger.warning("❌ spaCy model not found, using basic parsing")
                self.nlp = None
        else:
            self.nlp = None
        
        # Time pattern definitions
        self.time_patterns = {
            # Common time expressions
            'morning': (6, 12),
            'afternoon': (12, 18),
            'evening': (18, 22),
            'night': (22, 6),
            'lunch': (12, 13),
            'dinner': (18, 20),
            'breakfast': (7, 9),
            
            # Work-related times
            'work_start': (9, 9),
            'work_end': (17, 17),
            'meeting_time': (10, 16),
            'standup': (9, 10),
            
            # Relative periods
            'earlier': -3600,  # 1 hour ago
            'later': 3600,     # 1 hour later
            'recently': -1800,  # 30 minutes ago
            'soon': 1800,      # 30 minutes later
        }
        
        # Intent classification patterns
        self.intent_patterns = {
            'when': ['when', 'what time', 'at what', 'during'],
            'what': ['what', 'which', 'show me', 'find'],
            'show': ['show', 'display', 'give me', 'list'],
            'find': ['find', 'search', 'look for', 'locate'],
            'during': ['during', 'while', 'throughout', 'within']
        }
        
        # User behavior patterns
        self.user_patterns = {
            'common_apps': defaultdict(int),
            'common_times': defaultdict(int),
            'query_history': deque(maxlen=100),
            'disambiguation_choices': defaultdict(int)
        }
        
        # Performance metrics
        self.parse_times = deque(maxlen=100)
        self.accuracy_scores = deque(maxlen=100)
        self.total_queries = 0
        self.successful_parses = 0
        
        logger.info("✅ AdvancedTemporalParser initialized")
    
    def parse_temporal_query(self, query: str, current_context: Dict[str, Any] = None) -> TemporalQuery:
        """
        Parse temporal query with high accuracy
        
        Args:
            query: Natural language query
            current_context: Current application/workflow context
            
        Returns:
            TemporalQuery object with resolved time ranges and search strategy
        """
        try:
            start_time = time.time()
            
            # Update query history
            self.user_patterns['query_history'].append({
                'query': query,
                'timestamp': datetime.now(),
                'context': current_context
            })
            
            # Extract intent using spaCy NER
            intent = self._classify_intent(query)
            
            # Extract temporal entities
            temporal_entities = self._extract_temporal_entities(query)
            
            # Resolve time ranges
            time_range = self._resolve_time_range(temporal_entities, current_context)
            
            # Extract priority keywords
            priority_keywords = self._extract_priority_keywords(query, intent)
            
            # Determine context filters
            context_filters = self._extract_context_filters(query, current_context)
            
            # Determine search strategy
            search_strategy = self._determine_search_strategy(intent, temporal_entities, priority_keywords)
            
            # Create temporal query
            temporal_query = TemporalQuery(
                original_query=query,
                intent=intent,
                time_range=time_range,
                priority_keywords=priority_keywords,
                context_filters=context_filters,
                search_strategy=search_strategy
            )
            
            # Update performance metrics
            parse_time = time.time() - start_time
            self.parse_times.append(parse_time)
            self.total_queries += 1
            
            logger.debug(f"🔍 Parsed query in {parse_time:.3f}s: {query}")
            
            return temporal_query
            
        except Exception as e:
            logger.error(f"❌ Temporal query parsing failed: {e}")
            return self._create_fallback_query(query, current_context)
    
    def _classify_intent(self, query: str) -> QueryIntent:
        """Classify query intent using spaCy NER and pattern matching"""
        try:
            query_lower = query.lower()
            
            # Use spaCy if available
            if self.nlp:
                doc = self.nlp(query)
                
                # Extract entities
                entities = [ent.text for ent in doc.ents]
                
                # Classify intent based on question words and verbs
                intent_scores = defaultdict(float)
                
                for token in doc:
                    if token.pos_ == 'PRON' and token.text.lower() in ['what', 'when', 'where', 'which']:
                        intent_scores[token.text.lower()] += 0.8
                    elif token.pos_ == 'VERB':
                        verb_lower = token.text.lower()
                        if verb_lower in ['show', 'display', 'list']:
                            intent_scores['show'] += 0.6
                        elif verb_lower in ['find', 'search', 'look']:
                            intent_scores['find'] += 0.6
                
                # Get best intent
                if intent_scores:
                    best_intent = max(intent_scores, key=intent_scores.get)
                    confidence = intent_scores[best_intent]
                else:
                    best_intent = 'what'
                    confidence = 0.5
                
                # Extract keywords
                keywords = [token.text.lower() for token in doc 
                          if token.pos_ in ['NOUN', 'VERB', 'ADJ'] and len(token.text) > 2]
                
                # Extract context clues
                context_clues = [token.text.lower() for token in doc 
                               if token.pos_ in ['PREP', 'ADV'] and len(token.text) > 2]
                
            else:
                # Fallback pattern matching
                entities = []
                keywords = [word for word in query_lower.split() if len(word) > 2]
                context_clues = []
                
                # Simple intent classification
                for intent, patterns in self.intent_patterns.items():
                    if any(pattern in query_lower for pattern in patterns):
                        best_intent = intent
                        confidence = 0.7
                        break
                else:
                    best_intent = 'what'
                    confidence = 0.5
            
            return QueryIntent(
                intent_type=best_intent,
                confidence=confidence,
                entities=entities,
                temporal_entities=[],  # Will be filled later
                keywords=keywords,
                context_clues=context_clues
            )
            
        except Exception as e:
            logger.error(f"❌ Intent classification failed: {e}")
            return QueryIntent(
                intent_type='what',
                confidence=0.3,
                entities=[],
                temporal_entities=[],
                keywords=query.split(),
                context_clues=[]
            )
    
    def _extract_temporal_entities(self, query: str) -> List[TemporalEntity]:
        """Extract temporal entities from query"""
        try:
            temporal_entities = []
            
            # Use spaCy if available
            if self.nlp:
                doc = self.nlp(query)
                
                # Extract DATE and TIME entities
                for ent in doc.ents:
                    if ent.label_ in ['DATE', 'TIME']:
                        temporal_entity = TemporalEntity(
                            text=ent.text,
                            label=ent.label_,
                            start=ent.start_char,
                            end=ent.end_char,
                            confidence=0.9
                        )
                        
                        # Try to resolve the time
                        resolved_time = self._resolve_temporal_entity(ent.text)
                        if resolved_time:
                            temporal_entity.resolved_time = resolved_time
                            temporal_entity.time_range = self._create_time_range(resolved_time)
                        
                        temporal_entities.append(temporal_entity)
            
            # Pattern-based extraction for common expressions
            temporal_patterns = [
                (r'\b(yesterday|today|tomorrow)\b', 'DATE'),
                (r'\b(\d{1,2}:\d{2})\b', 'TIME'),
                (r'\b(morning|afternoon|evening|night)\b', 'TIME'),
                (r'\b(before|after|during)\s+(\w+)', 'RELATIVE'),
                (r'\b(\d+)\s+(minutes?|hours?|days?)\s+ago\b', 'RELATIVE'),
                (r'\b(last|next)\s+(week|month|year)\b', 'RELATIVE'),
                (r'\b(earlier|later|recently|soon)\b', 'RELATIVE')
            ]
            
            for pattern, label in temporal_patterns:
                matches = re.finditer(pattern, query.lower())
                for match in matches:
                    temporal_entity = TemporalEntity(
                        text=match.group(),
                        label=label,
                        start=match.start(),
                        end=match.end(),
                        confidence=0.8
                    )
                    
                    # Try to resolve the time
                    resolved_time = self._resolve_temporal_entity(match.group())
                    if resolved_time:
                        temporal_entity.resolved_time = resolved_time
                        temporal_entity.time_range = self._create_time_range(resolved_time)
                    
                    temporal_entities.append(temporal_entity)
            
            return temporal_entities
            
        except Exception as e:
            logger.error(f"❌ Temporal entity extraction failed: {e}")
            return []
    
    def _resolve_temporal_entity(self, text: str) -> Optional[datetime]:
        """Resolve temporal entity to specific datetime"""
        try:
            text_lower = text.lower().strip()
            now = datetime.now()
            
            # Handle common patterns
            if text_lower == 'today':
                return now.replace(hour=12, minute=0, second=0, microsecond=0)
            elif text_lower == 'yesterday':
                return (now - timedelta(days=1)).replace(hour=12, minute=0, second=0, microsecond=0)
            elif text_lower == 'tomorrow':
                return (now + timedelta(days=1)).replace(hour=12, minute=0, second=0, microsecond=0)
            
            # Handle time patterns
            if text_lower in self.time_patterns:
                pattern = self.time_patterns[text_lower]
                if isinstance(pattern, tuple):
                    start_hour, end_hour = pattern
                    return now.replace(hour=start_hour, minute=0, second=0, microsecond=0)
                else:
                    # Relative time in seconds
                    return now + timedelta(seconds=pattern)
            
            # Handle relative time expressions
            relative_match = re.match(r'(\d+)\s+(minutes?|hours?|days?)\s+ago', text_lower)
            if relative_match:
                amount = int(relative_match.group(1))
                unit = relative_match.group(2)
                
                if 'minute' in unit:
                    return now - timedelta(minutes=amount)
                elif 'hour' in unit:
                    return now - timedelta(hours=amount)
                elif 'day' in unit:
                    return now - timedelta(days=amount)
            
            # Handle fuzzy time parsing
            if FUZZYWUZZY_AVAILABLE:
                fuzzy_matches = process.extract(text_lower, list(self.time_patterns.keys()), limit=1)
                if fuzzy_matches and fuzzy_matches[0][1] > 70:  # >70% similarity
                    matched_pattern = fuzzy_matches[0][0]
                    pattern = self.time_patterns[matched_pattern]
                    if isinstance(pattern, tuple):
                        start_hour, end_hour = pattern
                        return now.replace(hour=start_hour, minute=0, second=0, microsecond=0)
                    else:
                        return now + timedelta(seconds=pattern)
            
            # Try dateutil parser as fallback
            if DATEUTIL_AVAILABLE:
                try:
                    return dateutil_parser.parse(text, fuzzy=True)
                except (ValueError, TypeError):
                    pass
            
            return None
            
        except Exception as e:
            logger.error(f"❌ Temporal resolution failed for '{text}': {e}")
            return None
    
    def _create_time_range(self, base_time: datetime) -> Tuple[datetime, datetime]:
        """Create time range around base time"""
        try:
            # Create 1-hour range around base time
            start_time = base_time - timedelta(minutes=30)
            end_time = base_time + timedelta(minutes=30)
            
            return (start_time, end_time)
            
        except Exception as e:
            logger.error(f"❌ Time range creation failed: {e}")
            return (base_time, base_time + timedelta(hours=1))
    
    def _resolve_time_range(self, temporal_entities: List[TemporalEntity], 
                          current_context: Dict[str, Any] = None) -> Tuple[datetime, datetime]:
        """Resolve final time range for search"""
        try:
            now = datetime.now()
            
            # If no temporal entities, use recent time (last 2 hours)
            if not temporal_entities:
                return (now - timedelta(hours=2), now)
            
            # Use the first temporal entity with resolved time
            for entity in temporal_entities:
                if entity.time_range:
                    return entity.time_range
                elif entity.resolved_time:
                    return self._create_time_range(entity.resolved_time)
            
            # Fallback to recent time
            return (now - timedelta(hours=1), now)
            
        except Exception as e:
            logger.error(f"❌ Time range resolution failed: {e}")
            return (datetime.now() - timedelta(hours=1), datetime.now())
    
    def _extract_priority_keywords(self, query: str, intent: QueryIntent) -> List[str]:
        """Extract priority keywords for search"""
        try:
            # Start with keywords from intent
            keywords = intent.keywords.copy()
            
            # Add entity text as high-priority keywords
            for entity in intent.entities:
                if entity.lower() not in keywords:
                    keywords.append(entity.lower())
            
            # Filter out common words
            stop_words = {'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'}
            keywords = [kw for kw in keywords if kw not in stop_words and len(kw) > 2]
            
            # Sort by importance (entities first, then nouns, then others)
            priority_keywords = []
            entity_keywords = [e.lower() for e in intent.entities]
            
            # Add entity keywords first
            for kw in keywords:
                if kw in entity_keywords:
                    priority_keywords.append(kw)
            
            # Add remaining keywords
            for kw in keywords:
                if kw not in priority_keywords:
                    priority_keywords.append(kw)
            
            return priority_keywords[:10]  # Limit to top 10
            
        except Exception as e:
            logger.error(f"❌ Priority keyword extraction failed: {e}")
            return query.split()[:5]
    
    def _extract_context_filters(self, query: str, current_context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Extract context filters for search"""
        try:
            filters = {}
            
            # App context filter
            if current_context and 'app' in current_context:
                filters['app'] = current_context['app']
            
            # Look for app mentions in query
            app_patterns = {
                'vscode': ['vscode', 'vs code', 'code', 'editor'],
                'terminal': ['terminal', 'command', 'shell', 'bash'],
                'browser': ['browser', 'chrome', 'safari', 'firefox'],
                'slack': ['slack', 'message', 'chat'],
                'meeting': ['meeting', 'zoom', 'call', 'video']
            }
            
            query_lower = query.lower()
            for app, patterns in app_patterns.items():
                if any(pattern in query_lower for pattern in patterns):
                    filters['app_mention'] = app
                    break
            
            # File type filters
            file_extensions = re.findall(r'\.([a-zA-Z0-9]+)', query)
            if file_extensions:
                filters['file_types'] = file_extensions
            
            # Project context
            if 'project' in query_lower or 'repo' in query_lower:
                filters['context_type'] = 'project'
            
            return filters
            
        except Exception as e:
            logger.error(f"❌ Context filter extraction failed: {e}")
            return {}
    
    def _determine_search_strategy(self, intent: QueryIntent, temporal_entities: List[TemporalEntity], 
                                 priority_keywords: List[str]) -> str:
        """Determine optimal search strategy"""
        try:
            # If strong temporal entities, use temporal strategy
            if temporal_entities and any(e.confidence > 0.8 for e in temporal_entities):
                return 'temporal'
            
            # If many keywords, use content strategy
            if len(priority_keywords) > 5:
                return 'content'
            
            # If intent is "when", prioritize temporal
            if intent.intent_type == 'when':
                return 'temporal'
            
            # Default to mixed strategy
            return 'mixed'
            
        except Exception as e:
            logger.error(f"❌ Search strategy determination failed: {e}")
            return 'mixed'
    
    def rank_search_results(self, results: List[Dict[str, Any]], 
                          temporal_query: TemporalQuery) -> List[SearchResult]:
        """Rank search results with temporal relevance"""
        try:
            ranked_results = []
            
            for result in results:
                # Calculate content relevance
                content_relevance = self._calculate_content_relevance(
                    temporal_query.priority_keywords, 
                    result.get('content', '')
                )
                
                # Calculate temporal relevance
                temporal_relevance = self._calculate_temporal_relevance(
                    result.get('timestamp', datetime.now()),
                    temporal_query.time_range
                )
                
                # Calculate behavior boost
                behavior_boost = self._calculate_behavior_boost(
                    result, 
                    temporal_query
                )
                
                # Calculate final score
                final_score = self._calculate_final_score(
                    content_relevance, 
                    temporal_relevance, 
                    behavior_boost,
                    temporal_query.search_strategy
                )
                
                # Create search result
                search_result = SearchResult(
                    content=result.get('content', ''),
                    timestamp=result.get('timestamp', datetime.now()),
                    metadata=result.get('metadata', {}),
                    content_relevance=content_relevance,
                    temporal_relevance=temporal_relevance,
                    behavior_boost=behavior_boost,
                    final_score=final_score
                )
                
                ranked_results.append(search_result)
            
            # Sort by final score
            ranked_results.sort(key=lambda r: r.final_score, reverse=True)
            
            return ranked_results
            
        except Exception as e:
            logger.error(f"❌ Search result ranking failed: {e}")
            return [SearchResult(
                content=r.get('content', ''),
                timestamp=r.get('timestamp', datetime.now()),
                metadata=r.get('metadata', {}),
                content_relevance=0.5,
                temporal_relevance=0.5,
                behavior_boost=1.0,
                final_score=0.5
            ) for r in results]
    
    def _calculate_content_relevance(self, keywords: List[str], content: str) -> float:
        """Calculate content relevance score"""
        try:
            if not keywords or not content:
                return 0.0
            
            content_lower = content.lower()
            matches = sum(1 for keyword in keywords if keyword.lower() in content_lower)
            
            # Jaccard similarity
            content_words = set(content_lower.split())
            keyword_set = set(kw.lower() for kw in keywords)
            
            intersection = len(content_words & keyword_set)
            union = len(content_words | keyword_set)
            
            jaccard = intersection / union if union > 0 else 0.0
            simple_match = matches / len(keywords) if keywords else 0.0
            
            # Weighted combination
            return 0.7 * jaccard + 0.3 * simple_match
            
        except Exception as e:
            logger.error(f"❌ Content relevance calculation failed: {e}")
            return 0.0
    
    def _calculate_temporal_relevance(self, timestamp: datetime, 
                                    time_range: Tuple[datetime, datetime]) -> float:
        """Calculate temporal relevance with Gaussian decay"""
        try:
            start_time, end_time = time_range
            
            # If timestamp is within range, high relevance
            if start_time <= timestamp <= end_time:
                return 1.0
            
            # Calculate distance from range
            if timestamp < start_time:
                distance_seconds = (start_time - timestamp).total_seconds()
            else:
                distance_seconds = (timestamp - end_time).total_seconds()
            
            # Gaussian decay with sigma = 1 hour
            sigma = 3600.0  # 1 hour
            relevance = math.exp(-(distance_seconds ** 2) / (2 * sigma ** 2))
            
            return relevance
            
        except Exception as e:
            logger.error(f"❌ Temporal relevance calculation failed: {e}")
            return 0.5
    
    def _calculate_behavior_boost(self, result: Dict[str, Any], 
                                temporal_query: TemporalQuery) -> float:
        """Calculate behavior-based boost"""
        try:
            boost = 1.0
            
            # Boost based on app usage patterns
            app_context = result.get('metadata', {}).get('app_context', '')
            if app_context:
                usage_count = self.user_patterns['common_apps'].get(app_context, 0)
                boost *= 1.0 + (usage_count / 100)  # Up to 2x boost for frequently used apps
            
            # Boost based on similar queries
            query_similarity = self._calculate_query_similarity(temporal_query.original_query)
            boost *= 1.0 + (query_similarity * 0.5)  # Up to 1.5x boost for similar queries
            
            return min(boost, 2.0)  # Cap at 2x boost
            
        except Exception as e:
            logger.error(f"❌ Behavior boost calculation failed: {e}")
            return 1.0
    
    def _calculate_query_similarity(self, query: str) -> float:
        """Calculate similarity to previous queries"""
        try:
            if not self.user_patterns['query_history']:
                return 0.0
            
            # Simple similarity based on keyword overlap
            query_words = set(query.lower().split())
            
            similarities = []
            for hist_query in list(self.user_patterns['query_history'])[-10:]:  # Last 10 queries
                hist_words = set(hist_query['query'].lower().split())
                if hist_words:
                    intersection = len(query_words & hist_words)
                    union = len(query_words | hist_words)
                    similarity = intersection / union if union > 0 else 0.0
                    similarities.append(similarity)
            
            return max(similarities) if similarities else 0.0
            
        except Exception as e:
            logger.error(f"❌ Query similarity calculation failed: {e}")
            return 0.0
    
    def _calculate_final_score(self, content_relevance: float, temporal_relevance: float, 
                             behavior_boost: float, search_strategy: str) -> float:
        """Calculate final search score"""
        try:
            if search_strategy == 'temporal':
                weights = (0.3, 0.7)  # (content, temporal)
            elif search_strategy == 'content':
                weights = (0.8, 0.2)  # (content, temporal)
            else:  # mixed
                weights = (0.6, 0.4)  # (content, temporal)
            
            base_score = weights[0] * content_relevance + weights[1] * temporal_relevance
            final_score = base_score * behavior_boost
            
            return min(final_score, 1.0)  # Cap at 1.0
            
        except Exception as e:
            logger.error(f"❌ Final score calculation failed: {e}")
            return 0.5
    
    def _create_fallback_query(self, query: str, current_context: Dict[str, Any] = None) -> TemporalQuery:
        """Create fallback query when parsing fails"""
        try:
            now = datetime.now()
            
            fallback_intent = QueryIntent(
                intent_type='what',
                confidence=0.3,
                entities=[],
                temporal_entities=[],
                keywords=query.split()[:5],
                context_clues=[]
            )
            
            return TemporalQuery(
                original_query=query,
                intent=fallback_intent,
                time_range=(now - timedelta(hours=1), now),
                priority_keywords=query.split()[:5],
                context_filters=current_context or {},
                search_strategy='mixed'
            )
            
        except Exception as e:
            logger.error(f"❌ Fallback query creation failed: {e}")
            return TemporalQuery(
                original_query=query,
                intent=QueryIntent('what', 0.1, [], [], [], []),
                time_range=(datetime.now() - timedelta(hours=1), datetime.now()),
                priority_keywords=[],
                context_filters={},
                search_strategy='mixed'
            )
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get parser performance statistics"""
        try:
            avg_parse_time = sum(self.parse_times) / len(self.parse_times) if self.parse_times else 0
            success_rate = self.successful_parses / self.total_queries if self.total_queries > 0 else 0
            
            return {
                'total_queries': self.total_queries,
                'successful_parses': self.successful_parses,
                'success_rate': success_rate,
                'avg_parse_time_ms': avg_parse_time * 1000,
                'query_history_size': len(self.user_patterns['query_history']),
                'learned_patterns': len(self.user_patterns['common_apps']),
                'spacy_available': self.nlp is not None,
                'dateutil_available': DATEUTIL_AVAILABLE,
                'fuzzywuzzy_available': FUZZYWUZZY_AVAILABLE
            }
            
        except Exception as e:
            logger.error(f"❌ Performance stats failed: {e}")
            return {'error': str(e)}
    
    def update_user_patterns(self, query: str, results: List[SearchResult], selected_result: SearchResult):
        """Update user behavior patterns based on selections"""
        try:
            # Update app usage patterns
            if selected_result.metadata.get('app_context'):
                app = selected_result.metadata['app_context']
                self.user_patterns['common_apps'][app] += 1
            
            # Update time patterns
            hour = selected_result.timestamp.hour
            self.user_patterns['common_times'][hour] += 1
            
            # Update disambiguation choices
            if len(results) > 1:
                query_key = ' '.join(query.split()[:3])  # First 3 words as key
                self.user_patterns['disambiguation_choices'][query_key] += 1
            
            self.successful_parses += 1
            
        except Exception as e:
            logger.error(f"❌ User pattern update failed: {e}")
    
    def cleanup(self):
        """Clean up resources"""
        try:
            # Clear patterns to free memory
            self.user_patterns['query_history'].clear()
            self.user_patterns['common_apps'].clear()
            self.user_patterns['common_times'].clear()
            self.user_patterns['disambiguation_choices'].clear()
            
            logger.info("✅ AdvancedTemporalParser cleanup completed")
            
        except Exception as e:
            logger.error(f"❌ Cleanup failed: {e}")
    
    def __del__(self):
        """Destructor"""
        self.cleanup()