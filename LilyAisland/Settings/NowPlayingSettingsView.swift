import SwiftUI

struct NowPlayingSettingsView: View {
    @AppStorage("nowplaying_enabled") private var isNowPlayingEnabled = true
    @AppStorage("nowplaying_show_artwork") private var showArtwork = true
    @AppStorage("nowplaying_show_progress") private var showProgress = true
    @AppStorage("nowplaying_polling_interval") private var pollingInterval: Double = 1.0

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        Form {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loc.loc(.nowplaying_title))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)

            Section {
                Toggle(loc.loc(.nowplaying_enable), isOn: $isNowPlayingEnabled)
                    .toggleStyle(.switch)

                Toggle(loc.loc(.nowplaying_show_artwork), isOn: $showArtwork)
                    .toggleStyle(.switch)
                    .disabled(!isNowPlayingEnabled)

                Toggle(loc.loc(.nowplaying_show_progress), isOn: $showProgress)
                    .toggleStyle(.switch)
                    .disabled(!isNowPlayingEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.loc(.nowplaying_polling_interval))
                        Spacer()
                        Text(String(format: "%.1f", pollingInterval) + loc.loc(.label_s))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $pollingInterval, in: 0.5...5.0, step: 0.5)
                        .tint(.red)
                }
                .padding(.vertical, 4)
                .disabled(!isNowPlayingEnabled)
            }
        }
        .padding(30)
        .formStyle(.grouped)
    }
}
