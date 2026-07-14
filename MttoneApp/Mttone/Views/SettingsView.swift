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
]
let enLocale: [String: String] = [
    "settings": "Settings", "save": "Save",
    "speech_model": "Speech Recognition", "downloaded": "Downloaded",
    "cache": "Cache", "model_label": "Model", "redownload": "Re-download",
    "china_mirror": "HF-Mirror", "huggingface": "HuggingFace",
    "about_desc": "Offline Meeting Minutes  |  WhisperKit + FluidAudio",
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
]

struct VoicePreset: Identifiable { let id = UUID(); let name: String; let size: String }

struct SettingsView: View {
    @State private var settings = SettingsManager.shared
    @State private var showLangPicker = false
    @State private var showSavedToast = false
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
                                        if settings.isModelDownloading {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(width: 12, height: 12)
                                            Text(String(format: "%.0f%%", settings.modelDownloadProgress * 100))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.blue)
                                            Button {
                                                downloadTask?.cancel()
                                                downloadTask = nil
                                                settings.isModelDownloading = false
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
                                            Text("未下载")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .frame(width: 135, height: 26, alignment: .center)
                                    .background(isModelDownloaded ? Color.green.opacity(0.12) : (settings.isModelDownloading ? Color.blue.opacity(0.12) : Color.red.opacity(0.12)))
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
                                            if settings.isModelDownloading {
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
                                        .background(settings.isModelDownloading ? Color.gray.opacity(0.12) : (isModelDownloaded ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12)))
                                        .foregroundStyle(settings.isModelDownloading ? .gray : (isModelDownloaded ? .orange : .blue))
                                        .cornerRadius(20)
                                    }
                                    .disabled(settings.isModelDownloading)
                                    .buttonStyle(.plain)
                                }
                                
                                if let err = settings.modelDownloadError {
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
    
    /// 模型实际存储目录（modelPath 下的子路径）
    private var modelRepoPath: String {
        URL(fileURLWithPath: settings.modelPath)
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml").path
    }
    
    private var isModelDownloaded: Bool {
        if settings.modelPath.isEmpty {
            print("[ModelCheck] modelPath is empty")
            return false
        }
        let id = modelID(for: settings.selectedVoice)
        let repoPath = modelRepoPath
        let modelURL = URL(fileURLWithPath: repoPath).appendingPathComponent(id)
        print("[ModelCheck] selectedVoice=\(settings.selectedVoice), modelID=\(id), path=\(modelURL.path)")
        
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDir)
        print("[ModelCheck] exists=\(exists), isDir=\(isDir.boolValue)")
        if exists && isDir.boolValue {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelURL.path) {
                print("[ModelCheck] dir has \(contents.count) items")
                return !contents.isEmpty
            }
        }
        // 兜底：扫描所有已知模型目录
        for v in ["openai_whisper-large-v3", "openai_whisper-large-v3_turbo", "openai_whisper-medium"] {
            let check = URL(fileURLWithPath: repoPath).appendingPathComponent(v)
            var d: ObjCBool = false
            if FileManager.default.fileExists(atPath: check.path, isDirectory: &d), d.boolValue {
                if let c = try? FileManager.default.contentsOfDirectory(atPath: check.path), !c.isEmpty {
                    print("[ModelCheck] Fallback: found model '\(v)' at \(check.path)")
                    return true
                }
            }
        }
        return false
    }
    
    private func downloadModel() {
        if settings.modelPath.isEmpty {
            selectPath()
        }
        
        if settings.modelPath.isEmpty {
            settings.modelDownloadError = loc("err_no_path")
            return
        }
        
        let variant = modelID(for: settings.selectedVoice)
        let endpoint = settings.useChinaMirror ? "https://hf-mirror.com" : "https://huggingface.co"
        print("[Download] === 开始下载 ===")
        print("[Download] selectedVoice: \(settings.selectedVoice)")
        print("[Download] variant: \(variant)")
        print("[Download] endpoint: \(endpoint)")
        print("[Download] downloadBase: \(settings.modelPath)")
        print("[Download] useChinaMirror: \(settings.useChinaMirror)")
        
        settings.isModelDownloading = true
        settings.modelDownloadProgress = 0.0
        settings.modelDownloadError = nil
        settings.downloadingModelVoice = settings.selectedVoice

        downloadTask = Task {
            let downloadURL = URL(fileURLWithPath: settings.modelPath)
            var currentEndpoint = endpoint
            var attemptCount = 0
            let maxAttempts = settings.useChinaMirror ? 2 : 1
            
            while attemptCount < maxAttempts {
                if Task.isCancelled { return }
                attemptCount += 1
                
                print("[Download] 尝试从 \(currentEndpoint) 下载 (第 \(attemptCount) 次)")
                print("[Download] variant=\(variant), downloadBase=\(downloadURL.path)")
                
                do {
                    // 设置下载超时（10 分钟）
                    let downloadResult = try await withThrowingTaskGroup(of: URL.self) { group -> URL in
                        group.addTask {
                            return try await WhisperKit.download(
                                variant: variant,
                                downloadBase: downloadURL,
                                endpoint: currentEndpoint
                            ) { progress in
                                if Task.isCancelled { return }
                                DispatchQueue.main.async {
                                    settings.modelDownloadProgress = progress.fractionCompleted
                                }
                            }
                        }
                        
                        group.addTask {
                            try await Task.sleep(nanoseconds: 600_000_000_000) // 10 分钟
                            throw NSError(domain: "Download", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "下载超时，请检查网络连接"
                            ])
                        }
                        
                        let result = try await group.next()
                        group.cancelAll()
                        return result!
                    }
                    
                    print("[Download] 下载成功: \(downloadResult.path)")
                    if Task.isCancelled { return }
                    await WhisperService.shared.reset()
                    
                    DispatchQueue.main.async {
                        self.downloadTask = nil
                        settings.isModelDownloading = false
                        settings.modelVersion = self.modelID(for: self.settings.selectedVoice)
                        settings.modelDownloadError = nil
                        print("[Download] === 下载完成, modelVersion=\(settings.modelVersion) ===")
                    }
                    return
                    
                } catch {
                    print("[Download] 从 \(currentEndpoint) 下载失败: \(error.localizedDescription)")
                    print("[Download] error type: \(type(of: error))")
                    
                    // 如果是 HF-Mirror 失败且还有重试机会，回退到 HuggingFace
                    if settings.useChinaMirror && attemptCount < maxAttempts {
                        print("[Download] HF-Mirror 失败，自动回退到 HuggingFace")
                        currentEndpoint = "https://huggingface.co"
                        DispatchQueue.main.async {
                            settings.modelDownloadProgress = 0.0
                        }
                        continue
                    }
                    
                    // 最终失败
                    if Task.isCancelled { return }
                    DispatchQueue.main.async {
                        settings.modelDownloadError = "\(loc("err_download_failed"))\n\(error.localizedDescription)\n(variant=\(variant))"
                        self.downloadTask = nil
                        settings.isModelDownloading = false
                    }
                    return
                }
            }
        }
    }
    
    /// 通过 HF-Mirror 的 /raw/ 端点下载模型文件，绕过 HubApi 的 metadata 校验
    private func downloadViaMirror(
        variant: String,
        downloadBase: URL,
        endpoint: String,
        progressCallback: @escaping (Double) -> Void
    ) async throws {
        let repoId = "argmaxinc/whisperkit-coreml"
        let repo = "models/\(repoId)"
        
        // 1. 从 API 获取文件列表
        print("[Mirror] 获取文件列表...")
        let apiURL = URL(string: "\(endpoint)/api/\(repo)/revision/main")!
        let (data, _) = try await URLSession.shared.data(from: apiURL)
        
        struct Sibling: Decodable { let rfilename: String }
        struct RepoResponse: Decodable { let siblings: [Sibling] }
        
        let response = try JSONDecoder().decode(RepoResponse.self, from: data)
        let allFiles = response.siblings.map { $0.rfilename }
        print("[Mirror] 仓库共有 \(allFiles.count) 个文件")
        
        // 2. 过滤出目标 variant 的文件
        let pattern = "*\(variant)*"
        let files = allFiles.filter { fnmatch(pattern, $0, 0) == 0 }
        print("[Mirror] 匹配 \(pattern) 的文件: \(files.count) 个")
        
        guard !files.isEmpty else {
            throw NSError(domain: "MirrorDownload", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "未找到匹配 \(pattern) 的文件"
            ])
        }
        
        // 3. 逐个下载文件
        let destBase = downloadBase.appendingPathComponent(repo)
        var downloadedCount = 0
        
        for file in files {
            if Task.isCancelled { return }
            
            let fileURL = URL(string: "\(endpoint)/\(repo)/raw/main/\(file)")!
            let destPath = destBase.appendingPathComponent(file)
            
            // 创建目录
            let dir = destPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            // 下载文件（带重试）
            var lastError: Error? = nil
            for attempt in 1...3 {
                do {
                    let (fileData, _) = try await URLSession.shared.data(from: fileURL)
                    try fileData.write(to: destPath)
                    break
                } catch {
                    lastError = error
                    print("[Mirror] 文件 \(file) 下载失败 (尝试 \(attempt)/3): \(error.localizedDescription)")
                    if attempt < 3 {
                        try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                    }
                }
            }
            
            if lastError != nil {
                throw lastError!
            }
            
            downloadedCount += 1
            let progress = Double(downloadedCount) / Double(files.count)
            progressCallback(progress)
            
            if downloadedCount % 10 == 0 || downloadedCount == files.count {
                print("[Mirror] 进度: \(downloadedCount)/\(files.count) (\(Int(progress * 100))%)")
            }
        }
        
        print("[Mirror] 全部 \(downloadedCount) 个文件下载完成")
    }

    private func load() {
        settings.load()
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
