import SwiftUI
import AppKit

// 🌟 完美复刻：加大加粗的饱满闪电版
struct MacNativeBatteryIcon: View {
    var level: Int
    var isCharging: Bool
    
    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                // 1. 电池外壳
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color.gray, lineWidth: 1.5)
                    .frame(width: 25, height: 12)
                
                // 2. 真实电量填充
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white)
                    .frame(width: max(0, 21 * CGFloat(level) / 100.0), height: 8)
                    .padding(.leading, 2)
                
                // 3. 原生大闪电图标
                if isCharging {
                    ZStack {
                        // 加大偏移量，适配更粗的闪电，形成完美的纯黑镂空描边
                        Image(systemName: "bolt.fill").foregroundColor(.black).offset(x: -1.2, y: 0)
                        Image(systemName: "bolt.fill").foregroundColor(.black).offset(x: 1.2, y: 0)
                        Image(systemName: "bolt.fill").foregroundColor(.black).offset(x: 0, y: -1.2)
                        Image(systemName: "bolt.fill").foregroundColor(.black).offset(x: 0, y: 1.2)
                        
                        // 核心的白色闪电
                        Image(systemName: "bolt.fill").foregroundColor(.white)
                    }
                    // 🌟 核心调整：尺寸放大到 11.5，字重改为最粗壮的 .black
                    .font(.system(size: 11.5, weight: .black))
                    .frame(width: 25, height: 12, alignment: .center)
                }
            }
            
            // 4. 电池正极突起
            Path { path in
                path.addRoundedRect(
                    in: CGRect(x: 0, y: 0, width: 2, height: 4),
                    cornerSize: CGSize(width: 1, height: 1)
                )
            }
            .fill(Color.gray)
            .frame(width: 2, height: 4)
        }
    }
}

struct AudioEqualizerView: View {
    var isPlaying: Bool
    var mode: IslandMode
    
    var body: some View {
        HStack(spacing: 3) {
            EqualizerBar(isPlaying: isPlaying, mode: mode, animationSpeed: 0.4)
            EqualizerBar(isPlaying: isPlaying, mode: mode, animationSpeed: 0.3)
            EqualizerBar(isPlaying: isPlaying, mode: mode, animationSpeed: 0.5)
            EqualizerBar(isPlaying: isPlaying, mode: mode, animationSpeed: 0.35)
        }
    }
}

struct EqualizerBar: View {
    var isPlaying: Bool
    var mode: IslandMode
    var animationSpeed: Double
    @State private var isAnimating = false
    
    var body: some View {
        Capsule()
            .fill(isPlaying ? Color.purple : Color.gray.opacity(0.5))
            .frame(width: 3, height: isPlaying && isAnimating ? 16 : 4)
            .animation(isPlaying ? Animation.easeInOut(duration: animationSpeed).repeatForever(autoreverses: true) : .spring(), value: isAnimating)
            .onAppear { if isPlaying { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAnimating = true } } }
            .onChange(of: isPlaying) { newValue in
                isAnimating = false; if newValue { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAnimating = true } }
            }
            .onChange(of: mode) { _ in
                if isPlaying { isAnimating = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAnimating = true } }
            }
    }
}

struct ContentView: View {
    @ObservedObject var state: IslandState
    
    @AppStorage("enable_haptics") private var enableHaptics = true
    @AppStorage("island_x_offset") private var islandXOffset: Double = 0.0
    @AppStorage("focus_hide_label") private var hideLabel = false
    @AppStorage("default_y_offset") private var defaultYOffset: Double = 0.0
    @AppStorage("capsule_y_offset") private var capsuleYOffset: Double = 0.0
    
    @AppStorage("battery_show_percentage") private var showBatteryPercentage = true
    
    @State private var playButtonScale: CGFloat = 1.0
    @State private var prevButtonScale: CGFloat = 1.0
    @State private var nextButtonScale: CGFloat = 1.0
    @State private var coverScale: CGFloat = 1.0
    
    var currentYOffset: CGFloat {
        if state.mode == .collapsed && !state.isMediaActive {
            return CGFloat(defaultYOffset)
        } else {
            return CGFloat(capsuleYOffset)
        }
    }
    
    var currentCornerRadius: CGFloat {
        if state.mode == .expanded { return 32 }
        else { return state.currentHeight / 2 }
    }
    
    var progressRatio: Double { guard state.media.duration > 0 else { return 0 }; return min(max(state.media.position / state.media.duration, 0), 1) }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .fill(Color.black)
                    .padding(.top, -currentCornerRadius)
                
                if state.mode == .volume {
                    HStack(spacing: 0) {
                        Image(systemName: state.volume.volume == 0 ? "speaker.slash.fill" : (state.volume.volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"))
                            .foregroundColor(.white).font(.system(size: 16)).frame(width: 24, height: 24)
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                                Capsule().fill(Color.white).frame(width: geo.size.width * state.volume.volume, height: 6).animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.volume.volume)
                            }
                        }.frame(width: 60, height: 6)
                    }.padding(.horizontal, 18).frame(height: state.currentHeight)
                    
                } else if state.mode == .brightness {
                    HStack(spacing: 0) {
                        Image(systemName: "sun.max.fill").foregroundColor(.white).font(.system(size: 16)).frame(width: 24, height: 24)
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                                Capsule().fill(Color.white).frame(width: geo.size.width * state.brightness.brightness, height: 6).animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.brightness.brightness)
                            }
                        }.frame(width: 60, height: 6)
                    }.padding(.horizontal, 18).frame(height: state.currentHeight)
                    
                } else if state.mode == .dnd {
                    HStack(spacing: 0) {
                        Image(systemName: state.dnd.isDNDOn ? "moon.fill" : "moon").foregroundColor(state.dnd.isDNDOn ? .indigo : .white).font(.system(size: 16)).frame(width: 24, height: 24)
                        Spacer()
                        if !hideLabel {
                            Text(state.dnd.isDNDOn ? "On" : "Off").font(.system(size: 13, weight: .bold)).foregroundColor(state.dnd.isDNDOn ? .white : .gray).padding(.horizontal, 12).padding(.vertical, 4).background(state.dnd.isDNDOn ? Color.indigo : Color.white.opacity(0.1)).clipShape(Capsule())
                        }
                    }.padding(.horizontal, 18).frame(height: state.currentHeight)
                    
                } else if state.mode == .battery {
                    HStack(spacing: 0) {
                        Text(state.battery.isCharging ? "Charging" : "Battery")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            if showBatteryPercentage {
                                Text("\(state.battery.batteryLevel)%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(state.battery.batteryLevel <= 20 && !state.battery.isCharging ? .red : .white)
                            }
                            
                            MacNativeBatteryIcon(level: state.battery.batteryLevel, isCharging: state.battery.isCharging)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: state.currentHeight)
                    
                } else if state.mode == .expanded {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            if let nsImage = state.media.artworkImage { Image(nsImage: nsImage).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).shadow(color: .black.opacity(0.5), radius: 8, y: 4).scaleEffect(coverScale) }
                            else { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 64, height: 64).overlay(Image(systemName: "music.note").font(.system(size: 24)).foregroundColor(.white.opacity(0.7))).scaleEffect(coverScale) }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(state.media.trackName).font(.system(size: 18, weight: .bold)).foregroundColor(.white).lineLimit(1)
                                Text(state.media.artistName).font(.system(size: 16, weight: .regular)).foregroundColor(.gray).lineLimit(1)
                            }
                            Spacer()
                            AudioEqualizerView(isPlaying: state.media.isPlaying, mode: state.mode)
                        }
                        HStack(spacing: 12) {
                            Text(formatTime(state.media.position)).font(.system(size: 12, design: .monospaced)).foregroundColor(.gray).frame(width: 35, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                                    Capsule().fill(Color.white).frame(width: geo.size.width * progressRatio, height: 6).animation(.linear(duration: 1.0), value: progressRatio)
                                }
                            }.frame(height: 6)
                            Text("-" + formatTime(state.media.duration - state.media.position)).font(.system(size: 12, design: .monospaced)).foregroundColor(.gray).frame(width: 40, alignment: .trailing)
                        }
                        HStack(spacing: 45) {
                            Image(systemName: "backward.fill").font(.system(size: 24)).foregroundColor(.white).contentShape(Rectangle()).scaleEffect(prevButtonScale).onTapGesture { triggerButtonAnimation(for: $prevButtonScale, triggerCover: true); state.media.previousTrack() }
                            Image(systemName: state.media.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 32)).foregroundColor(.white).contentShape(Rectangle()).scaleEffect(playButtonScale).animation(.spring(), value: state.media.isPlaying).onTapGesture { triggerButtonAnimation(for: $playButtonScale, triggerCover: false); state.media.togglePlayPause() }
                            Image(systemName: "forward.fill").font(.system(size: 24)).foregroundColor(.white).contentShape(Rectangle()).scaleEffect(nextButtonScale).onTapGesture { triggerButtonAnimation(for: $nextButtonScale, triggerCover: true); state.media.nextTrack() }
                            Image(systemName: "airplayaudio").font(.system(size: 20)).foregroundColor(.gray).offset(x: 20)
                        }
                    }.padding(.horizontal, 32).padding(.top, 42).padding(.bottom, 24)
                    
                } else {
                    if state.isMediaActive {
                        HStack(spacing: 0) {
                            if let nsImage = state.media.artworkImage { Image(nsImage: nsImage).resizable().scaledToFill().frame(width: 24, height: 24).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) }
                            else { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.purple).frame(width: 24, height: 24).overlay(Image(systemName: "music.note").font(.system(size: 10)).foregroundColor(.white)) }
                            Spacer()
                            if state.mode == .hovered { Text("控制正在播放").font(.system(size: 12, weight: .medium)).foregroundColor(.white) }
                            Spacer()
                            AudioEqualizerView(isPlaying: state.media.isPlaying, mode: state.mode).frame(width: 24, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: state.currentHeight)
                    } else {
                        HStack(spacing: 12) {
                            Circle().fill(state.monitor.cpuUsage > 0.8 ? Color.red : (state.monitor.cpuUsage > 0.5 ? Color.yellow : Color.blue)).frame(width: 8, height: 8)
                            Circle().fill(state.monitor.memoryUsage > 0.8 ? Color.red : (state.monitor.memoryUsage > 0.6 ? Color.yellow : Color.green)).frame(width: 8, height: 8)
                        }
                        .frame(height: state.currentHeight)
                    }
                }
            }
            .frame(width: state.currentWidth, height: state.currentHeight)
            .animation(.spring(response: 0.4, dampingFraction: 1.0), value: state.mode)
            .animation(.spring(response: 0.4, dampingFraction: 1.0), value: state.isMediaActive)
            .onTapGesture {
                guard state.mode != .volume && state.mode != .brightness && state.mode != .dnd && state.mode != .battery else { return }
                
                if state.mode == .hovered {
                    triggerHaptic(.generic)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { state.mode = .expanded }
                }
            }
            
            if state.mode != .expanded && state.mode != .volume && state.mode != .brightness && state.mode != .dnd && state.mode != .battery {
                Color.clear.frame(width: state.currentWidth, height: state.invisibleHitboxHeight)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            guard state.mode != .volume && state.mode != .brightness && state.mode != .dnd && state.mode != .battery else { return }
            
            if hovering {
                if state.mode == .collapsed {
                    triggerHaptic(.generic)
                    withAnimation(.spring(response: 0.32, dampingFraction: 1.0)) { state.mode = .hovered }
                }
            }
            else {
                if state.mode == .hovered || state.mode == .expanded {
                    triggerHaptic(.generic)
                    withAnimation(.spring(response: 0.32, dampingFraction: 1.0)) { state.mode = .collapsed }
                }
            }
        }
        .frame(width: state.expandedWidth, height: state.expandedHeight + state.invisibleHitboxHeight, alignment: .top)
        .offset(x: CGFloat(islandXOffset), y: currentYOffset)
    }
    
    private func triggerHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        if enableHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        }
    }
    
    private func triggerButtonAnimation(for scale: Binding<CGFloat>, triggerCover: Bool) {
        triggerHaptic(.generic)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { scale.wrappedValue = 0.7; if triggerCover { self.coverScale = 0.85 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            triggerHaptic(.alignment)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { scale.wrappedValue = 1.0; if triggerCover { self.coverScale = 1.0 } }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds <= 0 || seconds.isNaN { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
