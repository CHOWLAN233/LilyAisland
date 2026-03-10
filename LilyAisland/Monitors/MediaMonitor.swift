import Foundation
import Combine
import AppKit

class MediaMonitor: ObservableObject {
    @Published var trackName: String = "未在播放"
    @Published var artistName: String = "请打开音乐 App"
    @Published var isPlaying: Bool = false
    @Published var duration: Double = 0.0
    @Published var position: Double = 0.0
    @Published var artworkImage: NSImage? = nil
    
    private var timer: Timer?
    private var lastFetchedTrack: String = ""
    
    func start() {
        updateMediaInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMediaInfo()
        }
    }
    
    func updateMediaInfo() {
        DispatchQueue.global(qos: .background).async {
            let scriptSource = """
            if application "Music" is running then
                tell application "Music"
                    if player state is playing or player state is paused then
                        set tName to name of current track
                        set tArtist to artist of current track
                        set tDuration to duration of current track
                        set tPosition to player position
                        set tState to player state as string
                        return tName & "|||" & tArtist & "|||" & tDuration & "|||" & tPosition & "|||" & tState
                    else
                        return "STOPPED"
                    end if
                end tell
            else
                return "NOT_RUNNING"
            end if
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let output = scriptObject.executeAndReturnError(&error)
                if let stringValue = output.stringValue {
                    self.parseAppleScriptOutput(stringValue)
                }
            }
        }
    }
    
    private func parseAppleScriptOutput(_ output: String) {
        if output == "NOT_RUNNING" || output == "STOPPED" {
            DispatchQueue.main.async {
                self.trackName = "未在播放"
                self.artistName = "Lily Island"
                self.isPlaying = false
                self.position = 0
                self.duration = 0
                self.artworkImage = nil
                self.lastFetchedTrack = ""
            }
            return
        }
        
        let parts = output.components(separatedBy: "|||")
        if parts.count == 5 {
            let newTrackName = parts[0]
            let newArtist = parts[1]
            let newDuration = Double(parts[2]) ?? 0
            let newPosition = Double(parts[3]) ?? 0
            let newIsPlaying = (parts[4] == "playing")
            
            DispatchQueue.main.async {
                self.trackName = newTrackName
                self.artistName = newArtist
                self.duration = newDuration
                self.position = newPosition
                self.isPlaying = newIsPlaying
            }
            
            if newTrackName != lastFetchedTrack {
                self.lastFetchedTrack = newTrackName
                self.fetchArtwork()
            }
        }
    }
    
    private func fetchArtwork() {
        DispatchQueue.global(qos: .utility).async {
            let scriptSource = """
            tell application "Music"
                if exists (artworks of current track) then
                    return raw data of artwork 1 of current track
                end if
            end tell
            """
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let descriptor = scriptObject.executeAndReturnError(&error)
                let rawData = descriptor.data
                if let image = NSImage(data: rawData) {
                    DispatchQueue.main.async {
                        self.artworkImage = image
                    }
                    return
                }
            }
            DispatchQueue.main.async { self.artworkImage = nil }
        }
    }
    
    // --- 核心优化：乐观 UI 更新 ---
    func togglePlayPause() {
        // 立刻在主线程修改 UI 状态，不等脚本执行完，消除卡顿感
        DispatchQueue.main.async { self.isPlaying.toggle() }
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "if application \"Music\" is running then tell application \"Music\" to playpause"
            self.executeScript(script)
        }
    }
    
    func nextTrack() {
        DispatchQueue.main.async { self.position = 0 } // 切歌瞬间进度归零
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "if application \"Music\" is running then tell application \"Music\" to next track"
            self.executeScript(script)
        }
    }
    
    func previousTrack() {
        DispatchQueue.main.async { self.position = 0 }
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "if application \"Music\" is running then tell application \"Music\" to previous track"
            self.executeScript(script)
        }
    }
    
    private func executeScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        updateMediaInfo()
    }
}
