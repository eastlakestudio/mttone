import AVFoundation
import WhisperKit

/// 音频录制 + 基于 WhisperKit 的本地实时转写服务
@Observable
final class AudioRecorder {

    // MARK: - 公开状态

    var isRecording = false
    var segments: [TranscriptSegment] = []
    var currentAmplitude: Float = 0.0  // 用于音量可视化（0.0 ~ 1.0）
    var errorMessage: String?

    // MARK: - 私有属性

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var audioConverter: AVAudioConverter?
    
    private var recordingStartTime: Date?
    private var segmentCounter = 0
    private var currentMeetingId: String?

    // 实时流属性
    private var currentLiveAudioBuffer: [Float] = []
    private var finalizedSentences: [String] = []
    private var currentLiveText: String = ""
    private var pauseTimer: Timer?
    
    private var isTranscriptionTaskRunning = false
    private var liveTranscriptionTask: Task<Void, Never>?

    init() {}

    // MARK: - 权限请求

    func requestPermissions() async -> Bool {
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
        micGranted = true
        #endif
        guard micGranted else {
            errorMessage = "需要麦克风权限才能录制会议"
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
        finalizedSentences = []
        currentLiveAudioBuffer = []
        currentLiveText = ""
        currentMeetingId = meetingId
        pauseTimer?.invalidate()
        pauseTimer = nil

        // 配置 Audio Session (仅 iOS)
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let wavSavePath = savePath.deletingPathExtension().appendingPathExtension("wav")
        audioFile = try AVAudioFile(
            forWriting: wavSavePath,
            settings: recordingFormat.settings
        )
        
        let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(WhisperKit.sampleRate), channels: 1, interleaved: false)!
        self.audioConverter = AVAudioConverter(from: recordingFormat, to: whisperFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            try? self.audioFile?.write(from: buffer)
            self.updateAmplitude(buffer: buffer)
            
            var floatArray: [Float] = []
            if buffer.format.sampleRate == Double(WhisperKit.sampleRate) && buffer.format.channelCount == 1 {
                floatArray = AudioProcessor.convertBufferToArray(buffer: buffer)
            } else {
                guard let converter = self.audioConverter else { return }
                do {
                    let resampled = try AudioProcessor.resampleBuffer(buffer, with: converter)
                    floatArray = AudioProcessor.convertBufferToArray(buffer: resampled)
                } catch {
                    print("[AudioRecorder] resampleBuffer error: \(error)")
                }
            }
            
            self.appendAudioAndCheckVAD(floatArray)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recordingStartTime = Date()
        isRecording = true
        
        // 启动后台轮询转写循环
        startTranscriptionLoop()
        
        print("[Audio] Recording started for meeting: \(meetingId)")
    }

    // MARK: - 停止录音

    func stopRecording() -> Int {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        audioFile = nil
        audioConverter = nil
        
        isTranscriptionTaskRunning = false
        liveTranscriptionTask?.cancel()
        liveTranscriptionTask = nil
        pauseTimer?.invalidate()
        pauseTimer = nil

        let duration: Int
        if let start = recordingStartTime {
            duration = Int(Date().timeIntervalSince(start))
        } else {
            duration = 0
        }

        isRecording = false
        currentAmplitude = 0
        print("[Audio] Recording stopped. Duration: \(duration)s, Segments: \(segments.count)")

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        return duration
    }

    // MARK: - 内部方法

    private func appendAudioAndCheckVAD(_ audio: [Float]) {
        let amplitude = self.currentAmplitude
        
        DispatchQueue.main.async {
            self.currentLiveAudioBuffer.append(contentsOf: audio)
            
            // 如果有人说话（能量大于阈值），重置静音定时器
            if amplitude > 0.02 {
                self.pauseTimer?.invalidate()
                self.pauseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    self?.freezeCurrentLiveText()
                }
            } else if self.pauseTimer == nil {
                // 如果长期无人说话（定时器未启动），防止纯静音音频在数组中无限堆积导致大模型幻觉
                if self.currentLiveAudioBuffer.count > 16000 * 2 {
                    // 保留最后 0.5 秒的缓冲，丢弃之前的纯静音
                    self.currentLiveAudioBuffer = Array(self.currentLiveAudioBuffer.suffix(8000))
                }
            }
        }
    }

    private func startTranscriptionLoop() {
        isTranscriptionTaskRunning = true
        liveTranscriptionTask = Task {
            while self.isTranscriptionTaskRunning && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                
                let audioToProcess = self.currentLiveAudioBuffer
                guard audioToProcess.count > 8000 else { continue }
                
                do {
                    let text = try await WhisperService.shared.transcribeLive(audioArray: audioToProcess)
                    await MainActor.run {
                        self.currentLiveText = text
                        self.updateSegments()
                    }
                } catch {
                    print("[AudioRecorder] transcribeLive error: \(error)")
                }
            }
        }
    }

    @objc private func freezeCurrentLiveText() {
        let trimmed = currentLiveText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            finalizedSentences.append(trimmed)
        }
        currentLiveText = ""
        currentLiveAudioBuffer = []
        updateSegments()
    }
    
    private func updateSegments() {
        guard let meetingId = currentMeetingId else { return }
        let elapsed = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        var displaySentences = finalizedSentences
        let trimmedLive = currentLiveText.trimmingCharacters(in: .whitespaces)
        if !trimmedLive.isEmpty {
            displaySentences.append(trimmedLive)
        }
        
        var newSegments: [TranscriptSegment] = []
        for (index, text) in displaySentences.enumerated() {
            let isLast = index == displaySentences.count - 1
            let isFinalSegment = !isLast 
            let estimatedStartTime = max(0, elapsed - Double(displaySentences.count - index) * 3.0)
            
            let seg = TranscriptSegment(
                id: "\(meetingId)_live_\(index)",
                startTime: estimatedStartTime,
                endTime: elapsed,
                text: text,
                speakerLabel: "Speaker_1",
                isFinal: isFinalSegment
            )
            newSegments.append(seg)
        }
        self.segments = newSegments
    }

    private func updateAmplitude(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let avg = sum / Float(frameLength)
        DispatchQueue.main.async {
            self.currentAmplitude = self.currentAmplitude * 0.7 + avg * 0.3
        }
    }
}

// MARK: - 错误类型

enum RecorderError: LocalizedError {
    case microphoneAccessDenied

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied: return "麦克风权限被拒绝"
        }
    }
}
