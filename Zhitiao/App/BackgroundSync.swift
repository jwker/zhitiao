import BackgroundTasks
import Foundation

/// 后台刷新。
///
/// 系统按自己的节奏唤醒，可能几小时才给一次，所以只能当兜底，不能当主路径。
/// 真正靠得住的是前台同步和静默推送。
enum BackgroundSync {

    static let taskIdentifier = "com.jiangweiku.zhitiao.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // 先把下一次排上，避免这次跑完就断档
        schedule()

        let work = Task { @MainActor in
            await SyncEngine.shared.syncIfNeeded(minInterval: 0)
            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            work.cancel()
        }
    }
}
