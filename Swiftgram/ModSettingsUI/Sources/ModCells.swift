import Foundation
import UIKit

final class ModSliderCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    let slider = UISlider()

    var format: (Float) -> String = { String(format: "%.2f", $0) }
    var onChange: ((Float) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.titleLabel.font = UIFont.systemFont(ofSize: 16.0)
        self.valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15.0, weight: .regular)
        self.valueLabel.textColor = .secondaryLabel
        self.valueLabel.textAlignment = .right
        self.slider.addTarget(self, action: #selector(self.sliderChanged), for: .valueChanged)

        for view in [self.titleLabel, self.valueLabel, self.slider] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }
        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.titleLabel.topAnchor.constraint(equalTo: margins.topAnchor),
            self.valueLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.valueLabel.firstBaselineAnchor.constraint(equalTo: self.titleLabel.firstBaselineAnchor),
            self.valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: self.titleLabel.trailingAnchor, constant: 8.0),
            self.slider.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.slider.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.slider.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 8.0),
            self.slider.bottomAnchor.constraint(equalTo: margins.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, value: Float, range: ClosedRange<Float>, format: @escaping (Float) -> String, onChange: @escaping (Float) -> Void) {
        self.titleLabel.text = title
        self.slider.minimumValue = range.lowerBound
        self.slider.maximumValue = range.upperBound
        self.slider.value = value
        self.format = format
        self.onChange = onChange
        self.valueLabel.text = format(value)
    }

    @objc private func sliderChanged() {
        self.valueLabel.text = self.format(self.slider.value)
        self.onChange?(self.slider.value)
    }
}

final class ModSwitchCell: UITableViewCell {
    let toggle = UISwitch()
    var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.accessoryView = self.toggle
        self.toggle.addTarget(self, action: #selector(self.switchChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func switchChanged() {
        self.onChange?(self.toggle.isOn)
    }
}

/// A text view to try the typing animation.
final class ModTextPreviewCell: UITableViewCell, UITextViewDelegate {
    let textView = UITextView()
    var onTextChange: ((UITextView) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.textView.font = UIFont.systemFont(ofSize: 17.0)
        self.textView.backgroundColor = .clear
        self.textView.isScrollEnabled = false
        self.textView.delegate = self
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.textView)
        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.textView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.textView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 4.0),
            self.textView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -4.0),
            self.textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textViewDidChange(_ textView: UITextView) {
        self.onTextChange?(textView)
    }
}

/// Generic single choice list.
final class ModOptionsController: UITableViewController {
    private let options: [(id: String, title: String)]
    private var selected: String
    private let onSelect: (String) -> Void

    init(title: String, options: [(id: String, title: String)], selected: String, onSelect: @escaping (String) -> Void) {
        self.options = options
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "option") ?? UITableViewCell(style: .default, reuseIdentifier: "option")
        let option = self.options[indexPath.row]
        cell.textLabel?.text = option.title
        cell.accessoryType = option.id == self.selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.selected = self.options[indexPath.row].id
        tableView.reloadData()
        self.onSelect(self.selected)
    }
}
