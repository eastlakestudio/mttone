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
    "url_address": "URL 地址", "model": "模型", "token": "Token", "custom": "自定义",
    "prompt": "会议纪要提示词", "reset_prompt": "重置默认提示词",
    "about_desc": "本地离线会议纪要系统  |  WhisperKit + FluidAudio",
    "copyright": "© 2024-2026 Eastlake Studio",
]
let enLocale: [String: String] = [
    "settings": "Settings", "save": "Save",
    "speech_model": "Speech Recognition", "downloaded": "Downloaded",
    "cache": "Cache", "model_label": "Model", "redownload": "Re-download",
    "china_mirror": "HF-Mirror", "huggingface": "HuggingFace",
    "cloud_llm": "Cloud LLM", "not_configured": "Not Configured",
    "url_address": "URL", "model": "Model", "token": "Token", "custom": "Custom",
    "prompt": "Summary Prompt", "reset_prompt": "Reset Default",
    "about_desc": "Offline Meeting Minutes  |  WhisperKit + FluidAudio",
    "copyright": "© 2024-2026 Eastlake Studio",
]

struct VoicePreset: Identifiable { let id = UUID(); let name: String; let size: String }

struct SettingsView: View {
    @State private var llmURL = ""; @State private var llmToken = ""; @State private var llmModel = ""
    @State private var summaryPrompt = ""; @State private var langSetting = ""
    @State private var modelPath = ""; @State private var selectedVoice = "large-v3"
    @State private var useChina = true; @State private var llmPresetIndex = 0
    @State private var showLangPicker = false

    private let voices = [VoicePreset(name: "large-v3", size: "3.0 GB"), VoicePreset(name: "large-v3-turbo", size: "1.9 GB")]
    private let llmPresets = [
        ("GPT-4o", "https://api.openai.com/v1", "gpt-4o"),
        ("Qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
        ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
        ("智谱AI", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
    ]

    private let labelWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text(loc("settings")).font(.title3).fontWeight(.semibold)
                Spacer()
                Button { showLangPicker = true } label: {
                    Text(langSetting == "en" ? "EN" : "中").font(.caption).fontWeight(.medium)
                        .frame(width: 28, height: 20)
                        .background(.quaternary).clipShape(Capsule())
                }.buttonStyle(.plain)
                .popover(isPresented: $showLangPicker) {
                    VStack(spacing: 2) {
                        Button("跟随系统") { langSetting = ""; showLangPicker = false }.padding(5).contentShape(Rectangle())
                        Button("简体中文") { langSetting = "zh-Hans"; showLangPicker = false }.padding(5).contentShape(Rectangle())
                        Button("English") { langSetting = "en"; showLangPicker = false }.padding(5).contentShape(Rectangle())
                    }.padding(6).frame(width: 100)
                }
                Button(loc("save")) { save() }.buttonStyle(.borderedProminent).tint(.purple).controlSize(.small)
            }.padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            // Voice Model
            VStack(spacing: 0) {
                rowHeader(loc("speech_model"), icon: "waveform.circle.fill", color: .purple)
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        labelledField(loc("model_label"), width: labelWidth) {
                            Picker("", selection: $selectedVoice) {
                                ForEach(voices) { v in Text("\(v.name)  (\(v.size))").tag(v.name) }
                            }.pickerStyle(.menu).frame(width: 240)
                        }
                        Spacer()
                        Text("· \(loc("downloaded"))").font(.callout).foregroundStyle(.green)
                    }
                    HStack(spacing: 10) {
                        labelledField(loc("cache"), width: labelWidth) {
                            HStack {
                                Text(modelPath.isEmpty ? WhisperKitCachePath : modelPath)
                                    .font(.callout).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button { selectPath() } label: { Image(systemName: "folder").font(.callout).foregroundStyle(.purple) }.buttonStyle(.plain)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Rectangle().fill(.clear).frame(width: labelWidth)
                        HStack(spacing: 8) {
                            Picker("", selection: $useChina) {
                                Text(loc("china_mirror")).tag(true)
                                Text(loc("huggingface")).tag(false)
                            }.pickerStyle(.menu).frame(width: 120).labelsHidden()
                            Spacer()
                            Button(loc("redownload")) {}.buttonStyle(.bordered).controlSize(.small).tint(.orange)
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            // Cloud LLM + Prompt (关联配置，不分割)
            VStack(spacing: 0) {
                rowHeader(loc("cloud_llm"), icon: "cloud.fill", color: .blue)
                HStack(spacing: 10) {
                    labelledField(loc("model"), width: labelWidth) {
                        Picker("", selection: $llmPresetIndex) {
                            ForEach(0..<llmPresets.count, id: \.self) { i in Text(llmPresets[i].0).tag(i) }
                            Divider(); Text(loc("custom")).tag(4)
                        }.pickerStyle(.menu).frame(width: 120)
                        .onChange(of: llmPresetIndex) { _, idx in
                            if idx < llmPresets.count { llmModel = llmPresets[idx].2; llmURL = llmPresets[idx].1 }
                        }
                    }
                    if llmPresetIndex == 4 {
                        labelledField(loc("url_address"), width: 50) {
                            TextField("", text: $llmURL).textFieldStyle(.roundedBorder).font(.callout)
                        }
                    }
                    labelledField(loc("token"), width: 40) {
                        SecureField("", text: $llmToken).textFieldStyle(.roundedBorder).font(.callout)
                    }
                }

                // Prompt (fills remaining space, no divider)
                VStack(spacing: 6) {
                    HStack {
                        Label(loc("prompt"), systemImage: "text.bubble.fill").font(.subheadline).foregroundStyle(.indigo)
                        Spacer()
                        Button(loc("reset_prompt")) {
                            summaryPrompt = langSetting == "en"
                                ? "Please organize the following meeting transcript into a structured summary (overview/topics/decisions/action items)."
                                : "请将以下会议记录整理成结构化会议纪要（概要/议题/决策/待办）。"
                        }.buttonStyle(.borderless).font(.caption).foregroundStyle(.purple)
                    }
                    TextEditor(text: $summaryPrompt)
                        .font(.callout)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                        .padding(10)
                        .background(.quaternary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }.padding(.horizontal, 24).padding(.vertical, 16)

            Spacer(minLength: 0)

            // About
            Divider()
            VStack(spacing: 3) {
                Text("Mttone  v1.4.0").font(.caption).fontWeight(.medium)
                Text(loc("about_desc")).font(.caption2).foregroundStyle(.secondary)
                Text(loc("copyright")).font(.caption2).foregroundStyle(.tertiary)
            }.padding(.vertical, 12)
        }
        .frame(minWidth: 540, minHeight: 600)
        .background(.regularMaterial)
        .onAppear { load() }
    }

    // MARK: - Helpers

    private func rowHeader(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon).font(.subheadline).foregroundStyle(color).padding(.bottom, 8)
    }

    private func labelledField<Content: View>(_ label: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.callout).foregroundStyle(.secondary).frame(width: width, alignment: .trailing)
            content()
        }
    }

    private var WhisperKitCachePath: String {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("whisperkit").path
    }

    private func load() {
        let d = UserDefaults.standard
        llmURL = d.string(forKey: "llm_url") ?? ""; llmToken = d.string(forKey: "llm_token") ?? ""
        llmModel = d.string(forKey: "llm_model") ?? "gpt-4o"
        summaryPrompt = d.string(forKey: "summary_prompt") ?? "请将以下会议记录整理成结构化会议纪要（概要/议题/决策/待办）。"
        langSetting = d.string(forKey: "ui_language") ?? ""
        modelPath = d.string(forKey: "model_path") ?? ""
        selectedVoice = d.string(forKey: "voice_model") ?? "large-v3"
        useChina = d.bool(forKey: "use_china_mirror")
        if let idx = llmPresets.firstIndex(where: { $0.2 == llmModel }) { llmPresetIndex = idx }
        else { llmPresetIndex = 4 }
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(llmURL, forKey: "llm_url"); d.set(llmToken, forKey: "llm_token")
        d.set(llmModel, forKey: "llm_model"); d.set(summaryPrompt, forKey: "summary_prompt")
        d.set(langSetting, forKey: "ui_language"); d.set(modelPath, forKey: "model_path")
        d.set(selectedVoice, forKey: "voice_model"); d.set(useChina, forKey: "use_china_mirror")
    }
    private func selectPath() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: modelPath.isEmpty ? NSHomeDirectory() : modelPath)
        if panel.runModal() == .OK, let url = panel.url { modelPath = url.path }
    }
}
