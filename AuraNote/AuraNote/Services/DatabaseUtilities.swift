import Foundation
import SQLite3

/// 通用 SQLite 工具层：错误类型、常量、扩展
/// 与 DatabaseManager 解耦，独立供所有数据库扩展文件使用

// MARK: - SQLite 常量

/// SQLite 内存管理标识：绑定字符串时生命期由 SQLite 管理
internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - 错误类型

enum DBError: LocalizedError {
    case prepareFailed(String)
    case executeFailed(String)

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg): return "SQL Prepare Failed: \(msg)"
        case .executeFailed(let msg): return "SQL Execute Failed: \(msg)"
        }
    }
}

// MARK: - String Extension

extension String {
    /// Swift String → SQLite C 字符串（桥接至 NSString.utf8String）
    var cString: UnsafePointer<CChar>? {
        return (self as NSString).utf8String
    }
}
