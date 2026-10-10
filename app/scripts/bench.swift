#!/usr/bin/env swift
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct Phase {
    let name: String
    let seconds: Double
    let instruction: String
    let cue: String
    let byHand: Bool
}

struct Span: Codable {
    let name: String
    let start: Double
    let end: Double
}

struct Run: Codable {
    let commit: String
    let subject: String
    let app: String
    let feed: String
    let window: String
    let pid: Int32
    let attended: Bool
    let spans: [Span]
    let toggles: [Double]
}

struct Cell {
    var fmt = ""
    var text = ""
    var frames: [String] = []
}

struct Table {
    var columns: [String] = []
    var rows: [[Cell]] = []

    func cells(_ column: String) -> [Cell] {
        guard let index = columns.firstIndex(of: column) else { return [] }
        return rows.map { index < $0.count ? $0[index] : Cell() }
    }
}

struct AppWindow {
    let number: Int
    let bounds: CGRect
}

struct Sample {
    let time: Double
    let main: Bool
    let ms: Double
    let stack: String
}

struct Interval {
    let start: Double
    let end: Double
    let owner: String
    let swap: String
}

struct Slide {
    let post: Double
    let burstEnd: Double
    let frames: [Interval]

    var span: ClosedRange<Double>? {
        guard frames.count > 1 else { return nil }
        let first = frames[0].start
        let last = frames[frames.count - 1].start
        return burstEnd < last ? max(first, burstEnd)...last : first...last
    }
}

struct SlideFigures {
    var layout = 0.0
    var app = 0.0
    var commits = 0
    var frames = 0
    var gpu = 0.0
    var found = 0
}

struct Marker {
    let step: String
    let label: String
    let phase: String?
    let needles: [String]
}

let usage = """
Usage:
  app/scripts/bench.swift <commit>                 build <commit>, record the feed on the fixed scenario with the human, print the numbers
  app/scripts/bench.swift --unattended <commit>    the same with the build left in the background: only the scripted phases get input
  app/scripts/bench.swift --analyze <run>          print the numbers of a recorded run again
"""

let phases = [
    Phase(name: "idle", seconds: 5, instruction: "touch nothing", cue: "Hands off.", byHand: false),
    Phase(name: "scroll", seconds: 12, instruction: "scroll the feed with two fingers, up and down, without stopping", cue: "Scroll the feed, up and down.", byHand: true),
    Phase(name: "pointer", seconds: 10, instruction: "move the pointer over the posts and their buttons, without scrolling or clicking", cue: "Move the pointer over the posts.", byHand: true),
    Phase(name: "toggles", seconds: 10, instruction: "touch nothing: the command presses Cmd+B every 0.5 s", cue: "Hands off.", byHand: false),
]
let gap = 2.0
let toggleEvery = 0.5
let slideSeconds = 0.22
let animationFrameGap = 0.02
let burstGap = 0.004
let burstLead = 0.05
let trimStart = 0.5
let trimEnd = 0.25
let firstTracePointer = 216.0
let cards = URL(string: "http://127.0.0.1:8765/cards")!
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let home = URL(fileURLWithPath: realpath(FileManager.default.temporaryDirectory.path, nil).map { String(cString: $0) } ?? NSTemporaryDirectory()).appending(path: "door-into-summer-bench")
let schemas = ["time-profile", "hitches", "hitches-updates", "hitches-renders", "hitches-gpu", "metal-gpu-intervals"]
let compositor = "WindowServer"

let markers = [
    Marker(step: "2", label: "SelectionTextField", phase: nil, needles: ["SelectionTextField"]),
    Marker(step: "2", label: "SelectionOverlay", phase: nil, needles: ["SelectionOverlay"]),
    Marker(step: "2", label: "-[NSControl resetCursorRects]", phase: nil, needles: ["-[NSControl resetCursorRects]"]),
    Marker(step: "2", label: "setCursorForMouseLocation:", phase: "scroll", needles: ["setCursorForMouseLocation:"]),
    Marker(step: "2", label: "setCursorForMouseLocation:", phase: "pointer", needles: ["setCursorForMouseLocation:"]),
    Marker(step: "3", label: "PointerBridge", phase: nil, needles: ["PointerBridge"]),
    Marker(step: "4", label: "HostingScrollView", phase: "scroll", needles: ["HostingScrollView"]),
    Marker(step: "4", label: "ScrollViewCommitMutation.apply", phase: "scroll", needles: ["ScrollViewCommitMutation.apply"]),
    Marker(step: "4", label: "feed layout: StackLayout, NSHostingView.layout()", phase: "scroll", needles: ["StackLayout", "NSHostingView.layout()"]),
    Marker(step: "4", label: "Core Text line breaking: TTypesetter, LineBreak", phase: "scroll", needles: ["TTypesetter", "LineBreak"]),
    Marker(step: "4 alt", label: "HostingScrollView.PlatformGroupContainer.hitTest", phase: "scroll", needles: ["PlatformGroupContainer.hitTest"]),
]
let hexNeedles = ["HexSprite", "HexLoader", "HexFrames"]
let glassNeedles = ["Glass", "Backdrop", "didChangeLuma"]
let textNeedles = ["StringDrawing.draw", "CTFontDrawGlyphs", "CTLineDraw", "DrawGlyphs", "_stringDrawingCoreTextEngine", "CGContextShowGlyphs"]
let decodeNeedles = ["@ImageIO", "@AppleJPEG", "decodedImage("]
let layoutNeedles = ["NSHostingView.layout()"]

var measured: pid_t?

func fail(_ line: String) -> Never {
    if let measured {
        kill(measured, SIGTERM)
    }
    FileHandle.standardError.write(Data("\(line)\n".utf8))
    exit(1)
}

func appending(_ file: URL) -> FileHandle {
    if !FileManager.default.fileExists(atPath: file.path) {
        FileManager.default.createFile(atPath: file.path, contents: nil)
    }
    guard let handle = try? FileHandle(forWritingTo: file) else { fail("unwritable: \(file.path)") }
    handle.seekToEndOfFile()
    return handle
}

@discardableResult
func shell(_ tool: String, _ arguments: [String], into file: URL? = nil, errors: URL? = nil) -> (status: Int32, text: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    let pipe = Pipe()
    if let file {
        process.standardOutput = appending(file)
    } else {
        process.standardOutput = pipe
    }
    if let errors {
        process.standardError = appending(errors)
    }
    do {
        try process.run()
    } catch {
        fail("\(tool) did not start: \(error.localizedDescription)")
    }
    let data = file == nil ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
}

func now() -> Double {
    Date().timeIntervalSince1970
}

func wait(until time: Double) {
    let left = time - now()
    if left > 0 {
        Thread.sleep(forTimeInterval: left)
    }
}

func awaited<Value>(seconds: Double, _ probe: () -> Value?) -> Value? {
    let deadline = now() + seconds
    repeat {
        if let value = probe() {
            return value
        }
        Thread.sleep(forTimeInterval: 0.25)
    } while now() < deadline
    return nil
}

func resolved(_ commit: String) -> (sha: String, subject: String) {
    let sha = shell("/usr/bin/git", ["-C", root.path, "rev-parse", "--short=7", "--verify", "\(commit)^{commit}"])
    guard sha.status == 0 else { fail("not a commit: \(commit)") }
    return (sha.text, shell("/usr/bin/git", ["-C", root.path, "log", "-1", "--format=%s", sha.text]).text)
}

func built(_ sha: String) -> URL {
    let source = home.appending(path: "builds/\(sha)")
    let app = source.appending(path: "app/.build/Door into Summer.app")
    guard !FileManager.default.fileExists(atPath: app.path) else { return app }
    let log = home.appending(path: "builds/\(sha).log")
    try? FileManager.default.removeItem(at: source)
    try? FileManager.default.removeItem(at: log)
    try? FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    print("building  \(sha), log in \(log.path)")
    let extracted = shell("/bin/zsh", ["-c", "git -C \"$1\" archive \"$2\" app | tar -x -C \"$3\"", "zsh", root.path, sha, source.path], errors: log)
    guard extracted.status == 0, shell("/bin/zsh", [source.appending(path: "app/scripts/make_app.sh").path], errors: log).status == 0 else {
        fail("the build of \(sha) failed: \(log.path)")
    }
    return app
}

func feed() -> String {
    guard let data = try? Data(contentsOf: cards),
          let listed = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]], !listed.isEmpty else {
        fail("no card at \(cards.absoluteString): the backend and the fixture session must run first")
    }
    let posts = listed.reduce(0) { total, card in
        total + ((card["conversation"] as? [[String: Any]]) ?? []).count { $0["from"] as? String == "session" }
    }
    let working = listed.count { $0["working"] != nil }
    let names = listed.compactMap { $0["session"] as? String }.joined(separator: ", ")
    return "\(names): \(posts) posts, \(working) working"
}

func instances(of app: URL) -> Set<pid_t> {
    let executable = app.appending(path: "Contents/MacOS/DoorIntoSummer").path
    let lines = shell("/bin/ps", ["-axww", "-o", "pid=,command="]).text.split(separator: "\n")
    return Set(lines.compactMap { line in
        let fields = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
        guard fields.count == 2, fields[1].hasPrefix(executable) else { return nil }
        return pid_t(fields[0])
    })
}

func launched(_ app: URL) -> pid_t {
    let before = instances(of: app)
    shell("/usr/bin/open", ["-g", "-n", app.path])
    guard let pid = awaited(seconds: 20, { instances(of: app).subtracting(before).first }) else { fail("the build did not start: \(app.path)") }
    return pid
}

func onScreen() -> [[String: Any]] {
    (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
        .filter { $0[kCGWindowLayer as String] as? Int == 0 }
}

func window(of pid: pid_t) -> AppWindow? {
    onScreen().compactMap { info -> AppWindow? in
        guard info[kCGWindowOwnerPID as String] as? Int == Int(pid),
              let number = info[kCGWindowNumber as String] as? Int,
              let raw = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: raw as CFDictionary) else { return nil }
        return AppWindow(number: number, bounds: bounds)
    }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
}

func isFront(_ pid: pid_t) -> Bool {
    onScreen().first?[kCGWindowOwnerPID as String] as? Int == Int(pid)
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func children(of element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func title(of element: AXUIElement) -> String? {
    [kAXTitleAttribute, kAXDescriptionAttribute].lazy.compactMap { attribute(element, $0) as? String }.first { !$0.isEmpty }
}

func role(of element: AXUIElement) -> String? {
    attribute(element, kAXRoleAttribute) as? String
}

func pressedMenu(_ pid: pid_t, _ path: [String]) -> Bool {
    guard let bar = attribute(AXUIElementCreateApplication(pid), kAXMenuBarAttribute) else { return false }
    var node = bar as! AXUIElement
    for name in path {
        let items = children(of: node).flatMap { role(of: $0) == kAXMenuRole ? children(of: $0) : [$0] }
        guard let next = items.first(where: { title(of: $0) == name }) else { return false }
        node = next
    }
    return AXUIElementPerformAction(node, kAXPressAction as CFString) == .success
}

func buttons(titled name: String, in element: AXUIElement, app: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 48, !CFEqual(element, app) else { return [] }
    let own = role(of: element) == kAXButtonRole && title(of: element) == name ? [element] : []
    return own + children(of: element).flatMap { buttons(titled: name, in: $0, app: app, depth: depth + 1) }
}

func details(_ pid: pid_t) -> [AXUIElement] {
    let app = AXUIElementCreateApplication(pid)
    let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
    return windows.flatMap { buttons(titled: "details", in: $0, app: app) }
}

func opened(_ pid: pid_t) -> AppWindow {
    if let shown = awaited(seconds: 3, { window(of: pid) }) {
        return shown
    }
    guard pressedMenu(pid, ["File", "New Window"]) else { fail("the measured build has no File > New Window to press") }
    guard let shown = awaited(seconds: 10, { window(of: pid) }) else { fail("the measured build opened no window") }
    return shown
}

func primed(_ pid: pid_t) {
    guard let last = details(pid).last, AXUIElementPerformAction(last, kAXPressAction as CFString) == .success else {
        fail("no details button to press in the measured build")
    }
    Thread.sleep(forTimeInterval: 0.5)
    guard pressedMenu(pid, ["View", "Details"]) else { fail("View > Details did not press in the measured build") }
    Thread.sleep(forTimeInterval: 0.5)
}

func front(_ pid: pid_t) {
    _ = NSRunningApplication(processIdentifier: pid)?.activate()
    if awaited(seconds: 2, { isFront(pid) ? true : nil }) != nil {
        return
    }
    AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    guard awaited(seconds: 2, { isFront(pid) ? true : nil }) != nil else { fail("the measured build did not come to the front") }
}

func toggle(_ pid: pid_t) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: down)
        event?.flags = .maskCommand
        event?.postToPid(pid)
    }
}

func say(_ text: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = [text]
    try? process.run()
}

func recording(_ pid: pid_t, into trace: URL, seconds: Int, log: URL) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["xctrace", "record", "--template", "Animation Hitches", "--instrument", "Time Profiler", "--instrument", "GPU",
                         "--attach", String(pid), "--time-limit", "\(seconds)s", "--output", trace.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    let started = DispatchSemaphore(value: 0)
    let output = appending(log)
    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        output.write(data)
        if String(decoding: data, as: UTF8.self).contains("Ctrl-C to stop") {
            started.signal()
        }
    }
    do {
        try process.run()
    } catch {
        fail("xctrace did not start: \(error.localizedDescription)")
    }
    guard started.wait(timeout: .now() + 90) == .success else { fail("the recording did not start: \(log.path)") }
    return process
}

func toggled(_ pid: pid_t, for seconds: Double) -> [Double] {
    let start = now()
    return (0..<Int(seconds / toggleEvery)).map { index in
        wait(until: start + 0.1 + Double(index) * toggleEvery)
        let posted = now()
        toggle(pid)
        return posted
    }
}

func played(_ pid: pid_t, attended: Bool) -> (spans: [Span], toggles: [Double]) {
    var spans: [Span] = []
    var toggles: [Double] = []
    var next = now()
    for (index, phase) in phases.enumerated() {
        let input = phase.byHand && !attended ? "no input, unattended" : phase.instruction
        print("\(index + 1). \(phase.name), \(Int(phase.seconds)) s: \(input)")
        if attended {
            say(phase.cue)
        }
        wait(until: next + gap)
        let start = now()
        if phase.name == "toggles" {
            toggles = toggled(pid, for: phase.seconds)
        }
        wait(until: start + phase.seconds)
        spans.append(Span(name: phase.name, start: start, end: start + phase.seconds))
        next = start + phase.seconds
    }
    if attended {
        say("Done.")
    }
    return (spans, toggles)
}

func schedule() {
    print("When Enter is pressed, the measured build comes to the front and a voice calls each phase:")
    for (index, phase) in phases.enumerated() {
        print("  \(index + 1). \(phase.name), \(Int(phase.seconds)) s: \(phase.instruction)")
    }
    print("Keep the pointer over the feed. \"Done\" ends it, the build quits and the numbers print.")
    print("Press Enter to start.")
    _ = readLine()
}

func record(_ commit: String, attended: Bool) {
    let (sha, subject) = resolved(commit)
    let app = built(sha)
    let fixture = feed()
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.dateFormat = "yyyyMMdd-HHmmss"
    let stamp = format.string(from: Date())
    let directory = home.appending(path: "runs/\(sha)-\(stamp)")
    signal(SIGINT) { _ in
        if let measured {
            kill(measured, SIGTERM)
        }
        exit(130)
    }
    let pid = launched(app)
    measured = pid
    let window = opened(pid)
    guard let buttonsShown = awaited(seconds: 20, { details(pid).isEmpty ? nil : details(pid).count }) else { fail("the measured build shows no post") }
    primed(pid)
    if attended {
        schedule()
        front(pid)
    }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let capture = directory.appending(path: "window.png")
    shell("/usr/sbin/screencapture", ["-x", "-o", "-l\(window.number)", capture.path])
    let trace = directory.appending(path: "feed.trace")
    let limit = Int((phases.reduce(0) { $0 + $1.seconds + gap } + 4).rounded(.up))
    let process = recording(pid, into: trace, seconds: limit, log: directory.appending(path: "xctrace.log"))
    let (spans, toggles) = played(pid, attended: attended)
    process.waitUntilExit()
    kill(pid, SIGTERM)
    measured = nil
    guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: trace.path) else { fail("the recording failed: \(directory.path)/xctrace.log") }
    let shown = "\(Int(window.bounds.width)) x \(Int(window.bounds.height)) pt, \(buttonsShown) details buttons on screen, drawn: \(capture.path)"
    let run = Run(commit: sha, subject: subject, app: app.path, feed: fixture, window: shown, pid: pid, attended: attended, spans: spans, toggles: toggles)
    guard let data = try? JSONEncoder().encode(run), (try? data.write(to: directory.appending(path: "run.json"))) != nil else { fail("run.json unwritten in \(directory.path)") }
    print("exporting the trace's tables, about two minutes")
    analyze(directory)
}

final class TableReader: NSObject, XMLParserDelegate {
    private struct Open {
        let name: String
        let label: String
        let id: String?
        let ref: String?
        var cell: Cell
        var binary = ""
    }

    private(set) var table = Table()
    private var stored: [String: Cell] = [:]
    private var open: [Open] = []
    private var row: [Cell]?
    private var mnemonic: String?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "mnemonic" {
            mnemonic = ""
        } else if name == "row" {
            row = []
        } else if row != nil {
            open.append(Open(name: name, label: attributes["name"] ?? "", id: attributes["id"], ref: attributes["ref"], cell: Cell(fmt: attributes["fmt"] ?? "")))
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if mnemonic != nil {
            mnemonic? += string
        } else if !open.isEmpty {
            open[open.count - 1].cell.text += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "mnemonic", let mnemonic {
            table.columns.append(mnemonic)
            self.mnemonic = nil
        } else if name == "row", let row {
            table.rows.append(row)
            self.row = nil
        } else if let closed = open.popLast() {
            close(closed)
        }
    }

    private func close(_ closed: Open) {
        var cell = closed.ref.flatMap { stored[$0] } ?? closed.cell
        if closed.ref == nil {
            cell.text = cell.text.trimmingCharacters(in: .whitespacesAndNewlines)
            cell.fmt = closed.name == "binary" ? closed.label : cell.fmt
            cell.frames = closed.name == "frame" ? ["\(closed.label) @\(closed.binary)"] : cell.frames
        }
        if let id = closed.id {
            stored[id] = cell
        }
        guard !open.isEmpty else {
            row?.append(cell)
            return
        }
        if closed.name == "binary" {
            open[open.count - 1].binary = cell.fmt
        } else {
            open[open.count - 1].cell.frames += cell.frames
        }
    }
}

func parsed(_ file: URL) -> Table {
    guard let parser = XMLParser(contentsOf: file) else { fail("unreadable: \(file.path)") }
    let reader = TableReader()
    parser.delegate = reader
    guard parser.parse() else { fail("unparsable: \(file.path)") }
    return reader.table
}

func exported(_ schema: String, of trace: URL, in directory: URL) -> Table {
    let file = directory.appending(path: "tables/\(schema).xml")
    if !FileManager.default.fileExists(atPath: file.path) {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let xpath = "/trace-toc/run[@number=\"1\"]/data/table[@schema=\"\(schema)\"]"
        guard shell("/usr/bin/xcrun", ["xctrace", "export", "--input", trace.path, "--xpath", xpath], into: file).status == 0 else {
            try? FileManager.default.removeItem(at: file)
            fail("the table \(schema) did not export from \(trace.path)")
        }
    }
    return parsed(file)
}

func between(_ text: String, _ open: String, _ close: String) -> String? {
    guard let start = text.range(of: open), let end = text.range(of: close, range: start.upperBound..<text.endIndex) else { return nil }
    return String(text[start.upperBound..<end.lowerBound])
}

func timeline(_ trace: URL) -> (origin: Double, duration: Double) {
    let toc = shell("/usr/bin/xcrun", ["xctrace", "export", "--input", trace.path, "--toc"]).text
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let start = between(toc, "<start-date>", "</start-date>").flatMap(iso.date(from:)),
          let duration = between(toc, "<duration>", "</duration>").flatMap(Double.init) else {
        fail("no start date in the table of contents of \(trace.path)")
    }
    return (start.timeIntervalSince1970, duration)
}

func seconds(_ cell: Cell) -> Double {
    (Double(cell.text) ?? 0) / 1e9
}

func intervals(_ table: Table, owner: String? = nil, keep: (Int) -> Bool = { _ in true }) -> [Interval] {
    let owners = owner.map { table.cells($0).map(\.fmt) } ?? []
    let swaps = table.cells("swap-id").map(\.text)
    return zip(table.cells("start"), table.cells("duration")).enumerated().compactMap { index, pair in
        guard keep(index) else { return nil }
        let start = seconds(pair.0)
        return Interval(start: start, end: start + seconds(pair.1), owner: index < owners.count ? owners[index] : "", swap: index < swaps.count ? swaps[index] : "")
    }
}

func union(_ spans: [Interval], within window: ClosedRange<Double>) -> Double {
    let clipped = spans.compactMap { span -> (Double, Double)? in
        let start = max(span.start, window.lowerBound)
        let end = min(span.end, window.upperBound)
        return end > start ? (start, end) : nil
    }.sorted { $0.0 < $1.0 }
    var total = 0.0
    var reach = -Double.infinity
    for (start, end) in clipped where end > reach {
        total += end - max(start, reach)
        reach = end
    }
    return total
}

func contains(_ stack: String, _ needles: [String]) -> Bool {
    needles.contains { stack.contains($0) }
}

func number(_ value: Double, _ digits: Int = 1) -> String {
    String(format: "%.\(digits)f", value)
}

func padded(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
}

struct Measure {
    let samples: [Sample]
    let hitches: [Interval]
    let commits: [Double]
    let appSwaps: Set<String>
    let renders: [Interval]
    let gpuFrames: [Interval]
    let gpu: [Interval]
    let pid: String

    func cpu(_ window: ClosedRange<Double>, main: Bool? = nil, needles: [String]? = nil) -> Double {
        samples.filter { sample in
            window.contains(sample.time) && (main == nil || sample.main == main) && (needles.map { contains(sample.stack, $0) } ?? true)
        }
        .reduce(0) { $0 + $1.ms }
    }

    func burstEnd(after post: Double) -> Double {
        var end = post
        for sample in samples where sample.time >= post {
            guard sample.time - end <= burstGap || (end == post && sample.time - post <= burstLead) else { break }
            end = sample.time
        }
        return end
    }

    func count(_ times: [Double], _ window: ClosedRange<Double>) -> Int {
        times.count { window.contains($0) }
    }

    func within(_ spans: [Interval], _ window: ClosedRange<Double>) -> [Interval] {
        spans.filter { window.contains($0.start) }
    }

    func gpuMs(_ window: ClosedRange<Double>, onCompositor: Bool) -> Double {
        union(gpu.filter { onCompositor ? $0.owner.hasPrefix(compositor) : $0.owner.contains("(\(pid))") }, within: window) * 1000
    }

    func ofApp(_ spans: [Interval]) -> [Interval] {
        spans.filter { appSwaps.contains($0.swap) }
    }

    func hitchMs(_ window: ClosedRange<Double>, appOnly: Bool) -> (ms: Double, count: Int) {
        let found = within(appOnly ? ofApp(hitches) : hitches, window)
        return (found.reduce(0) { $0 + ($1.end - $1.start) } * 1000, found.count)
    }

    func mean(_ spans: [Interval]) -> Double {
        spans.isEmpty ? 0 : spans.reduce(0) { $0 + ($1.end - $1.start) } / Double(spans.count) * 1000
    }
}

func measurement(of directory: URL, pid: String) -> Measure {
    let trace = directory.appending(path: "feed.trace")
    let tables = Dictionary(uniqueKeysWithValues: schemas.map { ($0, exported($0, of: trace, in: directory)) })
    let profile = tables["time-profile"] ?? Table()
    let samples = zip(zip(profile.cells("time"), profile.cells("thread")), zip(profile.cells("weight"), profile.cells("stack"))).map { first, second in
        Sample(time: seconds(first.0), main: first.1.fmt.hasPrefix("Main Thread"), ms: (Double(second.0.text) ?? 1_000_000) / 1e6, stack: second.1.frames.joined(separator: "\n"))
    }.sorted { $0.time < $1.time }
    let renders = tables["hitches-renders"] ?? Table()
    let levels = renders.cells("containment-level").map(\.text)
    return Measure(
        samples: samples,
        hitches: intervals(tables["hitches"] ?? Table(), owner: "process"),
        commits: (tables["hitches-updates"] ?? Table()).cells("start").map(seconds),
        appSwaps: Set((tables["hitches-updates"] ?? Table()).cells("swap-id").map(\.text)),
        renders: intervals(renders) { levels.count <= $0 || levels[$0] == "0" },
        gpuFrames: intervals(tables["hitches-gpu"] ?? Table()),
        gpu: intervals(tables["metal-gpu-intervals"] ?? Table(), owner: "process"),
        pid: pid
    )
}

func analyze(_ directory: URL) {
    guard let data = try? Data(contentsOf: directory.appending(path: "run.json")),
          let run = try? JSONDecoder().decode(Run.self, from: data) else { fail("no run.json in \(directory.path)") }
    let trace = directory.appending(path: "feed.trace")
    let (origin, duration) = timeline(trace)
    let measure = measurement(of: directory, pid: String(run.pid))
    let windows = Dictionary(uniqueKeysWithValues: run.spans.map { ($0.name, ($0.start - origin + trimStart)...($0.end - origin - trimEnd)) })
    var lines = header(run, directory: directory, duration: duration)
    lines += phaseTable(measure, run: run, windows: windows)
    lines += hitchLine(measure, windows: windows)
    lines += markerLines(measure, run: run, windows: windows, origin: origin)
    lines += elementLines(measure, run: run, windows: windows, origin: origin)
    let text = lines.joined(separator: "\n")
    print(text)
    try? text.appending("\n").write(to: directory.appending(path: "output.txt"), atomically: true, encoding: .utf8)
}

func header(_ run: Run, directory: URL, duration: Double) -> [String] {
    [
        "Door into Summer feed benchmark",
        "command   app/scripts/bench.swift \(run.attended ? "" : "--unattended ")\(run.commit)",
        "commit    \(run.commit) \(run.subject.prefix(100))",
        "build     \(run.app), pid \(run.pid)",
        "feed      \(run.feed)",
        "window    \(run.window)",
        "input     idle and toggles scripted, \(run.attended ? "scroll and pointer by hand" : "scroll and pointer without input (unattended)")",
        "trace     \(directory.appending(path: "feed.trace").path), \(number(duration)) s",
        "phases    measured from \(trimStart) s after each start to \(trimEnd) s before each end",
        "",
    ]
}

func phaseTable(_ measure: Measure, run: Run, windows: [String: ClosedRange<Double>]) -> [String] {
    let titles = ["phase", "s", "app CPU ms/s", "main", "other", "app commits/s", "app hitch ms/s", "display frames/s", "render ms/frame", "GPU ms/frame", "GPU \(compositor) ms/s", "GPU app ms/s"]
    let widths = titles.map { max($0.count, 7) }
    let line = { (cells: [String]) -> String in
        let first = cells[0].padding(toLength: widths[0], withPad: " ", startingAt: 0)
        return ([first] + zip(cells.dropFirst(), widths.dropFirst()).map { padded($0, $1) }).joined(separator: "  ")
    }
    let rows = phases.compactMap { phase -> String? in
        guard let window = windows[phase.name] else { return nil }
        let length = window.upperBound - window.lowerBound
        let frames = measure.within(measure.renders, window)
        return line([
            phase.name, number(length), number(measure.cpu(window) / length), number(measure.cpu(window, main: true) / length),
            number(measure.cpu(window, main: false) / length), number(Double(measure.count(measure.commits, window)) / length),
            number(measure.hitchMs(window, appOnly: true).ms / length),
            number(Double(frames.count) / length), number(measure.mean(frames), 2), number(measure.mean(measure.within(measure.gpuFrames, window)), 2),
            number(measure.gpuMs(window, onCompositor: true) / length), number(measure.gpuMs(window, onCompositor: false) / length),
        ])
    }
    return [line(titles)] + rows + [""]
}

func hitchLine(_ measure: Measure, windows: [String: ClosedRange<Double>]) -> [String] {
    guard let window = windows["scroll"] else { return [] }
    let length = window.upperBound - window.lowerBound
    let app = measure.hitchMs(window, appOnly: true)
    let display = measure.hitchMs(window, appOnly: false)
    let ratio = app.ms / length
    return [
        "Hitch time ratio while scrolling: \(number(ratio)) ms/s, \(app.count) hitches, \(number(app.ms)) ms over \(number(length)) s. Target under 5 ms/s: \(ratio < 5 ? "met" : "missed").",
        "  counted: the hitches whose frame carries an update of the app, joined by swap id (hitches, hitches-updates). The whole display: \(number(display.ms / length)) ms/s, \(display.count) hitches, other processes' frames included.",
        "",
    ]
}

func slides(_ measure: Measure, run: Run, origin: Double) -> [Slide] {
    run.toggles.map { posted in
        let post = posted - origin
        let period = measure.renders.filter { $0.start >= post && $0.start < post + toggleEvery - 0.02 }.sorted { $0.start < $1.start }
        let fast = period.indices.filter { index in
            let afterOne = index > 0 && period[index].start - period[index - 1].start < animationFrameGap
            let beforeOne = index + 1 < period.count && period[index + 1].start - period[index].start < animationFrameGap
            return afterOne || beforeOne
        }
        return Slide(post: post, burstEnd: measure.burstEnd(after: post), frames: fast.map { period[$0] })
    }
}

func slideFigures(_ measure: Measure, _ slides: [Slide]) -> SlideFigures {
    var figures = SlideFigures()
    for slide in slides {
        guard let span = slide.span, let last = slide.frames.last else {
            figures.layout += measure.cpu(slide.post...(slide.post + slideSeconds), needles: layoutNeedles)
            continue
        }
        let inside = span.lowerBound.nextUp...span.upperBound
        figures.layout += measure.cpu(slide.post...span.lowerBound, needles: layoutNeedles)
        figures.app += measure.cpu(inside)
        figures.commits += measure.count(measure.commits, inside)
        figures.frames += slide.frames.count
        figures.gpu += measure.gpuMs(span.lowerBound...last.end, onCompositor: true)
        figures.found += 1
    }
    return figures
}

func markerLines(_ measure: Measure, run: Run, windows: [String: ClosedRange<Double>], origin: Double) -> [String] {
    let all = (windows.values.map(\.lowerBound).min() ?? 0)...(windows.values.map(\.upperBound).max() ?? 0)
    var lines = ["Markers of the plan's steps, column \"Proof in the step's trace\": state, ms/s, share of the app CPU of the phase"]
    let toggles = slides(measure, run: run, origin: origin)
    if let window = windows["toggles"], !toggles.isEmpty {
        let phaseCPU = max(measure.cpu(window), 0.001)
        let length = window.upperBound - window.lowerBound
        let figures = slideFigures(measure, toggles)
        let count = Double(toggles.count)
        let found = Double(max(figures.found, 1))
        lines.append(markerRow("1", "NSHostingView.layout() before the slide", "toggles", figures.layout, figures.layout / length, figures.layout / phaseCPU,
                               "\(number(figures.layout / count)) ms per toggle"))
        lines.append(markerRow("1", "app samples during the slide", "toggles", figures.app, figures.app / length, figures.app / phaseCPU,
                               "\(number(figures.app / found)) ms and \(number(Double(figures.commits) / found)) app commits per slide, \(figures.found) of \(toggles.count) slides found"))
    }
    for marker in markers {
        let window = marker.phase.flatMap { windows[$0] } ?? all
        let length = window.upperBound - window.lowerBound
        let found = measure.cpu(window, needles: marker.needles)
        lines.append(markerRow(marker.step, marker.label, marker.phase ?? "all", found, found / length, found / max(measure.cpu(window), 0.001), ""))
    }
    if let window = windows["pointer"] {
        let rate = measure.cpu(window) / (window.upperBound - window.lowerBound)
        lines.append(noteRow("3", "app CPU with the pointer alone", "pointer", "\(number(rate)) ms/s, \(number(firstTracePointer)) ms/s in the plan's first trace"))
    }
    if let window = windows["scroll"] {
        let length = window.upperBound - window.lowerBound
        let ratio = measure.hitchMs(window, appOnly: true).ms / length
        lines.append(noteRow("4", "hitch time ratio, Animation Hitches", "scroll", "\(number(ratio)) ms/s on the app's frames, target under 5"))
    }
    return lines + [""]
}

func noteRow(_ step: String, _ label: String, _ phase: String, _ note: String) -> String {
    "step \(step.padding(toLength: 6, withPad: " ", startingAt: 0))\(label.padding(toLength: 55, withPad: " ", startingAt: 0))\(phase.padding(toLength: 9, withPad: " ", startingAt: 0))\(note)"
}

func markerRow(_ step: String, _ label: String, _ phase: String, _ ms: Double, _ rate: Double, _ share: Double, _ note: String) -> String {
    let state = ms > 0 ? "present" : "absent"
    let figures = ms > 0 ? "\(padded(number(rate), 7)) ms/s \(padded(number(share * 100), 5)) %" : ""
    return "step \(step.padding(toLength: 6, withPad: " ", startingAt: 0))\(label.padding(toLength: 55, withPad: " ", startingAt: 0))\(phase.padding(toLength: 9, withPad: " ", startingAt: 0))\(state.padding(toLength: 8, withPad: " ", startingAt: 0))\(figures)\(note.isEmpty ? "" : "  \(note)")"
}

func elementLines(_ measure: Measure, run: Run, windows: [String: ClosedRange<Double>], origin: Double) -> [String] {
    var lines = ["Elements: where the work ran, beside where it belongs"]
    let figures = slideFigures(measure, slides(measure, run: run, origin: origin))
    if figures.found > 0 {
        let found = Double(figures.found)
        lines.append("panel slide, toggles: per slide, from the end of the app's work on Cmd+B to the last of the frames under \(Int(animationFrameGap * 1000)) ms apart, \(number(Double(figures.frames) / found)) render server frames (hitches-renders), app \(number(figures.app / found)) ms (time-profile), \(number(Double(figures.commits) / found)) app commits (hitches-updates), GPU \(compositor) \(number(figures.gpu / found)) ms (metal-gpu-intervals). Belongs: render server and GPU, no app sample during the slide. Holds: \(figures.app == 0 && figures.commits == 0 ? "yes" : "no").")
    }
    if let window = windows["idle"] {
        let length = window.upperBound - window.lowerBound
        let hex = measure.cpu(window, needles: hexNeedles)
        let app = measure.cpu(window) / length
        let commits = Double(measure.count(measure.commits, window)) / length
        let frames = Double(measure.within(measure.renders, window).count) / length
        let gpu = measure.mean(measure.within(measure.gpuFrames, window))
        lines.append("hex loader, idle: app \(number(app)) ms/s of which \(number(hex)) ms in Hex frames (time-profile), \(number(commits)) app commits/s (hitches-updates), \(number(frames)) display frames/s, other processes' included (hitches-renders), GPU \(number(gpu, 2)) ms/frame (hitches-gpu). Belongs: render server and GPU, no app sample. Holds: \(hex == 0 && commits == 0 && frames > 0 ? "yes" : frames == 0 ? "unproven, no frame: no working post on screen" : "no").")
    }
    if let window = windows["scroll"] {
        lines += scrollElements(measure, window: window, attended: run.attended)
    }
    lines += spreadElement("chat bar Liquid Glass: Glass, Backdrop, didChangeLuma frames", glassNeedles, measure, windows: windows, belongs: "render server and GPU, no app sample", holds: { _, _, all in
        "on the app side \(all == 0 ? "yes" : "no, \(number(all)) ms in all phases"); its render server and GPU share is not isolated, since \(compositor)'s GPU time covers the whole screen: proving it needs a GPU capture of \(compositor) by layer, which Instruments does not record on macOS, or the same scroll with the chat bar hidden, a code change"
    })
    lines += spreadElement("rows' text drawing", textNeedles, measure, windows: windows, belongs: "the app's CPU, once per row", holds: { main, other, _ in
        "drawn by the app's CPU: yes; once per row: unproven, it needs the rows drawn counted against the rows that entered (\(number(main + other)) ms/s while scrolling)"
    })
    lines += spreadElement("image decoding", decodeNeedles, measure, windows: windows, belongs: "the CPU off the main thread or the hardware decoder, before the image is on screen", holds: { main, _, _ in
        main == 0 ? "yes off the main thread; before on screen: unproven, it needs decode times against each row's first frame" : "no, \(number(main)) ms/s on the main thread while scrolling"
    })
    return lines
}

func scrollElements(_ measure: Measure, window: ClosedRange<Double>, attended: Bool) -> [String] {
    let frames = measure.within(measure.renders, window)
    let appFrames = measure.ofApp(frames)
    let main = measure.cpu(window, main: true)
    let gpu = measure.mean(measure.ofApp(measure.within(measure.gpuFrames, window)))
    let unattended = attended ? "" : " Unattended: the feed got no scroll, so nothing here measures scrolling."
    return [
        "feed scrolling, scroll: \(frames.count) display frames, \(appFrames.count) of them carrying an app update (hitches-renders, hitches-updates); app main thread \(appFrames.isEmpty ? "\(number(main)) ms with no app frame" : "\(number(main / Double(appFrames.count), 2)) ms per app frame") (time-profile); on the app's frames, render server \(number(measure.mean(appFrames), 2)) ms/frame (hitches-renders) and GPU \(number(gpu, 2)) ms/frame (hitches-gpu). Belongs: render server and GPU, no app sample between frames. Holds: \(main == 0 && !frames.isEmpty ? "yes" : "no").\(unattended)"
    ]
}

func spreadElement(_ name: String, _ needles: [String], _ measure: Measure, windows: [String: ClosedRange<Double>], belongs: String, holds: (Double, Double, Double) -> String) -> [String] {
    let parts = phases.compactMap { phase -> String? in
        guard let window = windows[phase.name] else { return nil }
        let length = window.upperBound - window.lowerBound
        return "\(phase.name) \(number(measure.cpu(window, main: true, needles: needles) / length)) main + \(number(measure.cpu(window, main: false, needles: needles) / length)) other ms/s"
    }
    guard let scroll = windows["scroll"] else { return [] }
    let length = scroll.upperBound - scroll.lowerBound
    let main = measure.cpu(scroll, main: true, needles: needles) / length
    let other = measure.cpu(scroll, main: false, needles: needles) / length
    let all = windows.values.reduce(0) { $0 + measure.cpu($1, needles: needles) }
    return ["\(name), all phases: \(parts.joined(separator: ", ")) (time-profile). Belongs: \(belongs). Holds: \(holds(main, other, all))."]
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "--analyze" where arguments.count == 2:
    analyze(URL(fileURLWithPath: arguments[1]))
case "--unattended" where arguments.count == 2:
    record(arguments[1], attended: false)
case let commit? where arguments.count == 1 && !commit.hasPrefix("-"):
    record(commit, attended: true)
default:
    print(usage)
    exit(arguments == ["--help"] ? 0 : 2)
}
