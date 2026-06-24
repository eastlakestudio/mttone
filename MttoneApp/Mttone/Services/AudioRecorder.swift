import AVFoundation
import Speech

/// 音频录制 + 实时语音识别服务
/// 使用 Apple 原生 AVAudioEngine + SFSpeechRecognizer
@Observable
final class AudioRecorder {

    // MARK: - 公开状态

    var isRecording = false
    var segments: [TranscriptSegment] = []
    var currentAmplitude: Float = 0.0  // 用于音量可视化（0.0 ~ 1.0）
    var errorMessage: String?

    // MARK: - 私有属性

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private var segmentCounter = 0

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    }

    // MARK: - 权限请求

    func requestPermissions() async -> Bool {
        // 1. 麦克风权限
        let micGranted: Bool
        #if os(iOS)
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #else
        // macOS: 系统会在首次访问麦克风时自动弹出权限请求
        micGranted = true
        #endif
        guard micGranted else {
            errorMessage = "需要麦克风权限才能录制会议"
            return false
        }

        // 2. 语音识别权限
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            errorMessage = "需要语音识别权限才能进行实时转写"
            return false
        }

        return true
    }

    // MARK: - 开始录音

    func startRecording(meetingId: String, savePath: URL, contextualStrings: [String] = []) throws {
        // 重置状态
        segments = []
        segmentCounter = 0
        errorMessage = nil

        // 配置 Audio Session (仅 iOS)
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // 配置语音识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw RecorderError.recognitionUnavailable
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        if !contextualStrings.isEmpty {
            recognitionRequest.contextualStrings = contextualStrings
        }

        // 启动语音识别任务
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw RecorderError.recognitionUnavailable
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.handleRecognitionResult(result, meetingId: meetingId)
            }

            if let error {
                // 识别出错时仅打印警告，不中断录音
                print("[ASR] Recognition error: \(error.localizedDescription)")
            }
        }

        // 安装音频 Tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 创建音频文件用于持久化 - 直接使用输入流原始硬件格式（PCM 线性无压缩），防止 CoreAudio 在子线程写压缩流产生 zsh: abort 崩溃
        audioFile = try AVAudioFile(
            forWriting: savePath,
            settings: recordingFormat.settings
        )
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 1. 将 buffer 送入语音识别引擎
            self.recognitionRequest?.append(buffer)
            
            // 2. 将 buffer 直接写入 PCM 原始音频文件
            try? self.audioFile?.write(from: buffer)

            // 3. 计算当前音量用于 UI 动画
            self.updateAmplitude(buffer: buffer)
        }

        // 启动引擎
        audioEngine.prepare()
        try audioEngine.start()

        recordingStartTime = Date()
        isRecording = true
        print("[Audio] Recording started for meeting: \(meetingId)")
    }

    // MARK: - 停止录音

    func stopRecording() -> Int {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        audioFile = nil

        let duration: Int
        if let start = recordingStartTime {
            duration = Int(Date().timeIntervalSince(start))
        } else {
            duration = 0
        }

        isRecording = false
        currentAmplitude = 0
        print("[Audio] Recording stopped. Duration: \(duration)s, Segments: \(segments.count)")

        // 释放 Audio Session
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        return duration
    }

    // MARK: - 内部方法

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult, meetingId: String) {
        let elapsed = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // 将整段识别结果作为一个 segment 更新
        // SFSpeechRecognizer 返回的是累积结果，我们取最新的 bestTranscription
        let text = result.bestTranscription.formattedString

        if result.isFinal {
            // 最终结果：追加新 segment
            segmentCounter += 1
            let segment = TranscriptSegment(
                id: "\(meetingId)_seg_\(segmentCounter)",
                startTime: max(0, elapsed - 5),
                endTime: elapsed,
                text: text,
                speakerLabel: "Speaker_1", // SFSpeechRecognizer 不支持多说话人，暂用默认标签
                isFinal: true
            )
            // 替换最后一个非 final 的 segment（如果有的话），或追加
            if let lastIndex = segments.lastIndex(where: { !$0.isFinal }) {
                segments[lastIndex] = segment
            } else {
                segments.append(segment)
            }
        } else {
            // 中间结果：更新或追加一个临时 segment
            let tempSegment = TranscriptSegment(
                id: "\(meetingId)_live",
                startTime: max(0, elapsed - 3),
                endTime: elapsed,
                text: text,
                speakerLabel: "Speaker_1",
                isFinal: false
            )
            if let lastIndex = segments.lastIndex(where: { !$0.isFinal }) {
                segments[lastIndex] = tempSegment
            } else {
                segments.append(tempSegment)
            }
        }
    }

    private func updateAmplitude(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let avg = sum / Float(frameLength)
        // 平滑处理
        DispatchQueue.main.async {
            self.currentAmplitude = self.currentAmplitude * 0.7 + avg * 0.3
        }
    }
}

// MARK: - 错误类型

enum RecorderError: LocalizedError {
    case recognitionUnavailable
    case microphoneAccessDenied

    var errorDescription: String? {
        switch self {
        case .recognitionUnavailable: return "语音识别服务不可用"
        case .microphoneAccessDenied: return "麦克风权限被拒绝"
        }
    }
}
