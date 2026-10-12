import Foundation

/// Export / import / reset of every mod setting (UserDefaults keys "mod.*" plus Swiftgram's effect keys).
enum ModSettingsBackup {
    private static let extraKeys: Set<String> = ["canUseNY", "nyStyle"]
    private static let formatKey = "mod.backup.format"

    private static func isModKey(_ key: String) -> Bool {
        return key.hasPrefix("mod.") || self.extraKeys.contains(key)
    }

    static func exportToFile() -> URL? {
        var values: [String: Any] = [:]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() where self.isModKey(key) {
            values[key] = value
        }
        values[self.formatKey] = 1
        guard let data = try? PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mod-settings-\(formatter.string(from: Date())).plist")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func importFromFile(_ url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url),
              let values = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
              values[self.formatKey] != nil else {
            return false
        }
        for (key, value) in values where self.isModKey(key) && key != self.formatKey {
            UserDefaults.standard.set(value, forKey: key)
        }
        return true
    }

    static func reset() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where self.isModKey(key) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
