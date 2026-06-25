import SwiftUI

struct DisplaySettingsView: View {
    @AppStorage("brightness_enabled") private var isBrightnessEnabled = true
    @AppStorage("brightness_duration") private var brightnessDuration: Double = 2.0

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        Form {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loc.loc(.display_title))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)

            Section {
                Toggle(loc.loc(.display_enable), isOn: $isBrightnessEnabled)
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.loc(.display_duration))
                        Spacer()
                        Text(String(format: "%.1f", brightnessDuration) + loc.loc(.label_s))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $brightnessDuration, in: 1.0...5.0, step: 0.5)
                        .tint(.purple)
                }
                .padding(.vertical, 4)
                .disabled(!isBrightnessEnabled)
            }
        }
        .padding(30)
        .formStyle(.grouped)
    }
}
