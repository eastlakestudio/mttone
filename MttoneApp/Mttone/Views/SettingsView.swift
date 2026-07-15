import SwiftUI
import WhisperKit

// MARK: - 国际化
func loc(_ key: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "ui_language") ?? ""
    return (lang == "en" ? enLocale : zhLocale)[key] ?? key
}

let zhLocale: [String: String] = [
    "settings": "系统配置", "save": "保存",
    "speech_model": "语音识别模型", "downloaded": "已下载",
    "cache": "缓存", "model_label": "模型", "redownload": "重新下载",
    "china_mirror": "HF-Mirror", "huggingface": "HuggingFace",
    "about_desc": "本地离线会议纪要系统  |  WhisperKit + FluidAudio",
    "about_copyright": "© 2026 Eastlake Studio. 保留所有权利。",
    "about_feature_desc": "听纪是一款完全本地离线运行的智能会议纪要系统。\n基于 WhisperKit 语音识别引擎与 FluidAudio 声纹分离技术，\n支持实时录音转写、离线高精度转写、多说话人声纹分离与匹配。\n所有音频数据均在本地处理，无需联网，保障隐私安全。",
    "about_feature_desc_en": "AuraNote is a fully offline intelligent meeting minutes system.\nPowered by WhisperKit speech recognition and FluidAudio voiceprint diarization,\nit supports real-time transcription, offline high-accuracy transcription,\nand multi-speaker voiceprint separation & matching.\nAll audio data is processed locally — no internet required, ensuring complete privacy.",
    "copyright": "© 2026 Eastlake Studio",
    "model_name": "模型名称",
    "zhipu": "智谱AI",
    "err_no_path": "请先选择有效的缓存文件夹",
    "err_model_not_downloaded": "语音模型未下载\n请前往「系统配置」选择存储路径并下载模型",
    "err_model_load_failed": "语音模型加载失败\n请前往「系统配置」重新下载模型",
    "err_start_record_failed": "启动录音失败",
    "err_offline_transcribe_failed": "离线转写失败\n可尝试在「系统配置」中重新下载模型",
    "err_download_failed": "模型下载失败",
    "err_retry_hint": "可尝试在「系统配置」中重新下载模型",
    "err_permission_denied": "权限被拒绝",
    "err_create_meeting_failed": "创建会议失败",
    "err_unsupported_audio_format": "不支持的音频格式",
    "err_file_copy_failed": "文件复制失败",
    "downloading": "下载中...",
    "click_to_download": "点击下载",
    "not_downloaded": "未下载",
    "voice_model_not_ready": "语音模型未下载",
    "voice_model_ready": "已就绪",
    "model_downloading": "正在下载语音模型...",
    "select_path_hint": "请选择存储路径",
    "settings_saved": "配置已保存",
    "download_error_label": "下载失败",
    "status_ready": "准备就绪",
    "permission_hint": "请前往「系统设置 - 隐私与安全性 - 麦克风/语音识别」中开启权限。",
    "model_ready_suffix": "已就绪",
    "app_title": "听纪",
    "personnel_voiceprint": "人员与声纹",
    "personnel_voiceprint_help": "全局人员与声纹管理",
    "start_meeting": "开始会议",
    "permission_insufficient": "权限不足",
    "confirm": "确定",
    "no_meetings": "暂无会议记录",
    "start_meeting_hint": "点击右上角「开始会议」选择录音模式",
    "delete_meeting": "删除会议",
    "save_recording": "另存录音文件",
    "status_recording": "录音中",
    "status_pending_diarization": "未分离",
    "status_processing_llm": "分离未完成",
    "status_completed": "完成分离",
    "delete_confirm_detail": "以下关联会议将被删除（含录音文件、转写文本和说话人分离数据），此操作不可撤销。在删除前，您可以点击录音文件右侧的导出按钮手动导出所需文件。",
    "audio_file_label": "录音文件",
    "voice_clips_label": "语音剪辑",
    "created_label": "创建",
    "extend_label": "延续",
    "cancel": "取消",
    "confirm_delete": "确认删除",
    "switching_model_hint": "正在下载其他模型",
    "review_title": "会议回顾",
    "transcribing_progress": "转写中...",
    "transcribing_segments": "转写中 %d段 (~%d%%)",
    "debug_log": "调试日志",
    "analyzing": "分析中...",
    "reanalyze": "重新分析",
    "continue_analysis": "继续分析",
    "copy": "拷贝",
    "copy_hint": "拷贝纪要到剪贴板",
    "export": "导出",
    "done": "完成",
    "back": "返回",
    "meeting_inspector": "会议属性检查器",
    "confirm_retranscribe": "确认重新转写",
    "confirm_retranscribe_msg": "已有 %d 段转写结果，重新转写将覆盖现有内容且耗时较长（约 5-10 分钟），是否继续？",
    "transcribing_hint": "正在使用本地大模型高精度转写...",
    "transcript_missing": "转写数据缺失",
    "transcript_missing_hint": "录音文件可能尚未完成离线转写",
    "rerun_transcription": "重新运行离线转写",
    "audio_file_not_found": "录音文件不存在",
    "no_transcript": "暂无转写内容",
    "load_from_db": "从数据库加载",
    "segments_count": "%d 段",
    "export_meeting_record": "导出会议记录",
    "status_pending": "待分离",
    "status_ai_processing": "AI 处理中",
    "status_done": "已完成",
    "debug_log_empty": "暂无日志",
    "refresh": "刷新",
    "external_import": "外部导入",
    "meeting_info": "会议信息",
    "recording": "录音中",
    "listening": "正在聆听...",
    "stop_recording": "停止录音",
    "merge_prev": "合并到上一段",
    "attendees_section": "参会人",
    "global_staff": "全局人员",
    "new_speaker_ellipsis": "新建说话人...",
    "new_voiceprint": "新建声纹人",
    "name": "姓名",
    "confirm_delete_person": "确认删除",
    "confirm_delete_person_msg": "确定删除「%@」吗？此操作不可撤销。\n该人员的声纹向量和发言记录关联将被清除。",
    "personnel_list": "人员列表",
    "add_person": "添加人员",
    "no_personnel": "暂无人员",
    "edit": "编辑",
    "delete": "删除",
    "person_attributes": "人员属性",
    "role": "角色",
    "org": "组织",
    "personnel_overview": "人员总览",
    "total": "总计",
    "people_unit": "人",
    "no_speech_records": "暂无发言记录",
    "speech_count_fmt": "%d 条发言 · %d 场会议",
    "no_company": "未分组",
    "new_meeting": "新建会议",
    "meeting_language": "会议语言",
    "chinese": "中文",
    "meeting_topic": "会议主题",
    "enter_topic": "输入会议主题",
    "start_time": "开始时间",
    "meeting_location": "会议地点",
    "enter_location": "输入地点",
    "attendees": "参会人",
    "select_from_personnel": "从全局人员库选择...",
    "audio_source": "音频来源",
    "live_recording": "实时录音",
    "audio_file": "音频文件",
    "no_audio_selected": "未选择音频文件",
    "select_audio_file": "选择音频文件",
    "extend_meeting": "延续历史会议",
    "start": "开始",
    "meeting_properties": "会议属性",
    "rename_attendee": "重命名参会人",
    "new_name": "新名称",
    "topic": "会议主题",
    "end_time": "结束时间",
    "location_label": "地点",
    "meeting_place": "会议地点",
    "search_person": "搜索人员...",
    "new_personnel": "新建人员",
    "select_from_db": "从全局人员库多选",
    "speaker_matching": "说话人匹配",
    "dictionary": "字典",
    "no_unmatched": "暂无未匹配说话人",
    "bind_to_attendee": "绑定到参会人",
    "bind": "绑定",
    "speech_stats": "发言统计",
    "no_data": "暂无数据",
    "reassign": "重新分配到参会人",
    "rename": "重命名",
    "remove_from_attendees": "从参会人中移除",
    "person_name": "人名",
    "name_required": "姓名（必填）",
    "role_hint": "如：项目经理、开发工程师",
    "org_hint": "如：阿里巴巴、腾讯",
    "create": "创建",
    "select_attendees": "选择参会人",
    "search": "搜索...",
    "no_match": "无匹配人员",
    "new": "新建",
    "selected_count": "已选 %d 人",
    "confirm_btn": "确认",
    "initializing": "正在初始化...",
    "error": "错误",
    "filter_prefix": "过滤: %@",
    "play": "播放",
    "other_speakers": "其他说话人",
    "new_ellipsis": "新建...",
    "new_speaker": "新建说话人",
    "merge": "合并",
    "duration_min_sec": "%d分%d秒",
    "duration_sec_only": "%d秒",
    "copy_topic": "会议主题: %@",
    "copy_location": "会议地点: %@",
    "copy_time": "开始时间: %@",
    "copy_attendees": "参会人员: %@",
    "not_specified": "未指定",
    "export_record_title": "会议记录",
    "record_duration_fmt": "录音时长: %@",
    "follow_system": "跟随系统",
    "simplified_chinese": "简体中文",
    "path_not_exist": "不存在",
    "download_timeout": "下载超时，请检查网络连接",
    "no_attendees_yet": "暂无参会人",
    "sentences_count_fmt": "%d句",
    "people_count_fmt": "%d人",
    "model_not_downloaded_settings": "模型未下载，请前往系统设置选择路径并进行下载。",
    "model_load_failed": "模型加载失败，请检查网络后重试",
    "model_not_loaded": "模型尚未加载完成",
    "audio_file_not_found_name": "音频文件不存在: %@",
    "player_init_failed": "初始化播放器失败: %@",
    "mic_permission_required": "需要麦克风权限才能录制会议",
    "mic_permission_denied": "麦克风权限被拒绝",
    "default_meeting_title": "会议记录_%@",
    "audio_file_not_found_diag": "录音文件未找到（%@.* 不存在于 Documents 目录）",
    "audio_file_missing_diag": "录音文件 %@ 不存在，但发现相关文件: %@",
] 
let enLocale: [String: String] = [
    "settings": "Settings", "save": "Save",
    "speech_model": "Speech Recognition", "downloaded": "Downloaded",
    "cache": "Cache", "model_label": "Model", "redownload": "Re-download",
    "china_mirror": "HF-Mirror", "huggingface": "HuggingFace",
    "about_desc": "Offline Meeting Minutes  |  WhisperKit + FluidAudio",
    "about_copyright": "© 2026 Eastlake Studio. All rights reserved.",
    "about_feature_desc": "AuraNote is a fully offline intelligent meeting minutes system.\nPowered by WhisperKit speech recognition and FluidAudio voiceprint diarization,\nit supports real-time transcription, offline high-accuracy transcription,\nand multi-speaker voiceprint separation & matching.\nAll audio data is processed locally — no internet required, ensuring complete privacy.",
    "about_feature_desc_en": "AuraNote is a fully offline intelligent meeting minutes system.\nPowered by WhisperKit speech recognition and FluidAudio voiceprint diarization,\nit supports real-time transcription, offline high-accuracy transcription,\nand multi-speaker voiceprint separation & matching.\nAll audio data is processed locally — no internet required, ensuring complete privacy.",
    "copyright": "© 2026 Eastlake Studio",
    "model_name": "Model Name",
    "zhipu": "Zhipu AI",
    "err_no_path": "Please select a valid cache folder first",
    "err_model_not_downloaded": "Voice model not downloaded\nPlease go to Settings to select a storage path and download the model",
    "err_model_load_failed": "Voice model failed to load\nPlease go to Settings to re-download the model",
    "err_start_record_failed": "Failed to start recording",
    "err_offline_transcribe_failed": "Offline transcription failed\nTry re-downloading the model in Settings",
    "err_download_failed": "Model download failed",
    "err_retry_hint": "Try re-downloading the model in Settings",
    "err_permission_denied": "Permission denied",
    "err_create_meeting_failed": "Failed to create meeting",
    "err_unsupported_audio_format": "Unsupported audio format",
    "err_file_copy_failed": "File copy failed",
    "downloading": "Downloading...",
    "click_to_download": "Download",
    "not_downloaded": "Not downloaded",
    "voice_model_not_ready": "Voice model not downloaded",
    "voice_model_ready": "Ready",
    "model_downloading": "Downloading voice model...",
    "select_path_hint": "Please select a storage path",
    "settings_saved": "Settings saved",
    "download_error_label": "Download failed",
    "status_ready": "Ready",
    "permission_hint": "Please enable permissions in System Settings - Privacy & Security - Microphone/Audio Recognition.",
    "model_ready_suffix": "Ready",
    "app_title": "AuraNote",
    "personnel_voiceprint": "Personnel & Voiceprint",
    "personnel_voiceprint_help": "Global personnel and voiceprint management",
    "start_meeting": "Start Meeting",
    "permission_insufficient": "Insufficient Permissions",
    "confirm": "OK",
    "no_meetings": "No meetings yet",
    "start_meeting_hint": "Click 'Start Meeting' in the top right to choose a recording mode",
    "delete_meeting": "Delete Meeting",
    "save_recording": "Save Recording File",
    "status_recording": "Recording",
    "status_pending_diarization": "Not Diarized",
    "status_processing_llm": "Diarization Incomplete",
    "status_completed": "Diarized",
    "delete_confirm_detail": "The following linked meetings will be deleted (including recordings, transcripts, and speaker diarization data). This operation cannot be undone. Before deleting, you can click the export button next to a recording file to manually export it.",
    "audio_file_label": "Audio File",
    "voice_clips_label": "Voice Clips",
    "created_label": "Created",
    "extend_label": "Extend",
    "cancel": "Cancel",
    "confirm_delete": "Confirm Delete",
    "switching_model_hint": "Downloading a different model",
    "review_title": "Meeting Review",
    "transcribing_progress": "Transcribing...",
    "transcribing_segments": "Transcribing %d segments (~%d%%)",
    "debug_log": "Debug Log",
    "analyzing": "Analyzing...",
    "reanalyze": "Re-analyze",
    "continue_analysis": "Continue Analysis",
    "copy": "Copy",
    "copy_hint": "Copy minutes to clipboard",
    "export": "Export",
    "done": "Done",
    "back": "Back",
    "meeting_inspector": "Meeting Inspector",
    "confirm_retranscribe": "Confirm Re-transcription",
    "confirm_retranscribe_msg": "There are %d existing transcript segments. Re-transcription will overwrite current content and take a long time (~5-10 min). Continue?",
    "transcribing_hint": "Transcribing with local AI model...",
    "transcript_missing": "Transcript Data Missing",
    "transcript_missing_hint": "Recording may not have completed offline transcription yet",
    "rerun_transcription": "Re-run Offline Transcription",
    "audio_file_not_found": "Audio file not found",
    "no_transcript": "No Transcript Content",
    "load_from_db": "Load from Database",
    "segments_count": "%d segments",
    "export_meeting_record": "Export Meeting Record",
    "status_pending": "Pending Diarization",
    "status_ai_processing": "AI Processing",
    "status_done": "Completed",
    "debug_log_empty": "No logs yet",
    "refresh": "Refresh",
    "external_import": "External Import",
    "meeting_info": "Meeting Info",
    "recording": "Recording",
    "listening": "Listening...",
    "stop_recording": "Stop Recording",
    "merge_prev": "Merge with Previous",
    "attendees_section": "Attendees",
    "global_staff": "All Personnel",
    "new_speaker_ellipsis": "New Speaker...",
    "new_voiceprint": "New Voiceprint",
    "name": "Name",
    "confirm_delete_person": "Confirm Delete",
    "confirm_delete_person_msg": "Are you sure you want to delete '%@'? This cannot be undone.\nThe person's voiceprint and speech record associations will be cleared.",
    "personnel_list": "Personnel List",
    "add_person": "Add Person",
    "no_personnel": "No Personnel",
    "edit": "Edit",
    "delete": "Delete",
    "person_attributes": "Attributes",
    "role": "Role",
    "org": "Organization",
    "personnel_overview": "Personnel Overview",
    "total": "Total",
    "people_unit": "",
    "no_speech_records": "No Speech Records",
    "speech_count_fmt": "%d speeches · %d meetings",
    "no_company": "No Group",
    "new_meeting": "New Meeting",
    "meeting_language": "Language",
    "chinese": "中文",
    "meeting_topic": "Topic",
    "enter_topic": "Enter topic",
    "start_time": "Start Time",
    "meeting_location": "Location",
    "enter_location": "Enter location",
    "attendees": "Attendees",
    "select_from_personnel": "Select from personnel...",
    "audio_source": "Audio Source",
    "live_recording": "Live Recording",
    "audio_file": "Audio File",
    "no_audio_selected": "No audio file selected",
    "select_audio_file": "Select Audio File",
    "extend_meeting": "Extend Meeting",
    "start": "Start",
    "meeting_properties": "Meeting Properties",
    "rename_attendee": "Rename Attendee",
    "new_name": "New Name",
    "topic": "Topic",
    "end_time": "End Time",
    "location_label": "Location",
    "meeting_place": "Meeting Place",
    "search_person": "Search...",
    "new_personnel": "New Person",
    "select_from_db": "Select from personnel",
    "speaker_matching": "Speaker Matching",
    "dictionary": "Dictionary",
    "no_unmatched": "No unmatched speakers",
    "bind_to_attendee": "Bind to Attendee",
    "bind": "Bind",
    "speech_stats": "Speech Stats",
    "no_data": "No data",
    "reassign": "Reassign",
    "rename": "Rename",
    "remove_from_attendees": "Remove from Attendees",
    "person_name": "Name",
    "name_required": "Name (required)",
    "role_hint": "e.g. Project Manager, Developer",
    "org_hint": "e.g. Google, Apple",
    "create": "Create",
    "select_attendees": "Select Attendees",
    "search": "Search...",
    "no_match": "No matches",
    "new": "New",
    "selected_count": "%d selected",
    "confirm_btn": "Confirm",
    "initializing": "Initializing...",
    "error": "Error",
    "filter_prefix": "Filter: %@",
    "play": "Play",
    "other_speakers": "Other Speakers",
    "new_ellipsis": "New...",
    "new_speaker": "New Speaker",
    "merge": "Merge",
    "duration_min_sec": "%d min %d sec",
    "duration_sec_only": "%d sec",
    "copy_topic": "Topic: %@",
    "copy_location": "Location: %@",
    "copy_time": "Start Time: %@",
    "copy_attendees": "Attendees: %@",
    "not_specified": "Not specified",
    "export_record_title": "Meeting Minutes",
    "record_duration_fmt": "Duration: %@",
    "follow_system": "Follow System",
    "simplified_chinese": "简体中文",
    "path_not_exist": "Not Found",
    "download_timeout": "Download timed out, check network connection",
    "no_attendees_yet": "No attendees yet",
    "sentences_count_fmt": "%d sentences",
    "people_count_fmt": "%d people",
    "model_not_downloaded_settings": "Model not downloaded, please go to Settings to select a path and download.",
    "model_load_failed": "Failed to load model, please check network and retry",
    "model_not_loaded": "Model has not finished loading",
    "audio_file_not_found_name": "Audio file not found: %@",
    "player_init_failed": "Failed to initialize player: %@",
    "mic_permission_required": "Microphone permission is required to record meetings",
    "mic_permission_denied": "Microphone permission denied",
    "default_meeting_title": "Meeting Record_%@",
    "audio_file_not_found_diag": "Audio file not found (%@.* does not exist in Documents directory)",
    "audio_file_missing_diag": "Audio file %@ not found, but found related files: %@",
]

struct VoicePreset: Identifiable { let id = UUID(); let name: String; let size: String }

struct SettingsView: View {
    @State private var settings = SettingsManager.shared
    @State private var showLangPicker = false
    @State private var downloadTask: Task<Void, Never>? = nil
    @State private var downloadStateVersion = 0

    private let voices = [
        VoicePreset(name: "openai/whisper-large-v3", size: "3.0 GB"),
        VoicePreset(name: "openai/whisper-large-v3-turbo", size: "1.9 GB")
    ]

    private let labelWidth: CGFloat = 85

    var body: some View {
        @Bindable var settings = settings
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack(spacing: 12) {
                            Text(loc("settings"))
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Button { showLangPicker = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                    Text(settings.langSetting == "en" ? "EN" : "中")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showLangPicker, arrowEdge: .bottom) {
                                VStack(spacing: 2) {
                                    Button(loc("follow_system")) { settings.langSetting = ""; showLangPicker = false }.padding(6).contentShape(Rectangle())
                                    Button(loc("simplified_chinese")) { settings.langSetting = "zh-Hans"; showLangPicker = false }.padding(6).contentShape(Rectangle())
                                    Button("English") { settings.langSetting = "en"; showLangPicker = false }.padding(6).contentShape(Rectangle())
                                }
                                .padding(6)
                                .frame(width: 110)
                            }
                            
                        }
                        .padding(.top, 16)
                        
                        // Card 1: 语音识别模型
                        VStack(alignment: .leading, spacing: 16) {
                            Label(loc("speech_model"), systemImage: "waveform.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.purple)
                            
                            VStack(spacing: 12) {
                                // Row 1: Model Name + Spacer + Download source + Status badge
                                HStack(spacing: 12) {
                                    Text(loc("model_label"))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: labelWidth, alignment: .leading)
                                    
                                    Menu {
                                        ForEach(sortedVoices) { v in
                                            Button("\(v.name) (\(v.size))") {
                                                settings.selectedVoice = v.name
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("\(settings.selectedVoice) (\(voices.first(where: { $0.name == settings.selectedVoice })?.size ?? ""))")
                                                .font(.callout)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(width: 360, height: 28)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 360, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    // Custom Equal-Width Segmented Control
                                    HStack(spacing: 0) {
                                        Button {
                                            settings.useChinaMirror = true
                                        } label: {
                                            Text(loc("china_mirror"))
                                                .font(.body)
                                                .foregroundStyle(settings.useChinaMirror ? .white : .primary)
                                                .frame(width: 90, height: 24)
                                                .background(settings.useChinaMirror ? Color.blue : Color.clear)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            settings.useChinaMirror = false
                                        } label: {
                                            Text(loc("huggingface"))
                                                .font(.body)
                                                .foregroundStyle(!settings.useChinaMirror ? .white : .primary)
                                                .frame(width: 90, height: 24)
                                                .background(!settings.useChinaMirror ? Color.blue : Color.clear)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .background(Color.primary.opacity(0.08))
                                    .cornerRadius(6)
                                    .frame(width: 180, alignment: .trailing)
                                    
                                    Spacer().frame(width: 16)
                                    
                                    HStack(spacing: 4) {
                                        if settings.currentModelDownloading {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(width: 12, height: 12)
                                            Text(String(format: "%.0f%%", settings.currentModelProgress * 100))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.blue)
                                            if !settings.downloadingModelVoice.isEmpty && settings.downloadingModelVoice != settings.selectedVoice {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.orange)
                                            }
                                            Button {
                                                downloadTask?.cancel()
                                                downloadTask = nil
                                                let downloadingVoice = settings.downloadingModelVoice
                                                if !downloadingVoice.isEmpty {
                                                    settings.setDownloadState(SettingsManager.ModelDownloadState(), for: downloadingVoice)
                                                }
                                                // 取消时删除完成标记，避免残留导致误判
                                                let cancelledVariant = modelID(for: downloadingVoice.isEmpty ? settings.selectedVoice : downloadingVoice)
                                                if !settings.modelPath.isEmpty {
                                                    let cancelledMarker = URL(fileURLWithPath: settings.modelPath)
                                                        .appendingPathComponent("models/argmaxinc/whisperkit-coreml")
                                                        .appendingPathComponent(cancelledVariant)
                                                        .appendingPathComponent(".download_complete")
                                                    try? FileManager.default.removeItem(at: cancelledMarker)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.red)
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.plain)
                                        } else if isModelDownloaded {
                                            Circle().fill(Color.green).frame(width: 6, height: 6)
                                            Text(loc("downloaded"))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.green)
                                        } else {
                                            Circle().fill(Color.red).frame(width: 6, height: 6)
                                            Text(loc("not_downloaded"))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .frame(width: 135, height: 26, alignment: .center)
                                    .background(settings.currentModelDownloading ? Color.blue.opacity(0.12) : (isModelDownloaded ? Color.green.opacity(0.12) : Color.red.opacity(0.12)))
                                    .cornerRadius(20)
                                }
                                
                                // Row 2: Cache Path + Re-download button
                                HStack(spacing: 12) {
                                    Text(loc("cache"))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: labelWidth, alignment: .leading)
                                    
                                    HStack {
                                        let pathExists = !settings.modelPath.isEmpty && FileManager.default.fileExists(atPath: settings.modelPath)
                                        if settings.modelPath.isEmpty {
                                            Text(loc("select_path_hint"))
                                                .font(.callout)
                                                .foregroundStyle(.gray.opacity(0.8))
                                        } else if !pathExists {
                                            Text("\(settings.modelPath) (\(loc("path_not_exist")))")
                                                .font(.callout)
                                                .foregroundStyle(.red)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        } else {
                                            Text(settings.modelPath)
                                                .font(.callout)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                        Button(action: selectPath) {
                                            Image(systemName: "folder")
                                                .font(.callout)
                                                .foregroundStyle(.purple)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                                    
                                    Spacer().frame(width: 16)
                                    
                                    Button(action: downloadModel) {
                                        HStack(spacing: 4) {
                                            if settings.currentModelDownloading {
                                                ProgressView().controlSize(.small).frame(width: 12, height: 12)
                                                Text(loc("downloading"))
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            } else {
                                                Image(systemName: isModelDownloaded ? "arrow.clockwise" : "arrow.down.to.line")
                                                Text(isModelDownloaded ? loc("redownload") : loc("click_to_download"))
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                        .frame(width: 135, height: 26, alignment: .center)
                                        .background(settings.currentModelDownloading ? Color.gray.opacity(0.12) : (isModelDownloaded ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12)))
                                        .foregroundStyle(settings.currentModelDownloading ? .gray : (isModelDownloaded ? .orange : .blue))
                                        .cornerRadius(20)
                                    }
                                    .disabled(settings.currentModelDownloading)
                                    .buttonStyle(.plain)
                                }
                                
                                if let err = settings.currentModelError {
                                    HStack {
                                        Spacer().frame(width: labelWidth + 12)
                                        Text("\(loc("download_error_label")): \(err)")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background.opacity(0.4)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                    .padding(.horizontal, 24)
                }
                
                Divider()
                
                // About Footer
                VStack(spacing: 4) {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "AuraNote")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(loc("about_desc"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(loc("copyright"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
        }
        .frame(minWidth: 960, minHeight: 760)
        .background(.regularMaterial)
        .onAppear { load() }
        .onReceive(NotificationCenter.default.publisher(for: SettingsManager.downloadStateDidChangeNotification)) { _ in
            downloadStateVersion += 1
        }
    }

    // MARK: - Helpers

    /// 按优先级排序的模型列表：下载中 > 已下载 > 未下载
    private var sortedVoices: [VoicePreset] {
        voices.sorted { a, b in
            let stateA = settings.downloadState(for: a.name)
            let stateB = settings.downloadState(for: b.name)
            let rankA = stateA.isDownloading ? 0 : (stateA.isDownloaded ? 1 : 2)
            let rankB = stateB.isDownloading ? 0 : (stateB.isDownloaded ? 1 : 2)
            return rankA < rankB
        }
    }

    private func modelID(for voice: String) -> String {
        if voice == "openai/whisper-large-v3-turbo" {
            return "openai_whisper-large-v3_turbo"
        }
        return voice.replacingOccurrences(of: "openai/", with: "openai_")
    }
    
    /// 模型实际存储目录（modelPath 下的子路径）
    private var modelRepoPath: String {
        guard !settings.modelPath.isEmpty else { return "" }
        return URL(fileURLWithPath: settings.modelPath)
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml").path
    }
    
    private var isModelDownloaded: Bool {
        guard !settings.modelPath.isEmpty else { return false }
        let voice = settings.selectedVoice
        // 正在下载的模型不算已下载，避免下载中误判为已完成
        let state = settings.downloadState(for: voice)
        if state.isDownloading { return false }
        let id = modelID(for: voice)
        let repoPath = modelRepoPath
        guard !repoPath.isEmpty else { return false }
        let modelURL = URL(fileURLWithPath: repoPath).appendingPathComponent(id)
        
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDir)
        if exists && isDir.boolValue {
            let markerURL = modelURL.appendingPathComponent(".download_complete")
            return FileManager.default.fileExists(atPath: markerURL.path)
        }
        return false
    }
    
    private func downloadModel() {
        if settings.modelPath.isEmpty {
            selectPath()
        }
        
        if settings.modelPath.isEmpty {
            var errState = settings.downloadState(for: settings.selectedVoice)
            errState.error = loc("err_no_path")
            settings.setDownloadState(errState, for: settings.selectedVoice)
            return
        }
        
        let downloadingVoice = settings.selectedVoice
        let variant = modelID(for: downloadingVoice)
        let endpoint = settings.useChinaMirror ? "https://hf-mirror.com" : "https://huggingface.co"
        
        settings.setDownloadState(SettingsManager.ModelDownloadState(isDownloading: true, progress: 0.0, error: nil), for: downloadingVoice)

        downloadTask = Task {
            let downloadURL = URL(fileURLWithPath: settings.modelPath)
            var currentEndpoint = endpoint
            var attemptCount = 0
            let maxAttempts = settings.useChinaMirror ? 2 : 1
            
            while attemptCount < maxAttempts {
                if Task.isCancelled { return }
                attemptCount += 1
                
                do {
                    // 设置下载超时（10 分钟）
                    let downloadResult = try await withThrowingTaskGroup(of: URL.self) { group -> URL in
                        group.addTask {
                            return try await WhisperKit.download(
                                variant: variant,
                                downloadBase: downloadURL,
                                endpoint: currentEndpoint
                            ) { progress in
                                let downloadProgress = progress.fractionCompleted
                                DispatchQueue.main.async {
                                    var state = settings.downloadState(for: downloadingVoice)
                                    state.progress = downloadProgress
                                    settings.setDownloadState(state, for: downloadingVoice)
                                }
                            }
                        }
                        
                        group.addTask {
                            try await Task.sleep(nanoseconds: 600_000_000_000) // 10 分钟
                            throw NSError(domain: "Download", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: loc("download_timeout")
                            ])
                        }
                        
                        var downloadedURL: URL?
                        for try await result in group {
                            downloadedURL = result
                            group.cancelAll()
                            break
                        }
                        guard let url = downloadedURL else {
                            throw CancellationError()
                        }
                        return url
                    }
                    
                    // 再次确认未被取消，才写入完成标记
                    guard !Task.isCancelled else { return }
                    await WhisperService.shared.reset()
                    
                    let modelDir = downloadURL.appendingPathComponent("models/argmaxinc/whisperkit-coreml").appendingPathComponent(variant)
                    let markerURL = modelDir.appendingPathComponent(".download_complete")
                    try? Data().write(to: markerURL)
                    
                    DispatchQueue.main.async {
                        self.downloadTask = nil
                        var finalState = SettingsManager.ModelDownloadState()
                        finalState.isDownloaded = true
                        settings.setDownloadState(finalState, for: downloadingVoice)
                        settings.modelVersion = self.modelID(for: downloadingVoice)
                        settings.save()
                        settings.checkAndAutoSelectModel()
                    }
                    return
                    
                } catch {
                    // 如果是 HF-Mirror 失败且还有重试机会，回退到 HuggingFace
                    if settings.useChinaMirror && attemptCount < maxAttempts {
                        currentEndpoint = "https://huggingface.co"
                        DispatchQueue.main.async {
                            var state = settings.downloadState(for: downloadingVoice)
                            state.progress = 0.0
                            settings.setDownloadState(state, for: downloadingVoice)
                        }
                        continue
                    }
                    
                    // 最终失败
                    if Task.isCancelled { return }
                    DispatchQueue.main.async {
                        settings.setDownloadState(SettingsManager.ModelDownloadState(isDownloading: false, progress: 0.0, error: "\(loc("err_download_failed"))\n\(error.localizedDescription)\n(variant=\(variant))"), for: downloadingVoice)
                        self.downloadTask = nil
                    }
                    return
                }
            }
        }
    }
    
    private func load() {
        settings.load()
        // 进入配置页时，按优先级自动切换模型：下载中 > 已下载 > 未下载（都未下载则显示第一个）
        if let best = sortedVoices.first {
            settings.selectedVoice = best.name
        }
        // 检测已下载的模型版本
        if !settings.modelPath.isEmpty {
            let variant = modelID(for: settings.selectedVoice)
            let modelURL = URL(fileURLWithPath: modelRepoPath).appendingPathComponent(variant)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDir), isDir.boolValue {
                settings.modelVersion = variant
            }
        }
    }
    
    private func selectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settings.modelPath.isEmpty ? NSHomeDirectory() : settings.modelPath)
        if panel.runModal() == .OK, let url = panel.url {
            settings.modelPath = url.path
        }
    }
}
