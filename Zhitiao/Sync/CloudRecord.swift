import CloudKit
import Foundation

/// `SyncedDocument` 和 CloudKit 记录之间的转换。
///
/// 一条纸条一条记录，记录名就是纸条的 UUID。字段结构和 `CloudKitConfig.Field` 一一对应。
/// 正文和样式加起来只有几 KB，远低于单条记录 1MB 的上限，不需要 CKAsset。
///
/// 记录的系统字段（`CKRecord.encodeSystemFields`）要单独存一份：变更标签是只读属性，
/// 不能直接写回新建的 `CKRecord`，只能从存档恢复。没有它，每次上传都会被当成新记录，
/// 服务端会认为有冲突。
extension SyncedDocument {

    func makeRecord() -> CKRecord {
        let record: CKRecord
        if let data = recordSystemFields, let restored = Self.record(fromSystemFields: data) {
            record = restored
        } else {
            record = CKRecord(
                recordType: CloudKitConfig.recordType,
                recordID: Self.recordID(for: id)
            )
        }

        record[CloudKitConfig.Field.text] = text
        record[CloudKitConfig.Field.snapshot] = (try? JSONEncoder().encode(snapshot)) ?? Data()
        record[CloudKitConfig.Field.updatedAt] = updatedAt
        record[CloudKitConfig.Field.deviceID] = DeviceIdentity.current
        record[CloudKitConfig.Field.schemaVersion] = Int64(CloudKitConfig.schemaVersion)

        // 复活一条墓碑时要把字段清掉，不能只写 nil
        if let deletedAt {
            record[CloudKitConfig.Field.deletedAt] = deletedAt
        } else {
            record[CloudKitConfig.Field.deletedAt] = nil
        }

        return record
    }

    init?(record: CKRecord) {
        guard let uuid = UUID(uuidString: record.recordID.recordName) else { return nil }

        let text = record[CloudKitConfig.Field.text] as? String ?? ""
        let snapshot: CardSnapshot = {
            guard let data = record[CloudKitConfig.Field.snapshot] as? Data,
                  let decoded = try? JSONDecoder().decode(CardSnapshot.self, from: data)
            else { return CardSnapshot(spec: CardSpec()) }
            return decoded
        }()
        let updatedAt = record[CloudKitConfig.Field.updatedAt] as? Date ?? Date()
        let deletedAt = record[CloudKitConfig.Field.deletedAt] as? Date

        self.init(
            document: Document(id: uuid, text: text, updatedAt: updatedAt, snapshot: snapshot),
            deletedAt: deletedAt,
            changeTag: record.recordChangeTag,
            recordSystemFields: Self.systemFields(of: record),
            // 服务端版本就是下一次合并的基线
            baseline: DocumentBaseline(text: text, snapshot: snapshot),
            isDirty: false
        )
    }

    static func recordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: CloudKitConfig.zoneID)
    }

    static func systemFields(of record: CKRecord) -> Data? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}
