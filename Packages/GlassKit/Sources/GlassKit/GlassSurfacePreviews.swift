import SwiftUI

// A preview catalogue placed next to the mockup at the same scale so
// drift is visible (P4's "Done when" bar, docs/IMPLEMENTATION_PLAN.md
// §5). Compiled and type-checked like any other code — verified via CI,
// though actually *looking* at these needs Xcode's canvas or a device,
// neither of which exists in this environment (see issue #1's status
// note on what could and couldn't be verified here).

#Preview("Widget-size surfaces, every tint") {
    ZStack {
        Color.black
        HStack(spacing: 16) {
            ForEach(GlassTint.allCases, id: \.self) { tint in
                GlassSurface(
                    tint: tint, environment: .app, cornerRadius: GlassTokens.cornerRadiusWidget
                )
                .frame(width: 176, height: 176)
            }
        }
        .padding()
    }
}

#Preview("Phone-card-size surface") {
    ZStack {
        Color.black
        GlassSurface(tint: .red, environment: .app, cornerRadius: GlassTokens.cornerRadiusPhone)
            .frame(width: 340, height: 420)
    }
}

#Preview("Widget environment (no self-drawn edge)") {
    ZStack {
        Color.black
        GlassSurface(
            tint: .green, environment: .widget, cornerRadius: GlassTokens.cornerRadiusWidget
        )
        .frame(width: 176, height: 176)
    }
}
