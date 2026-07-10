import SwiftUI

/// A custom digit-only keypad — watchOS's system text input (Scribble/dictation/
/// tiny keyboard picker) is overkill for a 2-4 digit number, so this just shows
/// the digits themselves.
struct NumericKeypadView: View {
    let title: String
    let allowsDecimal: Bool
    let onDone: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(title: String, initialValue: String, allowsDecimal: Bool = false, onDone: @escaping (String) -> Void) {
        self.title = title
        self.allowsDecimal = allowsDecimal
        self.onDone = onDone
        self._text = State(initialValue: initialValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(text.isEmpty ? "0" : text)
                    .font(.title2.monospacedDigit())

                keypadRow(["1", "2", "3"])
                keypadRow(["4", "5", "6"])
                keypadRow(["7", "8", "9"])
                keypadRow([allowsDecimal ? "." : "", "0", "⌫"])

                Button("Done") {
                    Haptics.tap()
                    onDone(text)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private func keypadRow(_ keys: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                if key.isEmpty {
                    Color.clear.frame(maxWidth: .infinity)
                } else {
                    Button {
                        handle(key)
                    } label: {
                        Text(key)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.tappable)
                }
            }
        }
    }

    private func handle(_ key: String) {
        switch key {
        case "⌫":
            if !text.isEmpty { text.removeLast() }
        case ".":
            guard allowsDecimal, !text.contains(".") else { return }
            text += text.isEmpty ? "0." : "."
        default:
            guard text.count < 5 else { return }
            text += key
        }
    }
}
