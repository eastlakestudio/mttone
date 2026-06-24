use rusqlite::Connection;
use std::path::PathBuf;
use std::sync::Mutex;

pub struct DbState {
    pub db_path: Mutex<Option<String>>,
}

impl DbState {
    pub fn new() -> Self {
        Self {
            db_path: Mutex::new(None),
        }
    }
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct MeetingInfo {
    pub id: String,
    pub parent_meeting_id: Option<String>,
    pub title: String,
    pub location: Option<String>,
    pub audio_path: String,
    pub duration: i32,
    pub status: String,
    pub created_at: String,
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct DocumentInfo {
    pub id: String,
    pub filename: String,
    pub file_path: String,
    pub text_content: Option<String>,
    pub created_at: String,
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct SpeechClipInfo {
    pub id: String,
    pub meeting_id: String,
    pub speaker_label: String,
    pub contact_id: Option<String>,
    pub start_time: f64,
    pub end_time: f64,
    pub original_text: String,
    pub cleaned_text: Option<String>,
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct MeetingDetails {
    pub meeting: MeetingInfo,
    pub clips: Vec<SpeechClipInfo>,
}

fn get_connection(db_state: &tauri::State<'_, DbState>) -> Result<Connection, String> {
    let guard = db_state.db_path.lock().map_err(|e| format!("Lock failed: {}", e))?;
    let path_str = guard.as_ref().ok_or_else(|| "Database not initialized".to_string())?;
    Connection::open(path_str).map_err(|e| format!("Failed to open DB: {}", e))
}

#[tauri::command]
pub fn initialize_db_cmd(db_path: String, state: tauri::State<'_, DbState>) -> Result<String, String> {
    let path = PathBuf::from(&db_path);
    let conn = Connection::open(&path)
        .map_err(|e| format!("Failed to open database: {}", e))?;
    
    // 开启外键支持
    conn.execute("PRAGMA foreign_keys = ON;", [])
        .map_err(|e| format!("Failed to enable foreign keys: {}", e))?;
        
    let schema = include_str!("schema.sql");
    conn.execute_batch(schema)
        .map_err(|e| format!("Failed to execute schema: {}", e))?;
        
    if let Ok(mut guard) = state.db_path.lock() {
        *guard = Some(db_path);
    }
        
    Ok("Database initialized successfully".to_string())
}

#[tauri::command]
pub fn create_meeting_cmd(
    id: String,
    parent_meeting_id: Option<String>,
    title: String,
    location: Option<String>,
    audio_path: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<(), String> {
    let conn = get_connection(&db_state)?;
    conn.execute(
        "INSERT INTO meetings (id, parent_meeting_id, title, location, audio_path, duration, status) VALUES (?1, ?2, ?3, ?4, ?5, 0, 'recording')",
        rusqlite::params![id, parent_meeting_id, title, location, audio_path],
    )
    .map_err(|e| format!("Insert meeting failed: {}", e))?;
    Ok(())
}

#[tauri::command]
pub fn update_meeting_status_cmd(
    id: String,
    duration: i32,
    status: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<(), String> {
    let conn = get_connection(&db_state)?;
    conn.execute(
        "UPDATE meetings SET duration = ?1, status = ?2 WHERE id = ?3",
        rusqlite::params![duration, status, id],
    )
    .map_err(|e| format!("Update meeting status failed: {}", e))?;
    Ok(())
}

#[tauri::command]
pub fn save_speech_clip_cmd(
    id: String,
    meeting_id: String,
    speaker_label: String,
    start_time: f64,
    end_time: f64,
    original_text: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<(), String> {
    let conn = get_connection(&db_state)?;
    conn.execute(
        "INSERT OR REPLACE INTO speech_clips (id, meeting_id, speaker_label, start_time, end_time, original_text) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        rusqlite::params![id, meeting_id, speaker_label, start_time, end_time, original_text],
    )
    .map_err(|e| format!("Save speech clip failed: {}", e))?;
    Ok(())
}

#[tauri::command]
pub fn get_meetings_list_cmd(
    db_state: tauri::State<'_, DbState>,
) -> Result<Vec<MeetingInfo>, String> {
    let conn = get_connection(&db_state)?;
    let mut stmt = conn
        .prepare("SELECT id, parent_meeting_id, title, location, audio_path, duration, status, datetime(created_at, 'localtime') FROM meetings ORDER BY created_at DESC")
        .map_err(|e| format!("Prepare query failed: {}", e))?;
        
    let rows = stmt
        .query_map([], |row| {
            Ok(MeetingInfo {
                id: row.get(0)?,
                parent_meeting_id: row.get(1)?,
                title: row.get(2)?,
                location: row.get(3)?,
                audio_path: row.get(4)?,
                duration: row.get(5)?,
                status: row.get(6)?,
                created_at: row.get(7)?,
            })
        })
        .map_err(|e| format!("Query mapping failed: {}", e))?;
        
    let mut meetings = Vec::new();
    for r in rows {
        if let Ok(m) = r {
            meetings.push(m);
        }
    }
    Ok(meetings)
}

#[tauri::command]
pub fn get_meeting_details_cmd(
    meeting_id: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<MeetingDetails, String> {
    let conn = get_connection(&db_state)?;
    
    // 查询会议信息
    let mut stmt_m = conn
        .prepare("SELECT id, parent_meeting_id, title, location, audio_path, duration, status, datetime(created_at, 'localtime') FROM meetings WHERE id = ?1")
        .map_err(|e| format!("Prepare meeting query failed: {}", e))?;
    let mut rows_m = stmt_m
        .query_map([&meeting_id], |row| {
            Ok(MeetingInfo {
                id: row.get(0)?,
                parent_meeting_id: row.get(1)?,
                title: row.get(2)?,
                location: row.get(3)?,
                audio_path: row.get(4)?,
                duration: row.get(5)?,
                status: row.get(6)?,
                created_at: row.get(7)?,
            })
        })
        .map_err(|e| format!("Query mapping failed: {}", e))?;
    
    let meeting = rows_m
        .next()
        .ok_or_else(|| "Meeting not found".to_string())?
        .map_err(|e| format!("Meeting fetch failed: {}", e))?;
        
    // 查询段落切片
    let mut stmt_s = conn
        .prepare("SELECT id, meeting_id, speaker_label, contact_id, start_time, end_time, original_text, cleaned_text FROM speech_clips WHERE meeting_id = ?1 ORDER BY start_time ASC")
        .map_err(|e| format!("Prepare speech clips query failed: {}", e))?;
    let rows_s = stmt_s
        .query_map([&meeting_id], |row| {
            Ok(SpeechClipInfo {
                id: row.get(0)?,
                meeting_id: row.get(1)?,
                speaker_label: row.get(2)?,
                contact_id: row.get(3)?,
                start_time: row.get(4)?,
                end_time: row.get(5)?,
                original_text: row.get(6)?,
                cleaned_text: row.get(7)?,
            })
        })
        .map_err(|e| format!("Query mapping failed: {}", e))?;
        
    let mut clips = Vec::new();
    for r in rows_s {
        if let Ok(c) = r {
            clips.push(c);
        }
    }
    
    Ok(MeetingDetails { meeting, clips })
}

#[tauri::command]
pub fn add_document_cmd(
    id: String,
    filename: String,
    file_path: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<(), String> {
    let conn = get_connection(&db_state)?;
    conn.execute(
        "INSERT INTO documents (id, filename, file_path) VALUES (?1, ?2, ?3)",
        rusqlite::params![id, filename, file_path],
    )
    .map_err(|e| format!("Insert document failed: {}", e))?;
    Ok(())
}

#[tauri::command]
pub fn get_documents_cmd(
    db_state: tauri::State<'_, DbState>,
) -> Result<Vec<DocumentInfo>, String> {
    let conn = get_connection(&db_state)?;
    let mut stmt = conn
        .prepare("SELECT id, filename, file_path, text_content, datetime(created_at, 'localtime') FROM documents ORDER BY created_at DESC")
        .map_err(|e| format!("Prepare query failed: {}", e))?;
        
    let rows = stmt
        .query_map([], |row| {
            Ok(DocumentInfo {
                id: row.get(0)?,
                filename: row.get(1)?,
                file_path: row.get(2)?,
                text_content: row.get(3)?,
                created_at: row.get(4)?,
            })
        })
        .map_err(|e| format!("Query mapping failed: {}", e))?;
        
    let mut docs = Vec::new();
    for r in rows {
        if let Ok(d) = r {
            docs.push(d);
        }
    }
    Ok(docs)
}

#[tauri::command]
pub fn bind_document_cmd(
    meeting_id: String,
    document_id: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<(), String> {
    let conn = get_connection(&db_state)?;
    conn.execute(
        "INSERT OR IGNORE INTO meeting_document_bindings (meeting_id, document_id) VALUES (?1, ?2)",
        rusqlite::params![meeting_id, document_id],
    )
    .map_err(|e| format!("Bind document failed: {}", e))?;
    Ok(())
}

#[tauri::command]
pub fn get_meeting_documents_cmd(
    meeting_id: String,
    db_state: tauri::State<'_, DbState>,
) -> Result<Vec<DocumentInfo>, String> {
    let conn = get_connection(&db_state)?;
    let mut stmt = conn
        .prepare(
            "SELECT d.id, d.filename, d.file_path, d.text_content, datetime(d.created_at, 'localtime') 
             FROM documents d 
             INNER JOIN meeting_document_bindings b ON d.id = b.document_id 
             WHERE b.meeting_id = ?1 ORDER BY d.created_at DESC"
        )
        .map_err(|e| format!("Prepare query failed: {}", e))?;
        
    let rows = stmt
        .query_map([&meeting_id], |row| {
            Ok(DocumentInfo {
                id: row.get(0)?,
                filename: row.get(1)?,
                file_path: row.get(2)?,
                text_content: row.get(3)?,
                created_at: row.get(4)?,
            })
        })
        .map_err(|e| format!("Query mapping failed: {}", e))?;
        
    let mut docs = Vec::new();
    for r in rows {
        if let Ok(d) = r {
            docs.push(d);
        }
    }
    Ok(docs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initialize_database_in_memory() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute("PRAGMA foreign_keys = ON;", []).unwrap();
        
        let schema = include_str!("schema.sql");
        // 分离 vss0 虚拟表定义以兼容无 vss0 插件的测试环境
        let core_schema: Vec<&str> = schema
            .split(';')
            .filter(|section| !section.contains("USING vss0"))
            .collect();

        for section in core_schema {
            let trimmed = section.trim();
            if !trimmed.is_empty() {
                conn.execute(trimmed, []).unwrap();
            }
        }

        // 验证主表是否成功创建
        let mut stmt = conn.prepare("SELECT name FROM sqlite_master WHERE type='table'").unwrap();
        let tables: Vec<String> = stmt
            .query_map([], |row| row.get(0))
            .unwrap()
            .map(|r| r.unwrap())
            .collect();

        assert!(tables.contains(&"contacts".to_string()));
        assert!(tables.contains(&"meetings".to_string()));
        assert!(tables.contains(&"speech_clips".to_string()));
    }
}
