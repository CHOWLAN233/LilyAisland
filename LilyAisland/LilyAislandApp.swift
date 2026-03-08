import SwiftUI
import AppKit
import Combine

enum IslandMode {
    case collapsed
    case hovered
    case expanded
    case volume
}

class IslandState: ObservableObject {
    @Published var mode: IslandMode = .collapsed
    var monitor = SystemMonitor()
    var media = MediaMonitor()
    var volume = VolumeMonitor()
    
    var isMediaActive: Bool { return media.trackName != "未在播放" }
    
    let collapsedWidth: CGFloat = 180
    let islandHeight: CGFloat = 34
    
    let hoveredWidth: CGFloat = 190
    let hoveredHeight: CGFloat = 36
    
    let expandedWidth: CGFloat = 500
    let expandedHeight: CGFloat = 200
    
    let playingCompactWidth: CGFloat = 260
    let playingHoveredWidth: CGFloat = 270
    
    let volumeWidth: CGFloat = 360
    let volumeHeight: CGFloat = 34
    
    let invisibleHitboxHeight: CGFloat = 12
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        monitor.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }.store(in: &cancellables)
        media.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }.store(in: &cancellables)
        
        volume.$showVolumeUI
            .sink { [weak self] show in
                DispatchQueue.main.async {
                    // 【核心动画修复】：为音量模式的呼出和收回，套上和音乐播放器同款的弹簧动画！
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        if show {
                            self?.mode = .volume
                        } else if self?.mode == .volume {
                            self?.mode = .collapsed
                        }
                    }
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    var currentWidth: CGFloat {
        switch mode {
        case .collapsed: return isMediaActive ? playingCompactWidth : collapsedWidth
        case .hovered: return isMediaActive ? playingHoveredWidth : hoveredWidth
        case .expanded: return expandedWidth
        case .volume: return volumeWidth
        }
    }
    
    var currentHeight: CGFloat {
        switch mode {
        case .collapsed: return islandHeight
        case .hovered: return hoveredHeight
        case .expanded: return expandedHeight
        case .volume: return volumeHeight
        }
    }
}

@main
struct LilyAislandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { SettingsView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var state = IslandState()
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.monitor.start()
        state.media.start()
        state.volume.start()
        setupIslandWindow()
        setupMenuBar()
    }
    
    func setupIslandWindow() {
        let contentView = ContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)
        let canvasWidth = state.expandedWidth
        let canvasHeight = state.expandedHeight + state.invisibleHitboxHeight
        guard let screen = NSScreen.main else { return }
        
        let x = screen.frame.midX - (canvasWidth / 2)
        let y = screen.frame.maxY - canvasHeight
        let canvasRect = NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight)
        
        panel = NSPanel(contentRect: canvasRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.contentView = hostingView
        panel.acceptsMouseMovedEvents = true; panel.orderFront(nil)
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button { button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Lily Island") }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 Lily Island", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    @objc func showSettings() { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quitApp() { NSApplication.shared.terminate(nil) }
}

struct SettingsView: View {
    @State private var launchAtLogin = false
    var body: some View {
        Form {
            Section(header: Text("通用设置").font(.headline)) {
                Toggle("开机自动启动", isOn: $launchAtLogin).onChange(of: launchAtLogin) { _ in }
                Text("音量监控模块已就绪...").foregroundColor(.gray).padding(.top, 10)
            }
        }.padding(30).frame(width: 350, height: 200)
    }
}
