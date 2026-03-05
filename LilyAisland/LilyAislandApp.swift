import SwiftUI
import AppKit
import Combine

class IslandState: ObservableObject {
    @Published var isExpanded: Bool = false
    
    // 尺寸配置
    let collapsedWidth: CGFloat = 170
    let islandHeight: CGFloat = 32
    let expandedWidth: CGFloat = 400
    let expandedHeight: CGFloat = 100
    let invisibleHitboxHeight: CGFloat = 12
}

@main
struct LilyAislandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var state = IslandState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)
        
        // 【关键】赋予窗口最大可能的尺寸，让它成为一个固定画布
        let canvasWidth = state.expandedWidth
        let canvasHeight = state.expandedHeight + state.invisibleHitboxHeight
        
        guard let screen = NSScreen.main else { return }
        
        // 计算居中位置
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
        panel.backgroundColor = .clear // 透明像素会自动让鼠标点击穿透
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        
        panel.acceptsMouseMovedEvents = true
        panel.orderFront(nil)
    }
}
