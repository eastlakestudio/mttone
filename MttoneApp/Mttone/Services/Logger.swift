import Foundation

/// 轻量日志工具：输出到系统控制台 + 追加写入 Documents/debug.log（供 DebugLogView 展示）
enum AppLog {
    private static let queue = DispatchQueue(label: "app.log.q")
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func info(_ message: String, file: String = #file, function: String = #function) {
        log(level: "INFO", message: message, file: file, function: function)
    }

    static func warn(_ message: String, file: String = #file, function: String = #function) {
        log(level: "WARN", message: message, file: file, function: function)
    }

    static func error(_ message: String, file: String = #file, function: String = #function) {
        log(level: "ERROR", message: message, file: file, function: function)
    }

    private static func log(level: String, message: String, file: String, function: String) {
        let time = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let line = "[\(time)] [\(level)] [\(fileName):\(function)] \(message)"

        // 系统控制台
        NSLog("%@", line)

        // 追加写入 debug.log
        queue.async {
            let logURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("debug.log")
            let entry = line + "\n"
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(entry.data(using: .utf8) ?? Data())
                try? handle.close()
            } else {
                try? entry.data(using: .utf8)?.write(to: logURL, options: .atomic)
            }
        }
    }
}
