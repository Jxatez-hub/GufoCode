import SwiftUI

struct LanguagePickerView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let isSheet: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("🦉").font(.system(size: 70)).padding(.top, 30)
                Text(isSheet ? "Cambia linguaggio" : "Cosa vuoi imparare?")
                    .font(.title.weight(.heavy))
                    .padding(.bottom, 10)
                ForEach(Language.all) { lang in
                    Button {
                        guard lang.available else { return }
                        state.p.languageID = lang.id
                        if isSheet { dismiss() }
                    } label: {
                        HStack(spacing: 14) {
                            Text(lang.badge)
                                .font(.headline.weight(.heavy))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8).fill(lang.color))
                            Text(lang.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            if !lang.available {
                                Text("In arrivo")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else if state.p.languageID == lang.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.duoGreen)
                            }
                        }
                        .padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(!lang.available)
                    .opacity(lang.available ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @State private var showReset = false

    private var lessonsDone: Int {
        state.completedCount(for: state.p.languageID ?? "")
    }

    var body: some View {
        NavigationView {
            List {
                Section("Statistiche") {
                    Label("Serie: \(state.shownStreak) giorni", systemImage: "flame.fill")
                        .foregroundColor(.duoOrange)
                    Label("XP totali: \(state.p.xp)", systemImage: "bolt.fill")
                        .foregroundColor(.duoGold)
                    Label("Lezioni completate: \(lessonsDone)", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.duoGreenDark)
                    Label("Cuori: \(state.p.hearts)/5", systemImage: "heart.fill")
                        .foregroundColor(.duoRed)
                }
                Section("Obiettivo giornaliero") {
                    Picker("XP al giorno", selection: $state.p.dailyGoal) {
                        ForEach([10, 20, 30, 50], id: \.self) { value in
                            Text("\(value) XP").tag(value)
                        }
                    }
                }
                Section {
                    Button("Ricarica i cuori") { state.refillHearts() }
                    Button("Azzera tutti i progressi", role: .destructive) { showReset = true }
                }
            }
            .navigationTitle("Profilo")
            .alert("Azzerare i progressi?", isPresented: $showReset) {
                Button("Annulla", role: .cancel) {}
                Button("Azzera", role: .destructive) { state.resetAll() }
            } message: {
                Text("Perderai XP, serie e lezioni completate.")
            }
        }
    }
}
