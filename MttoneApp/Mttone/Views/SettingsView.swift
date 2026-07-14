import SwiftUI

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
    "cloud_llm": "云端大语言模型", "not_configured": "未配置",
    "url_address": "接口地址", "model": "模型", "token": "密钥 Token", "custom": "自定义",
    "prompt": "会议纪要提示词", "reset_prompt": "重置默认提示词",
    "about_desc": "本地离线会议纪要系统  |  WhisperKit + FluidAudio",
    "copyright": "© 2024-2026 Eastlake Studio",
    "model_name": "模型名称",
    "zhipu": "智谱AI",
]
let enLocale: [String: String] = [
    "settings": "Settings", "save": "Save",
    "speech_model": "Speech Recognition", "downloaded": "Downloaded",
    "cache": "Cache", "model_label": "Model", "redownload": "Re-download",
    "china_mirror": "HF-Mirror", "huggingface": "HuggingFace",
    "cloud_llm": "Cloud LLM", "not_configured": "Not Configured",
    "url_address": "API URL", "model": "Model", "token": "Token", "custom": "Custom",
    "prompt": "Summary Prompt", "reset_prompt": "Reset Default",
    "about_desc": "Offline Meeting Minutes  |  WhisperKit + FluidAudio",
    "copyright": "© 2024-2026 Eastlake Studio",
    "model_name": "Model Name",
    "zhipu": "Zhipu AI",
]

struct VoicePreset: Identifiable { let id = UUID(); let name: String; let size: String }

struct SettingsView: View {
    @State private var settings = SettingsManager.shared
    @State private var showLangPicker = false
    @State private var showSavedToast = false
    @State private var showTokenDetails = false
    @State private var llmPresetIndex = 0

    private let voices = [
        VoicePreset(name: "openai/whisper-large-v3", size: "3.0 GB"),
        VoicePreset(name: "openai/whisper-large-v3-turbo", size: "1.9 GB")
    ]
    private let llmPresets = [
        ("openai/gpt-4o", "https://api.openai.com/v1", "gpt-4o"),
        ("deepseek/deepseek-chat", "https://api.deepseek.com/v1", "deepseek-chat"),
        ("alibaba/qwen-plus", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
        ("zhipu/glm-4-flash", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
        ("siliconflow/deepseek-ai/DeepSeek-V3", "https://api.siliconflow.cn/v1", "deepseek-ai/DeepSeek-V3"),
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
                                    Button("跟随系统") { settings.langSetting = ""; showLangPicker = false }.padding(6).contentShape(Rectangle())
                                    Button("简体中文") { settings.langSetting = "zh-Hans"; showLangPicker = false }.padding(6).contentShape(Rectangle())
                                    Button("English") { settings.langSetting = "en"; showLangPicker = false }.padding(6).contentShape(Rectangle())
                                }
                                .padding(6)
                                .frame(width: 110)
                            }
                            
                            Button(action: save) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                    Text(loc("save"))
                                }
                                .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.regular)
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
                                        ForEach(voices) { v in
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
                                        Circle().fill(Color.green).frame(width: 6, height: 6)
                                        Text(loc("downloaded"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.green)
                                    }
                                    .frame(width: 135, height: 26, alignment: .center)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(20)
                                }
                                
                                // Row 2: Cache Path + Re-download button
                                HStack(spacing: 12) {
                                    Text(loc("cache"))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: labelWidth, alignment: .leading)
                                    
                                    HStack {
                                        Text(settings.modelPath.isEmpty ? WhisperKitCachePath : settings.modelPath)
                                            .font(.callout)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
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
                                    
                                    Button(action: {}) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                            Text(loc("redownload"))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .frame(width: 135, height: 26, alignment: .center)
                                        .background(Color.orange.opacity(0.12))
                                        .foregroundStyle(.orange)
                                        .cornerRadius(20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background.opacity(0.4)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        
                        // Card 2: 云端大语言模型
                        VStack(alignment: .leading, spacing: 16) {
                            Label(loc("cloud_llm"), systemImage: "cloud.fill")
                                .font(.headline)
                                .foregroundStyle(.blue)
                            
                            VStack(spacing: 12) {
                                // Row 1: Model Selection + Model Name
                                HStack(spacing: 24) {
                                    // Left: Model Selection
                                    HStack(spacing: 12) {
                                        Text(loc("model"))
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .frame(width: labelWidth, alignment: .leading)
                                        
                                        Menu {
                                            ForEach(0..<llmPresets.count, id: \.self) { i in
                                                Button(llmPresets[i].0 == "智谱AI" ? loc("zhipu") : llmPresets[i].0) {
                                                    llmPresetIndex = i
                                                    settings.llmModel = llmPresets[i].2
                                                    settings.llmURL = llmPresets[i].1
                                                }
                                            }
                                            Divider()
                                            Button(loc("custom")) {
                                                llmPresetIndex = llmPresets.count
                                            }
                                        } label: {
                                            HStack {
                                                Text(llmPresetIndex < llmPresets.count ? (llmPresets[llmPresetIndex].0 == "智谱AI" ? loc("zhipu") : llmPresets[llmPresetIndex].0) : loc("custom"))
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
                                    }
                                    
                                    // Right: Model Name
                                    HStack(spacing: 12) {
                                        Text(loc("model_name"))
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 75, alignment: .leading)
                                        
                                        TextField("gpt-4o", text: $settings.llmModel)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.callout)
                                            .disabled(llmPresetIndex != llmPresets.count)
                                    }
                                }
                                .onChange(of: llmPresetIndex) { _, idx in
                                    if idx < llmPresets.count {
                                        settings.llmModel = llmPresets[idx].2
                                        settings.llmURL = llmPresets[idx].1
                                    }
                                }
                                
                                // Row 2: API URL + Token
                                HStack(spacing: 24) {
                                    // Left: API URL
                                    HStack(spacing: 12) {
                                        Text(loc("url_address"))
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .frame(width: labelWidth, alignment: .leading)
                                        
                                        TextField("https://api.openai.com/v1", text: $settings.llmURL)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.callout)
                                            .disabled(llmPresetIndex != llmPresets.count)
                                            .frame(width: 360)
                                    }
                                    
                                    // Right: Token
                                    HStack(spacing: 12) {
                                        Text(loc("token"))
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 75, alignment: .leading)
                                        
                                        HStack {
                                            if showTokenDetails {
                                                TextField("API Key / Token", text: $settings.llmToken)
                                                    .textFieldStyle(.plain)
                                                    .font(.system(.callout, design: .monospaced))
                                            } else {
                                                SecureField("API Key / Token", text: $settings.llmToken)
                                                    .textFieldStyle(.plain)
                                                    .font(.system(.callout, design: .monospaced))
                                            }
                                            Button { showTokenDetails.toggle() } label: {
                                                Image(systemName: showTokenDetails ? "eye.slash" : "eye")
                                                    .font(.callout)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background.opacity(0.4)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        
                        // Card 3: 会议纪要提示词
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(loc("prompt"), systemImage: "text.bubble.fill")
                                    .font(.headline)
                                    .foregroundStyle(.indigo)
                                
                                Spacer()
                                
                                Button(action: resetCurrentPrompt) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text(loc("reset_prompt"))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            TextEditor(text: $settings.summaryPrompt)
                                .font(.callout)
                                .scrollContentBackground(.hidden)
                                .scrollIndicators(.never)
                                .padding(10)
                                .frame(minHeight: 120)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
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
                    Text("Mttone v1.4.0")
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
            
            // Toast
            if showSavedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("配置已保存")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(1)
            }
        }
        .frame(minWidth: 960, minHeight: 760)
        .background(.regularMaterial)
        .onAppear { load() }
    }

    // MARK: - Helpers

    private var WhisperKitCachePath: String {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("whisperkit").path
    }

    private func load() {
        settings.load()
        if let idx = llmPresets.firstIndex(where: { $0.2 == settings.llmModel }) {
            llmPresetIndex = idx
        } else {
            llmPresetIndex = llmPresets.count
        }
    }
    
    private func save() {
        settings.save()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSavedToast = false
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
    
    private func resetCurrentPrompt() {
        let activeLang = settings.langSetting.isEmpty ? (Bundle.main.preferredLocalizations.first ?? "zh-Hans") : settings.langSetting
        if activeLang.contains("en") {
            settings.summaryPromptEN = "You are a professional meeting assistant. Please organize the following meeting transcript into a structured summary, including:\n1. Overview\n2. Key Topics\n3. Decisions Made\n4. Action Items"
        } else {
            settings.summaryPromptZH = "你是一个专业的会议纪要整理助手。请将以下会议发言记录整理成结构化的会议纪要，包括：\n1. 会议概要\n2. 主要议题\n3. 决策事项\n4. 待办事项"
        }
    }
}
