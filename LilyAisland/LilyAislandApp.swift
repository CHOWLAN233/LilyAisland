import SwiftUI
import AppKit
import Combine

enum IslandMode {
    case collapsed
    case hovered
    case expanded
}

class IslandState: ObservableObject {
    @Published var mode: IslandMode = .collapsed
    var monitor = SystemMonitor()
    var media = MediaMonitor()
    
    // 判断媒体是否有真实内容（从而决定是否变宽）
    var isMediaActive: Bool {
        return media.trackName != "未在播放"
    }
    
    // --- 原始设定的尺寸 (严格保持不变) ---
    let collapsedWidth: CGFloat = 180
    let islandHeight: CGFloat = 34
    
    let hoveredWidth: CGFloat = 190
    let hoveredHeight: CGFloat = 36
    
    let expandedWidth: CGFloat = 500
    let expandedHeight: CGFloat = 200
    
    // --- 新增：当有音乐时，迷你胶囊形态的特殊宽度 ---
    let playingCompactWidth: CGFloat = 260
    let playingHoveredWidth: CGFloat = 270
    
    let invisibleHitboxHeight: CGFloat = 12
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        monitor.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            }
            .store(in: &cancellables)
        
        media.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            }
            .store(in: &cancellables)
    }
    
    var currentWidth: CGFloat {
        switch mode {
        case .collapsed: return isMediaActive ? playingCompactWidth : collapsedWidth
        case .hovered: return isMediaActive ? playingHoveredWidth : hoveredWidth
        case .expanded: return expandedWidth
        }
    }
    
    var currentHeight: CGFloat {
        switch mode {
        case .collapsed: return islandHeight
        case .hovered: return hoveredHeight
        case .expanded: return expandedHeight
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
        
        panel = NSPanel(
            contentRect: canvasRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        panel.acceptsMouseMovedEvents = true
        panel.orderFront(nil)
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Lily Island")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 Lily Island", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() { NSApplication.shared.terminate(nil) }
}

struct SettingsView: View {
    @State private var launchAtLogin = false
    var body: some View {
        Form {
            Section(header: Text("通用设置").font(.headline)) {
                Toggle("开机自动启动", isOn: $launchAtLogin).onChange(of: launchAtLogin) { _ in }
                Text("媒体控制面板已就绪...").foregroundColor(.gray).padding(.top, 10)
            }
        }
        .padding(30).frame(width: 350, height: 200)
    }
}
