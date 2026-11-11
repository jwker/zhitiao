import SwiftUI

/// 冲突处理页。
///
/// 冲突不是弹 alert，而是列表页顶部提示，点开这里逐条处理。后台产生的冲突不会丢，
/// 也不会一次弹好几个弹窗。
struct ConflictSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sync = SyncEngine.shared

    var body: some View {
        NavigationStack {
            Group {
                if sync.conflicts.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sync.conflicts) { conflict in
                            row(conflict)
                                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("待处理冲突")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ conflict: SyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.document(id: conflict.documentID)?.title ?? "这张纸条")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            if conflict.kind == .deleted {
                Text("这张纸条在其他设备上已经删除，但本机改过。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    version("本机", text: conflict.localText, date: conflict.localUpdatedAt)
                    version("其他设备", text: conflict.serverText, date: conflict.serverUpdatedAt)
                }
            }

            HStack(spacing: 8) {
                action("保留本机") {
                    sync.resolve(conflict, as: .keepLocal)
                }

                if conflict.kind == .deleted {
                    action("接受删除") {
                        sync.resolve(conflict, as: .keepServer)
                    }
                } else {
                    action("保留其他设备") {
                        sync.resolve(conflict, as: .keepServer)
                    }
                    action("两个都留") {
                        sync.resolve(conflict, as: .keepBoth)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func version(_ title: String, text: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            Text(text.isEmpty ? "（空）" : text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Self.timeText(date))
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.wash)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.muted)
            Text("没有待处理的冲突")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
