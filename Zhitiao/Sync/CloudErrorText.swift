import CloudKit
import Foundation

/// 把 `CKError` 翻成一句人话。设置页和调试输出都用它，避免到处写错误码。
enum CloudErrorText {

    static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }

        switch ck.code {
        case .notAuthenticated:
            return "iCloud 未登录，或本 App 的 iCloud 开关已关闭"
        case .networkUnavailable, .networkFailure:
            return "网络不可用"
        case .quotaExceeded:
            return "iCloud 空间已满"
        case .zoneNotFound:
            return "同步区域不存在"
        case .zoneBusy:
            return "iCloud 正忙，稍后重试"
        case .requestRateLimited:
            return "请求太频繁，稍后重试"
        case .serverRecordChanged:
            return "服务端已有更新的版本"
        case .changeTokenExpired:
            return "同步游标过期，需要重新拉取"
        case .accountTemporarilyUnavailable:
            return "iCloud 暂时不可用"
        case .partialFailure:
            return partialFailureText(ck)
        default:
            return "\(ck.localizedDescription)（\(ck.code.rawValue)）"
        }
    }

    private static func partialFailureText(_ error: CKError) -> String {
        guard let details = error.partialErrorsByItemID?.values, !details.isEmpty else {
            return "部分记录操作失败"
        }
        return details.prefix(3).map(describe).joined(separator: "；")
    }

    /// 原始错误全文，只在调试自检里用。CloudKit 的拒绝经常没有说明，
    /// 真正的线索在 userInfo 的 `CKErrorServerErrorKey` 里。
    static func debug(_ error: Error) -> String {
        let ns = error as NSError
        var lines = ["  \(ns.domain) \(ns.code)"]
        for (key, value) in ns.userInfo.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(key) = \(value)")
        }
        return lines.joined(separator: "\n")
    }
}
