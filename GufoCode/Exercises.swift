import SwiftUI

// MARK: - Layout a righe che vanno a capo

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Componenti comuni

struct PromptText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CodeBlock: View {
    let code: String
    var body: some View {
        Text(verbatim: code)
            .font(.system(.callout, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        Text(verbatim: text)
            .font(.system(.callout, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 2))
            .cornerRadius(10)
    }
}

// MARK: - Scelta multipla

struct ChoiceView: View {
    let ex: Exercise
    let locked: Bool
    @Binding var result: Bool?
    @State private var selected: Int? = nil

    private var opts: [String] { ex.options ?? [] }

    private func background(_ i: Int) -> Color {
        if locked {
            if i == ex.answer { return Color.duoGreen.opacity(0.2) }
            if i == selected { return Color.duoRed.opacity(0.2) }
            return Color(.systemBackground)
        }
        return selected == i ? Color.duoBlue.opacity(0.18) : Color(.systemBackground)
    }

    private func border(_ i: Int) -> Color {
        if locked {
            if i == ex.answer { return .duoGreen }
            if i == selected { return .duoRed }
            return Color(.systemGray4)
        }
        return selected == i ? .duoBlue : Color(.systemGray4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PromptText(text: ex.prompt)
            if let code = ex.code {
                CodeBlock(code: code)
            }
            ForEach(0..<opts.count, id: \.self) { i in
                Button {
                    guard !locked else { return }
                    selected = i
                    result = (i == ex.answer)
                } label: {
                    Text(verbatim: opts[i])
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(background(i))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border(i), lineWidth: 2))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Riordina le righe

struct OrderItem: Identifiable {
    let id: Int
    let text: String
}

struct OrderView: View {
    let ex: Exercise
    let locked: Bool
    @Binding var result: Bool?
    @State private var bank: [OrderItem]
    @State private var chosen: [OrderItem] = []

    init(ex: Exercise, locked: Bool, result: Binding<Bool?>) {
        self.ex = ex
        self.locked = locked
        self._result = result
        let lines = ex.lines ?? []
        var items = lines.enumerated().map { OrderItem(id: $0.offset, text: $0.element) }
        var tries = 0
        repeat {
            items.shuffle()
            tries += 1
        } while items.map({ $0.text }) == lines && items.count > 1 && tries < 20
        _bank = State(initialValue: items)
    }

    private func add(_ item: OrderItem) {
        guard !locked else { return }
        bank.removeAll { $0.id == item.id }
        chosen.append(item)
        update()
    }

    private func remove(_ item: OrderItem) {
        guard !locked else { return }
        chosen.removeAll { $0.id == item.id }
        bank.append(item)
        update()
    }

    private func update() {
        let lines = ex.lines ?? []
        if chosen.count == lines.count {
            result = chosen.map { $0.text } == lines
        } else {
            result = nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptText(text: ex.prompt)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chosen) { item in
                    Button { remove(item) } label: {
                        Chip(text: item.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(bank) { item in
                    Button { add(item) } label: {
                        Chip(text: item.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Completa il codice

enum Seg {
    case text(String)
    case blank(Int)
}

struct FillView: View {
    let ex: Exercise
    let locked: Bool
    @Binding var result: Bool?
    @State private var filled: [Int?]
    private let lines: [[Seg]]

    init(ex: Exercise, locked: Bool, result: Binding<Bool?>) {
        self.ex = ex
        self.locked = locked
        self._result = result
        var counter = 0
        var out: [[Seg]] = []
        for line in ex.template ?? [] {
            let parts = line.components(separatedBy: "___")
            var segs: [Seg] = []
            for (i, part) in parts.enumerated() {
                if !part.isEmpty { segs.append(.text(part)) }
                if i < parts.count - 1 {
                    segs.append(.blank(counter))
                    counter += 1
                }
            }
            out.append(segs)
        }
        self.lines = out
        _filled = State(initialValue: Array(repeating: nil, count: counter))
    }

    private var bank: [String] { ex.bank ?? [] }

    private func tapToken(_ i: Int) {
        guard !locked, !filled.contains(i),
              let slot = filled.firstIndex(where: { $0 == nil }) else { return }
        filled[slot] = i
        update()
    }

    private func tapBlank(_ b: Int) {
        guard !locked else { return }
        filled[b] = nil
        update()
    }

    private func update() {
        if filled.contains(where: { $0 == nil }) {
            result = nil
        } else {
            let blanks = ex.blanks ?? []
            result = (0..<filled.count).allSatisfy { b in
                b < blanks.count && bank[filled[b]!] == blanks[b]
            }
        }
    }

    private func blankText(_ b: Int) -> String {
        if let idx = filled[b] { return bank[idx] }
        return " "
    }

    private func blankColor(_ b: Int) -> Color {
        guard locked, let idx = filled[b] else { return .primary }
        let blanks = ex.blanks ?? []
        return (b < blanks.count && bank[idx] == blanks[b]) ? .duoGreenDark : .duoRed
    }

    @ViewBuilder
    private func segView(_ seg: Seg) -> some View {
        switch seg {
        case .text(let t):
            Text(verbatim: t)
        case .blank(let b):
            Button { tapBlank(b) } label: {
                Text(verbatim: blankText(b))
                    .foregroundColor(blankColor(b))
                    .frame(minWidth: 44)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray3), lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
    }

    private func lineView(_ segs: [Seg]) -> some View {
        HStack(spacing: 0) {
            if segs.isEmpty {
                Text(" ")
            }
            ForEach(0..<segs.count, id: \.self) { i in
                segView(segs[i])
            }
        }
        .font(.system(.callout, design: .monospaced))
        .frame(minHeight: 26)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptText(text: ex.prompt)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<lines.count, id: \.self) { li in
                    lineView(lines[li])
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            FlowLayout(spacing: 10) {
                ForEach(0..<bank.count, id: \.self) { i in
                    Button { tapToken(i) } label: {
                        Chip(text: bank[i])
                    }
                    .buttonStyle(.plain)
                    .opacity(filled.contains(i) ? 0.3 : 1)
                }
            }
        }
    }
}
