/// Where a `GlassSurface` is being rendered — determines whether it draws
/// its own outer edge/shadow, per S1's verdict (issue #1): iOS 26 draws a
/// genuine, live, system-composited Liquid Glass container around widget
/// content, so a `GlassSurface` inside one only needs to fill it, not add
/// a second edge on top. Nothing outside a widget provides that for free.
public enum GlassEnvironment: Hashable, Sendable {
    case widget
    case app
}
