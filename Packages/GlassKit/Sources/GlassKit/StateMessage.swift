import SwiftUI

/// The mockup's `.msg`/`.msg small`: the tight-typeface message and
/// dimmer subtitle used by the authorisation-missing and
/// insufficient-history states — no figure, no gauge, just copy.
public struct StateMessage: View {
    // FR + EN strings (P9, D9): `LocalizedStringKey` rather than plain
    // `String`, so a literal passed in at the call site (every call site
    // today) round-trips through the string catalog the same way a bare
    // `Text("...")` would — a plain `String` here would display verbatim
    // in whatever language it was written in, catalog or not.
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?

    // Dynamic Type (P9) — see `DebtFigure`'s doc comment on the same
    // mechanism; these are the only body copy in the two message-only
    // states (no-access, insufficient-history), so they carry the same
    // scaling obligation as the figure does elsewhere.
    @ScaledMetric private var titleSize: CGFloat = 16.5
    @ScaledMetric private var subtitleSize: CGFloat = 11.5

    public init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: subtitleSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }
}
