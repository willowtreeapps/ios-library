/* Copyright Urban Airship and Contributors */

import UIKit
import AirshipKit


class CustomPropertyStringsTableViewController: UITableViewController {
    let addStringsSegue:String = "addStringsSegue"
    var stringProperties:Array<String>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let addButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem:.add, target: self, action: #selector(CustomPropertyStringsTableViewController.addString))
        navigationItem.rightBarButtonItem = addButton

        tableView.delegate = self
        tableView.dataSource = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);

        let customPropertyTVC = self.navigationController?.viewControllers[2] as! CustomPropertyTableViewController
        stringProperties = customPropertyTVC.stringProperties

        tableView.reloadData()
    }

    @objc func addString () {
        performSegue(withIdentifier: addStringsSegue, sender: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let strings = stringProperties {
            return strings.count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "stringCell", for: indexPath)

        if cell.isEqual(nil) {
            cell = UITableViewCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier:"stringCell")
        }

        if let strings = stringProperties {
            cell.textLabel!.text = strings[indexPath.row]
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle:UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let customPropertyTVC = self.navigationController?.viewControllers[2] as! CustomPropertyTableViewController

        if (editingStyle == .delete &&
            tableView.cellForRow(at: indexPath)?.textLabel?.text?.isEmpty == false) {

            stringProperties?.remove(at:indexPath.row)
            customPropertyTVC.stringProperties = stringProperties!
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
