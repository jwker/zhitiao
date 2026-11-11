import CloudKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 本机标识。
///
/// 只用来在冲突提示里说明「这条改动来自哪台设备」，不是身份凭证，也不参与同步判断。
/// 存在本机 `UserDefaults`，不跟着纸条走。
enum DeviceIdentity {

    private static let key = "zhitiao.deviceID"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// 给人看的设备名。同一个 Apple ID 下可能有两台同名设备，所以只能当参考。
    static var displayName: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "Mac"
        #endif
    }
}
