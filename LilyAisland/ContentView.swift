import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @ObservedObject var state: IslandState
    
    var currentCornerRadius: CGFloat {
        return state.isExpanded ? 16 : 12
    }
    
    var body: some View {
        // 这是真正会发生形变并响应悬停的灵动岛本体
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .fill(Color.black)
                
                if state.isExpanded {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        
                        Text("Lily Island 准备就绪")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    HStack {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Spacer()
                        Text("Lily").font(.system(size: 11)).foregroundColor(.white)
                        Spacer()
                        Image(systemName: "bolt.fill").foregroundColor(.yellow).font(.system(size: 10))
                    }
                    .padding(.horizontal, 15)
                }
            }
            .frame(width: state.isExpanded ? state.expandedWidth : state.collapsedWidth,
                   height: state.isExpanded ? state.expandedHeight : state.islandHeight)
            
            // 底部透明感应区
            if !state.isExpanded {
                Color.clear
                    .frame(width: state.collapsedWidth, height: state.invisibleHitboxHeight)
            }
        }
        .contentShape(Rectangle()) // 确保只有灵动岛本体+下方感应区能触发悬停
        .onHover { hovering in
            if hovering != state.isExpanded {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    state.isExpanded = hovering
                }
            }
        }
        // 【解决崩溃的核心】给整个视图加上固定最大尺寸的外框，从顶部对齐
        .frame(width: state.expandedWidth,
               height: state.expandedHeight + state.invisibleHitboxHeight,
               alignment: .top)
    }
}
