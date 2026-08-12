import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @AppStorage("dailyGoal") private var dailyGoal = 10
    @AppStorage("newWordLimit") private var newWordLimit = 5
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("kittenVoiceID") private var kittenVoiceID = 1
    @AppStorage("kittenSpeechRate") private var kittenSpeechRate = 1.0
    @AppStorage("pronunciationLocale") private var pronunciationLocale = "en-US"
    @AppStorage("vocabularyBand") private var vocabularyBand = VocabularyBand.intermediate.rawValue
    @AppStorage("includePhrases") private var includePhrases = false
    @State private var rotationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Form {
                    Section("Daily practice") {
                        Stepper("Daily goal: \(dailyGoal) cards", value: $dailyGoal, in: 5...30, step: 5)
                        Stepper("New words: \(newWordLimit) per day", value: $newWordLimit, in: 1...15)
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
                        Picker("Learning range", selection: $vocabularyBand) {
                            ForEach(VocabularyBand.allCases) { band in
                                Text(band.title).tag(band.rawValue)
                            }
                        }
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
                    Section("How Lexilo works") {
                        Label("Reviews are scheduled automatically", systemImage: "calendar.badge.clock")
                        Label("Paired cards never appear the same day", systemImage: "arrow.left.arrow.right")
                        Label("Your learning stays on this device", systemImage: "iphone.and.arrow.forward")
                    }
                    Section {
                        HStack { Text("Lexilo"); Spacer(); Text("Version 1.0").foregroundStyle(.secondary) }
                    } footer: { Text("Open. Learn. Remember.") }
                }.scrollContentBackground(.hidden)
            }.navigationTitle("Settings")
        }
    }
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
