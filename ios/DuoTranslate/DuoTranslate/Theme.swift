import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.953, green: 0.965, blue: 0.980)
    static let navy = Color(red: 0.027, green: 0.231, blue: 0.447)
    static let blue = Color(red: 0.031, green: 0.455, blue: 0.788)
    static let ink = Color(red: 0.063, green: 0.141, blue: 0.235)
    static let muted = Color(red: 0.435, green: 0.502, blue: 0.580)
    static let line = Color(red: 0.875, green: 0.906, blue: 0.941)
    static let green = Color(red: 0.086, green: 0.525, blue: 0.396)
    static let red = Color(red: 0.875, green: 0.161, blue: 0.208)
    static let amber = Color(red: 0.655, green: 0.380, blue: 0.094)
    static let pauseOrange = Color(red: 0.961, green: 0.667, blue: 0.220)
}

private struct AdaptiveGlassModifier<S: Shape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(AppTheme.line.opacity(0.9), lineWidth: 1))
        }
    }
}

extension View {
    func adaptiveGlass<S: Shape>(in shape: S) -> some View {
        modifier(AdaptiveGlassModifier(shape: shape))
    }
}
