import SwiftUI
import AppKit
import Combine

enum IslandMode {
    case collapsed
    case hovered
    case expanded
    case volume
    case brightness
    case dnd
    case battery
}

class IslandState: ObservableObject {
    @Published var mode: IslandMode = .collapsed
    @Published var isMediaActive: Bool = false
    
    var monitor = SystemMonitor()
    var media = MediaMonitor()
    var volume = VolumeMonitor()
    var brightness = BrightnessMonitor()
    var dnd = DNDMonitor()
    var battery = BatteryMonitor()
    
    private var mediaPauseTimer: Timer?
    
    let collapsedWidth: CGFloat = 180
    let islandHeight: CGFloat = 32
    let hoveredWidth: CGFloat = 203
    let hoveredHeight: CGFloat = 36
    let expandedWidth: CGFloat = 500
    
    // 🌟 动态高度：音乐和电池面板完全独立
    var expandedHeight: CGFloat {
        if isMediaActive {
            return 200
        } else {
            return 130
        }
    }
    
    let playingCompactWidth: CGFloat = 260
    let playingCompactHeight: CGFloat = 34
    let playingHoveredWidth: CGFloat = 268
    let playingHoveredHeight: CGFloat = 38
    let volumeWidth: CGFloat = 360
    let volumeHeight: CGFloat = 34
    
    let invisibleHitboxHeight: CGFloat = 12
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        monitor.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }.store(in: &cancellables)
        
        battery.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }.store(in: &cancellables)
        
        media.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleMediaStateChange()
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
        
        volume.$showVolumeUI.sink { [weak self] show in DispatchQueue.main.async { withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) { if show { self?.mode = .volume } else if self?.mode == .volume { self?.mode = .collapsed } }; self?.objectWillChange.send() } }.store(in: &cancellables)
        
        brightness.$showBrightnessUI.sink { [weak self] show in DispatchQueue.main.async { withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) { if show { self?.mode = .brightness } else if self?.mode == .brightness { self?.mode = .collapsed } }; self?.objectWillChange.send() } }.store(in: &cancellables)
        
        dnd.$showDNDUI.sink { [weak self] show in DispatchQueue.main.async { withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) { if show { self?.mode = .dnd } else if self?.mode == .dnd { self?.mode = .collapsed } }; self?.objectWillChange.send() } }.store(in: &cancellables)
        
        battery.$showBatteryUI.sink { [weak self] show in DispatchQueue.main.async { withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) { if show { self?.mode = .battery } else if self?.mode == .battery { self?.mode = .collapsed } }; self?.objectWillChange.send() } }.store(in: &cancellables)
    }
    
    private func handleMediaStateChange() {
        let currentlyPlaying = media.isPlaying
        let hasTrack = media.trackName != "未在播放"
        
        if currentlyPlaying && hasTrack {
            mediaPauseTimer?.invalidate()
            mediaPauseTimer = nil
            if !isMediaActive {
                withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) { isMediaActive = true }
            }
        } else {
            if isMediaActive && mediaPauseTimer == nil {
                mediaPauseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
                        self.isMediaActive = false
                        if self.mode == .expanded { self.mode = .collapsed }
                    }
                }
            }
        }
    }
    
    var currentWidth: CGFloat {
        switch mode {
        case .collapsed: return isMediaActive ? playingCompactWidth : collapsedWidth
        case .hovered: return isMediaActive ? playingHoveredWidth : hoveredWidth
        case .expanded: return expandedWidth
        case .volume, .brightness, .dnd, .battery: return volumeWidth
        }
    }
    
    var currentHeight: CGFloat {
        switch mode {
        case .collapsed: return isMediaActive ? playingCompactHeight : islandHeight
        case .hovered: return isMediaActive ? playingHoveredHeight : hoveredHeight
        case .expanded: return expandedHeight
        case .volume, .brightness, .dnd, .battery: return volumeHeight
        }
    }
}

@main
struct LilyAislandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Lily Island", systemImage: "sparkles") {
            Button("偏好设置...") {
                appDelegate.showSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("退出 Lily Island") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var state = IslandState()
    var settingsWindow: NSWindow?
    
    override init() {
        super.init()
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        state.monitor.start()
        state.media.start()
        state.volume.start()
        state.brightness.start()
        state.dnd.start()
        state.battery.start()
        
        setupIslandWindow()
    }
    
    func setupIslandWindow() {
        let contentView = ContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)
        let canvasWidth = state.expandedWidth
        let canvasHeight = state.expandedHeight + state.invisibleHitboxHeight + 50
        guard let screen = NSScreen.main else { return }
        
        let x = screen.frame.midX - (canvasWidth / 2)
        let y = screen.frame.maxY - canvasHeight
        let canvasRect = NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight)
        
        panel = NSPanel(contentRect: canvasRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.contentView = hostingView
        panel.acceptsMouseMovedEvents = true; panel.orderFront(nil)
    }
    
    // 🌟 这里完美恢复了你原有的窗口生成逻辑，一行不少！
    func showSettingsWindow() {
        if settingsWindow == nil {
            let contentView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.titleVisibility = .hidden
            settingsWindow?.titlebarAppearsTransparent = true
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: contentView)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
