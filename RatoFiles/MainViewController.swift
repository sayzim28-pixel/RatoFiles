import Foundation
import UIKit

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private var tableView: UITableView!
    private var currentURL: URL!
    private var fileItems: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Rato Files"
        view.backgroundColor = .systemBackground
        
        currentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        setupNavBar()
        setupTableView()
        loadFiles()
    }
    
    private func setupNavBar() {
        navigationItem.rightBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showCreateFolderAlert))
        navigationItem.leftBarButton = UIBarButtonItem(title: "Raiz", style: .plain, target: self, action: #selector(goToRoot))
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
    }
    
    private func loadFiles() {
        do {
            fileItems = try FileManager.default.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            tableView.reloadData()
        } catch {
            fileItems = []
        }
    }
    
    @objc private func goToRoot() {
        currentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadFiles()
    }
    
    @objc private func showCreateFolderAlert() {
        let alert = UIAlertController(title: "Rato Files", message: "Criar novo item na sandbox", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Nome do arquivo/pasta" }
        
        alert.addAction(UIAlertAction(title: "Pasta", style: .default, handler: { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let newDir = self.currentURL.appendingPathComponent(name)
            try? FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
            self.loadFiles()
        }))
        
        alert.addAction(UIAlertAction(title: "Arquivo", style: .default, handler: { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let newFile = self.currentURL.appendingPathComponent(name + ".txt")
            try? "Gerenciado por Rato Files".write(to: newFile, atomically: true, encoding: .utf8)
            self.loadFiles()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let url = fileItems[indexPath.row]
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        cell.textLabel?.text = url.lastPathComponent
        cell.imageView?.image = UIImage(systemName: isDir.boolValue ? "folder.fill" : "doc.text.fill")
        cell.accessoryType = isDir.boolValue ? .disclosureIndicator : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let url = fileItems[indexPath.row]
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        if isDir.boolValue {
            currentURL = url
            loadFiles()
        } else {
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Arquivo vazio"
            let alert = UIAlertController(title: url.lastPathComponent, message: content, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Fechar", style: .default))
            present(alert, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let url = fileItems[indexPath.row]
            try? FileManager.default.removeItem(at: url)
            fileItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}
