import Foundation

/// 纸条 + 同步元数据。
///
/// 界面层拿它当 `Document` 用：`title`、`subtitle`、`makeSpec()` 都转发到里面那张纸条，
/// 所以列表和卡片页不需要关心外面这层。存储层用它记录「删了没、传了没、上次同步时长什么样」。
///
/// 同步引擎还没接进来，`changeTag` 和 `baseline` 目前一直是 nil。
struct SyncedDocument: Identifiable, Codable, Equatable {

    var document: Document

    /// 有值表示已删除（墓碑）。列表里不显示，但记录要留着，否则另一台设备
    /// 拉增量时看不到删除事件，会把本地那条又推回来。
    var deletedAt: Date?

    /// CloudKit 记录的变更标签（change tag）。上传时带上它，服务端才知道本机
    /// 是基于哪个版本改的；别人先改过就会返回冲突。
    var changeTag: String?

    /// 记录的完整系统字段存档。变更标签是只读的，要带着它上传就必须靠这份存档
    /// 恢复出一个 `CKRecord`，否则服务端会把每次上传都当成新记录。
    var recordSystemFields: Data?

    /// 上次成功同步时的正文和样式，冲突时做三方比较用。
    var baseline: DocumentBaseline?

    /// 本机有改动还没上传
    var isDirty: Bool

    init(
        document: Document,
        deletedAt: Date? = nil,
        changeTag: String? = nil,
        recordSystemFields: Data? = nil,
        baseline: DocumentBaseline? = nil,
        isDirty: Bool = true
    ) {
        self.document = document
        self.deletedAt = deletedAt
        self.changeTag = changeTag
        self.recordSystemFields = recordSystemFields
        self.baseline = baseline
        self.isDirty = isDirty
    }

    var id: UUID { document.id }

    var text: String {
        get { document.text }
        set { document.text = newValue }
    }

    var updatedAt: Date {
        get { document.updatedAt }
        set { document.updatedAt = newValue }
    }

    var snapshot: CardSnapshot {
        get { document.snapshot }
        set { document.snapshot = newValue }
    }

    var title: String { document.title }
    var subtitle: String { document.subtitle }
    var isEmpty: Bool { document.isEmpty }

    func makeSpec() -> CardSpec { document.makeSpec() }

    var isDeleted: Bool { deletedAt != nil }
}

/// 上次同步时的内容。冲突检测要三方比较：基线、本机、服务端。
/// 只看 `updatedAt` 会把「A 改正文、B 只改样式」误判成冲突。
struct DocumentBaseline: Codable, Equatable {
    var text: String
    var snapshot: CardSnapshot
}
