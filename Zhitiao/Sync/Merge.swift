import Foundation

/// 三方合并的结果。
struct MergeResult {
    /// 合并后的本机记录。`isDirty` 为 true 时还需要再传一次。
    var document: SyncedDocument
    /// 正文两边都改了，需要用户选
    var conflict: SyncConflict?
}

/// 三方比较：基线（上次同步时的内容）、本机、服务端。
///
/// 只看 `updatedAt` 会把「A 改正文、B 只改样式」误判成冲突，所以正文和样式分开比。
/// 样式冲突不弹窗，直接取较新的；正文冲突才进队列。
enum Merge {

    static func merge(local: SyncedDocument, server: SyncedDocument) -> MergeResult {
        let base = local.baseline

        let localTextChanged = base.map { local.text != $0.text } ?? true
        let serverTextChanged = base.map { server.text != $0.text } ?? true

        var text = server.text
        var needsUpload = false
        var conflict: SyncConflict?

        if local.text == server.text {
            text = server.text
        } else if base != nil {
            if !localTextChanged {
                // 本机没动正文，服务端动过
                text = server.text
            } else if !serverTextChanged {
                // 只有本机动过
                text = local.text
                needsUpload = true
            } else {
                // 两边都动了，内容还不一样
                text = local.text
                needsUpload = true
                conflict = makeConflict(local: local, server: server, kind: .text)
            }
        } else {
            // 没有基线（从没成功同步过），又和服务端不一致，只能让用户判断
            text = local.text
            needsUpload = true
            conflict = makeConflict(local: local, server: server, kind: .text)
        }

        let snapshot: CardSnapshot
        if local.snapshot == server.snapshot {
            snapshot = server.snapshot
        } else if let base {
            if local.snapshot == base.snapshot {
                snapshot = server.snapshot
            } else if server.snapshot == base.snapshot {
                snapshot = local.snapshot
                needsUpload = true
            } else {
                // 样式两边都改了：取较新的，不打扰用户
                snapshot = local.updatedAt > server.updatedAt ? local.snapshot : server.snapshot
                needsUpload = true
            }
        } else {
            snapshot = local.updatedAt > server.updatedAt ? local.snapshot : server.snapshot
            needsUpload = true
        }

        let merged = SyncedDocument(
            document: Document(
                id: local.id,
                text: text,
                updatedAt: max(local.updatedAt, server.updatedAt),
                snapshot: snapshot
            ),
            deletedAt: nil,
            changeTag: server.changeTag,
            recordSystemFields: server.recordSystemFields,
            // 服务端版本成为新的基线
            baseline: DocumentBaseline(text: server.text, snapshot: server.snapshot),
            isDirty: needsUpload
        )

        return MergeResult(document: merged, conflict: conflict)
    }

    private static func makeConflict(
        local: SyncedDocument,
        server: SyncedDocument,
        kind: SyncConflict.Kind
    ) -> SyncConflict {
        SyncConflict(
            documentID: local.id,
            kind: kind,
            baseText: local.baseline?.text,
            localText: local.text,
            serverText: server.text,
            localUpdatedAt: local.updatedAt,
            serverUpdatedAt: server.updatedAt,
            serverSnapshot: server.snapshot,
            serverChangeTag: server.changeTag,
            serverSystemFields: server.recordSystemFields
        )
    }
}
