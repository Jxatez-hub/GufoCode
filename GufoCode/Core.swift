import SwiftUI

// MARK: - Colori

extension Color {
    static let duoGreen = Color(red: 0.345, green: 0.800, blue: 0.008)
    static let duoGreenDark = Color(red: 0.345, green: 0.655, blue: 0.0)
    static let duoBlue = Color(red: 0.110, green: 0.690, blue: 0.965)
    static let duoRed = Color(red: 1.0, green: 0.294, blue: 0.294)
    static let duoRedDark = Color(red: 0.918, green: 0.169, blue: 0.169)
    static let duoOrange = Color(red: 1.0, green: 0.590, blue: 0.0)
    static let duoGold = Color(red: 1.0, green: 0.784, blue: 0.0)
    static let duoPurple = Color(red: 0.808, green: 0.510, blue: 1.0)
}

// MARK: - Modelli del corso

struct Exercise: Codable, Identifiable {
    let type: String
    let prompt: String
    let code: String?
    let options: [String]?
    let answer: Int?
    let lines: [String]?
    let template: [String]?
    let bank: [String]?
    let blanks: [String]?
    let explanation: String

    var id: String { prompt + (code ?? "") }
}

struct Lesson: Codable {
    let title: String
    let exercises: [Exercise]
}

struct CourseUnit: Codable {
    let title: String
    let subtitle: String
    let lessons: [Lesson]
}

struct Course: Codable {
    let language: String
    let units: [CourseUnit]
}

func loadCourseFile(_ id: String) -> Course? {
    guard let url = Bundle.main.url(forResource: id, withExtension: "json"),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Course.self, from: data)
}

// MARK: - Linguaggi

struct Language: Identifiable {
    let id: String
    let name: String
    let badge: String
    let color: Color

    var available: Bool {
        Bundle.main.url(forResource: id, withExtension: "json") != nil
    }

    static let all: [Language] = [
        Language(id: "python", name: "Python", badge: "Py", color: .duoBlue),
        Language(id: "javascript", name: "JavaScript", badge: "JS", color: .duoGold),
        Language(id: "swift", name: "Swift", badge: "Sw", color: .duoOrange),
        Language(id: "c", name: "C", badge: "C", color: .duoPurple),
        Language(id: "java", name: "Java", badge: "Jv", color: .duoRed)
    ]
}

// MARK: - Progressi salvati

struct SavedProgress: Codable {
    var languageID: String? = nil
    var xp: Int = 0
    var streak: Int = 0
    var lastDay: String = ""
    var todayXP: Int = 0
    var hearts: Int = 5
    var heartsStamp: Date = Date()
    var done: [String: Int] = [:]
    var dailyGoal: Int = 20
}

final class AppState: ObservableObject {
    @Published var p: SavedProgress {
        didSet { save() }
    }

    private let key = "gufocode.progress.v1"
    private let heartInterval: TimeInterval = 1800 // un cuore ogni 30 minuti

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(SavedProgress.self, from: data) {
            p = saved
        } else {
            p = SavedProgress()
        }
        refreshHearts()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var language: Language? {
        Language.all.first { $0.id == p.languageID }
    }

    // Cuori

    func refreshHearts() {
        guard p.hearts < 5 else { return }
        let elapsed = Date().timeIntervalSince(p.heartsStamp)
        let gained = Int(elapsed / heartInterval)
        if gained > 0 {
            p.hearts = min(5, p.hearts + gained)
            if p.hearts >= 5 {
                p.heartsStamp = Date()
            } else {
                p.heartsStamp = p.heartsStamp.addingTimeInterval(Double(gained) * heartInterval)
            }
        }
    }

    var minutesToNextHeart: Int {
        let remaining = heartInterval - Date().timeIntervalSince(p.heartsStamp)
        return max(1, Int(ceil(remaining / 60)))
    }

    func loseHeart() {
        refreshHearts()
        if p.hearts >= 5 { p.heartsStamp = Date() }
        p.hearts = max(0, p.hearts - 1)
    }

    func refillHearts() {
        p.hearts = 5
        p.heartsStamp = Date()
    }

    // Giorni e serie

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private var today: String { dayString(Date()) }

    private var yesterday: String {
        dayString(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
    }

    var shownStreak: Int {
        (p.lastDay == today || p.lastDay == yesterday) ? p.streak : 0
    }

    var shownTodayXP: Int {
        p.lastDay == today ? p.todayXP : 0
    }

    private func rollDay() {
        if p.lastDay == today { return }
        p.streak = (p.lastDay == yesterday) ? p.streak + 1 : 1
        p.lastDay = today
        p.todayXP = 0
    }

    // Progressi

    func completedCount(for languageID: String) -> Int {
        p.done[languageID] ?? 0
    }

    func complete(languageID: String, globalIndex: Int, xp gain: Int) {
        rollDay()
        p.xp += gain
        p.todayXP += gain
        if globalIndex == (p.done[languageID] ?? 0) {
            p.done[languageID] = globalIndex + 1
        }
    }

    func resetAll() {
        p = SavedProgress()
    }
}
