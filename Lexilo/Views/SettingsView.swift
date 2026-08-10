import SwiftUI

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal = 10
    @AppStorage("newWordLimit") private var newWordLimit = 5
    @AppStorage("voiceAccent") private var voiceAccent = "US"
    @AppStorage("soundEnabled") private var soundEnabled = true

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
                        Picker("Voice", selection: $voiceAccent) { Text("American English").tag("US"); Text("British English").tag("UK") }
                        Toggle("Play pronunciation", isOn: $soundEnabled)
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

