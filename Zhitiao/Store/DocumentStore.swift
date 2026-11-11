import Foundation

/// 数据层：纸条列表 + 模型配置。
///
/// 纸条存在 `Application Support/Zhitiao/documents.json`，整份列表一个文件，写入用原子写，
/// 避免写到一半被杀进程留下半个文件。模型配置仍然放本机 `UserDefaults`：它只有几 KB，
/// 而且永远不会同步。
///
/// 两者都不联网。iCloud 同步在开发中，目前只查账号状态。
final class DocumentStore {

    static let shared = DocumentStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let config = "zhitiao.aiConfig"
        static let imageConfig = "zhitiao.imageConfig"
        /// 旧版本把整份列表存在 UserDefaults 里，`reset()` 时一并清掉
        static let legacyDocuments = "zhitiao.documents.v2"
        static let legacyText = "zhitiao.text"
        static let legacySpec = "zhitiao.spec"
    }

    private init() {}

    // MARK: - 纸条列表

    private var fileURL: URL { AppStorage.url("documents.json") }

    func loadDocuments() -> [SyncedDocument] {
        AppStorage.migrateLegacyFileIfNeeded("documents.json")
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        do {
            return try Self.decoder.decode(StoredFile.self, from: data).documents
        } catch {
            // 文件读不出来时不能直接覆盖，先挪到旁边留证，再按空列表启动
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("documents-broken-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return []
        }
    }

    func saveDocuments(_ documents: [SyncedDocument]) {
        // 空纸条不落盘：新建后马上被杀进程时，别在列表里留一条空白。
        // 同步过的空纸条要留，因为它后面要变成墓碑。
        let persistable = documents.filter { !($0.isEmpty && $0.changeTag == nil) }
        let file = StoredFile(version: StoredFile.currentVersion, documents: persistable)
        guard let data = try? Self.encoder.encode(file) else { return }

        do {
            AppStorage.ensureDirectory()
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 写盘失败只影响持久化，不该让界面崩。下次改动会再试一次。
        }
    }

    /// 文件里带一个版本号，以后换格式时能判断怎么读
    private struct StoredFile: Codable {
        static let currentVersion = 1
        var version: Int
        var documents: [SyncedDocument]
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    // MARK: - 模型配置

    var config: AIClient.Config {
        get {
            guard let data = defaults.data(forKey: Key.config) else { return .default }
            return (try? JSONDecoder().decode(AIClient.Config.self, from: data)) ?? .default
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.config)
            }
        }
    }

    /// 插画模型配置（可选）
    var imageConfig: IllustrationGenerator.Config {
        get {
            guard let data = defaults.data(forKey: Key.imageConfig) else { return .default }
            return (try? JSONDecoder().decode(IllustrationGenerator.Config.self, from: data)) ?? .default
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.imageConfig)
            }
        }
    }

    /// 清空全部数据（调试用）
    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
        defaults.removeObject(forKey: Key.config)
        defaults.removeObject(forKey: Key.imageConfig)
        defaults.removeObject(forKey: Key.legacyDocuments)
        defaults.removeObject(forKey: Key.legacyText)
        defaults.removeObject(forKey: Key.legacySpec)
    }
}
