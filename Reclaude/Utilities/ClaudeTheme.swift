import SwiftUI

/// Claude's brand color palette — warm gradient from peach to lavender.
enum ClaudeTheme {
    // MARK: - Brand Colors

    /// Primary peach — Claude message bubbles, sparkle icon, main accent
    static let peach = Color(red: 244/255, green: 194/255, blue: 142/255)       // #f4c28e

    /// Light peach — tool call pills, secondary accents
    static let lightPeach = Color(red: 244/255, green: 199/255, blue: 168/255)  // #f4c7a8

    /// Blush — code block backgrounds, subtle fills
    static let blush = Color(red: 244/255, green: 204/255, blue: 194/255)       // #f4ccc2

    /// Pink — hover states, tertiary accents
    static let pink = Color(red: 244/255, green: 209/255, blue: 220/255)        // #f4d1dc

    /// Lavender — user message bubbles
    static let lavender = Color(red: 244/255, green: 214/255, blue: 246/255)    // #f4d6f6

    // MARK: - Semantic Aliases

    /// Claude assistant message background
    static let claudeBubble = peach

    /// User message background
    static let userBubble = lavender

    /// Tool call pill background
    static let toolPill = lightPeach

    /// Code block background
    static let codeBlock = blush

    /// Sparkle icon / "Claude" label color
    static let sparkle = peach

    /// Subtle accent for sidebar highlights
    static let sidebarAccent = pink
}
