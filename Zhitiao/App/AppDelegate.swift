import CloudKit
import UIKit

/// 接收 CloudKit 的静默推送，并把后台刷新任务接进来。
///
/// 静默推送不需要用户授权，也不会弹任何提示；收到后只做一次增量同步。
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 静默推送不弹权限框，但必须先注册才能拿到 token
        application.registerForRemoteNotifications()
        BackgroundSync.register()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await SyncEngine.shared.handleRemoteNotification()
            completionHandler(.newData)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit 自己管理 token，这里不需要转发
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // 模拟器没有推送能力，失败是正常的
    }
}
