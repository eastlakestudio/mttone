import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 13.0, *)
class AudioCaptureHelper: NSObject, SCStreamOutput {
    private var stream: SCStream?
    
    func startCapture(targetAppName: String) async {
        do {
            // 1. 获取屏幕和音频的可共享内容列表
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // 2. 过滤寻找目标应用程序 (如 "Feishu" 或 "TencentMeeting")
            guard let app = shareableContent.applications.first(where: { 
                $0.applicationName.lowercased().contains(targetAppName.lowercased()) 
            }) else {
                fputs("Target application '\(targetAppName)' not found.\n", stderr)
                exit(1)
            }
            
            // 3. 配置流：排除窗口视觉，仅开启音频捕获
            let filter = SCContentFilter(display: shareableContent.displays[0], excludingApplications: [], exceptingWindows: [])
            
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesHeadersAndWindows = true
            // 设为 0 以完全关闭视频通道，仅留音频
            config.width = 0
            config.height = 0
            
            // 4. 初始化并启动采集流
            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "mttone.audio.capture"))
            
            try await stream?.startCapture()
            fputs("Capture stream started for \(app.applicationName).\n", stderr)
            
        } catch {
            fputs("Failed to initialize capture: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    
    // 5. 音频帧到达回调：直接通过标准输出发送原始 PCM 数据给 Rust
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        
        var data = Data(count: length)
        data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            if let baseAddress = buffer.baseAddress {
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
            }
        }
        
        // 写入 stdout，回传给 Rust 后端
        FileHandle.standardOutput.write(data)
    }
    
    func stopCapture() async {
        do {
            try await stream?.stopCapture()
        } catch {
            fputs("Error stopping capture: \(error.localizedDescription)\n", stderr)
        }
    }
}
