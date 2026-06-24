use serde::{Serialize, Deserialize};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;
use uuid::Uuid;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

#[derive(Clone, Serialize, Deserialize)]
pub struct TranscriptSegment {
    pub id: String,
    pub start_time: f64,
    pub end_time: f64,
    pub text: String,
    pub speaker_label: String,
}

// 录音状态管理器
pub struct RecordingState {
    pub is_recording: Arc<AtomicBool>,
    pub active_meeting_id: Arc<Mutex<Option<String>>>,
    pub audio_buffer: Arc<std::sync::Mutex<Vec<i16>>>,
}

impl RecordingState {
    pub fn new() -> Self {
        Self {
            is_recording: Arc::new(AtomicBool::new(false)),
            active_meeting_id: Arc::new(Mutex::new(None)),
            audio_buffer: Arc::new(std::sync::Mutex::new(Vec::new())),
        }
    }
}

// 混音处理：麦克风采样与 ScreenCaptureKit 系统音频采样混合
pub fn mix_audio_streams(mic_sample: f32, system_sample: f32) -> f32 {
    let mixed = mic_sample * 0.8 + system_sample * 0.8;
    mixed.clamp(-1.0, 1.0)
}

// 物理硬件麦克风录音控制 (cpal + hound)
fn start_hardware_recording(
    is_recording: Arc<AtomicBool>,
    meeting_id: String,
    audio_buffer: Arc<std::sync::Mutex<Vec<i16>>>,
) -> Result<(), String> {
    println!("[Audio] Starting hardware recording thread...");
    std::thread::spawn(move || {
        let host = cpal::default_host();
        println!("[Audio] Got CPAL host: {:?}", host.id());
        
        let device = match host.default_input_device() {
            Some(d) => {
                let name = d.name().unwrap_or_else(|_| "Unknown".to_string());
                println!("[Audio] Found default input device: {}", name);
                d
            },
            None => {
                eprintln!("[Audio] ERROR: No input audio device found. Please check your Mac's microphone permissions or hardware.");
                return;
            }
        };

        let config = match device.default_input_config() {
            Ok(c) => {
                println!("[Audio] Device default config: {:?}", c);
                c
            },
            Err(e) => {
                eprintln!("[Audio] ERROR: Failed to get default input config: {}", e);
                return;
            }
        };

        // 设置符合 Whisper.cpp 期待的 16000Hz 单声道格式
        let spec = hound::WavSpec {
            channels: 1,
            sample_rate: 16000,
            bits_per_sample: 16,
            sample_format: hound::SampleFormat::Int,
        };

        let filename = format!("meeting_{}.wav", meeting_id);
        let mut writer = match hound::WavWriter::create(filename, spec) {
            Ok(w) => w,
            Err(e) => {
                eprintln!("Failed to create WAV writer: {}", e);
                return;
            }
        };

        let err_fn = |err| eprintln!("an error occurred on stream: {}", err);
        let is_recording_cb = is_recording.clone();

        let stream = match config.sample_format() {
            cpal::SampleFormat::F32 => {
                let audio_buffer_cb = audio_buffer.clone();
                device.build_input_stream(
                    &config.into(),
                    move |data: &[f32], _: &_| {
                        if is_recording_cb.load(Ordering::Relaxed) {
                            if let Ok(mut buf) = audio_buffer_cb.lock() {
                                for &sample in data {
                                    let val = (sample * 32767.0) as i16;
                                    let _ = writer.write_sample(val);
                                    buf.push(val);
                                }
                            }
                        }
                    },
                    err_fn,
                    None,
                )
            }
            cpal::SampleFormat::I16 => {
                let audio_buffer_cb = audio_buffer.clone();
                device.build_input_stream(
                    &config.into(),
                    move |data: &[i16], _: &_| {
                        if is_recording_cb.load(Ordering::Relaxed) {
                            if let Ok(mut buf) = audio_buffer_cb.lock() {
                                for &sample in data {
                                    let _ = writer.write_sample(sample);
                                    buf.push(sample);
                                }
                            }
                        }
                    },
                    err_fn,
                    None,
                )
            }
            _ => {
                eprintln!("Unsupported sample format");
                return;
            }
        };

        let stream = match stream {
            Ok(s) => {
                println!("[Audio] Input stream built successfully.");
                s
            },
            Err(e) => {
                eprintln!("[Audio] ERROR: Failed to build input stream: {}", e);
                return;
            }
        };

        if let Err(e) = stream.play() {
            eprintln!("[Audio] ERROR: Failed to play stream: {}", e);
            return;
        }

        println!("[Audio] Recording stream is now PLAYING...");


        while is_recording.load(Ordering::Relaxed) {
            std::thread::sleep(Duration::from_millis(100));
        }

        drop(stream);
    });

    Ok(())
}

// 真实实时语音分段 ASR 转写并入库
async fn real_asr_stream(
    app: AppHandle,
    is_recording: Arc<AtomicBool>,
    audio_buffer: Arc<std::sync::Mutex<Vec<i16>>>,
    meeting_id: String,
    db_path: String,
) {
    let mut last_processed_index = 0;
    let sample_rate = 16000;
    // 5 秒对应的采样数 (16000 * 5 = 80000)
    let chunk_size = 5 * sample_rate;
    let mut chunk_index = 0;

    // 清空起始缓冲区
    if let Ok(mut buf) = audio_buffer.lock() {
        buf.clear();
    }

    let py_path = std::path::PathBuf::from("/Users/minghualiu/personal/EastlakeStudio/mttone/venv/bin/python");
    let worker_script = std::path::PathBuf::from("/Users/minghualiu/personal/EastlakeStudio/mttone/src-tauri/src/audio/audio_worker.py");

    while is_recording.load(Ordering::Relaxed) {
        tokio::time::sleep(Duration::from_secs(5)).await;

        let samples = {
            if let Ok(buf) = audio_buffer.lock() {
                buf.clone()
            } else {
                continue;
            }
        };

        if samples.len() > last_processed_index + chunk_size {
            let start_idx = last_processed_index;
            let end_idx = samples.len();
            let chunk_samples = &samples[start_idx..end_idx];
            last_processed_index = end_idx;

            // 写入临时 chunk WAV 文件用于转写
            let temp_dir = std::env::temp_dir();
            let temp_wav_path = temp_dir.join(format!("temp_chunk_{}_{}.wav", meeting_id, chunk_index));

            let spec = hound::WavSpec {
                channels: 1,
                sample_rate: 16000,
                bits_per_sample: 16,
                sample_format: hound::SampleFormat::Int,
            };

            if let Ok(mut writer) = hound::WavWriter::create(&temp_wav_path, spec) {
                for &s in chunk_samples {
                    let _ = writer.write_sample(s);
                }
                if let Err(e) = writer.finalize() {
                    eprintln!("Failed to finalize wav chunk: {}", e);
                    let _ = std::fs::remove_file(&temp_wav_path);
                    continue;
                }

                // 调用 python transcribe 执行真实转写
                let output = std::process::Command::new(&py_path)
                    .arg(&worker_script)
                    .arg("transcribe")
                    .arg(&temp_wav_path)
                    .output();

                match output {
                    Ok(out) => {
                        if out.status.success() {
                            let stdout_str = String::from_utf8_lossy(&out.stdout);
                            if let Ok(json_val) = serde_json::from_str::<serde_json::Value>(&stdout_str) {
                                if json_val["status"] == "ok" {
                                    if let Some(segs) = json_val["segments"].as_array() {
                                        for seg in segs {
                                            let text = seg["text"].as_str().unwrap_or("").trim();
                                            if !text.is_empty() {
                                                let rel_start = seg["start"].as_f64().unwrap_or(0.0);
                                                let rel_end = seg["end"].as_f64().unwrap_or(0.0);

                                                let offset = (start_idx as f64) / (sample_rate as f64);
                                                let abs_start = offset + rel_start;
                                                let abs_end = offset + rel_end;

                                                let segment = TranscriptSegment {
                                                    id: Uuid::new_v4().to_string(),
                                                    start_time: abs_start,
                                                    end_time: abs_end,
                                                    text: text.to_string(),
                                                    speaker_label: format!("Speaker_{}", chunk_index % 3 + 1),
                                                };

                                                // 写入数据库 speech_clips
                                                if let Ok(conn) = rusqlite::Connection::open(&db_path) {
                                                    let _ = conn.execute(
                                                        "INSERT OR REPLACE INTO speech_clips (id, meeting_id, speaker_label, start_time, end_time, original_text) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                                                        rusqlite::params![&segment.id, &meeting_id, &segment.speaker_label, segment.start_time, segment.end_time, &segment.text],
                                                    );
                                                }

                                                let _ = app.emit("transcript-segment", segment);
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            let stderr_str = String::from_utf8_lossy(&out.stderr);
                            eprintln!("ASR worker stderr: {}", stderr_str);
                        }
                    }
                    Err(e) => {
                        eprintln!("Failed to run Python ASR worker: {}", e);
                    }
                }

                let _ = std::fs::remove_file(temp_wav_path);
            }

            chunk_index += 1;
        }
    }
}

#[tauri::command]
pub async fn start_recording_cmd(
    meeting_id: String,
    app: AppHandle,
    state: State<'_, RecordingState>,
    db_state: State<'_, crate::db::DbState>,
) -> Result<String, String> {
    println!("[Audio] start_recording_cmd called with meeting_id: {}", meeting_id);
    if state.is_recording.load(Ordering::Relaxed) {
        println!("[Audio] Already recording, aborting cmd.");
        return Err("Already recording".to_string());
    }

    let db_path_opt = {
        let guard = db_state.db_path.lock().unwrap();
        guard.clone()
    };
    let db_path = match db_path_opt {
        Some(p) => {
            println!("[Audio] DB Path acquired: {:?}", p);
            p
        },
        None => {
            eprintln!("[Audio] ERROR: Database not initialized!");
            return Err("Database not initialized".to_string());
        }
    };

    *state.active_meeting_id.lock().await = Some(meeting_id.clone());
    state.is_recording.store(true, Ordering::Relaxed);


    // 清空缓存
    if let Ok(mut buf) = state.audio_buffer.lock() {
        buf.clear();
    }

    // 1. 尝试开启真正的硬件录音
    let is_recording_clone_hw = state.is_recording.clone();
    let meeting_id_clone_hw = meeting_id.clone();
    let audio_buffer_clone_hw = state.audio_buffer.clone();
    
    std::thread::spawn(move || {
        if let Err(err) = start_hardware_recording(is_recording_clone_hw, meeting_id_clone_hw, audio_buffer_clone_hw) {
            eprintln!("Hardware recording error: {}", err);
        }
    });

    // 2. 同时运行 ASR 分段识别事件流以推送前端真实数据
    let is_recording_clone = state.is_recording.clone();
    let meeting_id_clone = meeting_id.clone();
    let audio_buffer_clone = state.audio_buffer.clone();
    tokio::spawn(async move {
        real_asr_stream(app, is_recording_clone, audio_buffer_clone, meeting_id_clone, db_path).await;
    });

    Ok(meeting_id)
}

#[tauri::command]
pub async fn stop_recording_cmd(
    state: State<'_, RecordingState>,
    db_state: State<'_, crate::db::DbState>,
) -> Result<String, String> {
    if !state.is_recording.load(Ordering::Relaxed) {
        return Err("Not recording".to_string());
    }

    state.is_recording.store(false, Ordering::Relaxed);
    let mut active_id = state.active_meeting_id.lock().await;
    let meeting_id = active_id.take().unwrap_or_default();

    let db_path_opt = {
        let guard = db_state.db_path.lock().unwrap();
        guard.clone()
    };
    if let Some(db_path) = db_path_opt {
        if let Ok(conn) = rusqlite::Connection::open(&db_path) {
            let duration: f64 = conn.query_row(
                "SELECT COALESCE(MAX(end_time), 0) FROM speech_clips WHERE meeting_id = ?1",
                [&meeting_id],
                |row| row.get(0)
            ).unwrap_or(0.0);
            
            let _ = conn.execute(
                "UPDATE meetings SET duration = ?1, status = 'pending_diarization' WHERE id = ?2",
                rusqlite::params![duration as i32, &meeting_id],
            );
        }
    }

    Ok(meeting_id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mix_audio_streams_normal() {
        let mic = 0.5;
        let sys = 0.3;
        let mixed = mix_audio_streams(mic, sys);
        assert!((mixed - 0.64).abs() < 1e-5);
    }

    #[test]
    fn test_mix_audio_streams_clamping() {
        let mic = 0.9;
        let sys = 0.9;
        let mixed = mix_audio_streams(mic, sys);
        assert_eq!(mixed, 1.0);
    }
}
