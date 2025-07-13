import Foundation
import SQLite3

// MARK: - Learning & Personalization System for Phase 3

class LearningManager {
    private var db: OpaquePointer?
    private let dbPath: String
    private let maxVocabEntries = 10000
    private let maxToneEntries = 100
    
    init() {
        // Create database in app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sttDirectory = appSupport.appendingPathComponent("STTDictate", isDirectory: true)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: sttDirectory, withIntermediateDirectories: true, attributes: nil)
        
        dbPath = sttDirectory.appendingPathComponent("learning.db").path
        
        initializeDatabase()
        NSLog("🧠 LearningManager initialized: \(dbPath)")
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func initializeDatabase() {
        // Open database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            NSLog("❌ Failed to open learning database")
            return
        }
        
        // Create tables
        createTables()
    }
    
    private func createTables() {
        // Vocabulary table - stores learned words with context
        let createVocabTable = """
            CREATE TABLE IF NOT EXISTS vocabulary (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT NOT NULL,
                context TEXT,
                app_category TEXT,
                frequency INTEGER DEFAULT 1,
                learned_date DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(word, app_category)
            );
        """
        
        // Tone preferences table - stores user tone preferences per context
        let createToneTable = """
            CREATE TABLE IF NOT EXISTS tone_preferences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_id TEXT,
                app_category TEXT,
                ui_context TEXT,
                preferred_tone TEXT,
                confidence REAL DEFAULT 1.0,
                usage_count INTEGER DEFAULT 1,
                last_used DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(app_id, ui_context)
            );
        """
        
        // User corrections table - learns from user edits and corrections
        let createCorrectionsTable = """
            CREATE TABLE IF NOT EXISTS corrections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_text TEXT NOT NULL,
                corrected_text TEXT NOT NULL,
                context_info TEXT,
                correction_type TEXT, -- 'tone', 'vocabulary', 'grammar'
                created_date DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        // Execute table creation
        executeSQL(createVocabTable)
        executeSQL(createToneTable)
        executeSQL(createCorrectionsTable)
        
        // Create indexes for performance
        executeSQL("CREATE INDEX IF NOT EXISTS idx_vocab_word ON vocabulary(word);")
        executeSQL("CREATE INDEX IF NOT EXISTS idx_vocab_category ON vocabulary(app_category);")
        executeSQL("CREATE INDEX IF NOT EXISTS idx_tone_category ON tone_preferences(app_category);")
    }
    
    private func executeSQL(_ sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            NSLog("❌ SQL Error: \(errorMessage)")
        }
    }
    
    // MARK: - Vocabulary Learning
    
    func learnVocabulary(word: String, context: ContextInfo) {
        let sql = """
            INSERT OR REPLACE INTO vocabulary (word, context, app_category, frequency)
            VALUES (?, ?, ?, COALESCE((SELECT frequency FROM vocabulary WHERE word = ? AND app_category = ?) + 1, 1));
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, word, -1, nil)
            sqlite3_bind_text(statement, 2, context.uiContext, -1, nil)
            sqlite3_bind_text(statement, 3, context.appCategory, -1, nil)
            sqlite3_bind_text(statement, 4, word, -1, nil)
            sqlite3_bind_text(statement, 5, context.appCategory, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                NSLog("🧠 Learned vocabulary: '\(word)' in \(context.appCategory)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func getPersonalVocabulary(for context: ContextInfo) -> [String] {
        let sql = """
            SELECT word FROM vocabulary 
            WHERE app_category = ? OR app_category = 'general'
            ORDER BY frequency DESC, learned_date DESC 
            LIMIT 1000;
        """
        
        var words: [String] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, context.appCategory, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let word = sqlite3_column_text(statement, 0) {
                    words.append(String(cString: word))
                }
            }
        }
        sqlite3_finalize(statement)
        
        return words
    }
    
    // MARK: - Tone Learning
    
    func learnTonePreference(context: ContextInfo, preferredTone: String, confidence: Double = 1.0) {
        let sql = """
            INSERT OR REPLACE INTO tone_preferences 
            (app_id, app_category, ui_context, preferred_tone, confidence, usage_count, last_used)
            VALUES (?, ?, ?, ?, ?, 
                COALESCE((SELECT usage_count FROM tone_preferences WHERE app_id = ? AND ui_context = ?) + 1, 1),
                CURRENT_TIMESTAMP);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, context.appId, -1, nil)
            sqlite3_bind_text(statement, 2, context.appCategory, -1, nil)
            sqlite3_bind_text(statement, 3, context.uiContext, -1, nil)
            sqlite3_bind_text(statement, 4, preferredTone, -1, nil)
            sqlite3_bind_double(statement, 5, confidence)
            sqlite3_bind_text(statement, 6, context.appId, -1, nil)
            sqlite3_bind_text(statement, 7, context.uiContext, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                NSLog("🧠 Learned tone preference: '\(preferredTone)' for \(context.appCategory)/\(context.uiContext)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func getPreferredTone(for context: ContextInfo) -> String? {
        // Try exact match first (app + ui context)
        if let tone = queryTonePreference(appId: context.appId, uiContext: context.uiContext) {
            return tone
        }
        
        // Fall back to app category
        if let tone = queryTonePreference(appCategory: context.appCategory) {
            return tone
        }
        
        return nil
    }
    
    private func queryTonePreference(appId: String? = nil, appCategory: String? = nil, uiContext: String? = nil) -> String? {
        var sql = "SELECT preferred_tone FROM tone_preferences WHERE "
        var conditions: [String] = []
        
        if let appId = appId {
            conditions.append("app_id = ?")
        }
        if let appCategory = appCategory {
            conditions.append("app_category = ?")
        }
        if let uiContext = uiContext {
            conditions.append("ui_context = ?")
        }
        
        sql += conditions.joined(separator: " AND ")
        sql += " ORDER BY confidence DESC, usage_count DESC LIMIT 1;"
        
        var statement: OpaquePointer?
        var result: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            var bindIndex: Int32 = 1
            
            if let appId = appId {
                sqlite3_bind_text(statement, bindIndex, appId, -1, nil)
                bindIndex += 1
            }
            if let appCategory = appCategory {
                sqlite3_bind_text(statement, bindIndex, appCategory, -1, nil)
                bindIndex += 1
            }
            if let uiContext = uiContext {
                sqlite3_bind_text(statement, bindIndex, uiContext, -1, nil)
            }
            
            if sqlite3_step(statement) == SQLITE_ROW {
                if let tone = sqlite3_column_text(statement, 0) {
                    result = String(cString: tone)
                }
            }
        }
        sqlite3_finalize(statement)
        
        return result
    }
    
    // MARK: - User Corrections Learning
    
    func learnFromCorrection(original: String, corrected: String, context: ContextInfo, type: String) {
        // Store the correction
        let sql = """
            INSERT INTO corrections (original_text, corrected_text, context_info, correction_type)
            VALUES (?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, original, -1, nil)
            sqlite3_bind_text(statement, 2, corrected, -1, nil)
            sqlite3_bind_text(statement, 3, "\(context.appCategory):\(context.uiContext)", -1, nil)
            sqlite3_bind_text(statement, 4, type, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                NSLog("🧠 Learned from correction: \(type)")
                
                // Extract and learn new vocabulary
                if context.shouldLearnVocab {
                    learnVocabularyFromText(corrected, context: context)
                }
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func learnVocabularyFromText(_ text: String, context: ContextInfo) {
        // Extract proper nouns and technical terms (capitalized words, uncommon terms)
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        for word in words {
            let trimmed = word.trimmingCharacters(in: CharacterSet.punctuationCharacters)
            
            // Learn capitalized words (likely names/places) and technical terms
            if trimmed.count > 2 && (trimmed.first?.isUppercase == true || isLikelyTechnicalTerm(trimmed)) {
                learnVocabulary(word: trimmed, context: context)
            }
        }
    }
    
    private func isLikelyTechnicalTerm(_ word: String) -> Bool {
        // Simple heuristics for technical terms
        return word.contains("API") || 
               word.contains("URL") || 
               word.contains("HTTP") ||
               word.contains("_") ||
               word.contains("-") ||
               (word.count > 6 && word.lowercased() != word) // Mixed case long words
    }
    
    // MARK: - Statistics and Maintenance
    
    func getStats() -> [String: Int] {
        var stats: [String: Int] = [:]
        
        // Count vocabulary entries
        if let count = queryCount("SELECT COUNT(*) FROM vocabulary") {
            stats["vocabulary_entries"] = count
        }
        
        // Count tone preferences
        if let count = queryCount("SELECT COUNT(*) FROM tone_preferences") {
            stats["tone_preferences"] = count
        }
        
        // Count corrections
        if let count = queryCount("SELECT COUNT(*) FROM corrections") {
            stats["corrections"] = count
        }
        
        return stats
    }
    
    private func queryCount(_ sql: String) -> Int? {
        var statement: OpaquePointer?
        var result: Int?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                result = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        
        return result
    }
    
    func cleanupOldEntries() {
        // Remove old vocabulary entries if exceeding limit
        executeSQL("""
            DELETE FROM vocabulary WHERE id NOT IN (
                SELECT id FROM vocabulary ORDER BY frequency DESC, learned_date DESC LIMIT \(maxVocabEntries)
            );
        """)
        
        // Remove old tone preferences if exceeding limit  
        executeSQL("""
            DELETE FROM tone_preferences WHERE id NOT IN (
                SELECT id FROM tone_preferences ORDER BY usage_count DESC, last_used DESC LIMIT \(maxToneEntries)
            );
        """)
        
        NSLog("🧠 Cleanup completed")
    }
}