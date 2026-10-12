import Foundation
import UIKit
import ModSettings

/// List of personal bots (auto-reply rules).
final class ModBotsController: UITableViewController {
    private var rules: [ModBotRule] = []

    init() {
        super.init(style: .insetGrouped)
        self.title = "Личные боты"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addPressed))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rules = ModBotRules.rules
        self.tableView.reloadData()
    }

    private func save() {
        ModBotRules.rules = self.rules
    }

    @objc private func addPressed() {
        let sheet = UIAlertController(title: "Новый бот", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Пустой", style: .default, handler: { [weak self] _ in
            self?.openEditor(rule: ModBotRule(), isNew: true)
        }))
        for template in ModBotRules.templates {
            sheet.addAction(UIAlertAction(title: template.name, style: .default, handler: { [weak self] _ in
                var rule = template
                rule.id = UUID().uuidString
                self?.openEditor(rule: rule, isNew: true)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    private func openEditor(rule: ModBotRule, isNew: Bool) {
        let controller = ModBotEditorController(rule: rule, onSave: { [weak self] updated in
            guard let self else {
                return
            }
            if let index = self.rules.firstIndex(where: { $0.id == updated.id }) {
                self.rules[index] = updated
            } else {
                self.rules.append(updated)
            }
            self.save()
            self.tableView.reloadData()
        })
        controller.title = isNew ? "Новый бот" : rule.name
        self.navigationController?.pushViewController(controller, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rules.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if self.rules.isEmpty {
            return "Ботов пока нет. Нажмите «+», чтобы создать бота из шаблона или с нуля."
        }
        return "Отвечает первый подходящий бот. Свайп влево — удалить. Боты не отвечают другим ботам и каналам."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "rule") as? ModSwitchCell) ?? ModSwitchCell(style: .subtitle, reuseIdentifier: "rule")
        let rule = self.rules[indexPath.row]
        cell.selectionStyle = .default
        cell.textLabel?.text = rule.name
        var details = rule.trigger.title
        if rule.trigger != .any && !rule.pattern.isEmpty {
            details += ": \(rule.pattern)"
        }
        details += " · \(rule.scope.title)"
        cell.detailTextLabel?.text = details
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.toggle.isOn = rule.isEnabled
        cell.onChange = { [weak self] value in
            guard let self, let index = self.rules.firstIndex(where: { $0.id == rule.id }) else {
                return
            }
            self.rules[index].isEnabled = value
            self.save()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.openEditor(rule: self.rules[indexPath.row], isNew: false)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.rules.remove(at: indexPath.row)
            self.save()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}

private final class ModTextFieldCell: UITableViewCell, UITextFieldDelegate {
    let textField = UITextField()
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        self.textField.clearButtonMode = .whileEditing
        self.textField.autocorrectionType = .no
        self.textField.addTarget(self, action: #selector(self.changed), for: .editingChanged)
        self.textField.delegate = self
        self.contentView.addSubview(self.textField)
        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.textField.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.textField.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.textField.topAnchor.constraint(equalTo: margins.topAnchor),
            self.textField.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            self.textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 28.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func changed() {
        self.onChange?(self.textField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class ModTextViewCell: UITableViewCell, UITextViewDelegate {
    let textView = UITextView()
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.textView.font = UIFont.preferredFont(forTextStyle: .body)
        self.textView.backgroundColor = .clear
        self.textView.isScrollEnabled = false
        self.textView.delegate = self
        self.contentView.addSubview(self.textView)
        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.textView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: -4.0),
            self.textView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.textView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 4.0),
            self.textView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -4.0),
            self.textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textViewDidChange(_ textView: UITextView) {
        self.onChange?(textView.text)
        // Let the table grow with the text.
        if let tableView = self.superview as? UITableView ?? self.superview?.superview as? UITableView {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }
}

/// Editor of one personal bot.
final class ModBotEditorController: UITableViewController {
    private enum Row {
        case name
        case enabled
        case trigger
        case pattern
        case reply
        case scope
        case onlyWhenInactive
        case quote
        case delay
        case cooldown
    }

    private var rule: ModBotRule
    private let onSave: (ModBotRule) -> Void

    private var sections: [(title: String, footer: String?, rows: [Row])] {
        var triggerRows: [Row] = [.trigger]
        if self.rule.trigger != .any {
            triggerRows.append(.pattern)
        }
        return [
            (title: "Бот", footer: nil, rows: [.name, .enabled]),
            (title: "Когда отвечать", footer: self.triggerFooter, rows: triggerRows),
            (title: "Ответ", footer: "Подстановки: {name} — имя собеседника, {text} — его сообщение, {time} — время, {date} — дата.", rows: [.reply]),
            (title: "Где", footer: nil, rows: [.scope, .onlyWhenInactive, .quote]),
            (title: "Тайминг", footer: "Пауза — задержка перед ответом. Перерыв — не отвечать в том же чате чаще этого.", rows: [.delay, .cooldown])
        ]
    }

    private var triggerFooter: String? {
        switch self.rule.trigger {
        case .any: return "Бот ответит на любое входящее сообщение (не чаще, чем раз в «перерыв»)."
        case .contains: return "Несколько слов — через запятую. Регистр не важен."
        case .exact: return "Сообщение должно совпадать полностью. Регистр не важен."
        case .startsWith: return "Сообщение должно начинаться с этого текста."
        case .regex: return "Например: ^\\d{4}$ — сообщение из четырёх цифр."
        }
    }

    init(rule: ModBotRule, onSave: @escaping (ModBotRule) -> Void) {
        self.rule = rule
        self.onSave = onSave
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.keyboardDismissMode = .onDrag
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(self.savePressed))
    }

    @objc private func savePressed() {
        self.view.endEditing(true)
        if self.rule.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let alert = UIAlertController(title: "Пустой ответ", message: "Напишите, что бот должен отвечать.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        if self.rule.trigger == .regex && (try? NSRegularExpression(pattern: self.rule.pattern)) == nil {
            let alert = UIAlertController(title: "Ошибка в выражении", message: "Регулярное выражение не распознано.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        self.onSave(self.rule)
        self.navigationController?.popViewController(animated: true)
    }

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

    private func switchCell(title: String, value: Bool, onChange: @escaping (Bool) -> Void) -> UITableViewCell {
        let cell = (self.tableView.dequeueReusableCell(withIdentifier: "switch") as? ModSwitchCell) ?? ModSwitchCell(style: .default, reuseIdentifier: "switch")
        cell.textLabel?.text = title
        cell.toggle.isOn = value
        cell.onChange = onChange
        return cell
    }

    private func sliderCell(title: String, value: Double, range: ClosedRange<Float>, format: @escaping (Float) -> String, onChange: @escaping (Float) -> Void) -> UITableViewCell {
        let cell = (self.tableView.dequeueReusableCell(withIdentifier: "slider") as? ModSliderCell) ?? ModSliderCell(style: .default, reuseIdentifier: "slider")
        cell.configure(title: title, value: Float(value), range: range, format: format, onChange: onChange)
        return cell
    }

    private func valueCell(title: String, value: String) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "value") ?? UITableViewCell(style: .value1, reuseIdentifier: "value")
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = value
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch self.sections[indexPath.section].rows[indexPath.row] {
        case .name:
            let cell = (tableView.dequeueReusableCell(withIdentifier: "field") as? ModTextFieldCell) ?? ModTextFieldCell(style: .default, reuseIdentifier: "field")
            cell.textField.placeholder = "Название"
            cell.textField.text = self.rule.name
            cell.onChange = { [weak self] text in
                self?.rule.name = text
            }
            return cell
        case .enabled:
            return self.switchCell(title: "Включён", value: self.rule.isEnabled, onChange: { [weak self] value in
                self?.rule.isEnabled = value
            })
        case .trigger:
            return self.valueCell(title: "Условие", value: self.rule.trigger.title)
        case .pattern:
            let cell = (tableView.dequeueReusableCell(withIdentifier: "field") as? ModTextFieldCell) ?? ModTextFieldCell(style: .default, reuseIdentifier: "field")
            cell.textField.placeholder = self.rule.trigger == .contains ? "привет, здравствуй" : "Текст"
            cell.textField.text = self.rule.pattern
            cell.onChange = { [weak self] text in
                self?.rule.pattern = text
            }
            return cell
        case .reply:
            let cell = (tableView.dequeueReusableCell(withIdentifier: "textView") as? ModTextViewCell) ?? ModTextViewCell(style: .default, reuseIdentifier: "textView")
            cell.textView.text = self.rule.reply
            cell.onChange = { [weak self] text in
                self?.rule.reply = text
            }
            return cell
        case .scope:
            return self.valueCell(title: "Чаты", value: self.rule.scope.title)
        case .onlyWhenInactive:
            return self.switchCell(title: "Только когда я не в приложении", value: self.rule.onlyWhenAppInactive, onChange: { [weak self] value in
                self?.rule.onlyWhenAppInactive = value
            })
        case .quote:
            return self.switchCell(title: "Отвечать с цитатой", value: self.rule.replyWithQuote, onChange: { [weak self] value in
                self?.rule.replyWithQuote = value
            })
        case .delay:
            return self.sliderCell(title: "Пауза перед ответом", value: self.rule.delaySeconds, range: 0.0 ... 30.0, format: { String(format: "%.0f с", $0) }, onChange: { [weak self] value in
                self?.rule.delaySeconds = Double(value.rounded())
            })
        case .cooldown:
            return self.sliderCell(title: "Перерыв в одном чате", value: self.rule.cooldownMinutes, range: 0.0 ... 1440.0, format: { value in
                let minutes = Int(value.rounded())
                if minutes == 0 {
                    return "нет"
                } else if minutes < 60 {
                    return "\(minutes) мин"
                } else {
                    return String(format: "%.1f ч", Double(minutes) / 60.0)
                }
            }, onChange: { [weak self] value in
                self?.rule.cooldownMinutes = Double(value.rounded())
            })
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch self.sections[indexPath.section].rows[indexPath.row] {
        case .trigger:
            let options = ModBotRule.Trigger.allCases.map { (id: $0.rawValue, title: $0.title) }
            let controller = ModOptionsController(title: "Условие", options: options, selected: self.rule.trigger.rawValue, onSelect: { [weak self] id in
                self?.rule.trigger = ModBotRule.Trigger(rawValue: id) ?? .contains
                self?.tableView.reloadData()
            })
            self.navigationController?.pushViewController(controller, animated: true)
        case .scope:
            let options = ModBotRule.Scope.allCases.map { (id: $0.rawValue, title: $0.title) }
            let controller = ModOptionsController(title: "Чаты", options: options, selected: self.rule.scope.rawValue, onSelect: { [weak self] id in
                self?.rule.scope = ModBotRule.Scope(rawValue: id) ?? .privateChats
                self?.tableView.reloadData()
            })
            self.navigationController?.pushViewController(controller, animated: true)
        default:
            break
        }
    }
}
