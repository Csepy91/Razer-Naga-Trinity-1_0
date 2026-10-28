import SwiftUI

struct NoticeBarView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        if let notice = store.notice {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon(for: notice.tone))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(toneForeground(notice.tone))
                    .frame(width: 16, alignment: .center)
                    .padding(.top, 1)

                Text(label(for: notice))
                    .font(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.text0)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    store.dismissNotice()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("notice.dismiss"))
            }
            .padding(.leading, 15)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .fill(Theme.surfaceStrong)
                    .overlay(alignment: .leading) {
                        // Accent strip — drawn inside the background so it
                        // matches content height and never expands the bar.
                        Rectangle()
                            .fill(toneForeground(notice.tone))
                            .frame(width: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 4)
            // Intrinsic height only — never share leftover VStack space.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .top)
            .accessibilityElement(children: .combine)
        }
    }

    private func label(for notice: Notice) -> String {
        if let key = notice.key, l10n.exists(key) {
            return l10n.t(key, params: notice.params)
        }
        if notice.message.contains("Razer Naga Trinity not found") {
            return l10n.t("driverNotices.notFound")
        }
        return notice.message
    }

    private func icon(for tone: NoticeTone) -> String {
        switch tone {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func toneForeground(_ tone: NoticeTone) -> Color {
        switch tone {
        case .success: return Theme.accent
        case .error: return Theme.danger
        case .info: return Theme.info
        }
    }
}
