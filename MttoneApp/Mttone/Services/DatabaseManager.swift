import Foundation
import SQLite3

internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 本地 SQLite 数据库管理器
/// 使用 iOS 内置的 SQLite3 C API，零外部依赖
@Observable
final class DatabaseManager {

    private var db: OpaquePointer?
    private let dbPath: String

    init() {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        dbPath = documentsURL.appendingPathComponent("mttone.db").path
        openDatabase()
        createTables()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - 数据库初始化

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("[DB] ERROR: Failed to open database: \(errmsg)")
        } else {
            print("[DB] Database opened at: \(dbPath)")
            // 开启外键约束
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        }
    }

    private func createTables() {
        let schema = """
        CREATE TABLE IF NOT EXISTS contacts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            avatar_url TEXT,
            created_at TEXT DEFAULT (datetime('now')),
            updated_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS meetings (
            id TEXT PRIMARY KEY,
            parent_meeting_id TEXT,
            title TEXT NOT NULL,
            location TEXT,
            audio_path TEXT NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL CHECK(status IN ('recording', 'pending_diarization', 'processing_llm', 'completed')),
            summary TEXT,
            created_at TEXT DEFAULT (datetime('now')),
            updated_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (parent_meeting_id) REFERENCES meetings(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            file_path TEXT NOT NULL,
            text_content TEXT,
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS meeting_document_bindings (
            meeting_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            PRIMARY KEY (meeting_id, document_id),
            FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS speech_clips (
            id TEXT PRIMARY KEY,
            meeting_id TEXT NOT NULL,
            speaker_label TEXT NOT NULL,
            contact_id TEXT,
            start_time REAL NOT NULL,
            end_time REAL NOT NULL,
            original_text TEXT NOT NULL,
            cleaned_text TEXT,
            audio_clip_path TEXT,
            is_key_clip INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
            FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL
        );
        """

        if sqlite3_exec(db, schema, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("[DB] ERROR: Failed to create tables: \(errmsg)")
        } else {
            print("[DB] Tables created successfully")
        }
    }

    // MARK: - Meeting CRUD

    func createMeeting(_ meeting: Meeting) throws {
        let sql = """
        INSERT INTO meetings (id, parent_meeting_id, title, location, audio_path, duration, status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, meeting.id.cString, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 2, value: meeting.parentMeetingId)
        sqlite3_bind_text(stmt, 3, meeting.title.cString, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 4, value: meeting.location)
        sqlite3_bind_text(stmt, 5, meeting.audioPath.cString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 6, Int32(meeting.duration))
        sqlite3_bind_text(stmt, 7, meeting.status.rawValue.cString, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.executeFailed(lastError)
        }
        print("[DB] Meeting created: \(meeting.id) - \(meeting.title)")
    }

    /// 获取上一次会议的 ID
    func fetchLastMeetingId() -> String? {
        let sql = "SELECT id FROM meetings ORDER BY created_at DESC LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[DB] ERROR preparing last meeting fetch: \(lastError)")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            return columnText(stmt, index: 0)
        }
        return nil
    }

    func fetchAllMeetings() -> [Meeting] {
        let sql = "SELECT id, parent_meeting_id, title, location, audio_path, duration, status, summary, created_at, updated_at FROM meetings ORDER BY created_at DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[DB] ERROR fetching meetings: \(lastError)")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var meetings: [Meeting] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = columnText(stmt, index: 0)
            let parentId = columnOptionalText(stmt, index: 1)
            let title = columnText(stmt, index: 2)
            let location = columnOptionalText(stmt, index: 3)
            let audioPath = columnText(stmt, index: 4)
            let duration = Int(sqlite3_column_int(stmt, 5))
            let statusStr = columnText(stmt, index: 6)
            let summary = columnOptionalText(stmt, index: 7)
            let createdAtStr = columnText(stmt, index: 8)
            let updatedAtStr = columnText(stmt, index: 9)

            let status = Meeting.Status(rawValue: statusStr) ?? .recording
            let createdAt = dateFormatter.date(from: createdAtStr) ?? Date()
            let updatedAt = dateFormatter.date(from: updatedAtStr) ?? Date()

            meetings.append(Meeting(
                id: id,
                parentMeetingId: parentId,
                title: title,
                location: location,
                audioPath: audioPath,
                duration: duration,
                status: status,
                summary: summary,
                createdAt: createdAt,
                updatedAt: updatedAt
            ))
        }
        return meetings
    }

    func updateMeetingStatus(id: String, status: Meeting.Status, duration: Int? = nil) throws {
        var sql = "UPDATE meetings SET status = ?, updated_at = datetime('now')"
        if duration != nil {
            sql += ", duration = ?"
        }
        sql += " WHERE id = ?"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, status.rawValue.cString, -1, SQLITE_TRANSIENT)
        if let dur = duration {
            sqlite3_bind_int(stmt, 2, Int32(dur))
            sqlite3_bind_text(stmt, 3, id.cString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_text(stmt, 2, id.cString, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.executeFailed(lastError)
        }
    }

    // MARK: - SpeechClip CRUD

    func saveSpeechClip(_ clip: SpeechClip) throws {
        let sql = """
        INSERT INTO speech_clips (id, meeting_id, speaker_label, contact_id, start_time, end_time, original_text, cleaned_text, audio_clip_path, is_key_clip)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, clip.id.cString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, clip.meetingId.cString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, clip.speakerLabel.cString, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 4, value: clip.contactId)
        sqlite3_bind_double(stmt, 5, clip.startTime)
        sqlite3_bind_double(stmt, 6, clip.endTime)
        sqlite3_bind_text(stmt, 7, clip.originalText.cString, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 8, value: clip.cleanedText)
        bindOptionalText(stmt, index: 9, value: clip.audioClipPath)
        sqlite3_bind_int(stmt, 10, clip.isKeyClip ? 1 : 0)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.executeFailed(lastError)
        }
    }
    
    func deleteSpeechClips(meetingId: String) throws {
        let sql = "DELETE FROM speech_clips WHERE meeting_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, meetingId.cString, -1, SQLITE_TRANSIENT)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.executeFailed(lastError)
        }
    }
    
    func fetchSpeechClips(meetingId: String) -> [SpeechClip] {
        let sql = "SELECT id, meeting_id, speaker_label, contact_id, start_time, end_time, original_text, cleaned_text, audio_clip_path, is_key_clip, created_at FROM speech_clips WHERE meeting_id = ? ORDER BY start_time ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[DB] ERROR fetching speech clips: \(lastError)")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, meetingId.cString, -1, SQLITE_TRANSIENT)
        
        var clips: [SpeechClip] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = columnText(stmt, index: 0)
            let mId = columnText(stmt, index: 1)
            let speaker = columnText(stmt, index: 2)
            let contactId = columnOptionalText(stmt, index: 3)
            let start = sqlite3_column_double(stmt, 4)
            let end = sqlite3_column_double(stmt, 5)
            let text = columnText(stmt, index: 6)
            let cleaned = columnOptionalText(stmt, index: 7)
            let path = columnOptionalText(stmt, index: 8)
            let isKey = sqlite3_column_int(stmt, 9) != 0
            
            clips.append(SpeechClip(
                id: id,
                meetingId: mId,
                speakerLabel: speaker,
                contactId: contactId,
                startTime: start,
                endTime: end,
                originalText: text,
                cleanedText: cleaned,
                audioClipPath: path,
                isKeyClip: isKey
            ))
        }
        return clips
    }

    // MARK: - SQLite Helpers

    private var lastError: String {
        if let errmsg = sqlite3_errmsg(db) {
            return String(cString: errmsg)
        }
        return "Unknown error"
    }

    private func columnText(_ stmt: OpaquePointer?, index: Int32) -> String {
        if let cStr = sqlite3_column_text(stmt, index) {
            return String(cString: cStr)
        }
        return ""
    }

    private func columnOptionalText(_ stmt: OpaquePointer?, index: Int32) -> String? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        if let cStr = sqlite3_column_text(stmt, index) {
            return String(cString: cStr)
        }
        return nil
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v.cString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
}

// MARK: - 错误类型

enum DBError: LocalizedError {
    case prepareFailed(String)
    case executeFailed(String)

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg): return "SQL Prepare Failed: \(msg)"
        case .executeFailed(let msg): return "SQL Execute Failed: \(msg)"
        }
    }
}

// MARK: - String Extension

private extension String {
    var cString: UnsafePointer<CChar>? {
        return (self as NSString).utf8String
    }
}
