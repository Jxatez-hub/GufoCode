import SwiftUI

struct DuoButtonStyle: ButtonStyle {
    var color: Color
    var shadow: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(color))
            .background(RoundedRectangle(cornerRadius: 16).fill(shadow).offset(y: 4))
            .offset(y: configuration.isPressed ? 4 : 0)
            .padding(.bottom, 4)
    }
}

struct LessonView: View {
    @EnvironmentObject var state: AppState

    let lesson: Lesson
    let globalIndex: Int
    let isReplay: Bool
    let onClose: () -> Void

    @State private var queue: [Exercise]
    @State private var step = 0
    @State private var correctCount = 0
    @State private var mistakes = 0
    @State private var result: Bool? = nil
    @State private var checked = false
    @State private var attempt = 0
    @State private var finished = false
    @State private var failed = false
    @State private var gained = 0

    init(lesson: Lesson, globalIndex: Int, isReplay: Bool, onClose: @escaping () -> Void) {
        self.lesson = lesson
        self.globalIndex = globalIndex
        self.isReplay = isReplay
        self.onClose = onClose
        _queue = State(initialValue: lesson.exercises)
    }

    private var current: Exercise {
        queue[min(step, queue.count - 1)]
    }

    var body: some View {
        Group {
            if finished {
                resultView
            } else if failed {
                failedView
            } else {
                content
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: Lezione

    private var content: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                exerciseView
                    .id(attempt)
                    .padding(20)
            }
            bottomPanel
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.duoGreen)
                        .frame(width: geo.size.width * CGFloat(correctCount) / CGFloat(max(1, lesson.exercises.count)))
                }
            }
            .frame(height: 16)
            .animation(.easeInOut, value: correctCount)
            Label("\(state.p.hearts)", systemImage: "heart.fill")
                .font(.headline.weight(.heavy))
                .foregroundColor(.duoRed)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var exerciseView: some View {
        switch current.type {
        case "choice":
            ChoiceView(ex: current, locked: checked, result: $result)
        case "order":
            OrderView(ex: current, locked: checked, result: $result)
        case "fill":
            FillView(ex: current, locked: checked, result: $result)
        default:
            Text("Tipo di esercizio non supportato")
        }
    }

    private var correctText: String {
        let ex = current
        switch ex.type {
        case "choice":
            if let o = ex.options, let a = ex.answer, o.indices.contains(a) { return o[a] }
            return ""
        case "order":
            return (ex.lines ?? []).joined(separator: "\n")
        case "fill":
            return (ex.blanks ?? []).joined(separator: ",  ")
        default:
            return ""
        }
    }

    private var bottomPanel: some View {
        Group {
            if !checked {
                Button("CONTROLLA") { check() }
                    .buttonStyle(DuoButtonStyle(
                        color: result == nil ? Color(.systemGray4) : .duoGreen,
                        shadow: result == nil ? Color(.systemGray3) : .duoGreenDark))
                    .disabled(result == nil)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            } else {
                let ok = result == true
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(ok ? "Ottimo!" : "Risposta sbagliata")
                            .font(.title3.weight(.heavy))
                    }
                    .foregroundColor(ok ? .duoGreenDark : .duoRed)
                    if !ok {
                        Text("Risposta corretta:")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.duoRed)
                        Text(verbatim: correctText)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(.duoRed)
                    }
                    Text(current.explanation)
                        .font(.subheadline)
                        .foregroundColor(ok ? .duoGreenDark : .duoRed)
                    Button("CONTINUA") { next() }
                        .buttonStyle(DuoButtonStyle(
                            color: ok ? .duoGreen : .duoRed,
                            shadow: ok ? .duoGreenDark : .duoRedDark))
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((ok ? Color.duoGreen : Color.duoRed).opacity(0.16))
            }
        }
    }

    // MARK: Logica

    private func check() {
        guard let r = result else { return }
        checked = true
        if r {
            correctCount += 1
        } else {
            mistakes += 1
            state.loseHeart()
            queue.append(current) // l'esercizio sbagliato ritorna a fine lezione
        }
    }

    private func next() {
        if result == false && state.p.hearts == 0 {
            failed = true
            return
        }
        step += 1
        if step >= queue.count {
            finishLesson()
            return
        }
        result = nil
        checked = false
        attempt += 1
    }

    private func finishLesson() {
        let languageID = state.p.languageID ?? ""
        var gain = isReplay ? 8 : 15
        if mistakes == 0 { gain += 5 }
        state.complete(languageID: languageID, globalIndex: globalIndex, xp: gain)
        gained = gain
        finished = true
    }

    // MARK: Schermate finali

    private var resultView: some View {
        let total = lesson.exercises.count
        let accuracy = Int(100.0 * Double(total) / Double(total + mistakes))
        return VStack(spacing: 24) {
            Spacer()
            Text("🦉").font(.system(size: 80))
            Text("Lezione completata!")
                .font(.title.weight(.heavy))
                .foregroundColor(.duoGold)
            HStack(spacing: 16) {
                statBox(title: "XP TOTALI", value: "+\(gained)", color: .duoGold)
                statBox(title: "PRECISIONE", value: "\(accuracy)%", color: .duoGreen)
            }
            Spacer()
            Button("CONTINUA") { onClose() }
                .buttonStyle(DuoButtonStyle(color: .duoGreen, shadow: .duoGreenDark))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color)
            Text(value)
                .font(.title2.weight(.heavy))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .frame(width: 140)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: 2))
        .cornerRadius(14)
    }

    private var failedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("💔").font(.system(size: 80))
            Text("Hai finito i cuori")
                .font(.title.weight(.heavy))
            Text("Il prossimo cuore arriva tra circa \(state.minutesToNextHeart) minuti. Ripassa e riprova!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            Spacer()
            Button("ESCI") { onClose() }
                .buttonStyle(DuoButtonStyle(color: .duoBlue, shadow: Color(red: 0.08, green: 0.55, blue: 0.80)))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }
}
