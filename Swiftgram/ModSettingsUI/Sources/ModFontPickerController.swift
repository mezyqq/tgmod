import Foundation
import UIKit
import UniformTypeIdentifiers
import ModSettings
import ModFontOverride

/// List of font families, each drawn with itself. Empty id = system font.
final class ModFontPickerController: UITableViewController, UISearchResultsUpdating, UIDocumentPickerDelegate {
    private var families: [String] = []
    private var imported: Set<String> = []
    private var filtered: [String] = []
    private var selected: String
    private let onSelect: (String) -> Void
    private let searchController = UISearchController(searchResultsController: nil)

    init(selected: String, onSelect: @escaping (String) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        self.title = "Шрифт"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.placeholder = "Поиск шрифта"
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Импорт", style: .plain, target: self, action: #selector(self.importPressed))
        self.reloadFamilies()
    }

    private func reloadFamilies() {
        self.families = ModFontOverride.availableFamilies()
        self.imported = Set(ModFontOverride.importedFamilies())
        self.applyFilter()
    }

    private func applyFilter() {
        let query = self.searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if query.isEmpty {
            self.filtered = self.families
        } else {
            self.filtered = self.families.filter { $0.localizedCaseInsensitiveContains(query) }
        }
        self.tableView.reloadData()
    }

    func updateSearchResults(for searchController: UISearchController) {
        self.applyFilter()
    }

    // MARK: Import

    @objc private func importPressed() {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.font], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.font", "public.truetype-ttf-font", "public.opentype-font"], in: .import)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = true
        self.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var lastFamily: String?
        var failed: [String] = []
        for url in urls {
            if let family = ModFontOverride.importFontFile(at: url) {
                lastFamily = family
            } else {
                failed.append(url.lastPathComponent)
            }
        }
        self.reloadFamilies()
        if !failed.isEmpty {
            let alert = UIAlertController(title: "Не удалось импортировать", message: failed.joined(separator: "\n"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        } else if let lastFamily {
            self.select(family: lastFamily)
        }
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : self.filtered.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Шрифт меняется во всём приложении после перезапуска. Свои шрифты .ttf / .otf можно добавить кнопкой «Импорт», удалить — свайпом влево."
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "font") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "font")
        if indexPath.section == 0 {
            cell.textLabel?.text = "Системный (San Francisco)"
            cell.textLabel?.font = UIFont(name: ".SFUI-Regular", size: 17.0) ?? UIFont.preferredFont(forTextStyle: .body)
            cell.detailTextLabel?.text = nil
            cell.accessoryType = self.selected.isEmpty ? .checkmark : .none
        } else {
            let family = self.filtered[indexPath.row]
            cell.textLabel?.text = family
            if let name = UIFont.fontNames(forFamilyName: family).first, let font = UIFont(name: name, size: 17.0) {
                cell.textLabel?.font = font
            }
            cell.detailTextLabel?.text = self.imported.contains(family) ? "Импортирован · Съешь же ещё этих мягких булок" : "Съешь же ещё этих мягких булок"
            if let name = UIFont.fontNames(forFamilyName: family).first, let font = UIFont(name: name, size: 13.0) {
                cell.detailTextLabel?.font = font
            }
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryType = family == self.selected ? .checkmark : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.select(family: indexPath.section == 0 ? "" : self.filtered[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && self.imported.contains(self.filtered[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.section == 1 else {
            return
        }
        let family = self.filtered[indexPath.row]
        ModFontOverride.removeImportedFamily(family)
        if family == self.selected {
            self.select(family: "")
        }
        self.reloadFamilies()
    }

    private func select(family: String) {
        self.selected = family
        self.tableView.reloadData()
        self.onSelect(family)
    }
}
