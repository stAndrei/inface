import InfaceCore
import SwiftUI

enum InfaceTheme {
    static let background = Color(red: 0.10, green: 0.12, blue: 0.14)
    static let backgroundSecondary = Color(red: 0.14, green: 0.17, blue: 0.20)
    static let accent = Color(red: 0.91, green: 0.66, blue: 0.22)
    static let textPrimary = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let textSecondary = Color(red: 0.70, green: 0.72, blue: 0.74)
    static let danger = Color(red: 0.86, green: 0.35, blue: 0.30)
    static let alertGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.10, blue: 0.12),
            Color(red: 0.05, green: 0.18, blue: 0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
