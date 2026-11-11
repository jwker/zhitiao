import CloudKit
import Foundation

/// 同步引擎。
///
/// 一轮同步做四件事：查账号 → 确保区域存在 → 上传脏记录 → 拉增量，然后再补传一次
/// （冲突处理后本机版本要推上去）。所有网络调用都在 async 里，主线程只负责应用结果。
///
/// 冲突只在上传时发现，所以提示时机取决于同步什么时候跑：可能在前台，也可能是下次启动。
/// 冲突进持久化队列，不会丢，也不会一次弹好几个弹窗。
@MainActor
final class SyncEngine: ObservableObject {

    static let shared = SyncEngine()

    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var conflicts: [SyncConflict] = []
    @Published private(set) var isSyncing = false

    /// App 内开关。关掉后不联网，本地数据保留。
    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            SyncSettings.isEnabled = isEnabled
            if isEnabled {
                schedule(after: 0.2)
            } else {
                scheduledTask?.cancel()
                status = .disabled
            }
        }
    }

    var conflictCount: Int { conflicts.count }

    private weak var model: AppModel?
    private let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
    private var database: CKDatabase { container.privateCloudDatabase }
    private let cursorStore = SyncCursorStore()
    private let conflictStore = ConflictStore.shared
    private var cursor: SyncCursor
    private var scheduledTask: Task<Void, Never>?
    private var lastAttempt: Date?

    private init() {
        isEnabled = SyncSettings.isEnabled
        cursor = cursorStore.load()
        lastSyncedAt = cursor.lastSyncedAt
        // 上次同步成功过就先显示「已同步」，真正的状态等这一轮同步回来再覆盖
        status = cursor.lastSyncedAt == nil ? .idle : .synced
        conflicts = conflictStore.load()
    }

    func attach(model: AppModel) {
        self.model = model
    }

    // MARK: - 触发

    /// 本地改完 2 秒后同步一次。连续编辑只会跑最后一次。
    func schedule(after seconds: Double = 2) {
        guard isEnabled else { return }
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    /// 前台、推送、后台刷新用。`minInterval` 防止连续触发时重复跑。
    func syncIfNeeded(minInterval: TimeInterval = 5) async {
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < minInterval { return }
        await syncNow()
    }

    /// CloudKit 静默推送：不信任推送内容，统一走一次增量同步
    func handleRemoteNotification() async {
        await syncIfNeeded(minInterval: 0)
    }

    // MARK: - 同步

    func syncNow() async {
        guard isEnabled else {
            status = .disabled
            return
        }
        guard !isSyncing, let model else { return }
        lastAttempt = Date()
        isSyncing = true
        status = .syncing
        defer { isSyncing = false }

        await CloudAccount.shared.refresh()
        guard CloudAccount.shared.state.isAvailable else {
            status = .unavailable(CloudAccount.shared.state.title)
            return
        }

        do {
            try await ensureZone()
            try await ensureSubscription()
            try await uploadDirty(model)
            try await fetchChanges(model)
            // 冲突合并后本机版本还是脏的，再传一次把它推上去
            try await uploadDirty(model)
            try? await purgeOldTombstones(model)

            let now = Date()
            status = .synced
            lastSyncedAt = now
            cursor.lastSyncedAt = now
            cursorStore.save(cursor)
            model.persist(immediately: true)
        } catch {
            status = .failed(CloudErrorText.describe(error))
        }
    }

    /// 清掉游标和冲突（调试用，不动纸条本身）
    func resetLocalState() {
        cursorStore.reset()
        conflictStore.reset()
        cursor = SyncCursor()
        conflicts = []
        status = .idle
        lastSyncedAt = nil
    }

    // MARK: - 区域

    /// 每次同步都确认一次区域在不在。多一个轻量请求，换来区域被服务端删掉时能自动重建。
    private func ensureZone() async throws {
        do {
            _ = try await database.recordZone(for: CloudKitConfig.zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            _ = try await database.save(CKRecordZone(zoneName: CloudKitConfig.zoneName))
        }
    }

    /// 建一次静默推送订阅。数据库级别的订阅覆盖整个私有库，其他设备一改就会推过来。
    private func ensureSubscription() async throws {
        if cursor.subscriptionReady { return }

        let subscription = CKDatabaseSubscription(subscriptionID: "zhitiao-db-changes")
        let info = CKSubscription.NotificationInfo()
        // 只做静默推送：不弹提示、不需要通知权限
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        do {
            _ = try await database.save(subscription)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // 已经存在，忽略
        }

        cursor.subscriptionReady = true
        cursorStore.save(cursor)
    }

    // MARK: - 上传

    private func uploadDirty(_ model: AppModel) async throws {
        let dirty = model.documents.filter { $0.isDirty }
        guard !dirty.isEmpty else { return }

        for chunk in dirty.chunked(into: 400) {
            let records = chunk.map { $0.makeRecord() }
            let result = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )

            var firstError: Error?

            for (recordID, outcome) in result.saveResults {
                guard let uuid = UUID(uuidString: recordID.recordName) else { continue }

                switch outcome {
                case .success(let saved):
                    model.markUploaded(id: uuid, record: saved)

                case .failure(let error):
                    if let ck = error as? CKError,
                       ck.code == .serverRecordChanged,
                       let serverRecord = ck.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                       let serverDocument = SyncedDocument(record: serverRecord) {
                        applyServer(serverDocument, model: model)
                    } else {
                        firstError = firstError ?? error
                    }
                }
            }

            if let firstError {
                throw firstError
            }
        }
    }

    // MARK: - 拉增量

    private func fetchChanges(_ model: AppModel) async throws {
        var token = cursor.changeToken.flatMap(decodeToken)
        var more = true
        var rounds = 0

        while more && rounds < 50 {
            rounds += 1

            let result: (
                modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                deletions: [CKDatabase.RecordZoneChange.Deletion],
                changeToken: CKServerChangeToken,
                moreComing: Bool
            )

            do {
                result = try await database.recordZoneChanges(
                    inZoneWith: CloudKitConfig.zoneID,
                    since: token
                )
            } catch let error as CKError where error.code == .changeTokenExpired {
                // 游标过期：从头拉一次
                token = nil
                cursor.changeToken = nil
                cursorStore.save(cursor)
                continue
            }

            for (_, outcome) in result.modificationResultsByID {
                guard case .success(let modification) = outcome,
                      let serverDocument = SyncedDocument(record: modification.record)
                else { continue }
                applyServer(serverDocument, model: model)
            }

            for deletion in result.deletions {
                guard let uuid = UUID(uuidString: deletion.recordID.recordName) else { continue }
                applyDeletion(id: uuid, model: model)
            }

            token = result.changeToken
            more = result.moreComing
        }

        cursor.changeToken = encodeToken(token)
        cursorStore.save(cursor)
    }

    // MARK: - 应用服务端结果

    private func applyServer(_ server: SyncedDocument, model: AppModel) {
        guard let local = model.document(id: server.id) else {
            // 本机没有：另一台设备新建的，或者这是重装后的首次拉取
            model.insert(server)
            return
        }

        if !local.isDirty {
            model.replace(server)
            return
        }

        // 别处删了、本机还在改：进冲突队列，默认保留本机（复活）
        if server.isDeleted {
            enqueueConflict(
                SyncConflict(
                    documentID: local.id,
                    kind: .deleted,
                    baseText: local.baseline?.text,
                    localText: local.text,
                    serverText: "",
                    localUpdatedAt: local.updatedAt,
                    serverUpdatedAt: server.updatedAt,
                    serverSnapshot: server.snapshot,
                    serverChangeTag: server.changeTag,
                    serverSystemFields: server.recordSystemFields
                )
            )
            var revived = local
            revived.changeTag = server.changeTag
            revived.recordSystemFields = server.recordSystemFields
            revived.isDirty = true
            model.replace(revived)
            return
        }

        let result = Merge.merge(local: local, server: server)
        model.replace(result.document)
        if let conflict = result.conflict {
            enqueueConflict(conflict)
        }
    }

    private func applyDeletion(id: UUID, model: AppModel) {
        guard let local = model.document(id: id) else { return }

        if local.isDirty {
            // 服务端记录被物理删了，本机还改过：保留本机，下次上传会重新建
            var revived = local
            revived.changeTag = nil
            revived.recordSystemFields = nil
            revived.isDirty = true
            model.replace(revived)
        } else {
            model.removeDocument(id: id)
        }
    }

    private func enqueueConflict(_ conflict: SyncConflict) {
        // 同一条纸条只留最新的冲突，避免队列越积越多
        conflicts.removeAll { $0.documentID == conflict.documentID }
        conflicts.append(conflict)
        conflictStore.save(conflicts)
    }

    // MARK: - 墓碑清理

    /// 墓碑留 30 天，够其他设备拉到删除事件。之后连服务端记录一起删掉，
    /// 否则重装的设备会把这些已删除的纸条再拉回来。
    private func purgeOldTombstones(_ model: AppModel) async throws {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let expired = model.documents.filter {
            $0.isDeleted && !$0.isDirty && ($0.deletedAt ?? .distantPast) < cutoff
        }
        guard !expired.isEmpty else { return }

        for chunk in expired.chunked(into: 400) {
            let ids = chunk.map { SyncedDocument.recordID(for: $0.id) }
            let result = try await database.modifyRecords(
                saving: [],
                deleting: ids,
                atomically: false
            )
            for (recordID, outcome) in result.deleteResults {
                // 服务端已经没有这条了也算删成功
                let removed: Bool
                switch outcome {
                case .success:
                    removed = true
                case .failure(let error):
                    removed = (error as? CKError)?.code == .unknownItem
                }
                if removed, let uuid = UUID(uuidString: recordID.recordName) {
                    model.removeDocument(id: uuid)
                }
            }
        }
    }

    // MARK: - 冲突处理

    /// 用户对一条冲突做出选择。处理完从队列移除，并安排一次同步把结果推上去。
    func resolve(_ conflict: SyncConflict, as resolution: ConflictResolution) {
        guard let model else { return }

        switch (conflict.kind, resolution) {
        case (.text, .keepLocal), (.deleted, .keepLocal):
            // 默认策略已经把本机版本传上去了，什么都不用改
            finish(conflict, model: model)

        case (.text, .keepServer):
            // 冲突里的服务端版本是快照，之后可能又被默认策略覆盖过。
            // 直接上传会再撞一次冲突，所以先取服务端最新记录，把用户选的版本写上去。
            Task {
                await applyServerVersion(conflict)
                finish(conflict, model: model)
            }

        case (.text, .keepBoth):
            // 其他设备的版本另存成一张新纸条，原来的本机版本不动
            let copy = SyncedDocument(
                document: Document(
                    text: conflict.serverText,
                    updatedAt: Date(),
                    snapshot: conflict.serverSnapshot
                ),
                deletedAt: nil,
                changeTag: nil,
                recordSystemFields: nil,
                baseline: nil,
                isDirty: true
            )
            model.insert(copy)
            finish(conflict, model: model)

        case (.deleted, .keepServer):
            guard var local = model.document(id: conflict.documentID) else {
                finish(conflict, model: model)
                return
            }
            local.deletedAt = Date()
            local.isDirty = true
            model.replace(local)
            finish(conflict, model: model)

        case (.deleted, .keepBoth):
            // 删除冲突没有「两个都留」
            finish(conflict, model: model)
        }
    }

    private func finish(_ conflict: SyncConflict, model: AppModel) {
        conflicts.removeAll { $0.id == conflict.id }
        conflictStore.save(conflicts)
        model.persist(immediately: true)
        schedule(after: 0.5)
    }

    /// 把冲突里的服务端版本写回服务端，并同步本地。
    /// 服务端记录已经不存在时，退回「本机改成用户选的版本再上传」。
    private func applyServerVersion(_ conflict: SyncConflict) async {
        guard let model else { return }
        let recordID = SyncedDocument.recordID(for: conflict.documentID)

        do {
            let record = try await database.record(for: recordID)
            record[CloudKitConfig.Field.text] = conflict.serverText
            record[CloudKitConfig.Field.snapshot] = try JSONEncoder().encode(conflict.serverSnapshot)
            record[CloudKitConfig.Field.updatedAt] = Date()
            record[CloudKitConfig.Field.deletedAt] = nil
            let saved = try await database.save(record)

            guard var local = model.document(id: conflict.documentID) else { return }
            local.text = conflict.serverText
            local.snapshot = conflict.serverSnapshot
            local.updatedAt = saved[CloudKitConfig.Field.updatedAt] as? Date ?? Date()
            local.deletedAt = nil
            local.changeTag = saved.recordChangeTag
            local.recordSystemFields = SyncedDocument.systemFields(of: saved)
            local.baseline = DocumentBaseline(text: conflict.serverText, snapshot: conflict.serverSnapshot)
            local.isDirty = false
            model.replace(local)
        } catch let error as CKError where error.code == .unknownItem {
            guard var local = model.document(id: conflict.documentID) else { return }
            local.text = conflict.serverText
            local.snapshot = conflict.serverSnapshot
            local.updatedAt = Date()
            local.changeTag = nil
            local.recordSystemFields = nil
            local.baseline = nil
            local.isDirty = true
            model.replace(local)
        } catch {
            status = .failed(CloudErrorText.describe(error))
        }
    }

    #if DEBUG
    /// 调试用：制造一次真实冲突。
    ///
    /// 先把服务端那条改成「服务端改动」，再让本机用旧变更标签上传「本机改动」。
    /// 服务端会返回冲突，走三方比较进队列。没有第二台设备时用它验证整条链路。
    func simulateConflict() async {
        guard let model,
              let document = model.documents.first(where: { !$0.isDeleted && $0.changeTag != nil }),
              let systemFields = document.recordSystemFields,
              let record = SyncedDocument.record(fromSystemFields: systemFields)
        else {
            status = .failed("没有可用的已同步纸条")
            return
        }

        let stamp = Int(Date().timeIntervalSince1970)
        record[CloudKitConfig.Field.text] = "服务端改动 \(stamp)"
        record[CloudKitConfig.Field.updatedAt] = Date()

        do {
            _ = try await database.save(record)
        } catch {
            status = .failed("写服务端失败：\(CloudErrorText.describe(error))")
            return
        }

        var local = document
        local.text = "本机改动 \(stamp)"
        local.updatedAt = Date()
        local.isDirty = true
        model.replace(local)
        model.persist(immediately: true)

        await syncNow()
    }
    /// 调试用：制造一次删除冲突。
    /// 服务端那条打成墓碑，本机还在改，同步时会走「别处删了、本机改过」的分支。
    func simulateDeleteConflict() async {
        guard let model,
              let document = model.documents.first(where: { !$0.isDeleted && $0.changeTag != nil }),
              let systemFields = document.recordSystemFields,
              let record = SyncedDocument.record(fromSystemFields: systemFields)
        else {
            status = .failed("没有可用的已同步纸条")
            return
        }

        record[CloudKitConfig.Field.deletedAt] = Date()
        record[CloudKitConfig.Field.updatedAt] = Date()

        do {
            _ = try await database.save(record)
        } catch {
            status = .failed("写服务端失败：\(CloudErrorText.describe(error))")
            return
        }

        var local = document
        local.text = "本机改动 \(Int(Date().timeIntervalSince1970))"
        local.updatedAt = Date()
        local.isDirty = true
        model.replace(local)
        model.persist(immediately: true)

        await syncNow()
    }
    #endif

    // MARK: - 游标编解码

    private func encodeToken(_ token: CKServerChangeToken?) -> Data? {
        guard let token else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func decodeToken(_ data: Data) -> CKServerChangeToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
