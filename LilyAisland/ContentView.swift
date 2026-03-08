import SwiftUI
import AppKit

// --- 动态音频跳动频谱组件 ---
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
            .onAppear {
                if isPlaying {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAnimating = true }
                }
            }
            .onChange(of: isPlaying) { newValue in
                isAnimating = false
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAnimating = true }
                }
            }
            .onChange(of: mode) { _ in
                if isPlaying {
                    isAnimating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAnimating = true }
                }
            }
    }
}

// --- 主视图 ---
struct ContentView: View {
    @ObservedObject var state: IslandState
    
    @State private var playButtonScale: CGFloat = 1.0
    @State private var prevButtonScale: CGFloat = 1.0
    @State private var nextButtonScale: CGFloat = 1.0
    @State private var coverScale: CGFloat = 1.0
    
    var currentCornerRadius: CGFloat {
        switch state.mode {
        case .collapsed: return 12
        case .hovered: return 14
        case .expanded: return 32
        }
    }
    
    var progressRatio: Double {
        guard state.media.duration > 0 else { return 0 }
        return min(max(state.media.position / state.media.duration, 0), 1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                FlushTopShape(cornerRadius: currentCornerRadius)
                    .fill(Color.black)
                
                if state.mode == .expanded {
                    // --- 3. 完全展开：大型媒体控制面板 ---
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            if let nsImage = state.media.artworkImage {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                                    .scaleEffect(coverScale)
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 64, height: 64)
                                    .overlay(Image(systemName: "music.note").font(.system(size: 24)).foregroundColor(.white.opacity(0.7)))
                                    .scaleEffect(coverScale)
                            }
                            
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
                                    Capsule().fill(Color.white)
                                        .frame(width: geo.size.width * progressRatio, height: 6)
                                        .animation(.linear(duration: 1.0), value: progressRatio)
                                }
                            }.frame(height: 6)
                            Text("-" + formatTime(state.media.duration - state.media.position)).font(.system(size: 12, design: .monospaced)).foregroundColor(.gray).frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack(spacing: 45) {
                            Image(systemName: "backward.fill").font(.system(size: 24)).foregroundColor(.white).contentShape(Rectangle())
                                .scaleEffect(prevButtonScale)
                                .onTapGesture {
                                    triggerButtonAnimation(for: $prevButtonScale, triggerCover: true)
                                    state.media.previousTrack()
                                }
                            
                            Image(systemName: state.media.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 32)).foregroundColor(.white).contentShape(Rectangle())
                                .scaleEffect(playButtonScale)
                                .animation(.spring(), value: state.media.isPlaying)
                                .onTapGesture {
                                    triggerButtonAnimation(for: $playButtonScale, triggerCover: false)
                                    state.media.togglePlayPause()
                                }
                            
                            Image(systemName: "forward.fill").font(.system(size: 24)).foregroundColor(.white).contentShape(Rectangle())
                                .scaleEffect(nextButtonScale)
                                .onTapGesture {
                                    triggerButtonAnimation(for: $nextButtonScale, triggerCover: true)
                                    state.media.nextTrack()
                                }
                            
                            Image(systemName: "airplayaudio").font(.system(size: 20)).foregroundColor(.gray).offset(x: 20)
                        }
                    }
                    .padding(.horizontal, 32).padding(.top, 42).padding(.bottom, 24)
                    
                } else {
                    // --- 1 & 2. 折叠 / 悬停状态 ---
                    if state.isMediaActive {
                        HStack(spacing: 0) {
                            if let nsImage = state.media.artworkImage {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.purple)
                                    .frame(width: 24, height: 24)
                                    .overlay(Image(systemName: "music.note").font(.system(size: 10)).foregroundColor(.white))
                            }
                            
                            Spacer()
                            if state.mode == .hovered {
                                Text("控制正在播放")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .offset(y: 2)
                            }
                            Spacer()
                            
                            AudioEqualizerView(isPlaying: state.media.isPlaying, mode: state.mode)
                                .frame(width: 24, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        
                    } else {
                        HStack(spacing: 12) {
                            Circle().fill(state.monitor.cpuUsage > 0.8 ? Color.red : (state.monitor.cpuUsage > 0.5 ? Color.yellow : Color.blue)).frame(width: 8, height: 8)
                            Circle().fill(state.monitor.memoryUsage > 0.8 ? Color.red : (state.monitor.memoryUsage > 0.6 ? Color.yellow : Color.green)).frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(width: state.currentWidth, height: state.currentHeight)
            // 【核心修复魔法】监听音乐状态的改变，一旦有音乐和没音乐之间发生切换，强行执行平滑的弹簧动画！
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.isMediaActive)
            .onTapGesture {
                if state.mode == .hovered {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { state.mode = .expanded }
                }
            }
            
            if state.mode != .expanded { Color.clear.frame(width: state.hoveredWidth, height: state.invisibleHitboxHeight) }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                if state.mode == .collapsed {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { state.mode = .hovered }
                }
            } else {
                if state.mode != .collapsed {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    // 使用临界阻尼 0.95，防止收回时露出底部物理刘海
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.95)) { state.mode = .collapsed }
                }
            }
        }
        .frame(width: state.expandedWidth, height: state.expandedHeight + state.invisibleHitboxHeight, alignment: .top)
    }
    
    private func triggerButtonAnimation(for scale: Binding<CGFloat>, triggerCover: Bool) {
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.generic, performanceTime: .now)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            scale.wrappedValue = 0.7
            if triggerCover { self.coverScale = 0.85 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            haptic.perform(.alignment, performanceTime: .now)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale.wrappedValue = 1.0
                if triggerCover { self.coverScale = 1.0 }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds <= 0 || seconds.isNaN { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct FlushTopShape: Shape {
    var cornerRadius: CGFloat
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius), radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: cornerRadius, y: rect.maxY - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}
