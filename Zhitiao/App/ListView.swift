import SwiftUI

/// 首页：纸条列表。点一行进卡片页，右上角 ＋ 新建。
struct ListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.sortedDocuments.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(model.sortedDocuments) { document in
                        Button {
                            model.open(document)
                        } label: {
                            row(document)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
            }
        }
        .background(Theme.surface)
    }

    private func row(_ document: Document) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                if !document.subtitle.isEmpty {
                    Text(document.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(RelativeDate.label(document.updatedAt))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
                .padding(.leading, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Theme.line.opacity(2.4), lineWidth: 1.5)
                .frame(width: 56, height: 72)
                .overlay {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Theme.line.opacity(2.4))
                                .frame(width: 28, height: 1.5)
                        }
                    }
                }
                .padding(.bottom, 8)

            Text("还没有纸条")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.ink)

            Text("写一段话，它会被排成一张能发出去的图片。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
