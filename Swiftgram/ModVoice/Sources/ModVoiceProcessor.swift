import Foundation
import ModSettings

public struct ModVoiceConfig: Equatable {
    /// Semitones, -12...12.
    public var pitch: Double
    /// 0...1, ring modulation ("robot").
    public var robot: Double
    /// 0...1
    public var echo: Double
    /// 0...1
    public var reverb: Double
    /// 0...1, telephone band + saturation.
    public var radio: Double
    /// dB
    public var gain: Double

    public init(pitch: Double = 0.0, robot: Double = 0.0, echo: Double = 0.0, reverb: Double = 0.0, radio: Double = 0.0, gain: Double = 0.0) {
        self.pitch = pitch
        self.robot = robot
        self.echo = echo
        self.reverb = reverb
        self.radio = radio
        self.gain = gain
    }

    public var isIdentity: Bool {
        return abs(self.pitch) < 0.01 && self.robot < 0.001 && self.echo < 0.001 && self.reverb < 0.001 && self.radio < 0.001 && abs(self.gain) < 0.01
    }

    public static func fromSettings() -> ModVoiceConfig {
        return ModVoiceConfig(
            pitch: ModSettings.voicePitch,
            robot: ModSettings.voiceRobot,
            echo: ModSettings.voiceEcho,
            reverb: ModSettings.voiceReverb,
            radio: ModSettings.voiceRadio,
            gain: ModSettings.voiceGain
        )
    }

    public func saveToSettings() {
        ModSettings.voicePitch = self.pitch
        ModSettings.voiceRobot = self.robot
        ModSettings.voiceEcho = self.echo
        ModSettings.voiceReverb = self.reverb
        ModSettings.voiceRadio = self.radio
        ModSettings.voiceGain = self.gain
    }
}

public enum ModVoicePreset: String, CaseIterable {
    case custom
    case chipmunk
    case helium
    case child
    case deep
    case demon
    case robot
    case alien
    case radio
    case cave
    case echo
    case stadium

    public var title: String {
        switch self {
        case .custom: return "Своя настройка"
        case .chipmunk: return "Бурундук"
        case .helium: return "Гелий"
        case .child: return "Ребёнок"
        case .deep: return "Низкий голос"
        case .demon: return "Демон"
        case .robot: return "Робот"
        case .alien: return "Инопланетянин"
        case .radio: return "Рация"
        case .cave: return "Пещера"
        case .echo: return "Эхо"
        case .stadium: return "Стадион"
        }
    }

    public var config: ModVoiceConfig? {
        switch self {
        case .custom: return nil
        case .chipmunk: return ModVoiceConfig(pitch: 7.0)
        case .helium: return ModVoiceConfig(pitch: 12.0, gain: -2.0)
        case .child: return ModVoiceConfig(pitch: 4.0)
        case .deep: return ModVoiceConfig(pitch: -5.0, gain: 2.0)
        case .demon: return ModVoiceConfig(pitch: -9.0, robot: 0.15, reverb: 0.35, gain: 3.0)
        case .robot: return ModVoiceConfig(robot: 1.0)
        case .alien: return ModVoiceConfig(pitch: 5.0, robot: 0.5, echo: 0.2)
        case .radio: return ModVoiceConfig(radio: 1.0, gain: 3.0)
        case .cave: return ModVoiceConfig(pitch: -2.0, echo: 0.3, reverb: 0.6)
        case .echo: return ModVoiceConfig(echo: 0.55)
        case .stadium: return ModVoiceConfig(echo: 0.2, reverb: 0.8)
        }
    }
}

// MARK: - Building blocks

private struct Biquad {
    private var b0: Float = 1.0, b1: Float = 0.0, b2: Float = 0.0, a1: Float = 0.0, a2: Float = 0.0
    private var x1: Float = 0.0, x2: Float = 0.0, y1: Float = 0.0, y2: Float = 0.0

    static func highPass(frequency: Double, sampleRate: Double, q: Double = 0.707) -> Biquad {
        let w0 = 2.0 * Double.pi * frequency / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let cosW0 = cos(w0)
        let a0 = 1.0 + alpha
        var filter = Biquad()
        filter.b0 = Float((1.0 + cosW0) / 2.0 / a0)
        filter.b1 = Float(-(1.0 + cosW0) / a0)
        filter.b2 = Float((1.0 + cosW0) / 2.0 / a0)
        filter.a1 = Float(-2.0 * cosW0 / a0)
        filter.a2 = Float((1.0 - alpha) / a0)
        return filter
    }

    static func lowPass(frequency: Double, sampleRate: Double, q: Double = 0.707) -> Biquad {
        let w0 = 2.0 * Double.pi * frequency / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let cosW0 = cos(w0)
        let a0 = 1.0 + alpha
        var filter = Biquad()
        filter.b0 = Float((1.0 - cosW0) / 2.0 / a0)
        filter.b1 = Float((1.0 - cosW0) / a0)
        filter.b2 = Float((1.0 - cosW0) / 2.0 / a0)
        filter.a1 = Float(-2.0 * cosW0 / a0)
        filter.a2 = Float((1.0 - alpha) / a0)
        return filter
    }

    mutating func process(_ x: Float) -> Float {
        let y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2 = self.x1
        self.x1 = x
        self.y2 = self.y1
        self.y1 = y
        return y
    }
}

/// Pitch shifter on a circular delay line with two crossfaded read taps
/// (Hann windows offset by half a period sum to 1).
private struct PitchShifter {
    private var buffer: [Float]
    private let mask: Int
    private var writeIndex: Int = 0
    private var phase: Double = 0.0
    private let window: Double
    private let phaseStep: Double

    init(semitones: Double, sampleRate: Double) {
        let size = 8192
        self.buffer = [Float](repeating: 0.0, count: size)
        self.mask = size - 1
        self.window = min(Double(size) / 2.0 - 4.0, sampleRate * 0.045)
        let ratio = pow(2.0, semitones / 12.0)
        self.phaseStep = (1.0 - ratio) / self.window
    }

    private func read(delay: Double) -> Float {
        let position = Double(self.writeIndex) - delay - 2.0
        let base = Int(floor(position))
        let fraction = Float(position - Double(base))
        let a = self.buffer[base & self.mask]
        let b = self.buffer[(base + 1) & self.mask]
        return a + (b - a) * fraction
    }

    mutating func process(_ x: Float) -> Float {
        self.buffer[self.writeIndex & self.mask] = x

        self.phase += self.phaseStep
        self.phase -= floor(self.phase)
        var secondPhase = self.phase + 0.5
        secondPhase -= floor(secondPhase)

        let firstGain = Float(sin(Double.pi * self.phase))
        let secondGain = Float(sin(Double.pi * secondPhase))
        let y = self.read(delay: self.phase * self.window) * firstGain * firstGain + self.read(delay: secondPhase * self.window) * secondGain * secondGain

        self.writeIndex = (self.writeIndex + 1) & self.mask
        return y
    }
}

private struct Echo {
    private var buffer: [Float]
    private var index: Int = 0
    private let feedback: Float

    init(seconds: Double, feedback: Float, sampleRate: Double) {
        self.buffer = [Float](repeating: 0.0, count: max(1, Int(seconds * sampleRate)))
        self.feedback = feedback
    }

    mutating func process(_ x: Float) -> Float {
        let delayed = self.buffer[self.index]
        self.buffer[self.index] = x + delayed * self.feedback
        self.index += 1
        if self.index >= self.buffer.count {
            self.index = 0
        }
        return delayed
    }
}

private struct Comb {
    private var buffer: [Float]
    private var index: Int = 0
    private var store: Float = 0.0
    private let feedback: Float
    private let damping: Float

    init(length: Int, feedback: Float, damping: Float) {
        self.buffer = [Float](repeating: 0.0, count: max(1, length))
        self.feedback = feedback
        self.damping = damping
    }

    mutating func process(_ x: Float) -> Float {
        let output = self.buffer[self.index]
        self.store = output * (1.0 - self.damping) + self.store * self.damping
        self.buffer[self.index] = x + self.store * self.feedback
        self.index += 1
        if self.index >= self.buffer.count {
            self.index = 0
        }
        return output
    }
}

private struct AllPass {
    private var buffer: [Float]
    private var index: Int = 0

    init(length: Int) {
        self.buffer = [Float](repeating: 0.0, count: max(1, length))
    }

    mutating func process(_ x: Float) -> Float {
        let buffered = self.buffer[self.index]
        let output = buffered - x
        self.buffer[self.index] = x + buffered * 0.5
        self.index += 1
        if self.index >= self.buffer.count {
            self.index = 0
        }
        return output
    }
}

/// Freeverb-like: parallel combs into serial all-passes.
private struct Reverb {
    private var combs: [Comb]
    private var allPasses: [AllPass]

    init(sampleRate: Double) {
        let scale = sampleRate / 44100.0
        self.combs = [1116, 1188, 1277, 1356, 1422, 1491].map { Comb(length: Int(Double($0) * scale), feedback: 0.84, damping: 0.25) }
        self.allPasses = [556, 441, 341].map { AllPass(length: Int(Double($0) * scale)) }
    }

    mutating func process(_ x: Float) -> Float {
        let input = x * 0.15
        var sum: Float = 0.0
        for i in 0 ..< self.combs.count {
            sum += self.combs[i].process(input)
        }
        for i in 0 ..< self.allPasses.count {
            sum = self.allPasses[i].process(sum)
        }
        return sum
    }
}

// MARK: - Processor

/// Streaming voice effect chain for 16-bit mono PCM. Not thread safe, one instance per recording.
public final class ModVoiceProcessor {
    private let config: ModVoiceConfig
    private let sampleRate: Double

    private var pitchShifter: PitchShifter?
    private var echo: Echo?
    private var reverb: Reverb?
    private var radioHighPass: Biquad
    private var radioLowPass: Biquad
    private var robotPhase: Double = 0.0
    private let robotStep: Double
    private let gain: Float

    /// Returns a processor configured from the settings, or nil when the voice changer is off.
    public static func makeFromSettings(sampleRate: Double) -> ModVoiceProcessor? {
        if !ModSettings.voiceEnabled {
            return nil
        }
        let config = ModVoiceConfig.fromSettings()
        if config.isIdentity {
            return nil
        }
        return ModVoiceProcessor(config: config, sampleRate: sampleRate)
    }

    public init(config: ModVoiceConfig, sampleRate: Double) {
        self.config = config
        self.sampleRate = sampleRate
        if abs(config.pitch) >= 0.01 {
            self.pitchShifter = PitchShifter(semitones: config.pitch, sampleRate: sampleRate)
        }
        if config.echo >= 0.001 {
            self.echo = Echo(seconds: 0.22, feedback: Float(0.25 + 0.4 * config.echo), sampleRate: sampleRate)
        }
        if config.reverb >= 0.001 {
            self.reverb = Reverb(sampleRate: sampleRate)
        }
        self.radioHighPass = Biquad.highPass(frequency: 450.0, sampleRate: sampleRate)
        self.radioLowPass = Biquad.lowPass(frequency: 3000.0, sampleRate: sampleRate)
        self.robotStep = 2.0 * Double.pi * 55.0 / sampleRate
        self.gain = Float(pow(10.0, config.gain / 20.0))
    }

    public func process(sample input: Float) -> Float {
        var x = input

        if self.pitchShifter != nil {
            x = self.pitchShifter!.process(x)
        }

        if self.config.robot >= 0.001 {
            let modulated = x * Float(sin(self.robotPhase)) * 1.6
            self.robotPhase += self.robotStep
            if self.robotPhase > 2.0 * Double.pi {
                self.robotPhase -= 2.0 * Double.pi
            }
            let amount = Float(self.config.robot)
            x = x * (1.0 - amount) + modulated * amount
        }

        if self.config.radio >= 0.001 {
            var band = self.radioLowPass.process(self.radioHighPass.process(x))
            band = tanhf(band * 3.0) / tanhf(3.0)
            let amount = Float(self.config.radio)
            x = x * (1.0 - amount) + band * amount
        }

        if self.echo != nil {
            x += self.echo!.process(x) * Float(self.config.echo)
        }

        if self.reverb != nil {
            x += self.reverb!.process(x) * Float(self.config.reverb) * 1.5
        }

        x *= self.gain
        // Soft limiter.
        if x > 0.8 || x < -0.8 {
            x = tanhf(x)
        }
        return x
    }

    /// In-place processing of 16-bit samples.
    public func process(samples: UnsafeMutablePointer<Int16>, count: Int) {
        for i in 0 ..< count {
            let y = self.process(sample: Float(samples[i]) / 32768.0)
            samples[i] = Int16(max(-32768.0, min(32767.0, y * 32768.0)))
        }
    }

    /// In-place processing of float samples (-1...1).
    public func process(floatSamples: UnsafeMutablePointer<Float>, count: Int) {
        for i in 0 ..< count {
            floatSamples[i] = self.process(sample: floatSamples[i])
        }
    }
}
