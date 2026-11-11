import CloudKit

/// CloudKit 的固定配置：容器、区域、记录类型、字段名。
///
/// 记录类型和字段类型一旦部署到生产环境就不能改，只能加新字段，所以集中放在这里，
/// 要改只有这一处。字段名区分大小写，别随手改。
enum CloudKitConfig {

    /// 必须和 `Zhitiao.entitlements` 里的 `com.apple.developer.icloud-container-identifiers` 一致。
    /// 不一致时 `CKContainer(identifier:)` 会直接抛异常，不是返回错误。
    static let containerIdentifier = "iCloud.com.jiangweiku.zhitiao"

    /// 自定义区域。默认区域不支持变更令牌（change token），也没法做共享，所以不用默认区域。
    static let zoneName = "Zhitiao"

    static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName)
    }

    /// 一个纸条一条记录
    static let recordType = "Document"

    /// 记录字段名
    enum Field {
        static let text = "text"
        static let snapshot = "snapshot"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
        static let deviceID = "deviceID"
        static let schemaVersion = "schemaVersion"
    }

    /// 数据版本，写进每条记录，给以后的数据迁移留口子
    static let schemaVersion = 1
}
