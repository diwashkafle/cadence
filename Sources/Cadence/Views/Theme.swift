import SwiftUI

extension Category {
    var color: Color {
        switch self {
        case .work:          return Color(red: 0.13, green: 0.77, blue: 0.37) // green
        case .entertainment: return Color(red: 0.96, green: 0.42, blue: 0.27) // orange
        }
    }
    var symbol: String {
        self == .work ? "hammer.fill" : "popcorn.fill"
    }
}
