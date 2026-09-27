import XCTest

/// Deterministic checks run on every screen the UI tests photograph, on the
/// iPhone and the watch. Each reads one accessibility snapshot of the screen
/// (a single query, not one per element) and returns what it found wrong;
/// the caller fails the test with it. They exist because a walk that only
/// checks "the screen opened" passed a spinner sitting under its label and a
/// button wrapped onto two lines (2026-09-26).
///
/// The rules, each named in its message:
///   glyph-aligned   a spinner or small icon sits on its label's first line
///   button-one-line a button's own label does not wrap
///   on-screen       text does not run past the screen edge (sideways strips excepted)
///   no-overlap      two texts do not overlap (content under the bars excepted)
///   named-button    every button has something VoiceOver can read
///   no-error        no error banner is showing
enum LayoutChecks {
    struct Node {
        let type: XCUIElement.ElementType
        let frame: CGRect
        let label: String
        let identifier: String
        let title: String
        let value: String
        /// Inside a scroll view no taller than a strip (a tab strip, a chip row).
        let inStrip: Bool
        let inCell: Bool
        /// Inside a cell that VoiceOver reads as one element (it has a label):
        /// the system's own accessory buttons there (a DisclosureGroup's arrow) need no name.
        let inNamedCell: Bool
        /// Inside the project page's tab strip, or anything marked "…strip": it scrolls sideways.
        let inTabStrip: Bool
        /// Inside a button that has a name: a SwiftUI Menu is an outer, named
        /// element over an inner, unnamed one, and VoiceOver reads the outer.
        let inNamedButton: Bool
    }

    static func findings(in app: XCUIApplication) -> [String] {
        guard let root = try? app.snapshot() else { return ["snapshot: the screen could not be read"] }
        var nodes: [Node] = []
        func walk(_ s: XCUIElementSnapshot, strip: Bool, cell: Bool, namedCell: Bool, tabStrip: Bool, namedButton: Bool) {
            let isStrip = strip || (s.elementType == .scrollView && s.frame.height < 80 && s.frame.height > 0)
            let isCell = cell || s.elementType == .cell
            let isNamedCell = namedCell || (s.elementType == .cell && !s.label.isEmpty)
            let isTabStrip = tabStrip || s.identifier.hasPrefix("tab-") || s.identifier.hasSuffix("strip")
            let value = (s.value as? String) ?? ""
            nodes.append(Node(type: s.elementType, frame: s.frame, label: s.label, identifier: s.identifier, title: s.title, value: value,
                              inStrip: isStrip || isTabStrip, inCell: isCell, inNamedCell: isNamedCell, inTabStrip: isTabStrip,
                              inNamedButton: namedButton))
            let isNamedButton = namedButton || (s.elementType == .button && !s.label.isEmpty)
            for c in s.children { walk(c, strip: isStrip, cell: isCell, namedCell: isNamedCell, tabStrip: isTabStrip, namedButton: isNamedButton) }
        }
        walk(root, strip: false, cell: false, namedCell: false, tabStrip: false, namedButton: false)
        let screen = root.frame
        let bars = nodes.filter { [.navigationBar, .tabBar, .toolbar].contains($0.type) }.map(\.frame)
        let visible = { (f: CGRect) in f.width > 1 && f.height > 1 && f.intersects(screen) }
        let underBar = { (f: CGRect) in bars.contains { $0.intersects(f) } }
        let texts = nodes.filter { $0.type == .staticText && visible($0.frame) && !$0.label.isEmpty }
        var out: [String] = []

        // glyph-aligned
        let glyphs = nodes.filter {
            visible($0.frame) && ($0.type == .activityIndicator
                || ($0.type == .image && $0.frame.width <= 32 && $0.frame.height <= 32))
        }
        for g in glyphs where !underBar(g.frame) {
            let beside = texts.filter {
                $0.frame.minX >= g.frame.maxX - 2 && $0.frame.minX - g.frame.maxX <= 24
                    && $0.frame.maxY > g.frame.minY - 12 && $0.frame.minY < g.frame.maxY + 12
            }
            // The text whose first line is nearest the glyph: a list of steps
            // puts the next row's label inside the search window too.
            let firstLineMid = { (t: Node) in t.frame.minY + min(t.frame.height, 24) / 2 }
            guard let t = beside.min(by: { abs(firstLineMid($0) - g.frame.midY) < abs(firstLineMid($1) - g.frame.midY) }) else { continue }
            // An icon is held to single-line labels only: iOS centres a row's
            // icon on a two-line label on purpose. A spinner is always held
            // to the first line.
            let singleLine = t.frame.height <= 28
            if g.type == .image && !singleLine { continue }
            let lineMid = t.frame.minY + min(t.frame.height, 24) / 2
            let off = abs(g.frame.midY - lineMid)
            if off > 5 {
                out.append("glyph-aligned: \(g.type == .activityIndicator ? "spinner" : "icon") beside \"\(t.label.prefix(40))\" is \(Int(off))pt off its line")
            }
        }

        // button-one-line: a text inside a button (not a whole list row) taller than a line.
        // Only a label with a space can wrap; text under the bars is not on show.
        for b in nodes where b.type == .button && !b.inCell && visible(b.frame) && !underBar(b.frame) && !b.label.contains("\n") {
            let own = texts.filter {
                b.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) && $0.frame.height > 30
                    && $0.label.count < 40 && $0.label.contains(" ") && !underBar($0.frame)
            }
            for t in own { out.append("button-one-line: \"\(t.label)\" wraps (\(Int(t.frame.height))pt tall)") }
        }

        // on-screen
        for t in texts where !t.inStrip && !underBar(t.frame) {
            if t.frame.maxX > screen.maxX + 1 || t.frame.minX < screen.minX - 1 {
                out.append("on-screen: \"\(t.label.prefix(40))\" runs past the screen edge")
            }
        }

        // no-overlap
        let flat = texts.filter { !underBar($0.frame) && !$0.inStrip }
        for i in flat.indices {
            for j in flat.indices where j > i {
                let a = flat[i].frame, b = flat[j].frame
                let inter = a.intersection(b)
                guard !inter.isNull, !a.contains(b), !b.contains(a) else { continue }
                // A row read as one element ("Weather station, Restart owed") overlaps its own parts.
                let la = flat[i].label, lb = flat[j].label
                if la.contains(lb) || lb.contains(la) { continue }
                if inter.width * inter.height > 0.3 * min(a.width * a.height, b.width * b.height) {
                    out.append("no-overlap: \"\(flat[i].label.prefix(30))\" overlaps \"\(flat[j].label.prefix(30))\"")
                }
            }
        }

        // named-button
        // A button of 16pt or less is the system's own disclosure arrow.
        for b in nodes where b.type == .button && visible(b.frame) && !b.inNamedCell && !b.inNamedButton
            && !(b.frame.width <= 16 && b.frame.height <= 16)
            && b.label.isEmpty && b.identifier.isEmpty && b.title.isEmpty && b.value.isEmpty {
            out.append("named-button: an unnamed button at \(Int(b.frame.minX)),\(Int(b.frame.minY)) (\(Int(b.frame.width))×\(Int(b.frame.height)))")
        }

        // no-error
        if nodes.contains(where: { $0.identifier == "error-banner" }) {
            let msg = texts.first { $0.label.count > 12 }?.label.prefix(80) ?? ""
            out.append("no-error: an error banner is showing (\(msg))")
        }
        return Array(Set(out)).sorted()
    }

    /// Fails the running test with each finding, and attaches them as text beside the screenshot.
    static func check(_ app: XCUIApplication, screen: String, in test: XCTestCase) {
        let found = findings(in: app)
        guard !found.isEmpty else { return }
        let a = XCTAttachment(string: found.joined(separator: "\n"))
        a.name = "layout — \(screen)"
        a.lifetime = .keepAlways
        test.add(a)
        for f in found { XCTFail("[\(screen)] \(f)") }
    }
}
