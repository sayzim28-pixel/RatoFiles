import SwiftUI
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64?
    let modifiedAt: Date?

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

struct FileBrowserView: View {
    @State private var files: [FileItem] = []
    @State private var showImporter = false
    @State private var shareItems: [Any] = []
    @State private var copiedItem: FileItem?
    @State private var replacementTarget: FileItem?
    @State private var itemToRename: FileItem?
    @State private var itemToDelete: FileItem?
    @State private var message: String?

    private let fileManager = FileManager.default

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    VStack(spacing: 14) {
                        Image("RatMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 170)
                        Text("Sua pasta está vazia")
                            .font(.title3.weight(.semibold))
                        Text("Toque em Importar para trazer arquivos do app Arquivos.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    List(files) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.isDirectory ? "folder.fill" : iconName(for: item.url))
                                .foregroundStyle(item.isDirectory ? .blue : .secondary)
                                .font(.title3)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).lineLimit(1)
                                Text(detail(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button { copiedItem = item } label: {
                                Label("Copiar", systemImage: "doc.on.doc")
                            }
                            Button { duplicate(item) } label: {
                                Label("Duplicar", systemImage: "plus.square.on.square")
                            }
                            Button { replacementTarget = item; showImporter = true } label: {
                                Label("Substituir", systemImage: "arrow.triangle.2.circlepath")
                            }
                            Button { itemToRename = item } label: {
                                Label("Renomear", systemImage: "pencil")
                            }
                            Button { shareItems = [item.url] } label: {
                                Label("Compartilhar", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) { itemToDelete = item } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                    .refreshable { reloadFiles() }
                }
            }
            .navigationTitle("Rato Files")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { showImporter = true } label: {
                            Label("Acessar arquivos", systemImage: "folder")
                        }
                        if copiedItem != nil {
                            Button { pasteCopiedItem() } label: {
                                Label("Colar", systemImage: "doc.on.clipboard")
                            }
                        }
                    } label: {
                        Label("Ações", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: {
                        Label("Importar", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                DocumentImporter { urls in
                    if let replacementTarget, let sourceURL = urls.first {
                        replace(replacementTarget, with: sourceURL)
                        self.replacementTarget = nil
                    } else {
                        importFiles(urls)
                    }
                }
            }
            .sheet(item: $itemToRename) { item in
                RenameSheet(file: item, onSave: rename)
            }
            .sheet(isPresented: Binding(get: { !shareItems.isEmpty }, set: { if !$0 { shareItems = [] } })) {
                ActivityView(items: shareItems)
            }
            .alert("Excluir arquivo?", isPresented: Binding(get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } })) {
                Button("Cancelar", role: .cancel) { itemToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let itemToDelete { delete(itemToDelete) }
                    itemToDelete = nil
                }
            } message: {
                Text("Essa ação remove o arquivo da pasta do Rato Files.")
            }
            .alert("Rato Files", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .onAppear(perform: reloadFiles)
        }
    }

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func reloadFiles() {
        do {
            files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
                .map { url in
                    let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                    return FileItem(url: url, isDirectory: values?.isDirectory ?? false, size: values?.fileSize.map(Int64.init), modifiedAt: values?.contentModificationDate)
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            message = "Não foi possível carregar os arquivos: \(error.localizedDescription)"
        }
    }

    private func importFiles(_ urls: [URL]) {
        for sourceURL in urls {
            let destination = availableURL(for: sourceURL.lastPathComponent)
            do {
                try fileManager.copyItem(at: sourceURL, to: destination)
            } catch {
                message = "Não foi possível importar \(sourceURL.lastPathComponent)."
            }
        }
        reloadFiles()
    }

    private func pasteCopiedItem() {
        guard let copiedItem else { return }
        do {
            try fileManager.copyItem(at: copiedItem.url, to: availableURL(for: copiedItem.name))
            reloadFiles()
        } catch {
            message = "Não foi possível colar o arquivo."
        }
    }

    private func duplicate(_ item: FileItem) {
        do {
            try fileManager.copyItem(at: item.url, to: availableURL(for: item.name))
            reloadFiles()
        } catch {
            message = "Não foi possível duplicar o arquivo."
        }
    }

    private func replace(_ item: FileItem, with sourceURL: URL) {
        let temporaryURL = documentsURL.appendingPathComponent(".replacement-\(UUID().uuidString)")
        do {
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            _ = try fileManager.replaceItemAt(item.url, withItemAt: temporaryURL, backupItemName: nil, options: [])
            reloadFiles()
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            message = "Não foi possível substituir o arquivo."
        }
    }

    private func rename(_ item: FileItem, to name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        do {
            try fileManager.moveItem(at: item.url, to: documentsURL.appendingPathComponent(cleanName))
            reloadFiles()
        } catch {
            message = "Não foi possível renomear o arquivo."
        }
    }

    private func delete(_ item: FileItem) {
        do { try fileManager.removeItem(at: item.url); reloadFiles() }
        catch { message = "Não foi possível excluir o arquivo." }
    }

    private func availableURL(for name: String) -> URL {
        let original = documentsURL.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: original.path) else { return original }
        let ext = original.pathExtension
        let base = original.deletingPathExtension().lastPathComponent
        var counter = 2
        while fileManager.fileExists(atPath: documentsURL.appendingPathComponent("\(base) \(counter)\(ext.isEmpty ? "" : ".\(ext)")").path) { counter += 1 }
        return documentsURL.appendingPathComponent("\(base) \(counter)\(ext.isEmpty ? "" : ".\(ext)")")
    }

    private func iconName(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic": return "photo"
        case "pdf": return "doc.richtext"
        case "mp3", "m4a", "wav": return "music.note"
        case "mp4", "mov": return "film"
        default: return "doc"
        }
    }

    private func detail(for item: FileItem) -> String {
        if item.isDirectory { return "Pasta" }
        return item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Arquivo"
    }
}
