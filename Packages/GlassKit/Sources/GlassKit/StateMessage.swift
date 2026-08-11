import SwiftUI

/// The mockup's `.msg`/`.msg small`: the tight-typeface message and
/// dimmer subtitle used by the authorisation-missing and
/// insufficient-history states — no figure, no gauge, just copy.
public struct StateMessage: View {
    private let title: String
    private let subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }
}
