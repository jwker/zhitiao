import Foundation
import UIKit

/// 文档存储：当前文字和少量偏好。
///
/// 优先用 iCloud（`NSUbiquitousKeyValueStore`）；没有 iCloud 权限或未登录时，
/// 自动退回本地存储，功能不受影响。
final class DocumentStore {

    static let shared = DocumentStore()

    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    private enum Key {
        static let text = "zhitiao.text"
        static let spec = "zhitiao.spec"
        static let config = "zhitiao.aiConfig"
    }

    private init() {
        cloud.synchronize()
    }

    // MARK: - 正文

    var text: String {
        get {
            let value = cloud.string(forKey: Key.text)
                ?? defaults.string(forKey: Key.text)
                ?? ""
            return value
        }
        set {
            defaults.set(newValue, forKey: Key.text)
            cloud.set(newValue, forKey: Key.text)
            cloud.synchronize()
        }
    }

    // MARK: - 卡片参数

    var spec: CardSnapshot {
        get {
            guard let data = defaults.data(forKey: Key.spec) else { return CardSnapshot(spec: CardSpec()) }
            return (try? JSONDecoder().decode(CardSnapshot.self, from: data)) ?? CardSnapshot(spec: CardSpec())
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.spec)
            }
        }
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

    /// iCloud 是否可用（已登录且有权限）
    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
