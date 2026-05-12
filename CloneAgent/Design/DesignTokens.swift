//
//  DesignTokens.swift
//  CloneAgent
//
//  Spacing, radii, and layout constants aligned with design-ui.md (8-pt rhythm).
//

import CoreGraphics
import SwiftUI

enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 24
        static let button: CGFloat = 14
    }

    enum Content {
        /// Comfortable reading measure for markdown / summary on large screens.
        static let maxReadableWidth: CGFloat = 560
    }
}

extension View {
    /// Horizontal padding for screen edges (token `Spacing.xl`).
    func screenHorizontalPadding() -> some View {
        padding(.horizontal, DesignTokens.Spacing.xl)
    }

    /// Constrains readable blocks; centers on wider layouts.
    func readableContentWidth() -> some View {
        frame(maxWidth: DesignTokens.Content.maxReadableWidth)
            .frame(maxWidth: .infinity)
    }
}
