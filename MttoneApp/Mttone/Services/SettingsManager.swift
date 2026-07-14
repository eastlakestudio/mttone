import Foundation
import Observation

@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    var defaults: UserDefaults = .standard
    
    var llmURL: String = ""
    var llmToken: String = ""
    var llmModel: String = ""
    var summaryPromptZH: String = ""
    var summaryPromptEN: String = ""
    var langSetting: String = "" {
        didSet {
            defaults.set(langSetting, forKey: "ui_language")
            NotificationCenter.default.post(name: NSNotification.Name("MttoneSettingsDidChange"), object: nil)
        }
    }
    var modelPath: String = ""
    var selectedVoice: String = "openai/whisper-large-v3"
    var useChinaMirror: Bool = true
    
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
    
    private init() {
        load()
    }
    
    func load() {
        let d = defaults
        llmURL = d.string(forKey: "llm_url") ?? ""
        llmToken = d.string(forKey: "llm_token") ?? ""
        llmModel = d.string(forKey: "llm_model") ?? "gpt-4o"
        
        let oldPrompt = d.string(forKey: "summary_prompt")
        var zhVal = d.string(forKey: "summary_prompt_zh") ?? oldPrompt ?? "你是一个专业的会议纪要整理助手。请将以下会议发言记录整理成结构化的会议纪要，包括：\n1. 会议概要\n2. 主要议题\n3. 决策事项\n4. 待办事项"
        var enVal = d.string(forKey: "summary_prompt_en") ?? "You are a professional meeting assistant. Please organize the following meeting transcript into a structured summary, including:\n1. Overview\n2. Key Topics\n3. Decisions Made\n4. Action Items"
        
        if zhVal == "自定义提示词" || zhVal == "这是一个测试自定义提示词" {
            zhVal = "你是一个专业的会议纪要整理助手。请将以下会议发言记录整理成结构化的会议纪要，包括：\n1. 会议概要\n2. 主要议题\n3. 决策事项\n4. 待办事项"
        }
        if enVal == "自定义提示词" || enVal == "这是一个测试自定义提示词" {
            enVal = "You are a professional meeting assistant. Please organize the following meeting transcript into a structured summary, including:\n1. Overview\n2. Key Topics\n3. Decisions Made\n4. Action Items"
        }
        
        summaryPromptZH = zhVal
        summaryPromptEN = enVal
        
        langSetting = d.string(forKey: "ui_language") ?? ""
        selectedVoice = d.string(forKey: "voice_model") ?? "openai/whisper-large-v3"
        useChinaMirror = d.object(forKey: "use_china_mirror") as? Bool ?? true
        
        let savedPath = d.string(forKey: "model_path") ?? ""
        if savedPath.isEmpty {
            let defaultModelID = selectedVoice == "openai/whisper-large-v3-turbo" ? "openai_whisper-large-v3_turbo" : selectedVoice.replacingOccurrences(of: "openai/", with: "openai_")
            let defaultModelURL = URL(fileURLWithPath: defaultModelPath).appendingPathComponent(defaultModelID)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: defaultModelURL.path, isDirectory: &isDir), isDir.boolValue,
               let contents = try? FileManager.default.contentsOfDirectory(atPath: defaultModelURL.path), !contents.isEmpty {
                modelPath = defaultModelPath
            } else {
                modelPath = ""
            }
        } else {
            modelPath = savedPath
        }
    }
    
    func save() {
        let d = defaults
        d.set(llmURL, forKey: "llm_url")
        d.set(llmToken, forKey: "llm_token")
        d.set(llmModel, forKey: "llm_model")
        
        d.set(summaryPromptZH, forKey: "summary_prompt_zh")
        d.set(summaryPromptEN, forKey: "summary_prompt_en")
        // Also save to active prompt key
        d.set(summaryPrompt, forKey: "summary_prompt")
        
        d.set(langSetting, forKey: "ui_language")
        d.set(modelPath, forKey: "model_path")
        d.set(selectedVoice, forKey: "voice_model")
        d.set(useChinaMirror, forKey: "use_china_mirror")
        
        NotificationCenter.default.post(name: NSNotification.Name("MttoneSettingsDidChange"), object: nil)
    }
    
    private func getSystemLanguage() -> String {
        return Locale.preferredLanguages.first ?? "zh-Hans"
    }
}
