import Foundation
import AVFoundation

/// 录音播放服务
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    
    // MARK: - 公开状态
    
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    /// 当前播放中的声学振幅分贝（0.0 ~ 1.0），用于音量可视化
    var meterLevel: Float = 0.0
    
    var errorMessage: String? // 播放错误信息公开暴露
    var hasPlayer: Bool {
        return player != nil
    }
    
    // MARK: - 私有属性
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    // MARK: - 控制方法
    
    func startPlaying(url: URL) {
        stop()
        errorMessage = nil
        
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            #endif
            
            // 确保文件存在
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            if !fileExists {
                let err = String(format: loc("audio_file_not_found_name"), url.lastPathComponent)
                self.errorMessage = err
                return
            }
            
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.isMeteringEnabled = true
            newPlayer.volume = volume
            
            _ = newPlayer.prepareToPlay()
            
            self.player = newPlayer
            
            if newPlayer.play() {
                isPlaying = true
                duration = newPlayer.duration
                startTimer()
            } else {
                let err = "AVAudioPlayer.play() returned false"
                self.errorMessage = err
            }
        } catch {
            let errMsg = String(format: loc("player_init_failed"), error.localizedDescription)
            self.errorMessage = errMsg
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func resume() {
        if player?.play() == true {
            isPlaying = true
            startTimer()
        } else {
            // Resume failed
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        meterLevel = 0
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }
    
    var playbackEndTime: TimeInterval?
    
    // MARK: - 定时器相关
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
            
            // 自动播放终止逻辑（对应切片片段回放）
            if let endTime = self.playbackEndTime, self.currentTime >= endTime {
                self.pause()
                self.playbackEndTime = nil
                return
            }
            
            // 更新音量分贝
            player.updateMeters()
            let decibels = player.averagePower(forChannel: 0)
            // 将 -160dB ~ 0dB 的分贝值映射到 0.0 ~ 1.0 的线性范围
            let level: Float
            if decibels < -60 {
                level = 0
            } else if decibels >= 0 {
                level = 1
            } else {
                level = (decibels + 60) / 60
            }
            self.meterLevel = level
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.stop()
        }
    }
}
