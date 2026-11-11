import CloudKit
import Foundation

/// 同步引擎对外显示的状态。
enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case unavailable(String)
    case disabled
    case failed(String)

    var title: String {
        switch self {
        case .idle: return "未同步"
        case .syncing: return "正在同步…"
        case .synced: return "已同步"
        case .unavailable(let reason): return reason
        case .disabled: return "已关闭"
        case .failed: return "同步失败"
        }
    }

    /// 只有失败时带额外说明
    var detail: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

/// 一条等用户处理的冲突。
///
/// 冲突只在上传时发现：本机改了某条，传上去时服务端说这条已经被人改过。
/// 这里把两边的版本都存下来，等用户在界面上选。默认行为是「保留本机」，
/// 所以本机版本会先传上去，不会一直卡在待上传状态。
struct SyncConflict: Codable, Identifiable, Equatable {

    enum Kind: String, Codable {
        /// 两边都改了正文
        case text
        /// 本机在改，别处已经删了
        case deleted
    }

    var id: UUID
    var documentID: UUID
    var kind: Kind
    var baseText: String?
    var localText: String
    var serverText: String
    var localUpdatedAt: Date
    var serverUpdatedAt: Date
    var serverSnapshot: CardSnapshot
    var serverChangeTag: String?
    /// 服务端记录的系统字段存档。「保留其他设备」时用它上传，避免再撞一次冲突。
    var serverSystemFields: Data?
    var createdAt: Date

    init(
        documentID: UUID,
        kind: Kind,
        baseText: String?,
        localText: String,
        serverText: String,
        localUpdatedAt: Date,
        serverUpdatedAt: Date,
        serverSnapshot: CardSnapshot,
        serverChangeTag: String?,
        serverSystemFields: Data? = nil
    ) {
        self.id = UUID()
        self.documentID = documentID
        self.kind = kind
        self.baseText = baseText
        self.localText = localText
        self.serverText = serverText
        self.localUpdatedAt = localUpdatedAt
        self.serverUpdatedAt = serverUpdatedAt
        self.serverSnapshot = serverSnapshot
        self.serverChangeTag = serverChangeTag
        self.serverSystemFields = serverSystemFields
        self.createdAt = Date()
    }
}

/// 增量拉取的游标。`changeToken` 是 CloudKit 给的 opaque 值，存成 Data。
struct SyncCursor: Codable, Equatable {
    var changeToken: Data?
    /// 上次成功同步的时间，跨启动保留，设置页要显示
    var lastSyncedAt: Date?
    /// 静默推送的订阅建过没有
    var subscriptionReady: Bool = false
}

final class SyncCursorStore {

    private let url = AppStorage.url("sync-cursor.json")

    func load() -> SyncCursor {
        AppStorage.migrateLegacyFileIfNeeded("sync-cursor.json")
        guard let data = try? Data(contentsOf: url),
              let cursor = try? JSONDecoder().decode(SyncCursor.self, from: data)
        else { return SyncCursor() }
        return cursor
    }

    func save(_ cursor: SyncCursor) {
        AppStorage.ensureDirectory()
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func reset() {
        try? FileManager.default.removeItem(at: url)
    }
}

final class ConflictStore {

    static let shared = ConflictStore()

    private let url = AppStorage.url("conflicts.json")

    func load() -> [SyncConflict] {
        AppStorage.migrateLegacyFileIfNeeded("conflicts.json")
        guard let data = try? Data(contentsOf: url),
              let conflicts = try? JSONDecoder().decode([SyncConflict].self, from: data)
        else { return [] }
        return conflicts
    }

    func save(_ conflicts: [SyncConflict]) {
        AppStorage.ensureDirectory()
        guard let data = try? JSONEncoder().encode(conflicts) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func reset() {
        try? FileManager.default.removeItem(at: url)
    }
}


/// App 内的同步开关。只存本机，不参与同步。
enum SyncSettings {
    private static let key = "zhitiao.syncEnabled"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// 用户对一条冲突的选择。
enum ConflictResolution {
    /// 本机版本已经在默认策略下传上去了，只需要把冲突从队列里去掉
    case keepLocal
    /// 用其他设备的版本覆盖本机，再上传
    case keepServer
    /// 本机保留，其他设备的版本另存成一张新纸条
    case keepBoth
}
