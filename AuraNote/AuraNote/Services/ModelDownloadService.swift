import Foundation

/// 模型下载服务：从 hf-mirror 直连下载 WhisperKit CoreML 模型文件
/// 绕过 WhisperKit 内置下载器，URLSession 原生处理 307 重定向
enum ModelDownloadService {

    // MARK: - Delegate for byte-level progress

    private final class FileDownloadDelegate: NSObject, URLSessionDataDelegate {
        var completion: ((Result<Data, Error>) -> Void)?
        var onBytesReceived: ((Int64) -> Void)?
        var accumulatedData = Data()
        var httpResponse: HTTPURLResponse?

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            httpResponse = response as? HTTPURLResponse
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            accumulatedData.append(data)
            onBytesReceived?(Int64(data.count))
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                completion?(.failure(error))
            } else if let httpResp = httpResponse, httpResp.statusCode != 200 {
                completion?(.failure(NSError(domain: "HFMirror", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(httpResp.statusCode) for download"
                ])))
            } else if let httpResp = httpResponse, httpResp.mimeType?.hasPrefix("text/html") == true {
                completion?(.failure(NSError(domain: "HFMirror", code: -4, userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected HTML response, hf-mirror may be unavailable"
                ])))
            } else {
                completion?(.success(accumulatedData))
            }
        }
    }

    // MARK: - Public API

    /// 从 hf-mirror 下载模型文件
    /// - Parameters:
    ///   - variant: 模型变体目录名（如 "openai_whisper-large-v3-v20240930_turbo"）
    ///   - downloadBase: 下载根目录
    ///   - progressHandler: 进度回调 (0.0 ~ 1.0)，基于累积下载字节数
    /// - Returns: 下载完成的模型目录 URL
    static func download(
        variant: String,
        downloadBase: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        let repoId = "argmaxinc/whisperkit-coreml"
        let apiURL = URL(string: "https://hf-mirror.com/api/models/\(repoId)/revision/main")!

        // 1. 获取文件列表
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.connectionProxyDictionary = [:]  // 绕开系统代理
        sessionConfig.timeoutIntervalForRequest = 30   // 单次请求超时
        sessionConfig.timeoutIntervalForResource = 600 // 总资源超时（10分钟，632MB 模型留足余量）

        let session = URLSession(configuration: sessionConfig)

        let (data, response) = try await session.data(from: apiURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "HFMirror", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch model file list from hf-mirror"
            ])
        }

        struct Sibling: Codable { let rfilename: String; let size: Int64? }
        struct SiblingsResponse: Codable { let siblings: [Sibling] }
        let siblingsResponse = try JSONDecoder().decode(SiblingsResponse.self, from: data)

        // 筛选匹配 variant 的文件
        let prefix = "\(variant)/"
        let files = siblingsResponse.siblings.filter { $0.rfilename.hasPrefix(prefix) }
        guard !files.isEmpty else {
            throw NSError(domain: "HFMirror", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "No files found for variant \(variant)"
            ])
        }

        // 计算总字节数（缺失 size 的文件按 0 计，实际下载时会回退到文件计数）
        let totalSizedBytes = files.compactMap(\.size).reduce(0, +)
        let hasSizes = totalSizedBytes > 0
        let totalFiles = files.count

        AppLog.info("hf-mirror download: \(totalFiles) files for \(variant), total \(hasSizes ? ByteCountFormatter.string(fromByteCount: totalSizedBytes, countStyle: .file) : "unknown") bytes")

        // 2. 逐文件下载，逐字节跟踪进度（复用 delegate session，避免每次创建）
        let repoPath = downloadBase.appendingPathComponent("models/\(repoId)")
        var cumulativeBytes: Int64 = 0
        let delegate = FileDownloadDelegate()
        let downloadSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()

            let fileURL = URL(string: "https://hf-mirror.com/\(repoId)/resolve/main/\(file.rfilename)")!
            let localURL = repoPath.appendingPathComponent(file.rfilename)

            // 创建父目录
            try FileManager.default.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var dataTask: URLSessionDataTask?
            let fileData = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    delegate.completion = { result in
                        continuation.resume(with: result)
                    }
                    delegate.onBytesReceived = { bytes in
                        cumulativeBytes += bytes
                        if hasSizes {
                            progressHandler(Double(cumulativeBytes) / Double(totalSizedBytes))
                        } else {
                            let fileProgress = Double(cumulativeBytes) / Double(max(1, cumulativeBytes + 10_000_000))
                            progressHandler((Double(index) + fileProgress) / Double(totalFiles))
                        }
                    }
                    let task = downloadSession.dataTask(with: fileURL)
                    dataTask = task
                    task.resume()
                }
            } onCancel: {
                dataTask?.cancel()
            }

            // 重置 delegate 状态，准备下载下一个文件
            delegate.accumulatedData = Data()
            delegate.httpResponse = nil

            // 校验响应
            guard !fileData.isEmpty else {
                throw NSError(domain: "HFMirror", code: -5, userInfo: [
                    NSLocalizedDescriptionKey: "Empty response body for \(file.rfilename)"
                ])
            }
            try fileData.write(to: localURL, options: .atomic)

            // 无 size 信息时，每文件完成后报告确定进度
            if !hasSizes {
                cumulativeBytes = Int64(index + 1)
                progressHandler(Double(index + 1) / Double(totalFiles))
            }
        }

        AppLog.info("hf-mirror download complete: \(variant)")
        return repoPath.appendingPathComponent(variant)
    }
}
