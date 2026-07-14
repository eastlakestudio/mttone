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
    "copyright": "© 2024-2026 Eastlake Studio",
    "model_name": "模型名称",
    "zhipu": "智谱AI",
]
let enLocale: [String: String] = [
    "settings": "Settings", "save": "Save",
    "speech_model": "Speech Recognition", "downloaded": "Downloaded",
    "cache": "Cache", "model_label": "Model", "redownload": "Re-download",
    "china_mirror": "HF-Mirror", "huggingface": "HuggingFace",
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
    @State private var isDownloadingModel = false
    @State private var downloadProgress = 0.0
    @State private var downloadError: String? = nil
    @State private var downloadTask: Task<Void, Never>? = nil

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
                                        if isModelDownloaded {
                                            Circle().fill(Color.green).frame(width: 6, height: 6)
                                            Text(loc("downloaded"))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.green)
                                        } else if isDownloadingModel {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(width: 12, height: 12)
                                            Text(String(format: "%.0f%%", downloadProgress * 100))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.blue)
                                            Button {
                                                downloadTask?.cancel()
                                                downloadTask = nil
                                                isDownloadingModel = false
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.red)
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Circle().fill(Color.red).frame(width: 6, height: 6)
                                            Text("未下载")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .frame(width: 135, height: 26, alignment: .center)
                                    .background(isModelDownloaded ? Color.green.opacity(0.12) : (isDownloadingModel ? Color.blue.opacity(0.12) : Color.red.opacity(0.12)))
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
                                            Text("请选择存储路径")
                                                .font(.callout)
                                                .foregroundStyle(.gray.opacity(0.8))
                                        } else if !pathExists {
                                            Text("\(settings.modelPath) (不存在)")
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
                                            if isDownloadingModel {
                                                ProgressView().controlSize(.small).frame(width: 12, height: 12)
                                                Text("下载中...")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            } else {
                                                Image(systemName: isModelDownloaded ? "arrow.clockwise" : "arrow.down.to.line")
                                                Text(isModelDownloaded ? loc("redownload") : "点击下载")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                        .frame(width: 135, height: 26, alignment: .center)
                                        .background(isDownloadingModel ? Color.gray.opacity(0.12) : (isModelDownloaded ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12)))
                                        .foregroundStyle(isDownloadingModel ? .gray : (isModelDownloaded ? .orange : .blue))
                                        .cornerRadius(20)
                                    }
                                    .disabled(isDownloadingModel)
                                    .buttonStyle(.plain)
                                }
                                
                                if let err = downloadError {
                                    HStack {
                                        Spacer().frame(width: labelWidth + 12)
                                        Text("下载失败: \(err)")
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
                    Text("AuraNote v1.4.0")
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
    
    private var defaultModelPath: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml").path
    }
    
    private func modelID(for voice: String) -> String {
        if voice == "openai/whisper-large-v3-turbo" {
            return "openai_whisper-large-v3_turbo"
        }
        return voice.replacingOccurrences(of: "openai/", with: "openai_")
    }
    
    private var isModelDownloaded: Bool {
        if settings.modelPath.isEmpty { return false }
        let id = modelID(for: settings.selectedVoice)
        let modelURL = URL(fileURLWithPath: settings.modelPath).appendingPathComponent(id)
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDir), isDir.boolValue {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelURL.path), !contents.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func downloadModel() {
        if settings.modelPath.isEmpty {
            selectPath()
        }
        
        if settings.modelPath.isEmpty {
            downloadError = "请先选择有效的缓存文件夹"
            return
        }
        
        isDownloadingModel = true
        downloadProgress = 0.0
        downloadError = nil
        SettingsManager.shared.isModelDownloading = true
        SettingsManager.shared.modelDownloadProgress = 0.0

        downloadTask = Task {
            do {
                let variant = modelID(for: settings.selectedVoice)
                let endpoint = settings.useChinaMirror ? "https://hf-mirror.com" : "https://huggingface.co"
                
                _ = try await WhisperKit.download(
                    variant: variant,
                    downloadBase: URL(fileURLWithPath: settings.modelPath),
                    endpoint: endpoint
                ) { progress in
                    if Task.isCancelled { return }
                    DispatchQueue.main.async {
                        self.downloadProgress = progress.fractionCompleted
                        SettingsManager.shared.modelDownloadProgress = progress.fractionCompleted
                    }
                }
                
                if Task.isCancelled { return }
                
                await WhisperService.shared.reset()
                
                DispatchQueue.main.async {
                    self.isDownloadingModel = false
                    self.downloadTask = nil
                    SettingsManager.shared.isModelDownloading = false
                    SettingsManager.shared.modelVersion = self.modelID(for: self.settings.selectedVoice)
                }
            } catch {
                if Task.isCancelled { return }
                DispatchQueue.main.async {
                    self.downloadError = error.localizedDescription
                    self.isDownloadingModel = false
                    self.downloadTask = nil
                    SettingsManager.shared.isModelDownloading = false
                }
            }
        }
    }

    private func load() {
        settings.load()
        // 检测已下载的模型版本
        if !settings.modelPath.isEmpty {
            let variant = modelID(for: settings.selectedVoice)
            let modelURL = URL(fileURLWithPath: settings.modelPath).appendingPathComponent(variant)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDir), isDir.boolValue {
                settings.modelVersion = variant
            }
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
}
