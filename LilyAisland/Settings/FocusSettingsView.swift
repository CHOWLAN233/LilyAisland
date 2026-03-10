import SwiftUI

struct FocusSettingsView: View {
    @AppStorage("focus_enabled") private var isFocusEnabled = true
    @AppStorage("focus_duration") private var focusDuration: Double = 2.0
    // 🌟 1. 新增：声音提示开关
    @AppStorage("focus_play_sound") private var playSound = false
    @AppStorage("focus_hide_label") private var hideLabel = false
    
    var body: some View {
        Form {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Focus")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)
            
            Section {
                Toggle("Focus", isOn: $isFocusEnabled)
                    .toggleStyle(.switch)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(String(format: "%.1f s", focusDuration))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $focusDuration, in: 1.0...10.0, step: 0.5)
                        .tint(.indigo)
                }
                .padding(.vertical, 4)
                
                // 🌟 2. 还原竞品 UI：睡眠/勿扰时播放提示音
                HStack {
                    Text("Play sound on sleep focus")
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.gray)
                        .onTapGesture {
                            // 点击播放图标可以试听声音
                            NSSound(named: "Glass")?.play()
                        }
                    Spacer()
                    Toggle("", isOn: $playSound)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                Toggle("Hide label", isOn: $hideLabel)
                    .toggleStyle(.switch)
            }
        }
        .padding(30)
        .formStyle(.grouped)
    }
}
