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
    @AppStorage("desiredRetention") private var desiredRetention = 0.9
    @State private var iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    @State private var rotationMessage: String?
    @State private var showingImport = false
    @State private var showingRestore = false
    @State private var showingExporter = false
    @State private var backupDocument = LexiloBackupDocument()
    @State private var portabilityMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Form {
                    Section("Practice rounds") {
                        Stepper("Words per round: \(newWordLimit)", value: $newWordLimit, in: 5...20, step: 5)
                        Text("The first round completes your daily commitment. Each Next Round adds this many words to today’s set; Practice Again repeats the full set.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Pronunciation") {
                        Label("Fully offline pronunciation", systemImage: "waveform")
                        Text("Every word is synthesized by the bundled Kitten Nano v0.2 neural model through sherpa-onnx. Synthesis and audio caching stay on this device.")
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
                    Section("Offline dictionary") {
                        Picker("Learning level", selection: $vocabularyBand) {
                            ForEach(VocabularyBand.allCases) { band in
                                Text(band.title).tag(band.rawValue)
                            }
                        }
                        Text("Suggestions are selected only from the chosen difficulty level.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("Include phrases", isOn: $includePhrases)
                        Button {
                            let count = store.replaceUnstartedSuggestions()
                            rotationMessage = count > 0 ? "Prepared \(count) new suggestions" : "Your current learning queue is already in progress"
                        } label: {
                            Label("Replace unstarted suggestions", systemImage: "arrow.triangle.2.circlepath")
                        }
                        if let rotationMessage {
                            Text(rotationMessage).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(store.lexiconInformation.dataset) \(store.lexiconInformation.version) · \(store.lexiconInformation.lexemeCount.formatted()) searchable entries · \(store.lexiconInformation.learningCandidateCount.formatted()) learning candidates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        NavigationLink("Dictionary licenses and sources") {
                            LexiconLicensesView()
                        }
                    }
                    Section("Language support") {
                        Toggle("Show first-language support", isOn: $translationEnabled)
                        if translationEnabled {
                            Picker("First language", selection: $translationLanguage) {
                                ForEach(["Spanish", "Simplified Chinese", "Japanese", "Korean", "French", "German", "Other"], id: \.self) { Text($0) }
                            }
                            Text("English definitions remain primary. Personal translations stay visibly unreviewed until you confirm them; Lexilo does not silently generate translations.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("Import and portability") {
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
                        Text("Export and restore use a complete JSON snapshot. iCloud is optional; local mode always remains available.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Quality and memory") {
                        NavigationLink("Content quality dashboard") { ContentQualityView() }
                        NavigationLink("Advanced memory settings") {
                            Form {
                                Section("Desired retention") {
                                    Slider(value: $desiredRetention, in: 0.80...0.97, step: 0.01)
                                    LabeledContent("Target", value: "\(Int(desiredRetention * 100))%")
                                    Text("Higher targets schedule more reviews. 90% is a balanced default; the adaptive model still adjusts every card independently.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.navigationTitle("Memory settings")
                        }
                    }
                    Section("How Lexilo works") {
                        Label("Reviews are scheduled automatically", systemImage: "calendar.badge.clock")
                        Label("Paired cards never appear the same day", systemImage: "arrow.left.arrow.right")
                        Label("Local by default; iCloud is optional", systemImage: "iphone.and.arrow.forward")
                    }
                    Section {
                        HStack { Text("Lexilo"); Spacer(); Text("Version 1.0").foregroundStyle(.secondary) }
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

private struct ContentQualityView: View {
    @EnvironmentObject private var store: LearningStore
    private var quality: ContentQualitySummary { store.contentQualitySummary }

    var body: some View {
        List {
            Section("Automated checks") {
                qualityRow("Missing IPA", quality.missingIPA)
                qualityRow("Missing examples", quality.missingExamples)
                qualityRow("Duplicate senses", quality.duplicatedSenses)
                qualityRow("Definition length flags", quality.confusingDefinitions)
                qualityRow("Answer leakage flags", quality.exampleLeakage)
            }
            Section("Learner feedback") { qualityRow("Open reports", quality.learnerReports) }
            Section {
                Text("Checks run locally over the active vocabulary. Flags are review candidates, not automatic claims that content is wrong.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Content quality")
    }

    private func qualityRow(_ title: String, _ count: Int) -> some View {
        LabeledContent(title, value: count.formatted())
    }
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
            Section("Open English WordNet 2025") {
                Text("Definitions, examples, parts of speech, semantic relationships, and pronunciation metadata. Licensed under CC BY 4.0 and the Princeton WordNet License.")
                Link("Open English WordNet", destination: URL(string: "https://en-word.net/")!)
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
