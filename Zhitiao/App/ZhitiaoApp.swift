import SwiftUI

@main
struct ZhitiaoApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .tint(Theme.accent)
        }
    }
}

/// 设计系统的颜色：界面 90% 中性，一个强调色。
enum Theme {
    static let bg = Color(hex: "#FBFAF7")
    static let surface = Color(hex: "#FFFFFF")
    static let ink = Color(hex: "#16130F")
    static let muted = Color(hex: "#6E6A63")
    static let accent = Color(hex: "#C2410C")
    static let line = Color(hex: "#16130F").opacity(0.12)
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(
            .sRGB,
            red: Double((number & 0xFF0000) >> 16) / 255,
            green: Double((number & 0x00FF00) >> 8) / 255,
            blue: Double(number & 0x0000FF) / 255,
            opacity: 1
        )
    }
}
