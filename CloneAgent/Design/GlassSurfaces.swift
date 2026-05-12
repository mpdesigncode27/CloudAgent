//
//  GlassSurfaces.swift
//  CloneAgent
//
//  Liquid Glass (iOS 26+) with material / solid fallbacks (Reduce Transparency, non-iOS).
//

import SwiftUI

// MARK: - View modifiers

/// Applies card chrome: Liquid Glass when allowed, otherwise material or solid grouped background.
struct AdaptiveGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.thickMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            } else {
                #if os(iOS)
                content.cardChromeLiquidGlass(cornerRadius: cornerRadius)
                #else
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                #endif
            }
        }
    }
}

#if os(iOS)
private extension View {
    @ViewBuilder
    func cardChromeLiquidGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }
}
#endif

extension View {
    /// Card surface per design system (glass / material / solid).
    func adaptiveGlassCard(cornerRadius: CGFloat = DesignTokens.Radius.card) -> some View {
        modifier(AdaptiveGlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Grouped chrome (toolbar / action row)

/// Wraps sibling glass controls so they share one sampling region (HIG: glass cannot sample glass).
struct AdaptiveGlassChrome<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(spacing: CGFloat = DesignTokens.Spacing.md, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        Group {
            if reduceTransparency {
                content
                    .padding(DesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                            .fill(.thickMaterial)
                    )
            } else {
                #if os(iOS)
                if #available(iOS 26, *) {
                    GlassEffectContainer(spacing: spacing) {
                        content
                    }
                } else {
                    content
                        .padding(DesignTokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                                .fill(.regularMaterial)
                        )
                }
                #else
                content
                    .padding(DesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                            .fill(.regularMaterial)
                    )
                #endif
            }
        }
    }
}

// MARK: - Primary actions

extension View {
    /// Primary CTA: glass prominent on iOS 26+, bordered prominent fallback.
    @ViewBuilder
    func adaptivePrimaryButtonStyle() -> some View {
        #if os(iOS)
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
        #else
        self.buttonStyle(.borderedProminent)
        #endif
    }

    /// Secondary CTA.
    @ViewBuilder
    func adaptiveSecondaryButtonStyle() -> some View {
        #if os(iOS)
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
        #else
        self.buttonStyle(.bordered)
        #endif
    }
}
