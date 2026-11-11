import Foundation

/// 本机数据目录。App 自己的文件都放这里，和用户可见的 Documents 分开。
///
/// 文件名按 CloudKit 环境加后缀：Debug 包写 `-Development`，Release 包写 `-Production`。
/// 开发环境和生产环境的数据、游标、冲突队列各有一份，切构建配置时不会互相污染。
enum AppStorage {

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zhitiao", isDirectory: true)
    }

    /// 当前构建连的 CloudKit 环境，构建时由 `ICLOUD_CONTAINER_ENVIRONMENT` 写进 Info.plist
    static var environment: String {
        Bundle.main.object(forInfoDictionaryKey: "ZhitiaoCloudEnvironment") as? String ?? "Development"
    }

    /// 传进来的名字形如 `documents.json`，环境后缀插在扩展名前面
    static func url(_ name: String) -> URL {
        let nsName = name as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        let scoped = ext.isEmpty ? "\(base)-\(environment)" : "\(base)-\(environment).\(ext)"
        return directory.appendingPathComponent(scoped)
    }

    static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 老版本没分环境。旧数据都是 Debug 包写的，所以只让开发环境继承，生产环境从空开始。
    static func migrateLegacyFileIfNeeded(_ name: String) {
        guard environment == "Development" else { return }
        let legacy = directory.appendingPathComponent(name)
        let scoped = url(name)
        guard FileManager.default.fileExists(atPath: legacy.path),
              !FileManager.default.fileExists(atPath: scoped.path)
        else { return }
        try? FileManager.default.moveItem(at: legacy, to: scoped)
    }
}
