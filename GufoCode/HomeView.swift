import SwiftUI

@main
struct GufoCodeApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.p.languageID == nil {
                LanguagePickerView(isSheet: false)
            } else {
                TabView {
                    HomeView()
                        .tabItem { Label("Percorso", systemImage: "map.fill") }
                    ProfileView()
                        .tabItem { Label("Profilo", systemImage: "person.fill") }
                }
            }
        }
        .tint(.duoGreen)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            state.refreshHearts()
        }
    }
}

struct LessonRef: Identifiable {
    let id: Int
    let lesson: Lesson
    let isReplay: Bool
}

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var course: Course?
    @State private var selected: LessonRef?
    @State private var showPicker = false
    @State private var showNoHearts = false

    private let palette: [Color] = [.duoGreen, .duoBlue, .duoPurple, .duoOrange, .duoRed]

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showPicker: $showPicker)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    DailyGoalCard()
                    if let course = course {
                        pathView(course)
                    } else {
                        Text("Corso non disponibile")
                            .padding(40)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            state.refreshHearts()
            loadCourse()
        }
        .onChange(of: state.p.languageID) { _ in loadCourse() }
        .sheet(isPresented: $showPicker) {
            LanguagePickerView(isSheet: true)
                .environmentObject(state)
        }
        .fullScreenCover(item: $selected) { ref in
            LessonView(lesson: ref.lesson,
                       globalIndex: ref.id,
                       isReplay: ref.isReplay,
                       onClose: { selected = nil })
                .environmentObject(state)
        }
        .alert("Hai finito i cuori", isPresented: $showNoHearts) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Il prossimo cuore arriva tra circa \(state.minutesToNextHeart) minuti.")
        }
    }

    private func loadCourse() {
        if let id = state.p.languageID {
            course = loadCourseFile(id)
        } else {
            course = nil
        }
    }

    private func startIndexes(_ course: Course) -> [Int] {
        var starts = [0]
        for unit in course.units {
            starts.append((starts.last ?? 0) + unit.lessons.count)
        }
        return starts
    }

    private func open(_ index: Int, _ lesson: Lesson, _ done: Int) {
        state.refreshHearts()
        if state.p.hearts == 0 {
            showNoHearts = true
            return
        }
        selected = LessonRef(id: index, lesson: lesson, isReplay: index < done)
    }

    @ViewBuilder
    private func pathView(_ course: Course) -> some View {
        let done = state.completedCount(for: course.language)
        let starts = startIndexes(course)
        let total = starts.last ?? 0
        ForEach(0..<course.units.count, id: \.self) { u in
            let unit = course.units[u]
            let color = palette[u % palette.count]
            UnitBanner(number: u + 1, title: unit.title, subtitle: unit.subtitle, color: color)
            ForEach(0..<unit.lessons.count, id: \.self) { l in
                let g = starts[u] + l
                LessonNode(index: g,
                           status: g < done ? .done : (g == done ? .current : .locked),
                           accent: color,
                           action: { open(g, unit.lessons[l], done) })
            }
        }
        if done >= total {
            FinishBanner()
        }
    }
}

struct TopBar: View {
    @EnvironmentObject var state: AppState
    @Binding var showPicker: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(state.language?.badge ?? "?")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(state.language?.color ?? Color.gray))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Label("\(state.shownStreak)", systemImage: "flame.fill")
                .foregroundColor(.duoOrange)
            Label("\(state.p.xp)", systemImage: "bolt.fill")
                .foregroundColor(.duoGold)
            Label("\(state.p.hearts)", systemImage: "heart.fill")
                .foregroundColor(.duoRed)
        }
        .font(.headline.weight(.heavy))
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct DailyGoalCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let goal = max(1, state.p.dailyGoal)
        let value = min(1.0, Double(state.shownTodayXP) / Double(goal))
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundColor(.duoRed)
            VStack(alignment: .leading, spacing: 6) {
                Text("Obiettivo giornaliero")
                    .font(.subheadline.weight(.bold))
                ProgressView(value: value)
                    .tint(.duoGreen)
            }
            Text("\(state.shownTodayXP)/\(goal) XP")
                .font(.footnote.weight(.bold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

struct UnitBanner: View {
    let number: Int
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("UNITÀ \(number)")
                .font(.caption.weight(.heavy))
                .opacity(0.85)
            Text(title)
                .font(.title3.weight(.heavy))
            Text(subtitle)
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(color))
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

struct LessonNode: View {
    enum Status { case done, current, locked }

    let index: Int
    let status: Status
    let accent: Color
    let action: () -> Void

    private var mainColor: Color {
        switch status {
        case .done: return .duoGold
        case .current: return accent
        case .locked: return Color(.systemGray4)
        }
    }

    private var icon: String {
        switch status {
        case .done: return "checkmark"
        case .current: return "star.fill"
        case .locked: return "lock.fill"
        }
    }

    var body: some View {
        let dx = CGFloat(sin(Double(index) * 0.9) * 55)
        VStack(spacing: 6) {
            if status == .current {
                Text("INIZIA")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 2))
            }
            Button(action: action) {
                ZStack {
                    ZStack {
                        Circle().fill(mainColor)
                        Circle().fill(Color.black.opacity(0.28))
                    }
                    .frame(width: 76, height: 76)
                    .offset(y: 6)
                    Circle()
                        .fill(mainColor)
                        .frame(width: 76, height: 76)
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(status == .locked ? Color(.systemGray2) : .white)
                }
                .frame(width: 80, height: 88)
            }
            .buttonStyle(.plain)
            .disabled(status == .locked)
        }
        .offset(x: dx)
        .padding(.vertical, 10)
    }
}

struct FinishBanner: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("🏆").font(.system(size: 60))
            Text("Percorso completato!")
                .font(.title2.weight(.heavy))
            Text("Hai completato tutte le lezioni: ora sai scrivere piccoli programmi con variabili, condizioni, cicli e funzioni. Prova un altro linguaggio!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(30)
    }
}
