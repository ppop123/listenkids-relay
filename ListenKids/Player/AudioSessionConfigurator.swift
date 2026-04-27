import AVFoundation

enum AudioSessionConfigurator {
    static func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession activate failed: \(error)")
        }
    }
}
