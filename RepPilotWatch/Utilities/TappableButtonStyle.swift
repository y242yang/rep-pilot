import SwiftUI

/// Plain-style buttons render no press feedback at all on watchOS, which reads as
/// "did that tap even register?" — this dims/shrinks the label on press and fires
/// a haptic click, similar to the bubble feedback on the iPhone keyboard.
struct TappableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.4 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == TappableButtonStyle {
    static var tappable: TappableButtonStyle { TappableButtonStyle() }
}
