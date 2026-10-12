import Foundation

/// A rule of the local "personal bot": when an incoming message matches, the client replies by itself.
public struct ModBotRule: Codable, Equatable {
    public enum Trigger: String, Codable, CaseIterable {
        case any
        case contains
        case exact
        case startsWith
        case regex

        public var title: String {
            switch self {
            case .any: return "Любое сообщение"
            case .contains: return "Содержит слово"
            case .exact: return "Точный текст"
            case .startsWith: return "Начинается с"
            case .regex: return "Регулярное выражение"
            }
        }
    }

    public enum Scope: String, Codable, CaseIterable {
        case privateChats
        case groups
        case all

        public var title: String {
            switch self {
            case .privateChats: return "Личные чаты"
            case .groups: return "Группы (только упоминания)"
            case .all: return "Везде"
            }
        }
    }

    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var trigger: Trigger
    /// Keywords separated by commas / the exact text / the prefix / the regex.
    public var pattern: String
    /// Reply text. Placeholders: {name}, {time}, {date}, {text}.
    public var reply: String
    public var scope: Scope
    public var onlyWhenAppInactive: Bool
    public var replyWithQuote: Bool
    public var delaySeconds: Double
    /// Minimum interval between replies of this rule in one chat.
    public var cooldownMinutes: Double

    public init(id: String = UUID().uuidString, name: String = "Новый бот", isEnabled: Bool = true, trigger: Trigger = .contains, pattern: String = "", reply: String = "", scope: Scope = .privateChats, onlyWhenAppInactive: Bool = false, replyWithQuote: Bool = true, delaySeconds: Double = 2.0, cooldownMinutes: Double = 0.0) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.pattern = pattern
        self.reply = reply
        self.scope = scope
        self.onlyWhenAppInactive = onlyWhenAppInactive
        self.replyWithQuote = replyWithQuote
        self.delaySeconds = delaySeconds
        self.cooldownMinutes = cooldownMinutes
    }

    public func matches(text: String) -> Bool {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self.trigger {
        case .any:
            return true
        case .contains:
            let keywords = self.pattern.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return keywords.contains(where: { normalizedText.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil })
        case .exact:
            return normalizedText.compare(self.pattern.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        case .startsWith:
            let prefix = self.pattern.trimmingCharacters(in: .whitespaces)
            return !prefix.isEmpty && normalizedText.range(of: prefix, options: [.caseInsensitive, .anchored, .diacriticInsensitive]) != nil
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: self.pattern, options: [.caseInsensitive]) else {
                return false
            }
            return regex.firstMatch(in: normalizedText, options: [], range: NSRange(normalizedText.startIndex..., in: normalizedText)) != nil
        }
    }

    public func renderReply(authorName: String, incomingText: String, date: Date = Date()) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        return self.reply
            .replacingOccurrences(of: "{name}", with: authorName)
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: date))
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: date))
            .replacingOccurrences(of: "{text}", with: incomingText)
    }
}

public enum ModBotRules {
    private static let rulesKey = "mod.bots.rules"
    private static let enabledKey = "mod.bots.enabled"

    public static var isEnabled: Bool {
        get { return UserDefaults.standard.bool(forKey: self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: self.enabledKey) }
    }

    public static var rules: [ModBotRule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: self.rulesKey), let rules = try? JSONDecoder().decode([ModBotRule].self, from: data) else {
                return []
            }
            return rules
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: self.rulesKey)
            }
        }
    }

    /// Ready-made bots to start from.
    public static let templates: [ModBotRule] = [
        ModBotRule(name: "Автоответчик «Не на месте»", trigger: .any, reply: "Привет, {name}! Сейчас не могу ответить, напишу позже 🙌", scope: .privateChats, onlyWhenAppInactive: true, replyWithQuote: false, delaySeconds: 3.0, cooldownMinutes: 60.0),
        ModBotRule(name: "Приветствие", trigger: .contains, pattern: "привет, здравствуй, хай, hello, hi", reply: "Привет, {name}! 👋", scope: .privateChats, delaySeconds: 2.0, cooldownMinutes: 720.0),
        ModBotRule(name: "Пинг", trigger: .exact, pattern: "ping", reply: "pong 🏓 ({time})", scope: .all, delaySeconds: 0.5),
        ModBotRule(name: "Время", trigger: .startsWith, pattern: "сколько времени", reply: "Сейчас {time}, {date}", scope: .privateChats, delaySeconds: 1.0)
    ]
}
