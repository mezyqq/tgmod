import Foundation
import UIKit
import UniformTypeIdentifiers
import ModSettings
import ModFontOverride
import ModTypingAnimation
import ModVoice
import ModFaceMask
import ModText

/// Entry point: the "Customization" screen wrapped into a navigation controller, to be presented modally.
public func modMakeSettingsController(isDark: Bool, accentColor: UIColor) -> UIViewController {
    let root = ModSettingsController()
    let navigationController = UINavigationController(rootViewController: root)
    navigationController.overrideUserInterfaceStyle = isDark ? .dark : .light
    navigationController.view.tintColor = accentColor
    navigationController.navigationBar.prefersLargeTitles = true
    return navigationController
}

private enum Row: Equatable {
    case fontFamily

    case typingPreview
    case typingStyle
    case typingDuration
    case typingIntensity
    case typingHaptics
    case textStyle

    case avatarsSquare
    case avatarsCorner

    case maskEnabled
    case maskMode
    case maskPhoto
    case maskCircle
    case maskScale
    case maskFollowRotation
    case maskCoverWhenLost
    case videoFilter
    case videoMirror

    case voiceEnabled
    case voicePreset
    case voicePitch
    case voiceRobot
    case voiceEcho
    case voiceReverb
    case voiceRadio
    case voiceGain
    case voiceTest

    case botsEnabled
    case botsList

    case effects

    case backupExport
    case backupImport
    case backupReset
}

private struct Section {
    var title: String
    var footer: String?
    var rows: [Row]
}

private enum ChatEffect: String, CaseIterable {
    case `default`
    case snow
    case lightning

    var title: String {
        switch self {
        case .default: return "Выключено"
        case .snow: return "Снег"
        case .lightning: return "Гирлянда"
        }
    }

    static var current: ChatEffect {
        if !UserDefaults.standard.bool(forKey: "canUseNY") {
            return .default
        }
        return ChatEffect(rawValue: UserDefaults.standard.string(forKey: "nyStyle") ?? "") ?? .default
    }

    func save() {
        // Swiftgram's New Year effects (SGSimpleSettings keys), unlocked for the whole year.
        UserDefaults.standard.set(self != .default, forKey: "canUseNY")
        UserDefaults.standard.set(self.rawValue, forKey: "nyStyle")
    }
}

final class ModSettingsController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    private let voiceTester = ModVoiceTester()
    private var voiceTestStatus: String = "Проверить голос (запись 3 сек)"
    private var sections: [Section] = []

    init() {
        super.init(style: .insetGrouped)
        self.title = "Кастомизация"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.donePressed))
        self.tableView.keyboardDismissMode = .onDrag
        self.voiceTester.onStateChange = { [weak self] state in
            guard let self else {
                return
            }
            switch state {
            case .idle:
                self.voiceTestStatus = "Проверить голос (запись 3 сек)"
            case .recording:
                self.voiceTestStatus = "🎙 Говорите…"
            case .playing:
                self.voiceTestStatus = "▶️ Воспроизведение…"
            case let .failed(text):
                self.voiceTestStatus = "⚠️ \(text)"
            }
            self.reload(row: .voiceTest)
        }
        self.rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rebuild()
        self.tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.navigationController?.isBeingDismissed == true {
            self.voiceTester.cancel()
        }
    }

    @objc private func donePressed() {
        self.voiceTester.cancel()
        self.dismiss(animated: true)
    }

    // MARK: Model

    private func rebuild() {
        var sections: [Section] = []

        sections.append(Section(title: "Шрифт", footer: "Шрифт применяется ко всему интерфейсу и сообщениям после перезапуска.", rows: [.fontFamily]))

        sections.append(Section(title: "Печать и текст", footer: "Напечатайте что-нибудь в поле выше, чтобы увидеть анимацию. «Стиль текста» превращает отправляемые сообщения в особые символы, их видят все, в любом клиенте. Ссылки, @упоминания и #теги не меняются.", rows: [.typingPreview, .typingStyle, .typingDuration, .typingIntensity, .typingHaptics, .textStyle]))

        var avatarRows: [Row] = [.avatarsSquare]
        if ModSettings.squareAvatars {
            avatarRows.append(.avatarsCorner)
        }
        sections.append(Section(title: "Аватарки", footer: "Квадратные аватарки везде: списки чатов, сообщения, профили, сторис. Применяется после перезапуска.", rows: avatarRows))

        var maskRows: [Row] = [.maskEnabled]
        if ModSettings.maskEnabled {
            maskRows.append(.maskMode)
            if ModFaceMaskMode.current == .photo {
                maskRows.append(contentsOf: [.maskPhoto, .maskCircle])
            }
            maskRows.append(contentsOf: [.maskScale, .maskFollowRotation, .maskCoverWhenLost])
        }
        maskRows.append(contentsOf: [.videoFilter, .videoMirror])
        sections.append(Section(title: "Кружки", footer: "Маска закрывает лицо в видеосообщениях и следует за ним. «Закрывать при потере лица» не даст лицу мелькнуть, если распознавание на секунду сбилось. Фильтр и отражение тоже применяются к записи.", rows: maskRows))

        var voiceRows: [Row] = [.voiceEnabled]
        if ModSettings.voiceEnabled {
            voiceRows.append(contentsOf: [.voicePreset, .voicePitch, .voiceRobot, .voiceEcho, .voiceReverb, .voiceRadio, .voiceGain, .voiceTest])
        }
        sections.append(Section(title: "Смена голоса", footer: "Эффект применяется к голосовым сообщениям при записи. Собеседник услышит изменённый голос.", rows: voiceRows))

        sections.append(Section(title: "Личные боты", footer: "Автоответы, которые выполняет сам клиент: работают, пока приложение открыто или недавно свёрнуто.", rows: ModBotRules.isEnabled ? [.botsEnabled, .botsList] : [.botsEnabled]))

        sections.append(Section(title: "Эффекты", footer: "Падающий снег или гирлянда в интерфейсе. Применяется после перезапуска.", rows: [.effects]))

        sections.append(Section(title: "Настройки мода", footer: "Экспорт сохраняет все настройки мода и личных ботов в файл, им можно поделиться. Шрифты и фото маски в файл не входят.", rows: [.backupExport, .backupImport, .backupReset]))

        self.sections = sections
    }

    private func indexPath(of row: Row) -> IndexPath? {
        for (sectionIndex, section) in self.sections.enumerated() {
            if let rowIndex = section.rows.firstIndex(of: row) {
                return IndexPath(row: rowIndex, section: sectionIndex)
            }
        }
        return nil
    }

    private func reload(row: Row) {
        if let indexPath = self.indexPath(of: row) {
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func reloadStructure() {
        self.rebuild()
        self.tableView.reloadData()
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.sections[section].footer
    }

    private func valueCell(_ tableView: UITableView, title: String, value: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "value") ?? UITableViewCell(style: .value1, reuseIdentifier: "value")
        cell.textLabel?.text = title
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.text = value
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private func buttonCell(_ tableView: UITableView, title: String, destructive: Bool = false) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "button") ?? UITableViewCell(style: .default, reuseIdentifier: "button")
        cell.textLabel?.text = title
        cell.textLabel?.textColor = destructive ? .systemRed : self.view.tintColor
        cell.imageView?.image = nil
        return cell
    }

    private func switchCell(_ tableView: UITableView, title: String, value: Bool, onChange: @escaping (Bool) -> Void) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "switch") as? ModSwitchCell) ?? ModSwitchCell(style: .default, reuseIdentifier: "switch")
        cell.textLabel?.text = title
        cell.toggle.isOn = value
        cell.onChange = onChange
        return cell
    }

    private func sliderCell(_ tableView: UITableView, title: String, value: Double, range: ClosedRange<Float>, format: @escaping (Float) -> String, onChange: @escaping (Float) -> Void) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "slider") as? ModSliderCell) ?? ModSliderCell(style: .default, reuseIdentifier: "slider")
        cell.configure(title: title, value: Float(value), range: range, format: format, onChange: onChange)
        return cell
    }

    private func voiceSliderChanged(_ update: (inout ModVoiceConfig) -> Void) {
        var config = ModVoiceConfig.fromSettings()
        update(&config)
        config.saveToSettings()
        if ModSettings.voicePreset != ModVoicePreset.custom.rawValue {
            ModSettings.voicePreset = ModVoicePreset.custom.rawValue
            self.reload(row: .voicePreset)
        }
    }

    private static let percent: (Float) -> String = { String(format: "%.0f%%", $0 * 100.0) }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = self.sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .fontFamily:
            let family = ModSettings.fontFamily
            return self.valueCell(tableView, title: "Шрифт", value: family.isEmpty ? "Системный" : family)

        case .typingPreview:
            let cell = (tableView.dequeueReusableCell(withIdentifier: "preview") as? ModTextPreviewCell) ?? ModTextPreviewCell(style: .default, reuseIdentifier: "preview")
            cell.onTextChange = { textView in
                ModTypingAnimator.shared.textDidChange(inputView: textView, attributedText: textView.attributedText, selectedRange: textView.selectedRange)
            }
            return cell
        case .typingStyle:
            return self.valueCell(tableView, title: "Анимация печати", value: ModTypingStyle.current.title)
        case .typingDuration:
            return self.sliderCell(tableView, title: "Длительность", value: ModSettings.typingDuration, range: 0.1 ... 1.0, format: { String(format: "%.2f с", $0) }, onChange: { value in
                ModSettings.typingDuration = Double(value)
            })
        case .typingIntensity:
            return self.sliderCell(tableView, title: "Сила", value: ModSettings.typingIntensity, range: 0.25 ... 2.0, format: { String(format: "×%.2f", $0) }, onChange: { value in
                ModSettings.typingIntensity = Double(value)
            })
        case .typingHaptics:
            return self.switchCell(tableView, title: "Вибрация при печати", value: ModSettings.typingHaptics, onChange: { value in
                ModSettings.typingHaptics = value
            })
        case .textStyle:
            return self.valueCell(tableView, title: "Стиль текста", value: ModTextStyle.current.title)

        case .avatarsSquare:
            return self.switchCell(tableView, title: "Квадратные аватарки", value: ModSettings.squareAvatars, onChange: { [weak self] value in
                ModSettings.squareAvatars = value
                self?.reloadStructure()
                self?.askForRestart(message: "Форма аватарок изменится после перезапуска.")
            })
        case .avatarsCorner:
            let cell = self.sliderCell(tableView, title: "Скругление углов", value: ModSettings.avatarCornerRatio, range: 0.0 ... 0.5, format: { value in
                return value < 0.01 ? "Острые" : String(format: "%.0f%%", value * 200.0)
            }, onChange: { value in
                ModSettings.avatarCornerRatio = Double(value)
            })
            return cell

        case .maskEnabled:
            return self.switchCell(tableView, title: "Маска на лицо", value: ModSettings.maskEnabled, onChange: { [weak self] value in
                ModSettings.maskEnabled = value
                self?.reloadStructure()
            })
        case .maskMode:
            return self.valueCell(tableView, title: "Тип маски", value: ModFaceMaskMode.current.title)
        case .maskPhoto:
            let cell = self.buttonCell(tableView, title: ModFaceMask.storedMaskPhoto() == nil ? "Выбрать фото" : "Сменить фото")
            cell.imageView?.image = ModFaceMask.storedMaskPhoto().map { image in
                UIGraphicsImageRenderer(size: CGSize(width: 40.0, height: 40.0)).image { _ in
                    let rect = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
                    if ModSettings.maskCircle {
                        UIBezierPath(ovalIn: rect).addClip()
                    }
                    image.draw(in: rect)
                }
            }
            return cell
        case .maskCircle:
            return self.switchCell(tableView, title: "Круглая маска", value: ModSettings.maskCircle, onChange: { [weak self] value in
                ModSettings.maskCircle = value
                self?.reload(row: .maskPhoto)
            })
        case .maskScale:
            return self.sliderCell(tableView, title: "Размер маски", value: ModSettings.maskScale, range: 1.0 ... 2.5, format: { String(format: "×%.2f", $0) }, onChange: { value in
                ModSettings.maskScale = Double(value)
            })
        case .maskFollowRotation:
            return self.switchCell(tableView, title: "Поворачивать с головой", value: ModSettings.maskFollowRotation, onChange: { value in
                ModSettings.maskFollowRotation = value
            })
        case .maskCoverWhenLost:
            return self.switchCell(tableView, title: "Закрывать при потере лица", value: ModSettings.maskCoverWhenLost, onChange: { value in
                ModSettings.maskCoverWhenLost = value
            })
        case .videoFilter:
            return self.valueCell(tableView, title: "Фильтр", value: ModVideoFilter.current.title)
        case .videoMirror:
            return self.switchCell(tableView, title: "Отражать по горизонтали", value: ModVideoFilter.mirror, onChange: { value in
                ModVideoFilter.mirror = value
            })

        case .voiceEnabled:
            return self.switchCell(tableView, title: "Менять голос", value: ModSettings.voiceEnabled, onChange: { [weak self] value in
                ModSettings.voiceEnabled = value
                self?.reloadStructure()
            })
        case .voicePreset:
            return self.valueCell(tableView, title: "Пресет", value: (ModVoicePreset(rawValue: ModSettings.voicePreset) ?? .custom).title)
        case .voicePitch:
            return self.sliderCell(tableView, title: "Высота голоса (питч)", value: ModSettings.voicePitch, range: -12.0 ... 12.0, format: { String(format: "%+.1f полутон.", $0) }, onChange: { [weak self] value in
                self?.voiceSliderChanged { $0.pitch = Double(value) }
            })
        case .voiceRobot:
            return self.sliderCell(tableView, title: "Робот", value: ModSettings.voiceRobot, range: 0.0 ... 1.0, format: ModSettingsController.percent, onChange: { [weak self] value in
                self?.voiceSliderChanged { $0.robot = Double(value) }
            })
        case .voiceEcho:
            return self.sliderCell(tableView, title: "Эхо", value: ModSettings.voiceEcho, range: 0.0 ... 1.0, format: ModSettingsController.percent, onChange: { [weak self] value in
                self?.voiceSliderChanged { $0.echo = Double(value) }
            })
        case .voiceReverb:
            return self.sliderCell(tableView, title: "Реверберация", value: ModSettings.voiceReverb, range: 0.0 ... 1.0, format: ModSettingsController.percent, onChange: { [weak self] value in
                self?.voiceSliderChanged { $0.reverb = Double(value) }
            })
        case .voiceRadio:
            return self.sliderCell(tableView, title: "Рация", value: ModSettings.voiceRadio, range: 0.0 ... 1.0, format: ModSettingsController.percent, onChange: { [weak self] value in
                self?.voiceSliderChanged { $0.radio = Double(value) }
            })
        case .voiceGain:
            return self.sliderCell(tableView, title: "Громкость", value: ModSettings.voiceGain, range: -6.0 ... 12.0, format: { String(format: "%+.1f дБ", $0) }, onChange: { [weak self] value in
                self?.voiceSliderChanged { $0.gain = Double(value) }
            })
        case .voiceTest:
            return self.buttonCell(tableView, title: self.voiceTestStatus)

        case .botsEnabled:
            return self.switchCell(tableView, title: "Личные боты", value: ModBotRules.isEnabled, onChange: { [weak self] value in
                ModBotRules.isEnabled = value
                self?.reloadStructure()
            })
        case .botsList:
            let rules = ModBotRules.rules
            let enabledCount = rules.filter(\.isEnabled).count
            return self.valueCell(tableView, title: "Боты", value: rules.isEmpty ? "Нет" : "\(enabledCount) из \(rules.count) вкл.")

        case .effects:
            return self.valueCell(tableView, title: "Эффект", value: ChatEffect.current.title)

        case .backupExport:
            return self.buttonCell(tableView, title: "Экспорт настроек")
        case .backupImport:
            return self.buttonCell(tableView, title: "Импорт настроек")
        case .backupReset:
            return self.buttonCell(tableView, title: "Сбросить настройки мода", destructive: true)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = self.sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .fontFamily:
            let controller = ModFontPickerController(selected: ModSettings.fontFamily, onSelect: { [weak self] family in
                ModSettings.fontFamily = family
                self?.reload(row: .fontFamily)
                self?.askForRestart(message: "Шрифт применится после перезапуска приложения.")
            })
            self.navigationController?.pushViewController(controller, animated: true)
        case .typingStyle:
            self.pushOptions(title: "Анимация печати", options: ModTypingStyle.allCases.map { (id: $0.rawValue, title: $0.title) }, selected: ModTypingStyle.current.rawValue) { id in
                ModSettings.typingStyle = id
            }
        case .textStyle:
            self.pushOptions(title: "Стиль текста", options: ModTextStyle.allCases.map { (id: $0.rawValue, title: $0 == .none ? $0.title : "\($0.title)   — \($0.description)") }, selected: ModTextStyle.current.rawValue) { id in
                ModTextStyle.current = ModTextStyle(rawValue: id) ?? .none
            }
        case .maskMode:
            self.pushOptions(title: "Тип маски", options: ModFaceMaskMode.allCases.map { (id: $0.rawValue, title: $0.title) }, selected: ModFaceMaskMode.current.rawValue) { id in
                ModSettings.maskMode = id
            }
        case .maskPhoto:
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.delegate = self
            self.present(picker, animated: true)
        case .videoFilter:
            self.pushOptions(title: "Фильтр кружков", options: ModVideoFilter.allCases.map { (id: $0.rawValue, title: $0.title) }, selected: ModVideoFilter.current.rawValue) { id in
                ModVideoFilter.current = ModVideoFilter(rawValue: id) ?? .none
            }
        case .voicePreset:
            self.pushOptions(title: "Пресет голоса", options: ModVoicePreset.allCases.map { (id: $0.rawValue, title: $0.title) }, selected: ModSettings.voicePreset) { id in
                ModSettings.voicePreset = id
                if let config = ModVoicePreset(rawValue: id)?.config {
                    config.saveToSettings()
                }
            }
        case .voiceTest:
            self.voiceTester.run(seconds: 3.0, config: ModVoiceConfig.fromSettings())
        case .botsList:
            self.navigationController?.pushViewController(ModBotsController(), animated: true)
        case .effects:
            self.pushOptions(title: "Эффект", options: ChatEffect.allCases.map { (id: $0.rawValue, title: $0.title) }, selected: ChatEffect.current.rawValue) { [weak self] id in
                (ChatEffect(rawValue: id) ?? .default).save()
                self?.askForRestart(message: "Эффект появится после перезапуска.")
            }
        case .backupExport:
            self.exportSettings(sourceView: tableView.cellForRow(at: indexPath))
        case .backupImport:
            let picker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.propertyList, UTType.xml, UTType.data], asCopy: true)
            } else {
                picker = UIDocumentPickerViewController(documentTypes: ["com.apple.property-list", "public.xml", "public.data"], in: .import)
            }
            picker.delegate = self
            self.present(picker, animated: true)
        case .backupReset:
            let alert = UIAlertController(title: "Сбросить все настройки мода?", message: "Личные боты тоже удалятся.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { [weak self] _ in
                ModSettingsBackup.reset()
                self?.reloadStructure()
                self?.askForRestart(message: "Настройки сброшены.")
            }))
            self.present(alert, animated: true)
        default:
            break
        }
    }

    private func pushOptions(title: String, options: [(id: String, title: String)], selected: String, onSelect: @escaping (String) -> Void) {
        let controller = ModOptionsController(title: title, options: options, selected: selected, onSelect: { [weak self] id in
            onSelect(id)
            self?.reloadStructure()
        })
        self.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: Mask photo

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true)
        if let image {
            ModFaceMask.saveMaskPhoto(image)
            self.reload(row: .maskPhoto)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    // MARK: Backup

    private func exportSettings(sourceView: UIView?) {
        guard let url = ModSettingsBackup.exportToFile() else {
            return
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = sourceView ?? self.view
        self.present(controller, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        let success = ModSettingsBackup.importFromFile(url)
        self.reloadStructure()
        if success {
            self.askForRestart(message: "Настройки импортированы. Часть из них применится после перезапуска.")
        } else {
            let alert = UIAlertController(title: "Не удалось импортировать", message: "Файл не похож на настройки мода.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func askForRestart(message: String) {
        let alert = UIAlertController(title: "Нужен перезапуск", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Позже", style: .cancel))
        alert.addAction(UIAlertAction(title: "Перезапустить", style: .destructive, handler: { _ in
            exit(0)
        }))
        self.present(alert, animated: true)
    }
}
