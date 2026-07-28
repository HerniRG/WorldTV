import SwiftUI

enum DesignTokens {
    #if os(tvOS)
    static let sectionSpacing: CGFloat = 48
    static let contentSpacing: CGFloat = 30
    static let cardCornerRadius: CGFloat = 22
    static let cardWidth: CGFloat = 340
    static let logoHeight: CGFloat = 170
    static let pagePadding: CGFloat = 72
    static let countryGridMinimum: CGFloat = 520
    static let channelGridMinimum: CGFloat = 320
    #else
    static let sectionSpacing: CGFloat = 32
    static let contentSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 18
    static let cardWidth: CGFloat = 220
    static let logoHeight: CGFloat = 100
    static let pagePadding: CGFloat = 24
    static let countryGridMinimum: CGFloat = 400
    static let channelGridMinimum: CGFloat = 190
    #endif
}
