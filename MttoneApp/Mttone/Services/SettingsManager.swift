import Foundation
import Observation

@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    static let settingsDidChangeNotification = Notification.Name("AuraNoteSettingsDidChange")
    static let downloadStateDidChangeNotification = Notification.Name("AuraNoteDownloadStateDidChange")
    
    var defaults: UserDefaults = .standard
    
    var llmURL: String = ""
    var llmToken: String = ""
    var llmModel: String = ""
    var summaryPromptZH: String = ""
    var summaryPromptEN: String = ""
    var langSetting: String = "" {
        didSet {
            defaults.set(langSetting, forKey: "ui_language")
            NotificationCenter.default.post(name: SettingsManager.settingsDidChangeNotification, object: nil)
        }
    }
    var modelPath: String = ""
    var selectedVoice: String = "openai/whisper-large-v3"
    var useChinaMirror: Bool = true
    
    /// 唯一支持的模型
    static let supportedVoice = "openai/whisper-large-v3"
    
    /// 单个模型的下载状态
    struct ModelDownloadState: Codable {
        var isDownloading = false
        var progress: Double = 0.0
        var error: String? = nil
        var isDownloaded = false
    }
    var modelDownloadStates: [String: ModelDownloadState] = [:]
    
    /// 获取指定模型的下载状态
    func downloadState(for voice: String) -> ModelDownloadState {
        return modelDownloadStates[voice] ?? ModelDownloadState()
    }
    
    /// 设置指定模型的下载状态
    func setDownloadState(_ state: ModelDownloadState, for voice: String) {
        modelDownloadStates[voice] = state
        // 显式通知视图下载状态变化，解决 @Observable 对字典变更追踪不可靠的问题
        NotificationCenter.default.post(name: Self.downloadStateDidChangeNotification, object: nil)
    }
    
    /// 当前选中模型的下载状态（便捷访问）
    var currentModelDownloading: Bool {
        downloadState(for: selectedVoice).isDownloading
    }
    var currentModelProgress: Double {
        downloadState(for: selectedVoice).progress
    }
    var currentModelError: String? {
        downloadState(for: selectedVoice).error
    }
    
    /// 正在下载的模型名称（如果有）
    var downloadingModelVoice: String {
        modelDownloadStates.first { $0.value.isDownloading }?.key ?? ""
    }
    
    /// 模型是否已下载可用
    var isModelAvailable: Bool {
        let state = downloadState(for: Self.supportedVoice)
        return state.isDownloaded && !state.isDownloading
    }
    
    var modelVersion = "" {
        didSet { if !modelVersion.isEmpty { defaults.set(modelVersion, forKey: "current_model_version") } }
    }
    
    var defaultModelPath: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml").path
    }
    
    var summaryPrompt: String {
        get {
            let activeLang = langSetting.isEmpty ? getSystemLanguage() : langSetting
            return activeLang.contains("en") ? summaryPromptEN : summaryPromptZH
        }
        set {
            let activeLang = langSetting.isEmpty ? getSystemLanguage() : langSetting
            if activeLang.contains("en") {
                summaryPromptEN = newValue
            } else {
                summaryPromptZH = newValue
            }
        }
    }
    
    var isLLMConfigured: Bool {
        return !llmURL.isEmpty && !llmToken.isEmpty
    }
    
    /// 标记是否已完成首次启动时的文件系统同步（仅首次 load 时执行清理）
    private var hasPerformedStartupSync = false
    
    private init() {
        load()
    }
    
    func load() {
        let d = defaults
        llmURL = d.string(forKey: "llm_url") ?? ""
        // 从 Keychain 读取 token；同时兼容旧版 UserDefaults 迁移
        if let keychainToken = KeychainHelper.read(forKey: "llm_token"), !keychainToken.isEmpty {
            llmToken = keychainToken
        } else if let oldToken = d.string(forKey: "llm_token"), !oldToken.isEmpty {
            // 一次性迁移：从 UserDefaults 写入 Keychain
            KeychainHelper.save(oldToken, forKey: "llm_token")
            d.removeObject(forKey: "llm_token")
            llmToken = oldToken
        } else {
            llmToken = ""
        }
        llmModel = d.string(forKey: "llm_model") ?? "gpt-4o"
        
        let oldPrompt = d.string(forKey: "summary_prompt")
        var zhVal = d.string(forKey: "summary_prompt_zh") ?? oldPrompt ?? "你是一个专业的会议纪要整理助手。请将以下会议发言记录整理成结构化的会议纪要，包括：\n1. 会议概要\n2. 主要议题\n3. 决策事项\n4. 待办事项"
        var enVal = d.string(forKey: "summary_prompt_en") ?? "You are a professional meeting assistant. Please organize the following meeting transcript into a structured summary, including:\n1. Overview\n2. Key Topics\n3. Decisions Made\n4. Action Items"
        
        // 注意：以下中文字符串为旧版本硬编码值，用于迁移判断，不可改为 loc()
        if zhVal == "自定义提示词" || zhVal == "这是一个测试自定义提示词" {
            zhVal = "你是一个专业的会议纪要整理助手。请将以下会议发言记录整理成结构化的会议纪要，包括：\n1. 会议概要\n2. 主要议题\n3. 决策事项\n4. 待办事项"
        }
        // 注意：比较的是旧版本写入的硬编码值，不可改为 loc()
        if enVal == "自定义提示词" || enVal == "这是一个测试自定义提示词" {
            enVal = "You are a professional meeting assistant. Please organize the following meeting transcript into a structured summary, including:\n1. Overview\n2. Key Topics\n3. Decisions Made\n4. Action Items"
        }
        
        summaryPromptZH = zhVal
        summaryPromptEN = enVal
        
        langSetting = d.string(forKey: "ui_language") ?? ""
        selectedVoice = Self.supportedVoice
        useChinaMirror = d.object(forKey: "use_china_mirror") as? Bool ?? true
        
        // 先加载 modelPath，后续文件系统同步需要用到
        let savedPath = d.string(forKey: "model_path") ?? ""
        if !savedPath.isEmpty && FileManager.default.fileExists(atPath: savedPath) {
            modelPath = savedPath
        } else {
            // 清除无效的保存路径
            if !savedPath.isEmpty { d.removeObject(forKey: "model_path") }
            // 检查默认路径是否有模型
            let defaultModelID = "openai_whisper-large-v3"
            let defaultModelURL = URL(fileURLWithPath: defaultModelPath).appendingPathComponent(defaultModelID)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: defaultModelURL.path, isDirectory: &isDir), isDir.boolValue,
               let contents = try? FileManager.default.contentsOfDirectory(atPath: defaultModelURL.path), !contents.isEmpty {
                modelPath = defaultModelPath
            } else {
                modelPath = ""
            }
        }
        
        // 仅在首次启动时加载持久化的下载状态，后续使用内存中已有状态
        if !hasPerformedStartupSync {
            if let savedStatesData = d.data(forKey: "model_download_states"),
               let decoded = try? JSONDecoder().decode([String: ModelDownloadState].self, from: savedStatesData) {
                modelDownloadStates = decoded
            }
        }
        // 首次启动时与文件系统同步：以模型目录中的实际文件为准
        if !hasPerformedStartupSync && !modelPath.isEmpty {
            hasPerformedStartupSync = true
            let repoPath = modelPath + "/models/argmaxinc/whisperkit-coreml"
            let variant = "openai_whisper-large-v3"
            let modelDir = URL(fileURLWithPath: repoPath).appendingPathComponent(variant)
            let markerURL = modelDir.appendingPathComponent(".download_complete")
            let fsExists = FileManager.default.fileExists(atPath: markerURL.path)
            var state = downloadState(for: Self.supportedVoice)
            state.isDownloaded = fsExists
            // 清除残留的下载中状态（App 被杀后 Task 已消失）
            if state.isDownloading {
                state.isDownloading = false
                state.progress = 0.0
            }
            setDownloadState(state, for: Self.supportedVoice)
            // 同步后立即持久化
            if let encoded = try? JSONEncoder().encode(modelDownloadStates) {
                d.set(encoded, forKey: "model_download_states")
            }
        }
    }
    
    func save() {
        let d = defaults
        d.set(llmURL, forKey: "llm_url")
        // llmToken 存储在 Keychain 中，不写入 UserDefaults
        KeychainHelper.save(llmToken, forKey: "llm_token")
        d.set(llmModel, forKey: "llm_model")
        
        d.set(summaryPromptZH, forKey: "summary_prompt_zh")
        d.set(summaryPromptEN, forKey: "summary_prompt_en")
        // Also save to active prompt key
        d.set(summaryPrompt, forKey: "summary_prompt")
        
        d.set(langSetting, forKey: "ui_language")
        d.set(modelPath, forKey: "model_path")
        d.set(selectedVoice, forKey: "voice_model")
        d.set(useChinaMirror, forKey: "use_china_mirror")
        
        // 持久化每模型下载状态
        if let encoded = try? JSONEncoder().encode(modelDownloadStates) {
            d.set(encoded, forKey: "model_download_states")
        }
        
        NotificationCenter.default.post(name: SettingsManager.settingsDidChangeNotification, object: nil)
    }
    
    private func getSystemLanguage() -> String {
        return Locale.preferredLanguages.first ?? "zh-Hans"
    }
}
