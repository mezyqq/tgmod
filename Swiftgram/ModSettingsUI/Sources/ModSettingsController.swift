import Foundation
import UIKit
import ModSettings
import ModFontOverride
import ModTypingAnimation
import ModVoice
import ModFaceMask

/// Entry point: the "Customization" screen wrapped into a navigation controller, to be presented modally.
public func modMakeSettingsController(isDark: Bool, accentColor: UIColor) -> UIViewController {
    let root = ModSettingsController()
    let navigationController = UINavigationController(rootViewController: root)
    navigationController.overrideUserInterfaceStyle = isDark ? .dark : .light
    navigationController.view.tintColor = accentColor
    navigationController.navigationBar.prefersLargeTitles = true
    return navigationController
}

private enum Section: Int, CaseIterable {
    case font
    case typing
    case mask
    case voice
}

private enum MaskRow {
    case enabled
    case mode
    case photo
    case circle
    case scale
    case followRotation
    case coverWhenLost
}

private func maskRows() -> [MaskRow] {
    if !ModSettings.maskEnabled {
        return [.enabled]
    }
    var rows: [MaskRow] = [.enabled, .mode]
    if ModFaceMaskMode.current == .photo {
        rows.append(contentsOf: [.photo, .circle])
    }
    rows.append(contentsOf: [.scale, .followRotation, .coverWhenLost])
    return rows
}

private enum TypingRow: Int, CaseIterable {
    case preview
    case style
    case duration
    case intensity
}

private enum VoiceRow: Int, CaseIterable {
    case enabled
    case preset
    case pitch
    case robot
    case echo
    case reverb
    case radio
    case gain
    case test
}

final class ModSettingsController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let voiceTester = ModVoiceTester()
    private var voiceTestStatus: String = "Проверить голос (запись 3 сек)"

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
            self.tableView.reloadRows(at: [IndexPath(row: VoiceRow.test.rawValue, section: Section.voice.rawValue)], with: .none)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent || self.navigationController?.isBeingDismissed == true {
            self.voiceTester.cancel()
        }
    }

    @objc private func donePressed() {
        self.voiceTester.cancel()
        self.dismiss(animated: true)
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .font:
            return 1
        case .typing:
            return TypingRow.allCases.count
        case .mask:
            return maskRows().count
        case .voice:
            return ModSettings.voiceEnabled ? VoiceRow.allCases.count : 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .font:
            return "Шрифт"
        case .typing:
            return "Анимация печати"
        case .mask:
            return "Маска в кружках"
        case .voice:
            return "Смена голоса"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .font:
            return "Шрифт применяется ко всему интерфейсу и сообщениям после перезапуска."
        case .typing:
            return "Напечатайте что-нибудь в поле выше, чтобы увидеть анимацию. Работает в поле ввода всех чатов."
        case .mask:
            return "Лицо в видеосообщениях закрывается маской: она находит лицо и следует за ним. «Закрывать при потере лица» не даст лицу мелькнуть, если распознавание на секунду сбилось."
        case .voice:
            return "Эффект применяется к голосовым сообщениям при записи. Собеседник услышит изменённый голос."
        }
    }

    private func switchCell(_ tableView: UITableView, title: String, value: Bool, onChange: @escaping (Bool) -> Void) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "switch") as? ModSwitchCell) ?? ModSwitchCell(style: .default, reuseIdentifier: "switch")
        cell.textLabel?.text = title
        cell.toggle.isOn = value
        cell.onChange = onChange
        return cell
    }

    private func valueCell(_ tableView: UITableView, title: String, value: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "value") ?? UITableViewCell(style: .value1, reuseIdentifier: "value")
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = value
        cell.accessoryType = .disclosureIndicator
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
            self.tableView.reloadRows(at: [IndexPath(row: VoiceRow.preset.rawValue, section: Section.voice.rawValue)], with: .none)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .font:
            let family = ModSettings.fontFamily
            return self.valueCell(tableView, title: "Шрифт", value: family.isEmpty ? "Системный" : family)
        case .typing:
            switch TypingRow(rawValue: indexPath.row)! {
            case .preview:
                let cell = (tableView.dequeueReusableCell(withIdentifier: "preview") as? ModTextPreviewCell) ?? ModTextPreviewCell(style: .default, reuseIdentifier: "preview")
                cell.onTextChange = { textView in
                    ModTypingAnimator.shared.textDidChange(inputView: textView, attributedText: textView.attributedText, selectedRange: textView.selectedRange)
                }
                return cell
            case .style:
                return self.valueCell(tableView, title: "Стиль", value: ModTypingStyle.current.title)
            case .duration:
                return self.sliderCell(tableView, title: "Длительность", value: ModSettings.typingDuration, range: 0.1 ... 1.0, format: { String(format: "%.2f с", $0) }, onChange: { value in
                    ModSettings.typingDuration = Double(value)
                })
            case .intensity:
                return self.sliderCell(tableView, title: "Сила", value: ModSettings.typingIntensity, range: 0.25 ... 2.0, format: { String(format: "×%.2f", $0) }, onChange: { value in
                    ModSettings.typingIntensity = Double(value)
                })
            }
        case .mask:
            switch maskRows()[indexPath.row] {
            case .enabled:
                return self.switchCell(tableView, title: "Маска", value: ModSettings.maskEnabled, onChange: { [weak self] value in
                    ModSettings.maskEnabled = value
                    self?.tableView.reloadSections(IndexSet(integer: Section.mask.rawValue), with: .automatic)
                })
            case .mode:
                return self.valueCell(tableView, title: "Тип", value: ModFaceMaskMode.current.title)
            case .photo:
                let cell = tableView.dequeueReusableCell(withIdentifier: "photo") ?? UITableViewCell(style: .default, reuseIdentifier: "photo")
                let photo = ModFaceMask.storedMaskPhoto()
                cell.textLabel?.text = photo == nil ? "Выбрать фото" : "Сменить фото"
                cell.textLabel?.textColor = self.view.tintColor
                cell.imageView?.image = photo.map { image in
                    UIGraphicsImageRenderer(size: CGSize(width: 40.0, height: 40.0)).image { _ in
                        let rect = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
                        if ModSettings.maskCircle {
                            UIBezierPath(ovalIn: rect).addClip()
                        }
                        image.draw(in: rect)
                    }
                }
                return cell
            case .circle:
                return self.switchCell(tableView, title: "Круглая маска", value: ModSettings.maskCircle, onChange: { [weak self] value in
                    ModSettings.maskCircle = value
                    self?.tableView.reloadSections(IndexSet(integer: Section.mask.rawValue), with: .none)
                })
            case .scale:
                return self.sliderCell(tableView, title: "Размер маски", value: ModSettings.maskScale, range: 1.0 ... 2.5, format: { String(format: "×%.2f", $0) }, onChange: { value in
                    ModSettings.maskScale = Double(value)
                })
            case .followRotation:
                return self.switchCell(tableView, title: "Поворачивать с головой", value: ModSettings.maskFollowRotation, onChange: { value in
                    ModSettings.maskFollowRotation = value
                })
            case .coverWhenLost:
                return self.switchCell(tableView, title: "Закрывать при потере лица", value: ModSettings.maskCoverWhenLost, onChange: { value in
                    ModSettings.maskCoverWhenLost = value
                })
            }
        case .voice:
            switch VoiceRow(rawValue: indexPath.row)! {
            case .enabled:
                let cell = (tableView.dequeueReusableCell(withIdentifier: "switch") as? ModSwitchCell) ?? ModSwitchCell(style: .default, reuseIdentifier: "switch")
                cell.textLabel?.text = "Менять голос"
                cell.toggle.isOn = ModSettings.voiceEnabled
                cell.onChange = { [weak self] value in
                    ModSettings.voiceEnabled = value
                    self?.tableView.reloadSections(IndexSet(integer: Section.voice.rawValue), with: .automatic)
                }
                return cell
            case .preset:
                return self.valueCell(tableView, title: "Пресет", value: (ModVoicePreset(rawValue: ModSettings.voicePreset) ?? .custom).title)
            case .pitch:
                return self.sliderCell(tableView, title: "Высота голоса (питч)", value: ModSettings.voicePitch, range: -12.0 ... 12.0, format: { String(format: "%+.1f полутон.", $0) }, onChange: { [weak self] value in
                    self?.voiceSliderChanged { $0.pitch = Double(value) }
                })
            case .robot:
                return self.sliderCell(tableView, title: "Робот", value: ModSettings.voiceRobot, range: 0.0 ... 1.0, format: { String(format: "%.0f%%", $0 * 100.0) }, onChange: { [weak self] value in
                    self?.voiceSliderChanged { $0.robot = Double(value) }
                })
            case .echo:
                return self.sliderCell(tableView, title: "Эхо", value: ModSettings.voiceEcho, range: 0.0 ... 1.0, format: { String(format: "%.0f%%", $0 * 100.0) }, onChange: { [weak self] value in
                    self?.voiceSliderChanged { $0.echo = Double(value) }
                })
            case .reverb:
                return self.sliderCell(tableView, title: "Реверберация", value: ModSettings.voiceReverb, range: 0.0 ... 1.0, format: { String(format: "%.0f%%", $0 * 100.0) }, onChange: { [weak self] value in
                    self?.voiceSliderChanged { $0.reverb = Double(value) }
                })
            case .radio:
                return self.sliderCell(tableView, title: "Рация", value: ModSettings.voiceRadio, range: 0.0 ... 1.0, format: { String(format: "%.0f%%", $0 * 100.0) }, onChange: { [weak self] value in
                    self?.voiceSliderChanged { $0.radio = Double(value) }
                })
            case .gain:
                return self.sliderCell(tableView, title: "Громкость", value: ModSettings.voiceGain, range: -6.0 ... 12.0, format: { String(format: "%+.1f дБ", $0) }, onChange: { [weak self] value in
                    self?.voiceSliderChanged { $0.gain = Double(value) }
                })
            case .test:
                let cell = tableView.dequeueReusableCell(withIdentifier: "button") ?? UITableViewCell(style: .default, reuseIdentifier: "button")
                cell.textLabel?.text = self.voiceTestStatus
                cell.textLabel?.textColor = self.view.tintColor
                return cell
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .font:
            let controller = ModFontPickerController(selected: ModSettings.fontFamily, onSelect: { [weak self] family in
                ModSettings.fontFamily = family
                self?.tableView.reloadData()
                self?.askForRestart()
            })
            self.navigationController?.pushViewController(controller, animated: true)
        case .typing:
            if indexPath.row == TypingRow.style.rawValue {
                let options = ModTypingStyle.allCases.map { (id: $0.rawValue, title: $0.title) }
                let controller = ModOptionsController(title: "Стиль анимации", options: options, selected: ModTypingStyle.current.rawValue, onSelect: { [weak self] id in
                    ModSettings.typingStyle = id
                    self?.tableView.reloadData()
                })
                self.navigationController?.pushViewController(controller, animated: true)
            }
        case .mask:
            switch maskRows()[indexPath.row] {
            case .mode:
                let options = ModFaceMaskMode.allCases.map { (id: $0.rawValue, title: $0.title) }
                let controller = ModOptionsController(title: "Тип маски", options: options, selected: ModFaceMaskMode.current.rawValue, onSelect: { [weak self] id in
                    ModSettings.maskMode = id
                    self?.tableView.reloadData()
                })
                self.navigationController?.pushViewController(controller, animated: true)
            case .photo:
                let picker = UIImagePickerController()
                picker.sourceType = .photoLibrary
                picker.allowsEditing = true
                picker.delegate = self
                self.present(picker, animated: true)
            default:
                break
            }
        case .voice:
            if indexPath.row == VoiceRow.preset.rawValue {
                let options = ModVoicePreset.allCases.map { (id: $0.rawValue, title: $0.title) }
                let controller = ModOptionsController(title: "Пресет голоса", options: options, selected: ModSettings.voicePreset, onSelect: { [weak self] id in
                    ModSettings.voicePreset = id
                    if let config = ModVoicePreset(rawValue: id)?.config {
                        config.saveToSettings()
                    }
                    self?.tableView.reloadData()
                })
                self.navigationController?.pushViewController(controller, animated: true)
            } else if indexPath.row == VoiceRow.test.rawValue {
                self.voiceTester.run(seconds: 3.0, config: ModVoiceConfig.fromSettings())
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true)
        if let image {
            ModFaceMask.saveMaskPhoto(image)
            self.tableView.reloadSections(IndexSet(integer: Section.mask.rawValue), with: .none)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    private func askForRestart() {
        let alert = UIAlertController(title: "Нужен перезапуск", message: "Шрифт применится после перезапуска приложения.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Позже", style: .cancel))
        alert.addAction(UIAlertAction(title: "Перезапустить", style: .destructive, handler: { _ in
            exit(0)
        }))
        self.present(alert, animated: true)
    }
}
