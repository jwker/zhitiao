import CloudKit
import Foundation

/// 阶段 0 的自检：确认容器能读能写，并让 CloudKit 在开发环境自动建出 `Document` 记录类型。
///
/// 正式同步引擎在阶段 2 接进来。这里按「账号 → 用户记录 → 列区域 → 写空记录 → 写纸条记录
/// → 建自定义区域」逐级验证，哪一步断了就停在哪一步，并把原始错误打出来。
/// CloudKit 的「请求被拒绝」经常不带说明，真正的线索在 userInfo 里。
///
/// 开发环境允许自动建字段，生产环境不允许，所以这个自检只用于开发。
enum CloudProbe {

    static func run() async -> String {
        let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        let database = container.privateCloudDatabase
        var report: [String] = []

        // 1. 账号
        do {
            let account = CloudAccountState(try await container.accountStatus())
            report.append("账号：\(account.title)")
            guard account.isAvailable else { return report.joined(separator: "\n") }
        } catch {
            return fail(&report, step: "账号查询", error: error)
        }

        // 2. 用户记录：不碰数据库，只验证容器本身可用
        do {
            let id = try await container.userRecordID()
            report.append("容器：可用（\(id.recordName.prefix(8))…）")
        } catch {
            return fail(&report, step: "用户记录", error: error)
        }

        // 3. 列区域：只读
        report.append("iCloud 云盘：\(FileManager.default.ubiquityIdentityToken == nil ? "不可用" : "可用")")
        do {
            let zones = try await database.allRecordZones()
            report.append("区域列表：\(zones.count) 个")
        } catch {
            report.append("列区域：失败，\(CloudErrorText.describe(error))")
            report.append(CloudErrorText.debug(error))
            // 私有库失败时再看公开库：公开库不依赖用户账号，能区分「容器坏了」和「这个账号的私有库坏了」。
            // 只用只读请求，避免往 schema 里留下探针记录类型。
            do {
                let publicDB = container.publicCloudDatabase
                _ = try await publicDB.record(for: CKRecord.ID(recordName: "does-not-exist"))
                report.append("公开库：意外成功")
            } catch let error as CKError where error.code == .unknownItem {
                report.append("公开库：可访问（说明容器可用，问题在私有库或账号）")
            } catch {
                report.append("公开库：也失败，\(CloudErrorText.describe(error))")
                report.append(CloudErrorText.debug(error))
            }

            // 单条记录读取：确认是不是只有「列区域」这一个接口坏
            do {
                _ = try await database.record(for: CKRecord.ID(recordName: "does-not-exist"))
                report.append("单条读取：意外成功")
            } catch let error as CKError where error.code == .unknownItem {
                report.append("单条读取：正常（返回记录不存在）")
            } catch {
                report.append("单条读取：失败，\(CloudErrorText.describe(error))")
            }

            return report.joined(separator: "\n")
        }

        // 4. 写一条不带字段的空记录：把「容器/schema」和「字段」两类问题分开
        do {
            let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: CKRecord.ID(recordName: "probe-\(UUID().uuidString)"))
            let saved = try await database.save(record)
            try await database.deleteRecord(withID: saved.recordID)
            report.append("空记录：读写正常")
        } catch {
            return fail(&report, step: "空记录", error: error)
        }

        // 5. 用真实的 Document 结构写一条：开发环境会顺带把字段建出来
        do {
            let record = CKRecord(
                recordType: CloudKitConfig.recordType,
                recordID: CKRecord.ID(recordName: "probe-\(UUID().uuidString)")
            )
            fill(record)
            let saved = try await database.save(record)
            try await database.deleteRecord(withID: saved.recordID)
            report.append("Document 记录：读写正常")
        } catch {
            return fail(&report, step: "Document 记录", error: error)
        }

        // 6. 自定义区域：正式同步用它，因为默认区域不支持变更令牌
        do {
            _ = try await database.recordZone(for: CloudKitConfig.zoneID)
            report.append("自定义区域：已存在")
        } catch let error as CKError where error.code == .zoneNotFound {
            do {
                _ = try await database.save(CKRecordZone(zoneName: CloudKitConfig.zoneName))
                report.append("自定义区域：已创建")
            } catch {
                return fail(&report, step: "创建自定义区域", error: error)
            }
        } catch {
            return fail(&report, step: "查询自定义区域", error: error)
        }

        return report.joined(separator: "\n")
    }

    /// 探针记录用真实的字段结构，这样开发环境会顺带把 `Document` 的字段建出来。
    private static func fill(_ record: CKRecord) {
        record[CloudKitConfig.Field.text] = "probe"
        record[CloudKitConfig.Field.snapshot] = Data()
        record[CloudKitConfig.Field.updatedAt] = Date()
        record[CloudKitConfig.Field.deviceID] = DeviceIdentity.current
        record[CloudKitConfig.Field.schemaVersion] = Int64(CloudKitConfig.schemaVersion)
    }

    private static func fail(_ report: inout [String], step: String, error: Error) -> String {
        report.append("\(step)：失败，\(CloudErrorText.describe(error))")
        report.append(CloudErrorText.debug(error))
        return report.joined(separator: "\n")
    }
}
