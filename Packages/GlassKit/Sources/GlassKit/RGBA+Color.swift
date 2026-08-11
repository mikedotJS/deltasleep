import SwiftUI

extension RGBA {
    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
