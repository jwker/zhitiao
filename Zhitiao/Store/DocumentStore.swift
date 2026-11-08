import Foundation

/// 数据层：纸条列表 + 模型配置。
///
/// 纸条列表优先写 iCloud（`NSUbiquitousKeyValueStore`）；没有 iCloud 权限或未登录时
/// 自动退回本机 `UserDefaults`，功能不受影响。
final class DocumentStore {

    static let shared = DocumentStore()

    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    private enum Key {
        static let documents = "zhitiao.documents.v2"
        static let config = "zhitiao.aiConfig"
        static let imageConfig = "zhitiao.imageConfig"
        /// 旧版本的单个正文，用来做一次性迁移
        static let legacyText = "zhitiao.text"
        static let legacySpec = "zhitiao.spec"
    }

    private init() {
        cloud.synchronize()
    }

    // MARK: - 纸条列表

    var documents: [Document] {
        get {
            if let data = cloud.data(forKey: Key.documents),
               let list = try? JSONDecoder().decode([Document].self, from: data) {
                return list
            }
            if let data = defaults.data(forKey: Key.documents),
               let list = try? JSONDecoder().decode([Document].self, from: data) {
                return list
            }
            return migrateLegacy()
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.documents)
            cloud.set(data, forKey: Key.documents)
            cloud.synchronize()
        }
    }

    /// 老版本只存了一条正文和一个卡片设置，搬成第一条纸条
    private func migrateLegacy() -> [Document] {
        guard let text = defaults.string(forKey: Key.legacyText),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return [] }

        let snapshot: CardSnapshot
        if let data = defaults.data(forKey: Key.legacySpec),
           let saved = try? JSONDecoder().decode(CardSnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = CardSnapshot(spec: CardSpec())
        }

        let document = Document(text: text, snapshot: snapshot)
        defaults.removeObject(forKey: Key.legacyText)
        defaults.removeObject(forKey: Key.legacySpec)
        documents = [document]
        return [document]
    }

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

    /// 清掉旧版本残留的两个键（调试用）
    static func resetLegacy() {
        UserDefaults.standard.removeObject(forKey: "zhitiao.text")
        UserDefaults.standard.removeObject(forKey: "zhitiao.spec")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "zhitiao.text")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "zhitiao.spec")
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// iCloud 是否可用（已登录且有权限）
    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
