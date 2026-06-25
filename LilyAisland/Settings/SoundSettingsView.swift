import SwiftUI

struct SoundSettingsView: View {
    @AppStorage("volume_enabled") private var isVolumeEnabled = true
    @AppStorage("volume_duration") private var volumeDuration: Double = 2.0

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        Form {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.pink)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loc.loc(.sound_title))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)

            Section {
                Toggle(loc.loc(.sound_enable), isOn: $isVolumeEnabled)
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.loc(.sound_duration))
                        Spacer()
                        Text(String(format: "%.1f", volumeDuration) + loc.loc(.label_s))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $volumeDuration, in: 1.0...5.0, step: 0.5)
                        .tint(.pink)
                }
                .padding(.vertical, 4)
                .disabled(!isVolumeEnabled)
            }
        }
        .padding(30)
        .formStyle(.grouped)
    }
}
