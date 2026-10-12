import Foundation

// Settings of the mod. Stored in UserDefaults.standard; the key strings are shared with
// ModFontOverride (Objective-C), keep them in sync with ModFontOverride.m.
public final class ModSettings {
    public enum Keys {
        public static let fontFamily = "mod.font.family"
        public static let fontCustomFiles = "mod.font.customFiles"

        public static let typingStyle = "mod.typing.style"
        public static let typingDuration = "mod.typing.duration"
        public static let typingIntensity = "mod.typing.intensity"
        public static let typingHaptics = "mod.typing.haptics"

        public static let voiceEnabled = "mod.voice.enabled"
        public static let voicePreset = "mod.voice.preset"
        public static let voicePitch = "mod.voice.pitch"
        public static let voiceRobot = "mod.voice.robot"
        public static let voiceEcho = "mod.voice.echo"
        public static let voiceReverb = "mod.voice.reverb"
        public static let voiceRadio = "mod.voice.radio"
        public static let voiceGain = "mod.voice.gain"

        public static let maskEnabled = "mod.mask.enabled"
        public static let maskMode = "mod.mask.mode"
        public static let maskCircle = "mod.mask.circle"
        public static let maskScale = "mod.mask.scale"
        public static let maskFollowRotation = "mod.mask.followRotation"
        public static let maskCoverWhenLost = "mod.mask.coverWhenLost"
        public static let maskImageVersion = "mod.mask.imageVersion"

        public static let squareAvatars = "mod.avatars.square"
        public static let avatarCornerRatio = "mod.avatars.cornerRatio"
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    private static func double(_ key: String, _ defaultValue: Double) -> Double {
        if let value = self.defaults.object(forKey: key) as? NSNumber {
            return value.doubleValue
        }
        return defaultValue
    }

    // MARK: Font

    /// Empty string = system font.
    public static var fontFamily: String {
        get { return self.defaults.string(forKey: Keys.fontFamily) ?? "" }
        set { self.defaults.set(newValue, forKey: Keys.fontFamily) }
    }

    // MARK: Typing animation

    public static var typingStyle: String {
        get { return self.defaults.string(forKey: Keys.typingStyle) ?? "none" }
        set { self.defaults.set(newValue, forKey: Keys.typingStyle) }
    }

    /// Seconds.
    public static var typingDuration: Double {
        get { return self.double(Keys.typingDuration, 0.35) }
        set { self.defaults.set(newValue, forKey: Keys.typingDuration) }
    }

    /// 0.25...2.0, scales offsets / angles / scale factors of the animation.
    public static var typingIntensity: Double {
        get { return self.double(Keys.typingIntensity, 1.0) }
        set { self.defaults.set(newValue, forKey: Keys.typingIntensity) }
    }

    public static var typingHaptics: Bool {
        get { return self.defaults.bool(forKey: Keys.typingHaptics) }
        set { self.defaults.set(newValue, forKey: Keys.typingHaptics) }
    }

    // MARK: Voice changer

    public static var voiceEnabled: Bool {
        get { return self.defaults.bool(forKey: Keys.voiceEnabled) }
        set { self.defaults.set(newValue, forKey: Keys.voiceEnabled) }
    }

    public static var voicePreset: String {
        get { return self.defaults.string(forKey: Keys.voicePreset) ?? "custom" }
        set { self.defaults.set(newValue, forKey: Keys.voicePreset) }
    }

    /// Semitones, -12...12.
    public static var voicePitch: Double {
        get { return self.double(Keys.voicePitch, 0.0) }
        set { self.defaults.set(newValue, forKey: Keys.voicePitch) }
    }

    /// 0...1
    public static var voiceRobot: Double {
        get { return self.double(Keys.voiceRobot, 0.0) }
        set { self.defaults.set(newValue, forKey: Keys.voiceRobot) }
    }

    /// 0...1
    public static var voiceEcho: Double {
        get { return self.double(Keys.voiceEcho, 0.0) }
        set { self.defaults.set(newValue, forKey: Keys.voiceEcho) }
    }

    /// 0...1
    public static var voiceReverb: Double {
        get { return self.double(Keys.voiceReverb, 0.0) }
        set { self.defaults.set(newValue, forKey: Keys.voiceReverb) }
    }

    /// 0...1
    public static var voiceRadio: Double {
        get { return self.double(Keys.voiceRadio, 0.0) }
        set { self.defaults.set(newValue, forKey: Keys.voiceRadio) }
    }

    /// dB, -6...12.
    public static var voiceGain: Double {
        get { return self.double(Keys.voiceGain, 0.0) }
        set { self.defaults.set(newValue, forKey: Keys.voiceGain) }
    }

    // MARK: Face mask in video messages

    public static var maskEnabled: Bool {
        get { return self.defaults.bool(forKey: Keys.maskEnabled) }
        set { self.defaults.set(newValue, forKey: Keys.maskEnabled) }
    }

    /// "photo", "blur" or "pixelate".
    public static var maskMode: String {
        get { return self.defaults.string(forKey: Keys.maskMode) ?? "photo" }
        set { self.defaults.set(newValue, forKey: Keys.maskMode) }
    }

    public static var maskCircle: Bool {
        get { return (self.defaults.object(forKey: Keys.maskCircle) as? Bool) ?? true }
        set { self.defaults.set(newValue, forKey: Keys.maskCircle) }
    }

    /// Size of the mask relative to the detected face box, 1.0...2.5.
    public static var maskScale: Double {
        get { return self.double(Keys.maskScale, 1.7) }
        set { self.defaults.set(newValue, forKey: Keys.maskScale) }
    }

    public static var maskFollowRotation: Bool {
        get { return (self.defaults.object(forKey: Keys.maskFollowRotation) as? Bool) ?? true }
        set { self.defaults.set(newValue, forKey: Keys.maskFollowRotation) }
    }

    /// Cover the whole frame while no face is detected, so the face never leaks.
    public static var maskCoverWhenLost: Bool {
        get { return (self.defaults.object(forKey: Keys.maskCoverWhenLost) as? Bool) ?? true }
        set { self.defaults.set(newValue, forKey: Keys.maskCoverWhenLost) }
    }

    /// Incremented every time the mask photo changes.
    public static var maskImageVersion: Int {
        get { return self.defaults.integer(forKey: Keys.maskImageVersion) }
        set { self.defaults.set(newValue, forKey: Keys.maskImageVersion) }
    }

    // MARK: Avatars

    public static var squareAvatars: Bool {
        get { return self.defaults.bool(forKey: Keys.squareAvatars) }
        set { self.defaults.set(newValue, forKey: Keys.squareAvatars) }
    }

    /// Corner radius of square avatars relative to their width, 0 (sharp) ... 0.5 (circle).
    public static var avatarCornerRatio: Double {
        get { return self.double(Keys.avatarCornerRatio, 0.12) }
        set { self.defaults.set(newValue, forKey: Keys.avatarCornerRatio) }
    }
}
