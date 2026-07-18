import Foundation
import SQLite3

// MARK: - SpeechClip CRUD 扩展

extension DatabaseManager {

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

    func fetchSpeechClipsCount(meetingId: String) -> Int {
        let sql = "SELECT COUNT(*) FROM speech_clips WHERE meeting_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, meetingId.cString, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func fetchSpeechClips(meetingId: String) -> [SpeechClip] {
        let sql = "SELECT id, meeting_id, speaker_label, contact_id, start_time, end_time, original_text, cleaned_text, audio_clip_path, is_key_clip, created_at FROM speech_clips WHERE meeting_id = ? ORDER BY start_time ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, meetingId.cString, -1, SQLITE_TRANSIENT)

        var clips: [SpeechClip] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            clips.append(makeSpeechClip(from: stmt))
        }
        return clips
    }

    func updateSpeechClipContact(clipId: String, speakerLabel: String, contactId: String?) throws {
        let sql = "UPDATE speech_clips SET speaker_label = ?, contact_id = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, speakerLabel.cString, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 2, value: contactId)
        sqlite3_bind_text(stmt, 3, clipId.cString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.executeFailed(lastError)
        }
    }

    func updateSpeechClipText(clipId: String, text: String) throws {
        let sql = "UPDATE speech_clips SET original_text = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, text.cString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, clipId.cString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.executeFailed(lastError)
        }
    }

    func fetchSpeechClips(forContact contactId: String) -> [SpeechClip] {
        let sql = "SELECT id, meeting_id, speaker_label, contact_id, start_time, end_time, original_text, cleaned_text, audio_clip_path, is_key_clip, created_at FROM speech_clips WHERE contact_id = ? ORDER BY start_time ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, contactId.cString, -1, SQLITE_TRANSIENT)

        var clips: [SpeechClip] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            clips.append(makeSpeechClip(from: stmt))
        }
        return clips
    }

    func fetchSpeechClipsGroupedByMeeting(forContact contactId: String) -> [(meeting: Meeting, clips: [SpeechClip])] {
        let clipsSQL = """
        SELECT sc.id, sc.meeting_id, sc.speaker_label, sc.contact_id, sc.start_time, sc.end_time, 
               sc.original_text, sc.cleaned_text, sc.audio_clip_path, sc.is_key_clip, sc.created_at,
               m.title, m.created_at as meeting_created
        FROM speech_clips sc
        JOIN meetings m ON m.id = sc.meeting_id
        WHERE sc.contact_id = ?
        ORDER BY m.created_at DESC, sc.start_time ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, clipsSQL, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, contactId.cString, -1, SQLITE_TRANSIENT)

        var groups: [String: (meeting: Meeting, clips: [SpeechClip])] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = columnText(stmt, index: 0)
            let meetingId = columnText(stmt, index: 1)
            let speaker = columnText(stmt, index: 2)
            let cid = columnOptionalText(stmt, index: 3)
            let start = sqlite3_column_double(stmt, 4)
            let end = sqlite3_column_double(stmt, 5)
            let text = columnText(stmt, index: 6)
            let cleaned = columnOptionalText(stmt, index: 7)
            let path = columnOptionalText(stmt, index: 8)
            let isKey = sqlite3_column_int(stmt, 9) != 0
            let title = columnText(stmt, index: 11)
            let meetingCreated = Self.dateFormatter.date(from: columnText(stmt, index: 12)) ?? Date()

            let clip = SpeechClip(id: id, meetingId: meetingId, speakerLabel: speaker, contactId: cid,
                                   startTime: start, endTime: end, originalText: text, cleanedText: cleaned,
                                   audioClipPath: path, isKeyClip: isKey)

            if groups[meetingId] == nil {
                let meeting = Meeting(id: meetingId, parentMeetingId: nil, title: title,
                                      location: nil, audioPath: "", duration: 0, status: .completed,
                                      summary: nil, createdAt: meetingCreated, updatedAt: meetingCreated)
                groups[meetingId] = (meeting: meeting, clips: [])
            }
            groups[meetingId]?.clips.append(clip)
        }
        return groups.values.sorted { $0.meeting.createdAt > $1.meeting.createdAt }
    }

    func splitSpeechClip(oldClipId: String, newClip1: SpeechClip, newClip2: SpeechClip) throws {
        guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            throw DBError.executeFailed("BEGIN TRANSACTION: " + lastError)
        }

        do {
            let deleteSql = "DELETE FROM speech_clips WHERE id = ?"
            var delStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, deleteSql, -1, &delStmt, nil) == SQLITE_OK else {
                throw DBError.prepareFailed("DELETE speech_clips: " + lastError)
            }
            sqlite3_bind_text(delStmt, 1, oldClipId.cString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(delStmt) != SQLITE_DONE {
                sqlite3_finalize(delStmt)
                throw DBError.executeFailed("DELETE step: " + lastError)
            }
            sqlite3_finalize(delStmt)

            try insertSpeechClipInsideTransaction(clip: newClip1)
            try insertSpeechClipInsideTransaction(clip: newClip2)

            guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                throw DBError.executeFailed("COMMIT: " + lastError)
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private func insertSpeechClipInsideTransaction(clip: SpeechClip) throws {
        let sql = """
        INSERT INTO speech_clips (id, meeting_id, speaker_label, contact_id, start_time, end_time, original_text, cleaned_text, audio_clip_path, is_key_clip, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed("INSERT speech_clips: " + lastError)
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

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DBError.executeFailed("INSERT step: " + lastError)
        }
    }
}
