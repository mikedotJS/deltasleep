import SwiftUI

public extension RGBA {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
