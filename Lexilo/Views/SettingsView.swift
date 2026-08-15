import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    @AppStorage("newWordLimit") private var newWordLimit = 5
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("kittenVoiceID") private var kittenVoiceID = 1
    @AppStorage("kittenSpeechRate") private var kittenSpeechRate = 1.0
    @AppStorage("pronunciationLocale") private var pronunciationLocale = "en-US"
    @AppStorage("vocabularyBand") private var vocabularyBand = VocabularyBand.intermediate.rawValue
    @AppStorage("includePhrases") private var includePhrases = false
    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationLanguage") private var translationLanguage = "Spanish"
    @State private var iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    @State private var rotationMessage: String?
    @State private var showingImport = false
    @State private var showingRestore = false
    @State private var showingExporter = false
    @State private var backupDocument = LexiloBackupDocument()
    @State private var portabilityMessage: String?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Form {
                    Section("Daily practice") {
                        Stepper("Words per round: \(newWordLimit)", value: $newWordLimit, in: 5...20, step: 5)
                        Text("Start with one short round. You can always continue or repeat today’s words.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Pronunciation") {
                        Text("Pronunciation works offline and stays on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("Play pronunciation", isOn: $soundEnabled)
                        Picker("Neural voice", selection: $kittenVoiceID) {
                            ForEach(KittenVoice.all) { voice in
                                Text(voice.name).tag(voice.id)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Neural speech rate: \(kittenSpeechRate, specifier: "%.1f")×")
                            Slider(value: $kittenSpeechRate, in: 0.7...1.2, step: 0.1)
                        }
                        Picker("System fallback accent", selection: $pronunciationLocale) {
                            Text("American English").tag("en-US")
                            Text("British English").tag("en-GB")
                        }
                    }
                    Section("Vocabulary") {
                        Picker("Vocabulary level", selection: $vocabularyBand) {
                            ForEach(VocabularyBand.allCases) { band in
                                Text(band.title).tag(band.rawValue)
                            }
                        }
                        Text("Upcoming words match the level you choose.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("Include phrases", isOn: $includePhrases)
                        Button {
                            let count = store.replaceUnstartedSuggestions()
                            rotationMessage = count > 0 ? "Prepared \(count) new suggestions" : "Your current learning queue is already in progress"
                        } label: {
                            Label("Refresh upcoming words", systemImage: "arrow.triangle.2.circlepath")
                        }
                        if let rotationMessage {
                            Text(rotationMessage).font(.caption).foregroundStyle(.secondary)
                        }
                        NavigationLink("Dictionary sources and licenses") {
                            LexiconLicensesView()
                        }
                    }
                    Section("Language support") {
                        Toggle("Show first-language support", isOn: $translationEnabled)
                        if translationEnabled {
                            Picker("First language", selection: $translationLanguage) {
                                ForEach(["Spanish", "Simplified Chinese", "Japanese", "Korean", "French", "German", "Other"], id: \.self) { Text($0) }
                            }
                                Text("English definitions stay primary. Personal translations remain clearly labeled.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("Your data") {
                        Button { showingImport = true } label: { Label("Import CSV or TSV", systemImage: "tablecells") }
                        Button {
                            do {
                                backupDocument = LexiloBackupDocument(data: try store.exportData())
                                showingExporter = true
                            } catch {
                                portabilityMessage = error.localizedDescription
                            }
                        } label: { Label("Export Lexilo backup", systemImage: "square.and.arrow.up") }
                        Button { showingRestore = true } label: { Label("Restore backup", systemImage: "arrow.counterclockwise") }
                        Toggle("Sync backup with iCloud", isOn: Binding(
                            get: { iCloudSyncEnabled },
                            set: { requested in
                                if store.setICloudSync(enabled: requested) {
                                    iCloudSyncEnabled = requested
                                    portabilityMessage = requested ? "iCloud sync is on" : "iCloud sync is off; local learning is unchanged"
                                } else {
                                    iCloudSyncEnabled = false
                                    portabilityMessage = "iCloud Drive is unavailable. Your local data is unchanged."
                                }
                            }
                        ))
                        if let portabilityMessage { Text(portabilityMessage).font(.caption).foregroundStyle(.secondary) }
                        Text("Your learning stays on this device unless you choose iCloud sync or export a backup.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section {
                        HStack { Text("Lexilo"); Spacer(); Text("Version \(appVersion)").foregroundStyle(.secondary) }
                    } footer: { Text("Open. Learn. Remember.") }
                }.scrollContentBackground(.hidden)
            }.navigationTitle("Settings")
        }
        .onChange(of: soundEnabled) { _, enabled in
            if !enabled { speechPlayer.stop() }
        }
        .sheet(isPresented: $showingImport) { ImportVocabularyView() }
        .fileExporter(isPresented: $showingExporter, document: backupDocument, contentType: .json, defaultFilename: "Lexilo Backup") { result in
            if case let .failure(error) = result { portabilityMessage = error.localizedDescription }
            else { portabilityMessage = "Backup exported" }
        }
        .fileImporter(isPresented: $showingRestore, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                try store.restore(from: Data(contentsOf: url))
                portabilityMessage = "Backup restored"
            } catch {
                portabilityMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct LexiloBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data = Data()

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct ImportVocabularyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LearningStore
    @State private var step = 1
    @State private var choosingFile = false
    @State private var table: DelimitedTable?
    @State private var mapping = ImportColumnMapping()
    @State private var rows: [PersonalImportRow] = []
    @State private var duplicateResolution = ImportDuplicateResolution.mergeSense
    @State private var fileName = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        ForEach(1...3, id: \.self) { value in
                            Label(stepTitle(value), systemImage: step >= value ? "\(value).circle.fill" : "\(value).circle")
                                .font(.caption).foregroundStyle(step >= value ? LexiloTheme.sage : .secondary)
                            if value < 3 { Spacer() }
                        }
                    }
                }
                if step == 1 { chooseFileStep }
                else if step == 2 { mappingStep }
                else { previewStep }
            }
            .navigationTitle("Import words")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if step == 2 {
                        Button("Preview") { preparePreview() }.disabled(mapping.word == nil || mapping.meaning == nil)
                    } else if step == 3 {
                        Button("Import") {
                            let count = store.importPersonalRows(rows, duplicateResolution: duplicateResolution)
                            message = "Imported \(count) item\(count == 1 ? "" : "s")"
                        }.disabled(rows.isEmpty)
                    }
                }
            }
            .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]) { result in load(result) }
            .alert("Import complete", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("Done") { dismiss() }
            } message: { Text(message ?? "") }
        }
    }

    private var chooseFileStep: some View {
        Section("1. Choose a CSV or TSV file") {
            Text("Use a header row. Lexilo supports four fields: word, meaning, example, and tags.")
                .font(.caption).foregroundStyle(.secondary)
            Button { choosingFile = true } label: { Label("Choose file", systemImage: "doc.badge.plus") }
            if !fileName.isEmpty { LabeledContent("Selected", value: fileName) }
        }
    }

    @ViewBuilder
    private var mappingStep: some View {
        if let table {
            Section("2. Map columns") {
                columnPicker("Word", selection: $mapping.word, headers: table.headers)
                columnPicker("Meaning", selection: $mapping.meaning, headers: table.headers)
                columnPicker("Example", selection: $mapping.example, headers: table.headers, optional: true)
                columnPicker("Tags", selection: $mapping.tags, headers: table.headers, optional: true)
                Text("Every imported sense generates two practice directions on separate days.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var previewStep: some View {
        Section("3. Preview and resolve duplicates") {
            Picker("When a word exists", selection: $duplicateResolution) {
                ForEach(ImportDuplicateResolution.allCases) { Text($0.rawValue).tag($0) }
            }
            ForEach(rows.prefix(5)) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.word).font(.headline)
                        if isDuplicate(row) {
                            Text("EXISTING WORD").font(.caption2.bold()).foregroundStyle(LexiloTheme.brass)
                        }
                    }
                    Text(row.meaning).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    if !row.example.isEmpty { Text("“\(row.example)”").font(.caption).italic().lineLimit(1) }
                }.padding(.vertical, 4)
            }
            if rows.count > 5 { Text("Plus \(rows.count - 5) more").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func columnPicker(_ title: String, selection: Binding<Int?>, headers: [String], optional: Bool = false) -> some View {
        Picker(title, selection: selection) {
            if optional { Text("Not included").tag(Int?.none) }
            ForEach(headers.indices, id: \.self) { index in Text(headers[index]).tag(Int?.some(index)) }
        }
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let parsed = try DelimitedVocabularyImporter.parse(data: Data(contentsOf: url))
            table = parsed
            mapping = DelimitedVocabularyImporter.suggestedMapping(headers: parsed.headers)
            fileName = url.lastPathComponent
            step = 2
        } catch { message = "Could not open the file: \(error.localizedDescription)" }
    }

    private func preparePreview() {
        do {
            guard let table else { return }
            rows = try DelimitedVocabularyImporter.rows(from: table, mapping: mapping)
            step = 3
        } catch { message = error.localizedDescription }
    }

    private func isDuplicate(_ row: PersonalImportRow) -> Bool {
        store.words.contains { AnswerEvaluator.normalize($0.word) == AnswerEvaluator.normalize(row.word) }
    }

    private func stepTitle(_ value: Int) -> String { value == 1 ? "File" : value == 2 ? "Map" : "Preview" }
}

private struct LexiconLicensesView: View {
    var body: some View {
        List {
            Section("Kaikki / English Wiktionary") {
                Text("Definitions, examples, parts of speech, forms, and IPA are derived from the structured English Wiktionary extract. Licensed under CC BY-SA 4.0 and GFDL.")
                Link("Kaikki English dictionary", destination: URL(string: "https://kaikki.org/dictionary/English/")!)
                Link("Wiktionary licenses", destination: URL(string: "https://en.wiktionary.org/wiki/Wiktionary:Copyrights")!)
            }
            Section("CMU Pronouncing Dictionary") {
                Text("CMUdict fills pronunciation gaps only. Remaining words and phrases use explicitly generated eSpeak NG IPA. Neither source contributes words, definitions, senses, or examples.")
                Link("CMUdict", destination: URL(string: "https://github.com/cmusphinx/cmudict")!)
                Link("eSpeak NG", destination: URL(string: "https://github.com/espeak-ng/espeak-ng")!)
            }
            Section("wordfreq 3.1.1") {
                Text("Frequency values are used to order learning candidates. Code is Apache 2.0; redistributed data is CC BY-SA 4.0 with upstream corpus acknowledgements.")
                Link("wordfreq sources and license", destination: URL(string: "https://github.com/rspeer/wordfreq")!)
            }
            Section("Pronunciation") {
                Text("All entries use Kitten Nano v0.2 through sherpa-onnx, with the installed iOS voice only as a runtime failure fallback.")
                Link("sherpa-onnx", destination: URL(string: "https://github.com/k2-fsa/sherpa-onnx")!)
                Link("Kitten model documentation", destination: URL(string: "https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kitten.html")!)
            }
        }
        .navigationTitle("Sources & licenses")
    }
}
