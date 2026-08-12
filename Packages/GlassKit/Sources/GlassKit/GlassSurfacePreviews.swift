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

// Regression canary. Every preview above hard-codes `.frame(width:height:)`,
// which is exactly why none of them ever revealed that `GlassSurface` has no
// intrinsic size: in a vertical `ScrollView` it collapsed to ~10pt and the
// app's card shipped as a thin bar drawn across its own text. This one
// deliberately supplies no frame and composes the surface the way
// `MainScreenView` now does — content first, surface as its `.background`.
// If the card here ever stops wrapping the rows, the app screen is broken too.
//
// Worth being honest about what this buys: CI compiles `#Preview` bodies but
// never renders them, so this is a canary for a human in Xcode's canvas, not
// a test that can fail a build.
#Preview("Unframed in a ScrollView — content sizes the card") {
    ZStack {
        Color.black
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0 ..< 14, id: \.self) { index in
                    Text("Ligne \(index) — la carte doit envelopper ce contenu")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GlassTokens.phonePaddingHorizontal)
            .padding(.vertical, GlassTokens.phonePaddingVertical)
            .background {
                GlassSurface(
                    tint: .red, environment: .app, cornerRadius: GlassTokens.cornerRadiusPhone
                )
            }
            .padding(24)
        }
    }
}
