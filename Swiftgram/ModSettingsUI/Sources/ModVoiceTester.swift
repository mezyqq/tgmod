import Foundation
import AVFoundation
import ModVoice

/// Records a few seconds from the microphone, applies the voice config and plays it back.
final class ModVoiceTester {
    enum State {
        case idle
        case recording
        case playing
        case failed(String)
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var isBusy = false

    var onStateChange: ((State) -> Void)?

    func run(seconds: Double, config: ModVoiceConfig) {
        if self.isBusy {
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                if granted {
                    self.record(seconds: seconds, config: config)
                } else {
                    self.onStateChange?(.failed("Нет доступа к микрофону"))
                }
            }
        }
    }

    private func record(seconds: Double, config: ModVoiceConfig) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            self.onStateChange?(.failed("Аудиосессия: \(error.localizedDescription)"))
            return
        }

        let input = self.engine.inputNode
        let format = input.outputFormat(forBus: 0)
        if format.sampleRate <= 0.0 || format.channelCount == 0 {
            self.onStateChange?(.failed("Микрофон недоступен"))
            return
        }
        self.lock.lock()
        self.samples.removeAll()
        self.lock.unlock()

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0] else {
                return
            }
            let count = Int(buffer.frameLength)
            self.lock.lock()
            self.samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
            self.lock.unlock()
        }
        do {
            try self.engine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.onStateChange?(.failed("Не удалось начать запись"))
            return
        }
        self.isBusy = true
        self.onStateChange?(.recording)

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.isBusy else {
                return
            }
            input.removeTap(onBus: 0)
            self.engine.stop()
            self.play(sampleRate: format.sampleRate, config: config)
        }
    }

    private func play(sampleRate: Double, config: ModVoiceConfig) {
        self.lock.lock()
        var recorded = self.samples
        self.lock.unlock()

        let processor = ModVoiceProcessor(config: config, sampleRate: sampleRate)
        recorded.withUnsafeMutableBufferPointer { buffer in
            if let baseAddress = buffer.baseAddress {
                processor.process(floatSamples: baseAddress, count: buffer.count)
            }
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(recorded.count)),
              let channel = buffer.floatChannelData?[0] else {
            self.finish(.failed("Ошибка воспроизведения"))
            return
        }
        buffer.frameLength = AVAudioFrameCount(recorded.count)
        recorded.withUnsafeBufferPointer { source in
            if let baseAddress = source.baseAddress {
                channel.update(from: baseAddress, count: source.count)
            }
        }

        if self.player.engine == nil {
            self.engine.attach(self.player)
        }
        self.engine.connect(self.player, to: self.engine.mainMixerNode, format: format)
        do {
            try self.engine.start()
        } catch {
            self.finish(.failed("Ошибка воспроизведения"))
            return
        }
        self.onStateChange?(.playing)
        self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.finish(.idle)
            }
        })
        self.player.play()
    }

    private func finish(_ state: State) {
        self.player.stop()
        self.engine.stop()
        self.isBusy = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        self.onStateChange?(state)
    }

    func cancel() {
        if self.isBusy {
            self.engine.inputNode.removeTap(onBus: 0)
            self.finish(.idle)
        }
    }
}
