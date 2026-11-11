import CloudKit
import Foundation

/// iCloud 账号状态。同步能不能跑只看这一个状态，不看网络。
enum CloudAccountState: Equatable {
    case unknown
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case failed(String)

    init(_ status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }

    var isAvailable: Bool { self == .available }

    /// 设置页第一行显示的状态
    var title: String {
        switch self {
        case .unknown: return "正在检查…"
        case .available: return "已登录"
        case .noAccount: return "未登录"
        case .restricted: return "受限"
        case .temporarilyUnavailable: return "暂时不可用"
        case .failed: return "检查失败"
        }
    }

    /// 状态说明，没有额外信息时返回 nil
    var detail: String? {
        switch self {
        case .unknown, .available:
            return nil
        case .noAccount:
            return "在系统设置里登录 iCloud，或打开「使用 iCloud 的 App」里的纸条儿。"
        case .restricted:
            return "设备限制了 iCloud 访问，可能是家长控制或设备管理。"
        case .temporarilyUnavailable:
            return "iCloud 暂时不可用，稍后会自动重试。"
        case .failed(let message):
            return message
        }
    }
}

/// 账号状态检查。
///
/// 这是同步功能唯一允许在启动时碰 CloudKit 的地方，而且只读状态、不碰数据库，
/// 不会像以前那样把启动卡住。账号变化（登录、退出、关开关）时系统会发通知，自动重查。
@MainActor
final class CloudAccount: ObservableObject {

    static let shared = CloudAccount()

    @Published private(set) var state: CloudAccountState = .unknown
    @Published private(set) var lastChecked: Date?
    @Published private(set) var isChecking = false

    private let container: CKContainer
    private var observer: NSObjectProtocol?

    private init() {
        container = CKContainer(identifier: CloudKitConfig.containerIdentifier)

        observer = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await CloudAccount.shared.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refresh() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            state = CloudAccountState(try await container.accountStatus())
        } catch {
            state = .failed(CloudErrorText.describe(error))
        }
        lastChecked = Date()
    }
}
