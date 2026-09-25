import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let dillSave = UTType(exportedAs: "app.littledill.save", conformingTo: .data)
}

struct DillSaveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.dillSave] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw DillBackupError.unreadable }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum BackupText {
    static let exported = "Your encrypted backup is saved. Keep the .dill file to restore your pickle on any device."
    static let restored = "Your pickle is restored and saved on this device. You can undo this import until you close the app."
    static let undone = "Import undone. Your previous pickle is saved on this device again."
    static let openFailed = "This save could not be opened. Your current pickle is safe."
}

enum DillBackupFile {
    /// Matches the web name: `little-dill-` + toISOString() with `:` and `.` replaced by `-`, without the extension.
    static func basename(at date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: ".", with: "-")
        return "little-dill-" + stamp
    }
    static func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if let size, size > DillBackup.MAX_FILE_BYTES { throw DillBackupError.fileTooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: DillBackup.MAX_FILE_BYTES + 1) ?? Data()
        guard data.count <= DillBackup.MAX_FILE_BYTES else { throw DillBackupError.fileTooLarge }
        return data
    }
    static func shareURL(_ data: Data, filename: String = DillBackupFile.basename() + ".dill") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
    static func isCancel(_ error: Error) -> Bool { (error as? CocoaError)?.code == .userCancelled }
}

struct BackupLoad: Identifiable {
    let id = UUID()
    var preview: BackupPreview? = nil
    var error: String? = nil

    @MainActor static func open(_ url: URL, store: DillStore) -> BackupLoad {
        do {
            let data = try DillBackupFile.read(url)
            return BackupLoad(preview: try store.previewBackup(data))
        } catch let error as DillBackupError {
            return BackupLoad(error: error.message)
        } catch {
            return BackupLoad(error: BackupText.openFailed)
        }
    }
    /// Returns nil when the picker was cancelled.
    @MainActor static func open(_ result: Result<[URL], Error>, store: DillStore) -> BackupLoad? {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return nil }
            return open(url, store: store)
        case .failure(let error):
            return DillBackupFile.isCancel(error) ? nil : BackupLoad(error: BackupText.openFailed)
        }
    }
}

struct BackupShare: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor struct BackupPreviewSheet: View {
    @EnvironmentObject private var store: DillStore
    @Environment(\.dismiss) private var dismiss
    @State private var load: BackupLoad
    @State private var choosing = false
    @State private var outcome: String?
    private let restored: (() -> Void)?
    private let close: (() -> Void)?

    /// With `restored`, the caller shows the result. Without it, the sheet stays open to show the result and Undo.
    init(load: BackupLoad, restored: (() -> Void)? = nil, close: (() -> Void)? = nil) {
        _load = State(initialValue: load)
        self.restored = restored
        self.close = close
    }

    var body: some View {
        NavigationStack {
            Form {
                if let outcome { outcomeSection(outcome) } else { pickSections }
            }
            .accessibilityIdentifier("backup.preview")
            .navigationTitle("Welcome back, little dill.").navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var pickSections: some View {
        Section { Text("Your save stays on this device. Check your pickle before restoring it.") }
        if let preview = load.preview { previewSection(preview) }
        if let error = load.error {
            Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("backup.error") }
        }
        Section {
            if let preview = load.preview {
                Button("Restore this pickle") { restore(preview) }.fontWeight(.semibold).accessibilityIdentifier("backup.restore")
            }
            Button("Choose another file") { choosing = true }
                .fileImporter(isPresented: $choosing, allowedContentTypes: [.dillSave, .json, .data], allowsMultipleSelection: false) { result in
                    if let next = BackupLoad.open(result, store: store) { load = next }
                }
            Button("Cancel", role: .cancel) { finish() }.accessibilityIdentifier("backup.cancel")
        }
    }

    private func outcomeSection(_ text: String) -> some View {
        Section {
            Text(text).accessibilityIdentifier("backup.notice")
            if store.canUndoRestore {
                Button("Undo import") { if store.undoRestore() { outcome = BackupText.undone } }.accessibilityIdentifier("backup.undo")
            }
            Button("Done") { finish() }.fontWeight(.semibold).accessibilityIdentifier("backup.done")
        } header: {
            Text(text == BackupText.undone ? "Import undone" : "Pickle restored")
        }
    }

    private func finish() {
        if let close { close() } else { dismiss() }
    }

    private func previewSection(_ preview: BackupPreview) -> some View {
        Section {
            Text("Saved " + preview.savedAt.formatted(date: .abbreviated, time: .shortened))
            ForEach(preview.rows, id: \.label) { row in LabeledContent(row.label, value: row.value) }
        } header: {
            Text("Your pickle, as saved.")
        } footer: {
            Text("Restoring replaces your current pickle. Real elapsed time will apply at the daily care pace. You can undo the import until you close the app.")
        }
    }

    private func restore(_ preview: BackupPreview) {
        store.restoreBackup(preview)
        store.feedback(.medium)
        if let restored { restored(); finish() } else { outcome = BackupText.restored }
    }
}

@MainActor struct BackupSection: View {
    @EnvironmentObject private var store: DillStore
    @State private var exporting = false
    @State private var document: DillSaveDocument?
    @State private var filename = ""
    @State private var share: BackupShare?
    @State private var importing = false
    @State private var load: BackupLoad?
    @State private var notice: String?

    var body: some View {
        Section {
            Button { export() } label: { Label("Export save", systemImage: "square.and.arrow.down") }
                .accessibilityIdentifier("backup.export")
                .fileExporter(isPresented: $exporting, document: document, contentType: .dillSave, defaultFilename: filename) { result in
                    if case .failure(let error) = result {
                        if !DillBackupFile.isCancel(error) { notice = DillBackupError.exportFailed.message }
                    } else { notice = BackupText.exported }
                    document = nil
                }
            Button { shareSave() } label: { Label("Share save", systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier("backup.share")
                .sheet(item: $share) { item in ShareSheet(items: [item.url]).presentationDetents([.medium, .large]) }
            Button { importing = true } label: { Label("Import save", systemImage: "tray.and.arrow.down") }
                .accessibilityIdentifier("backup.import")
                .fileImporter(isPresented: $importing, allowedContentTypes: [.dillSave, .json, .data], allowsMultipleSelection: false) { result in
                    load = BackupLoad.open(result, store: store)
                }
                .sheet(item: $load) { item in
                    BackupPreviewSheet(load: item, restored: { notice = BackupText.restored }).environmentObject(store)
                }
            if store.canUndoRestore {
                Button { undo() } label: { Label("Undo import", systemImage: "arrow.uturn.backward") }
                    .accessibilityIdentifier("backup.undo")
            }
            if let recovery = store.recoveryCopy {
                Button { shareRecovery(recovery) } label: { Label("Share recovery copy", systemImage: "doc.badge.ellipsis") }
                    .accessibilityIdentifier("backup.recovery")
            }
            if let notice {
                Text(notice).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("backup.notice")
            }
        } header: {
            Text("Backups")
        } footer: {
            Text("Export keeps an encrypted .dill backup. Import restores it on this or another device, including the browser game. No password or account is needed.")
        }
    }

    private func export() {
        do {
            document = DillSaveDocument(data: try store.exportBackup())
            filename = DillBackupFile.basename()
            exporting = true
        } catch { notice = DillBackupError.exportFailed.message }
    }

    private func shareSave() {
        do {
            let data = try store.exportBackup()
            share = BackupShare(url: try DillBackupFile.shareURL(data))
        } catch { notice = DillBackupError.exportFailed.message }
    }

    /// The recovery copy is the raw on-device save, so it is shared as JSON instead of an encrypted .dill.
    private func shareRecovery(_ data: Data) {
        do { share = BackupShare(url: try DillBackupFile.shareURL(data, filename: "little-dill-recovery.json")) }
        catch { notice = DillBackupError.exportFailed.message }
    }

    private func undo() {
        if store.undoRestore() { notice = BackupText.undone }
    }
}

@MainActor struct DillBackupOpening: ViewModifier {
    @EnvironmentObject private var store: DillStore

    func body(content: Content) -> some View {
        content.onOpenURL { url in
            guard url.isFileURL, url.pathExtension.lowercased() == "dill" else { return }
            let load = BackupLoad.open(url, store: store)
            if url.path.contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
            BackupPresenter.present(load, store: store)
        }
    }
}

/// Presents over the topmost controller so an opened file shows above any sheet or full-screen cover.
@MainActor enum BackupPresenter {
    static func present(_ load: BackupLoad, store: DillStore) {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        guard var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController else { return }
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        weak var host: UIViewController?
        let controller = UIHostingController(rootView: AnyView(
            BackupPreviewSheet(load: load, close: { host?.dismiss(animated: true) }).environmentObject(store)))
        host = controller
        top.present(controller, animated: true)
    }
}

extension View {
    /// Presents the backup preview when the system opens a `.dill` file in the app. Non-file URLs pass through.
    @MainActor func dillBackupOpening() -> some View { modifier(DillBackupOpening()) }
}
