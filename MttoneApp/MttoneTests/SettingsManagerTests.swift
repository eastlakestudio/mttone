import XCTest
@testable import Mttone

final class SettingsManagerTests: XCTestCase {
    
    private var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "MttoneTests")
        testDefaults.removePersistentDomain(forName: "MttoneTests")
        SettingsManager.shared.defaults = testDefaults
    }
    
    override func tearDown() {
        SettingsManager.shared.defaults = .standard
        super.tearDown()
    }
    
    func testSettingsLoadDefaultValues() {
        let manager = SettingsManager.shared
        manager.load()
        
        // 验证加载的默认属性是否符合预期
        XCTAssertEqual(manager.llmURL, "")
        XCTAssertEqual(manager.llmToken, "")
        XCTAssertEqual(manager.llmModel, "gpt-4o")
        XCTAssertEqual(manager.selectedVoice, "openai/whisper-large-v3")
        XCTAssertTrue(manager.useChinaMirror)
    }
    
    func testSettingsSaveAndLoad() {
        let manager = SettingsManager.shared
        
        // 修改配置数据
        manager.llmURL = "https://api.deepseek.com/v1"
        manager.llmToken = "sk-test-token-123456"
        manager.llmModel = "deepseek-chat"
        manager.selectedVoice = "openai/whisper-large-v3-turbo"
        manager.useChinaMirror = false
        manager.langSetting = "en"
        manager.summaryPrompt = "这是一个测试自定义提示词_test_suite_val"
        manager.modelPath = "/path/to/custom/whisper"
        
        // 保存配置
        manager.save()
        
        // 验证 UserDefaults 直接存储的值
        let defaults = testDefaults!
        XCTAssertEqual(defaults.string(forKey: "llm_url"), "https://api.deepseek.com/v1")
        XCTAssertEqual(defaults.string(forKey: "llm_token"), "sk-test-token-123456")
        XCTAssertEqual(defaults.string(forKey: "llm_model"), "deepseek-chat")
        XCTAssertEqual(defaults.string(forKey: "voice_model"), "openai/whisper-large-v3-turbo")
        XCTAssertFalse(defaults.bool(forKey: "use_china_mirror"))
        XCTAssertEqual(defaults.string(forKey: "summary_prompt"), "这是一个测试自定义提示词_test_suite_val")
        XCTAssertEqual(defaults.string(forKey: "ui_language"), "en")
        XCTAssertEqual(defaults.string(forKey: "model_path"), "/path/to/custom/whisper")
        
        // 重新 load 并验证 manager 内的数据是否正确同步更新
        manager.load()
        XCTAssertEqual(manager.llmURL, "https://api.deepseek.com/v1")
        XCTAssertEqual(manager.llmToken, "sk-test-token-123456")
        XCTAssertEqual(manager.llmModel, "deepseek-chat")
        XCTAssertEqual(manager.selectedVoice, "openai/whisper-large-v3-turbo")
        XCTAssertFalse(manager.useChinaMirror)
        XCTAssertEqual(manager.summaryPrompt, "这是一个测试自定义提示词_test_suite_val")
        XCTAssertEqual(manager.langSetting, "en")
        XCTAssertEqual(manager.modelPath, "/path/to/custom/whisper")
        
        XCTAssertTrue(manager.isLLMConfigured)
    }
}
