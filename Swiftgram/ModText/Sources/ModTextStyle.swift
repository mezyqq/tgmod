import Foundation

/// Unicode "fonts" for outgoing messages: the text is sent with special characters,
/// so everybody sees the style, in any client.
public enum ModTextStyle: String, CaseIterable {
    case none
    case bold
    case italic
    case boldItalic
    case sans
    case script
    case fraktur
    case doubleStruck
    case monospace
    case fullwidth
    case smallCaps
    case circled
    case strikethrough
    case underline
    case upsideDown

    public static let settingsKey = "mod.text.style"

    public static var current: ModTextStyle {
        get { return ModTextStyle(rawValue: UserDefaults.standard.string(forKey: self.settingsKey) ?? "") ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: self.settingsKey) }
    }

    public var title: String {
        switch self {
        case .none: return "Обычный"
        default: return self.apply("Hello 123")
        }
    }

    public var description: String {
        switch self {
        case .none: return "Без стиля"
        case .bold: return "Жирный"
        case .italic: return "Курсив"
        case .boldItalic: return "Жирный курсив"
        case .sans: return "Без засечек"
        case .script: return "Рукописный"
        case .fraktur: return "Готический"
        case .doubleStruck: return "Контурный"
        case .monospace: return "Моноширинный"
        case .fullwidth: return "Широкий"
        case .smallCaps: return "Капитель"
        case .circled: return "В кружочках"
        case .strikethrough: return "Зачёркнутый (и кириллица)"
        case .underline: return "Подчёркнутый (и кириллица)"
        case .upsideDown: return "Вверх ногами"
        }
    }

    private static let smallCapsTable: [Character: String] = {
        let source = Array("abcdefghijklmnopqrstuvwxyz")
        let target = Array("ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢ")
        var result: [Character: String] = [:]
        for i in 0 ..< source.count {
            result[source[i]] = String(target[i])
        }
        return result
    }()

    private static let upsideDownTable: [Character: String] = {
        let pairs: [(String, String)] = [
            ("a", "ɐ"), ("b", "q"), ("c", "ɔ"), ("d", "p"), ("e", "ǝ"), ("f", "ɟ"), ("g", "ƃ"), ("h", "ɥ"), ("i", "ᴉ"),
            ("j", "ɾ"), ("k", "ʞ"), ("l", "l"), ("m", "ɯ"), ("n", "u"), ("o", "o"), ("p", "d"), ("q", "b"), ("r", "ɹ"),
            ("s", "s"), ("t", "ʇ"), ("u", "n"), ("v", "ʌ"), ("w", "ʍ"), ("x", "x"), ("y", "ʎ"), ("z", "z"),
            ("A", "∀"), ("C", "Ɔ"), ("E", "Ǝ"), ("F", "Ⅎ"), ("G", "⅁"), ("J", "ſ"), ("L", "˥"), ("M", "W"), ("P", "Ԁ"),
            ("T", "⊥"), ("U", "∩"), ("V", "Λ"), ("W", "M"), ("Y", "⅄"),
            ("1", "Ɩ"), ("2", "ᄅ"), ("3", "Ɛ"), ("4", "ㄣ"), ("5", "ϛ"), ("6", "9"), ("7", "ㄥ"), ("8", "8"), ("9", "6"), ("0", "0"),
            (".", "˙"), (",", "'"), ("'", ","), ("\"", "„"), ("?", "¿"), ("!", "¡"), ("(", ")"), (")", "("), ("[", "]"), ("]", "["),
            ("{", "}"), ("}", "{"), ("<", ">"), (">", "<"), ("_", "‾"), ("&", "⅋"),
            ("а", "ɐ"), ("б", "ƍ"), ("в", "ʚ"), ("г", "ɹ"), ("д", "ɓ"), ("е", "ǝ"), ("ё", "ǝ"), ("ж", "ж"), ("з", "ε"),
            ("и", "и"), ("й", "ņ"), ("к", "ʞ"), ("л", "v"), ("м", "w"), ("н", "н"), ("о", "о"), ("п", "u"), ("р", "d"),
            ("с", "ɔ"), ("т", "ɯ"), ("у", "ʎ"), ("ф", "ф"), ("х", "х"), ("ц", "ǹ"), ("ч", "Һ"), ("ш", "m"), ("щ", "m"),
            ("ъ", "q"), ("ы", "ıq"), ("ь", "q"), ("э", "є"), ("ю", "oı"), ("я", "ʁ")
        ]
        var result: [Character: String] = [:]
        for (source, target) in pairs {
            result[Character(source)] = target
        }
        return result
    }()

    private func mathematical(_ scalar: Unicode.Scalar, upper: UInt32, lower: UInt32, digits: UInt32?, exceptions: [UInt32: UInt32] = [:]) -> String? {
        let value = scalar.value
        var mapped: UInt32?
        if value >= 0x41 && value <= 0x5A {
            mapped = upper + (value - 0x41)
        } else if value >= 0x61 && value <= 0x7A {
            mapped = lower + (value - 0x61)
        } else if value >= 0x30 && value <= 0x39, let digits {
            mapped = digits + (value - 0x30)
        }
        guard var result = mapped else {
            return nil
        }
        if let exception = exceptions[result] {
            result = exception
        }
        return Unicode.Scalar(result).map { String(Character($0)) }
    }

    private func mapCharacter(_ character: Character) -> String {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
            return String(character)
        }
        switch self {
        case .none:
            return String(character)
        case .bold:
            return self.mathematical(scalar, upper: 0x1D400, lower: 0x1D41A, digits: 0x1D7CE) ?? String(character)
        case .italic:
            return self.mathematical(scalar, upper: 0x1D434, lower: 0x1D44E, digits: nil, exceptions: [0x1D455: 0x210E]) ?? String(character)
        case .boldItalic:
            return self.mathematical(scalar, upper: 0x1D468, lower: 0x1D482, digits: 0x1D7CE) ?? String(character)
        case .sans:
            return self.mathematical(scalar, upper: 0x1D5D4, lower: 0x1D5EE, digits: 0x1D7EC) ?? String(character)
        case .script:
            return self.mathematical(scalar, upper: 0x1D4D0, lower: 0x1D4EA, digits: nil) ?? String(character)
        case .fraktur:
            return self.mathematical(scalar, upper: 0x1D56C, lower: 0x1D586, digits: nil) ?? String(character)
        case .doubleStruck:
            let exceptions: [UInt32: UInt32] = [0x1D53A: 0x2102, 0x1D53F: 0x210D, 0x1D545: 0x2115, 0x1D547: 0x2119, 0x1D548: 0x211A, 0x1D549: 0x211D, 0x1D551: 0x2124]
            return self.mathematical(scalar, upper: 0x1D538, lower: 0x1D552, digits: 0x1D7D8, exceptions: exceptions) ?? String(character)
        case .monospace:
            return self.mathematical(scalar, upper: 0x1D670, lower: 0x1D68A, digits: 0x1D7F6) ?? String(character)
        case .fullwidth:
            if scalar.value == 0x20 {
                return "\u{3000}"
            }
            if scalar.value >= 0x21 && scalar.value <= 0x7E, let mapped = Unicode.Scalar(scalar.value + 0xFEE0) {
                return String(Character(mapped))
            }
            return String(character)
        case .smallCaps:
            return ModTextStyle.smallCapsTable[Character(String(character).lowercased())] ?? String(character)
        case .circled:
            let value = scalar.value
            var mapped: UInt32?
            if value >= 0x41 && value <= 0x5A {
                mapped = 0x24B6 + (value - 0x41)
            } else if value >= 0x61 && value <= 0x7A {
                mapped = 0x24D0 + (value - 0x61)
            } else if value == 0x30 {
                mapped = 0x24EA
            } else if value >= 0x31 && value <= 0x39 {
                mapped = 0x2460 + (value - 0x31)
            }
            return mapped.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? String(character)
        case .strikethrough:
            return character.isWhitespace ? String(character) : String(character) + "\u{0336}"
        case .underline:
            return character.isNewline ? String(character) : String(character) + "\u{0332}"
        case .upsideDown:
            return ModTextStyle.upsideDownTable[character] ?? ModTextStyle.upsideDownTable[Character(String(character).lowercased())] ?? String(character)
        }
    }

    /// Links, @mentions, #hashtags, /commands and e-mails must stay intact.
    private static let protectedRegex = try? NSRegularExpression(pattern: "(?:[a-zA-Z][a-zA-Z0-9+.-]*://\\S+|www\\.\\S+|[@#/$][\\w.]+|\\S+@\\S+\\.\\S+|\\S+\\.(?:com|ru|org|net|io|me|app|dev|gg|tv|su|ua|by|kz|info|xyz)(?:/\\S*)?)", options: [.caseInsensitive])

    public func apply(_ text: String) -> String {
        if self == .none {
            return text
        }
        let nsText = text as NSString
        if let regex = ModTextStyle.protectedRegex {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            if !matches.isEmpty {
                if self == .upsideDown {
                    return text
                }
                var result = ""
                var location = 0
                for match in matches {
                    if match.range.location > location {
                        result += self.applyUnprotected(nsText.substring(with: NSRange(location: location, length: match.range.location - location)))
                    }
                    result += nsText.substring(with: match.range)
                    location = match.range.location + match.range.length
                }
                if location < nsText.length {
                    result += self.applyUnprotected(nsText.substring(from: location))
                }
                return result
            }
        }
        return self.applyUnprotected(text)
    }

    private func applyUnprotected(_ text: String) -> String {
        if self == .upsideDown {
            // Every line is reversed, lines keep their order.
            return text.components(separatedBy: "\n").map { line in
                String(line.reversed().map { self.mapCharacter($0) }.joined())
            }.joined(separator: "\n")
        }
        return text.map { self.mapCharacter($0) }.joined()
    }

    /// Styles every attribute run except the ones carrying any of `skippingAttributes`
    /// (custom emoji, links, mentions), keeping all attributes on the styled runs.
    public func apply(to attributedText: NSAttributedString, skippingAttributes: [NSAttributedString.Key]) -> NSAttributedString {
        if self == .none || attributedText.length == 0 {
            return attributedText
        }
        let result = NSMutableAttributedString(string: "")
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attributes, range, _ in
            let substring = attributedText.attributedSubstring(from: range).string
            if attributes.keys.contains(where: { skippingAttributes.contains($0) }) {
                result.append(NSAttributedString(string: substring, attributes: attributes))
            } else {
                result.append(NSAttributedString(string: self.apply(substring), attributes: attributes))
            }
        }
        return result
    }
}
