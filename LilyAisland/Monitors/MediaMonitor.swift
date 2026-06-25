import Foundation
import Combine
import AppKit

class MediaMonitor: ObservableObject {
    @Published var trackName: String = "未在播放"
    @Published var artistName: String = "LilyAisland"
    @Published var isPlaying: Bool = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var artworkImage: NSImage? = nil

    // 防抖缓存，避免重复触发相同的 UI 更新
    private var lastFetchedTrack: String = ""
    private var timer: Timer?

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: "nowplaying_enabled") }
    private var showArtwork: Bool { UserDefaults.standard.bool(forKey: "nowplaying_show_artwork") }
    private var pollingInterval: Double {
        let val = UserDefaults.standard.double(forKey: "nowplaying_polling_interval")
        return val > 0 ? val : 1.0
    }

    func start() {
        if UserDefaults.standard.object(forKey: "nowplaying_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "nowplaying_enabled")
            UserDefaults.standard.set(true, forKey: "nowplaying_show_artwork")
            UserDefaults.standard.set(true, forKey: "nowplaying_show_progress")
            UserDefaults.standard.set(1.0, forKey: "nowplaying_polling_interval")
        }

        guard isEnabled else { return }

        // 按用户设置的间隔轮询播放状态
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.updateMediaInfo()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMediaInfo() {
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

        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", scriptSource]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()

                if let stringValue = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) {
                    self.parseAppleScriptOutput(stringValue)
                }
            } catch {
                print("执行 AppleScript 子进程失败: \(error)")
            }
        }
    }

    private func parseAppleScriptOutput(_ output: String) {
        if output == "NOT_RUNNING" || output == "STOPPED" || output.isEmpty {
            DispatchQueue.main.async {
                self.trackName = "未在播放"
                self.artistName = "LilyAisland"
                self.isPlaying = false
                self.position = 0
                self.duration = 0
                self.artworkImage = nil
                self.lastFetchedTrack = ""
            }
            return
        }
        
        let components = output.components(separatedBy: "|||")
        if components.count == 5 {
            let fetchedTrackName = components[0]
            let fetchedArtistName = components[1]
            let fetchedDuration = Double(components[2]) ?? 0
            let fetchedPosition = Double(components[3]) ?? 0
            let fetchedState = components[4]
            let isCurrentlyPlaying = (fetchedState.lowercased() == "playing")
            
            let trackIdentifier = "\(fetchedTrackName)-\(fetchedArtistName)"
            
            DispatchQueue.main.async {
                self.isPlaying = isCurrentlyPlaying
                self.position = fetchedPosition
                self.duration = fetchedDuration
                
                if self.lastFetchedTrack != trackIdentifier {
                    self.trackName = fetchedTrackName
                    self.artistName = fetchedArtistName
                    self.lastFetchedTrack = trackIdentifier
                    if self.showArtwork { self.fetchArtwork() }
                    else { self.artworkImage = nil }
                }
            }
        }
    }
    
    private func fetchArtwork() {
        let tempPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("lily_artwork_\(UUID().uuidString)")
        // AppleScript 无法通过 osascript stdout 正确返回二进制封面数据（会损坏），
        // 因此改为先写入临时文件，再用 NSImage 读取。
        let artworkScript = """
        if application "Music" is running then
            tell application "Music"
                if (count of artworks of current track) > 0 then
                    set artData to raw data of artwork 1 of current track
                    set outFile to POSIX file "\(tempPath)"
                    set fileRef to open for access outFile with write permission
                    set eof fileRef to 0
                    write artData to fileRef
                    close access fileRef
                    return "ARTWORK_SAVED"
                end if
            end tell
        end if
        return "NO_ARTWORK"
        """

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", artworkScript]

            let outPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .newlines)

                if result == "ARTWORK_SAVED", let image = NSImage(contentsOfFile: tempPath) {
                    DispatchQueue.main.async {
                        self?.artworkImage = image
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.artworkImage = nil
                    }
                }
            } catch {
                print("获取封面失败: \(error)")
                DispatchQueue.main.async {
                    self?.artworkImage = nil
                }
            }

            // 清理临时文件
            try? FileManager.default.removeItem(atPath: tempPath)
        }
    }
    
    // --- 恢复你原有的控制功能，并统一使用安全的底层调用 ---
    
    func togglePlayPause() {
        executeMediaCommand("tell application \"Music\" to playpause")
    }
    
    func nextTrack() {
        executeMediaCommand("tell application \"Music\" to next track")
    }
    
    func previousTrack() {
        executeMediaCommand("tell application \"Music\" to previous track")
    }
    
    private func executeMediaCommand(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            _ = try? task.run()
        }
    }
}
