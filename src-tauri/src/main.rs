// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod db;
mod audio;
mod diarization;
mod llm;

fn main() {
    tauri::Builder::default()
        .manage(audio::RecordingState::new())
        .manage(db::DbState::new())
        .manage(llm::LlmState::new())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            db::initialize_db_cmd,
            db::create_meeting_cmd,
            db::update_meeting_status_cmd,
            db::save_speech_clip_cmd,
            db::get_meetings_list_cmd,
            db::get_meeting_details_cmd,
            db::add_document_cmd,
            db::get_documents_cmd,
            db::bind_document_cmd,
            db::get_meeting_documents_cmd,
            audio::start_recording_cmd,
            audio::stop_recording_cmd,
            diarization::run_diarization_cmd,
            llm::process_text_cmd,
            llm::get_ollama_models_cmd,
            llm::pull_ollama_model_cmd,
            llm::get_active_model_cmd,
            llm::set_active_model_cmd
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
