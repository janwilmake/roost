import AppKit
import CryptoKit

let serverURL = URL(string: "http://127.0.0.1:4777/")!
let smallestTile: CGFloat = 22
/// Few sessions would make huge tiles; they stop growing here.
let largestTile: CGFloat = 40
/// A strip sizes its tiles as if it had at least this many, so a short strip does not get huge tiles.
let minimumTileCount = 8

/// The sizes of one strip. Each strip fills the height of its own screen, so a bigger screen gets bigger tiles.
struct TileMetrics {
    let size: CGFloat
    var gap: CGFloat { (size * 0.15).rounded() }
    var step: CGFloat { size + gap }
    /// The magnified tile and its reach grow with the tiles.
    var magnifiedSize: CGFloat { max(80, size * 1.6) }
    var radius: CGFloat { max(110, size * 2.75) }
    var scale: CGFloat { magnifiedSize / size }
    var magnifiedWidth: CGFloat { magnifiedSize + 4 }
    var padding: CGFloat { (scale - 1) * radius / 2 + 6 }
    /// The height of a topic's name in wide mode.
    var headerHeight: CGFloat { max(16, (size * 0.6).rounded()) }
}

let draggedScale: CGFloat = 1.25
let stripBottomMargin: CGFloat = 8

/// Wide mode lays the strip out in rows of this many tiles.
let wideColumns = 3

/// The frame of each tile in wide mode, measured down from the top of the strip, and the height they take together.
/// A tile starts a new row when its row is full or its group differs from the tile before it; a topic's header fills a row.
func gridCells(_ tiles: [(group: String, header: Bool)], columns: Int, metrics: TileMetrics) -> (cells: [NSRect], height: CGFloat) {
    var cells: [NSRect] = []
    var top: CGFloat = 0
    var rowHeight: CGFloat = 0
    var column = 0
    for (index, tile) in tiles.enumerated() {
        if index > 0 && (tile.header || column == columns || tile.group != tiles[index - 1].group) {
            top += rowHeight + metrics.gap
            column = 0
        }
        let height = tile.header ? metrics.headerHeight : metrics.size
        let width = tile.header ? CGFloat(columns) * metrics.step - metrics.gap : metrics.size
        cells.append(NSRect(x: CGFloat(column) * metrics.step, y: top, width: width, height: height))
        rowHeight = height
        column = tile.header ? columns : column + 1
    }
    return (cells, top + rowHeight)
}

enum Palette {
    static let terracotta = NSColor(srgbRed: 0.80, green: 0.33, blue: 0.17, alpha: 1)
    static let deepTerracotta = NSColor(srgbRed: 0.60, green: 0.22, blue: 0.11, alpha: 1)
    static let cream = NSColor(srgbRed: 1.0, green: 0.96, blue: 0.88, alpha: 1)
    static let tile = NSColor(srgbRed: 0.17, green: 0.15, blue: 0.12, alpha: 1)
    static let folder = NSColor(srgbRed: 0.33, green: 0.30, blue: 0.25, alpha: 1)
    static let tooltip = NSColor(srgbRed: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    static let flash = NSColor(srgbRed: 0.94, green: 0.54, blue: 0.36, alpha: 1)
}

// MARK: - Logo

func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

func eggPath() -> NSBezierPath {
    let egg = NSBezierPath()
    egg.move(to: point(50, 97))
    egg.curve(to: point(90, 38), controlPoint1: point(73, 97), controlPoint2: point(90, 63))
    egg.curve(to: point(50, 3), controlPoint1: point(90, 15), controlPoint2: point(72, 3))
    egg.curve(to: point(10, 38), controlPoint1: point(28, 3), controlPoint2: point(10, 15))
    egg.curve(to: point(50, 97), controlPoint1: point(10, 63), controlPoint2: point(27, 97))
    egg.close()
    return egg
}

/// One closed line from beak to comb to tail. The y axis points up.
func chickenPath() -> NSBezierPath {
    let line = NSBezierPath()
    line.move(to: point(85, 62))
    line.line(to: point(72, 68))
    line.curve(to: point(70, 75), controlPoint1: point(72, 71), controlPoint2: point(71, 73))
    line.curve(to: point(61, 78), controlPoint1: point(73, 85), controlPoint2: point(62, 87))
    line.curve(to: point(50, 78), controlPoint1: point(60, 89), controlPoint2: point(49, 89))
    line.curve(to: point(43, 71), controlPoint1: point(46, 85), controlPoint2: point(38, 81))
    line.curve(to: point(31, 53), controlPoint1: point(39, 62), controlPoint2: point(37, 55))
    line.curve(to: point(11, 77), controlPoint1: point(25, 52), controlPoint2: point(20, 66))
    line.curve(to: point(48, 20), controlPoint1: point(5, 50), controlPoint2: point(16, 20))
    line.curve(to: point(71, 51), controlPoint1: point(68, 20), controlPoint2: point(80, 36))
    line.line(to: point(74, 56))
    line.close()
    line.lineJoinStyle = .round
    line.lineCapStyle = .round
    return line
}

/// Draws the logo, an outlined chicken in an egg, filling a square.
func drawLogo(in rect: NSRect, egg: Bool = true) {
    NSGraphicsContext.saveGraphicsState()
    let toRect = NSAffineTransform()
    toRect.translateX(by: rect.minX, yBy: rect.minY)
    toRect.scale(by: rect.width / 100)
    toRect.concat()
    if egg { NSGradient(starting: Palette.terracotta, ending: Palette.deepTerracotta)?.draw(in: eggPath(), angle: -90) }

    let toEgg = NSAffineTransform()
    toEgg.translateX(by: 17.7, yBy: 10.3)
    toEgg.scale(by: 0.68)
    toEgg.concat()
    let chicken = chickenPath()
    chicken.lineWidth = 6
    Palette.cream.setStroke()
    chicken.stroke()
    Palette.cream.setFill()
    NSBezierPath(ovalIn: NSRect(x: 58.5, y: 62, width: 7, height: 7)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func renderIcon(pixels: Int, to path: String) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { throw CocoaError(.fileWriteUnknown) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let toPixels = NSAffineTransform()
    toPixels.scale(by: CGFloat(pixels) / 1024)
    toPixels.concat()

    // A full-bleed icon: macOS rounds the corners itself, and puts an icon with transparent edges on a gray plate.
    NSGradient(starting: Palette.terracotta, ending: Palette.deepTerracotta)?.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: -90)
    drawLogo(in: NSRect(x: -29, y: 40, width: 1060, height: 1060), egg: false)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: URL(fileURLWithPath: path))
}

// MARK: - Data

struct Face {
    let id: String
    let title: String
    let autoTitle: String
    let status: String
    let emoji: String
    let photo: String?
    /// The tile's background, which the session's Terminal tab shares so the two match at a glance. It turns pale in light mode.
    let color: NSColor?
    let folder: String
    let screenName: String?
    let waitingFor: String?
    let since: Double?
    let openedAt: Double?
    let snoozeUntil: Double?
    let snoozeRules: [String]
    let notes: String
    let notesAt: Double?
    let waiting: Int
    /// Items a teammate was asked to do: a blue dot when nothing waits on you.
    let team: Int
    /// What a session waits on while Claude is not thinking, such as "watching CI". Set by the session or by you.
    let wip: String?
    let wipAt: Double?
    /// "active" for the tab you look at in Terminal, "last" for that tab while another app is in front.
    var front: String?
    var topic: String?
    /// Every "(due …)", "back by …" and "promised by …" in the notes, soonest first.
    let deadlines: [Deadline]
    /// The deadline you set from the menu, in ms.
    let deadline: Double?

    init?(_ json: [String: Any]) {
        guard let id = json["id"] as? String, let status = json["status"] as? String else { return nil }
        self.id = id
        self.status = status
        title = json["title"] as? String ?? ""
        autoTitle = json["autoTitle"] as? String ?? ""
        emoji = json["emoji"] as? String ?? ""
        photo = json["photo"] as? String
        color = (json["color"] as? String).map { dark in
            let light = json["lightColor"] as? String ?? dark
            return NSColor(name: nil) { NSColor(hex: $0.isDark ? dark : light) }
        }
        folder = json["folder"] as? String ?? ""
        screenName = json["screenName"] as? String
        waitingFor = json["waitingFor"] as? String
        since = json["since"] as? Double
        openedAt = json["openedAt"] as? Double
        snoozeUntil = json["snoozeUntil"] as? Double
        snoozeRules = json["snoozeRules"] as? [String] ?? []
        notes = json["notes"] as? String ?? ""
        notesAt = json["notesAt"] as? Double
        waiting = json["waiting"] as? Int ?? 0
        team = json["team"] as? Int ?? 0
        wip = json["wip"] as? String
        wipAt = json["wipAt"] as? Double
        front = json["front"] as? String
        topic = json["topic"] as? String
        deadlines = (json["deadlines"] as? [[String: Any]] ?? []).compactMap(Deadline.init)
        deadline = json["deadline"] as? Double
    }

    var dueThisWeek: [Deadline] { deadlines.filter { thisWeek().contains(Date(timeIntervalSince1970: $0.at / 1000)) } }

    var signature: String { "\(id)|\(status)|\(emoji)|\(title)|\(since ?? 0)|\(topic ?? "")|\(photo?.hashValue ?? 0)|\(color?.description ?? "")|\(notes.hashValue)|\(waiting)|\(team)|\(wip ?? "")|\(front ?? "")|\(deadline ?? 0)" }

    var image: NSImage? {
        guard let base64 = photo?.split(separator: ",").last, let data = Data(base64Encoded: String(base64)) else { return nil }
        return NSImage(data: data)
    }

    var detail: String {
        let start = status == "wip" ? wipAt : since
        let status = status == "snoozed" ? statusText : [statusText, Face.duration(start).map { "for \($0)" }].compactMap { $0 }.joined(separator: " ")
        let opened = Face.duration(openedAt).map { "open \($0)" } ?? ""
        let noted = Face.duration(notesAt).map { "notes \($0) old" } ?? ""
        let repeats = Face.rulesText(snoozeRules).map { "snoozes \($0)" } ?? ""
        let teamText = team > 0 ? "waiting for team: \(team)" : ""
        return [status, teamText, repeats, folder, screenName ?? "", opened, noted]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static let snoozeRuleTitles: [(rule: String, title: String, short: String)] = [
        ("week", "During the Week (Mon–Fri)", "Mon–Fri"),
        ("workday", "During Work Hours (Mon–Fri 9–18)", "Mon–Fri 9–18"),
        ("weekend", "During the Weekend", "on weekends"),
    ]

    /// "Mon–Fri, on weekends", or nil without repeating snoozes.
    static func rulesText(_ rules: [String]) -> String? {
        let parts = snoozeRuleTitles.filter { rules.contains($0.rule) }.map(\.short)
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "until Sat 09:00", or the repeating snooze when it has no end.
    var snoozeNote: String {
        guard let snoozeUntil else { return Face.rulesText(snoozeRules) ?? "" }
        let until = Date(timeIntervalSince1970: snoozeUntil / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = until.timeIntervalSinceNow > 6 * 86400 ? "EEE d MMM HH:mm" : "EEE HH:mm"
        return "until \(formatter.string(from: until))"
    }

    private var statusText: String {
        switch status {
        case "needs-me": return waitingFor.map { "Needs me · \($0)" } ?? "Needs me"
        case "working": return "Working"
        case "shell": return "Shell command running"
        case "wip": return wip.flatMap { $0.isEmpty ? nil : "Work in progress · \($0)" } ?? "Work in progress"
        case "snoozed":
            guard let snoozeUntil else { return "Snoozed" }
            let formatter = DateFormatter()
            let until = Date(timeIntervalSince1970: snoozeUntil / 1000)
            // A snooze of a week or longer also names the date.
            formatter.dateFormat = until.timeIntervalSinceNow > 6 * 86400 ? "EEE d MMM HH:mm" : "EEE HH:mm"
            return "Snoozed until \(formatter.string(from: until))"
        default: return "Quiet"
        }
    }

    private static func duration(_ start: Double?) -> String? {
        guard let start else { return nil }
        let minutes = max(0, Int((Date().timeIntervalSince1970 * 1000 - start) / 60000))
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes / 60)h" }
        return "\(minutes / 1440)d"
    }
}

struct Deadline {
    let at: Double
    let allDay: Bool
    let text: String

    init?(_ json: [String: Any]) {
        guard let at = json["at"] as? Double, let text = json["text"] as? String else { return nil }
        self.at = at
        self.text = text
        allDay = json["allDay"] as? Bool ?? false
    }

    var date: Date { Date(timeIntervalSince1970: at / 1000) }
}

/// Monday 00:00 to the next Monday 00:00, local time.
func thisWeek(_ now: Date = Date()) -> DateInterval {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
}

let thisWeekTopicId = "roost-this-week"

private let dueFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE d MMM"
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return formatter
}()

/// "Today", "Tomorrow", or "Thu 19 Nov".
func dayName(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "Today" }
    if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
    return dueFormatter.string(from: date)
}

/// "Today 18:00", "Tomorrow 18:00" or "Fri 20 Nov 18:00", for a moment in ms.
func dueText(_ ms: Double) -> String {
    let date = Date(timeIntervalSince1970: ms / 1000)
    return "\(dayName(date)) \(timeFormatter.string(from: date))"
}

extension Double {
    var date: Date { Date(timeIntervalSince1970: self / 1000) }
}

func dueTime(_ deadline: Deadline) -> String { deadline.allDay ? "" : timeFormatter.string(from: deadline.date) }

/// The tooltip of the This week folder: each moment once, with the sessions due then under it.
/// For one session: its deadlines, up to three, grouped the same way.
func agendaText(_ faces: [Face], _ pick: (Face) -> [Deadline]) -> String {
    func when(_ deadline: Deadline) -> String { "\(dayName(deadline.date)) \(dueTime(deadline))".trimmingCharacters(in: .whitespaces) }
    func cut(_ text: String, _ limit: Int) -> String { text.count <= limit ? text : String(text.prefix(limit - 1)) + "…" }
    var rows: [(Deadline, String)]
    var more = 0
    if faces.count == 1, let face = faces.first {
        let due = pick(face)
        rows = due.prefix(3).map { ($0, cut($0.text, 50)) }
        more = max(0, due.count - 3)
    } else {
        rows = faces.compactMap { face in
            let due = pick(face)
            return due.first.map { ($0, cut(face.title, 32) + (due.count > 1 ? " (+\(due.count - 1))" : "")) }
        }
    }
    var lines: [String] = []
    var last: String?
    for (deadline, text) in rows.sorted(by: { $0.0.at < $1.0.at }) {
        let moment = when(deadline)
        if moment != last {
            lines.append(moment)
            last = moment
        }
        lines.append("   \(text)")
    }
    if more > 0 { lines.append("+\(more) more") }
    return lines.joined(separator: "\n")
}

struct Topic {
    let id: String
    let name: String
    var collapsed: Bool

    init(id: String, name: String, collapsed: Bool) {
        self.id = id
        self.name = name
        self.collapsed = collapsed
    }

    init?(_ json: [String: Any]) {
        guard let id = json["id"] as? String, let name = json["name"] as? String else { return nil }
        self.id = id
        self.name = name
        collapsed = json["collapsed"] as? Bool ?? false
    }

    var signature: String { "\(id)|\(name)|\(collapsed)" }
}

/// One tile of the strip, below the rooster.
enum Entry {
    case topic(Topic, members: [Face])
    case face(Face)

    var memberOf: String? {
        if case .face(let face) = self { return face.topic }
        return nil
    }
}

/// A topic sits where its first session sits, and its sessions follow it.
func entries(faces: [Face], topics: [Topic]) -> [Entry] {
    var result: [Entry] = []
    var placed = Set<String>()
    for face in faces {
        guard let id = face.topic, let topic = topics.first(where: { $0.id == id }) else {
            result.append(.face(face))
            continue
        }
        guard placed.insert(id).inserted else { continue }
        let members = faces.filter { $0.topic == id }
        result.append(.topic(topic, members: members))
        if !topic.collapsed { result += members.map(Entry.face) }
    }
    return result
}

func topicDetail(_ members: [Face], collapsed: Bool) -> String {
    let needing = members.filter { $0.status == "needs-me" }.count
    let working = members.filter { $0.status == "working" }.count
    var parts = ["\(members.count) session\(members.count == 1 ? "" : "s")"]
    if needing > 0 { parts.append("\(needing) need\(needing == 1 ? "s" : "") you") }
    if working > 0 { parts.append("\(working) working") }
    let wip = members.filter { $0.status == "wip" }.count
    if wip > 0 { parts.append("\(wip) work in progress") }
    let team = members.reduce(0) { $0 + $1.team }
    if team > 0 { parts.append("\(team) waiting for team") }
    parts.append(collapsed ? "click to expand" : "click to collapse")
    return parts.joined(separator: " · ")
}

// MARK: - Panels

func makeOverlayPanel(frame: NSRect) -> NSPanel {
    let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    return panel
}

/// The corner radius of a macOS app icon, as a share of its side.
func tilePath(_ rect: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
}

// MARK: - The strip

/// Magnifies the items under the cursor and reorders them, the way the Dock does.
///
/// The panel grows only while the cursor is on the strip, so at rest its empty area never
/// catches clicks that belong to the windows below.
final class StripView: NSView {
    private struct Item {
        let view: StripItemView
        let title: String
        let sessionId: String?
        let stripe: NSView?
        let notes: String
        let group: String
        let header: Bool
        let detail: () -> String
        /// Where the tile stood in the strip this one replaced, measured down from the top, while it moves to its place.
        var from: NSRect?
        /// New in this strip: it fades in as it slides into place.
        var appears = false

        var key: String { sessionId ?? "\(group)|\(title)" }
    }

    /// A tile of the old strip that this one no longer shows, shrinking into its topic.
    private struct Ghost {
        let view: NSView
        let from: NSRect
        let to: NSRect
    }

    var metrics = TileMetrics(size: 40)
    /// 1 for the single column; more in wide mode, which shows a grid without the zoom.
    var columns = 1
    /// The tiles before the first session: the rooster, and in wide mode the plus tile beside it.
    var leading = 1
    private var isWide: Bool { columns > 1 }
    var onReorder: (_ from: Int, _ to: Int) -> Void = { _, _ in }
    private var items: [Item] = []
    /// The tiles of the strip this one replaced, by key, with their frames measured down from the top.
    private var previous: [String: (view: NSView, frame: NSRect, group: String)] = [:]
    private var ghosts: [Ghost] = []
    private var morphStart: CFTimeInterval?
    /// The panel's frame before it grew to hold the old tiles while they move.
    private var morphRestore: NSRect?
    /// Set when the strip hides or shows its tiles: they fold into the rooster and grow out of it.
    var foldsIntoRooster = false
    private var isMorphing: Bool { morphStart != nil }
    private var tooltip: NSPanel?
    private var timer: Timer?
    private var amount: CGFloat = 0
    private var cursor: CGFloat = 0
    private var draggedIndex: Int?
    private var dropSlot = 0
    private(set) var topPadding: CGFloat = 0

    var isBusy: Bool { timer != nil }

    /// A rebuild under the cursor keeps the zoom and the label, so a click does not shrink the strip for a moment.
    /// Where each tile stands, measured down from the top. Taken before the panel resizes, which moves them.
    func snapshot() -> [String: (view: NSView, frame: NSRect, group: String)] {
        Dictionary(items.map { ($0.key, ($0.view as NSView, fromTop($0.view.frame), $0.group)) }) { first, _ in first }
    }

    func handOver(to next: StripView, tiles: [String: (view: NSView, frame: NSRect, group: String)]) {
        next.amount = amount
        next.cursor = cursor
        next.tooltip = tooltip
        tooltip = nil
        next.previous = tiles
    }

    func add(item view: StripItemView, title: String, sessionId: String? = nil, endsTopic: Bool = false, notes: String = "",
             group: String = "", header: Bool = false, detail: @escaping () -> String) {
        let stripe = endsTopic ? TopicEndView(frame: .zero) : nil
        items.append(Item(view: view, title: title, sessionId: sessionId, stripe: stripe, notes: notes, group: group, header: header,
                          detail: detail))
        addSubview(view)
        if let stripe { addSubview(stripe) }
        placeItems()
    }

    /// A rect measured down from the top of the strip, so it holds when the strip's height changes.
    private func fromTop(_ rect: NSRect) -> NSRect {
        NSRect(x: rect.minX, y: bounds.height - topPadding - rect.maxY, width: rect.width, height: rect.height)
    }

    private func toView(_ rect: NSRect) -> NSRect {
        NSRect(x: rect.minX, y: bounds.height - topPadding - rect.minY - rect.height, width: rect.width, height: rect.height)
    }

    /// After a rebuild every tile moves from where it stood to its new place. Tiles that stay slide and resize. The sessions
    /// of a topic that opens slide down out of its name and fade in; those of a topic that shuts slide up into it and fade out.
    /// Folding the strip does the same with the rooster.
    private func startMorph() {
        guard !previous.isEmpty else { return }
        let old = previous
        previous = [:]
        placeItems()
        let isTopic = { (view: NSView) in view is TopicView || view is TopicLabelView }
        // A small tile in the column of `rect`, in the row of `anchor`.
        let tucked = { (rect: NSRect, anchor: NSRect) -> NSRect in
            let side = rect.width * 0.5
            return NSRect(x: rect.midX - side / 2, y: anchor.midY - side / 2, width: side, height: side)
        }
        let topics = Dictionary(items.filter { isTopic($0.view) }.map { ($0.group, fromTop($0.view.frame)) }) { first, _ in first }
        let oldTopics = Dictionary(old.values.filter { isTopic($0.view) }.map { ($0.group, $0.frame) }) { first, _ in first }
        // The rooster is the first tile.
        let rooster = foldsIntoRooster ? items.first.map { fromTop($0.view.frame) } : nil
        let oldRooster = foldsIntoRooster ? items.first.flatMap { old[$0.key]?.frame } : nil
        var moves = false
        for index in items.indices {
            let now = fromTop(items[index].view.frame)
            if let from = old[items[index].key]?.frame {
                items[index].from = from
                if abs(from.minX - now.minX) + abs(from.minY - now.minY) + abs(from.width - now.width) > 0.5 { moves = true }
            } else {
                items[index].from = tucked(now, oldTopics[items[index].group] ?? oldRooster ?? now)
                items[index].appears = true
                moves = true
            }
        }
        let keys = Set(items.map(\.key))
        for (key, tile) in old where !keys.contains(key) {
            addSubview(tile.view, positioned: .below, relativeTo: nil)
            ghosts.append(Ghost(view: tile.view, from: tile.frame, to: tucked(tile.frame, topics[tile.group] ?? rooster ?? tile.frame)))
            moves = true
        }
        guard moves else {
            for index in items.indices { items[index].from = nil }
            return
        }
        morphStart = CACurrentMediaTime()
        begin()
        // The panel holds the old tiles until they reach their place.
        let extent = old.values.reduce(NSRect.zero) { $0.union($1.frame) }
        let (wider, taller) = (max(0, extent.maxX - bounds.width), max(0, extent.maxY - (bounds.height - topPadding)))
        if let window, wider > 0 || taller > 0 {
            let frame = window.frame
            morphRestore = frame
            window.setFrame(NSRect(x: frame.minX, y: frame.minY - taller, width: frame.width + wider, height: frame.height + taller), display: false)
        }
        placeItems()
    }

    /// Eases each tile from its old frame to the one the layout gives it now.
    private func applyMorph() {
        guard let start = morphStart else { return }
        let progress = min(1, (CACurrentMediaTime() - start) / 0.35)
        // Ease in and out, so nothing starts or stops with a jolt.
        let eased = progress < 0.5 ? 4 * pow(progress, 3) : 1 - pow(-2 * progress + 2, 3) / 2
        let blend = { (from: NSRect, to: NSRect) in
            NSRect(x: from.minX + (to.minX - from.minX) * eased, y: from.minY + (to.minY - from.minY) * eased,
                   width: from.width + (to.width - from.width) * eased, height: from.height + (to.height - from.height) * eased)
        }
        for item in items {
            guard let from = item.from else { continue }
            item.view.frame = toView(blend(from, fromTop(item.view.frame)))
            if item.appears { item.view.alphaValue = eased }
        }
        for ghost in ghosts {
            ghost.view.frame = toView(blend(ghost.from, ghost.to))
            ghost.view.alphaValue = 1 - eased
        }
        guard progress >= 1 else { return }
        morphStart = nil
        for index in items.indices {
            items[index].from = nil
            items[index].appears = false
            items[index].view.alphaValue = 1
        }
        ghosts.forEach { $0.view.removeFromSuperview() }
        ghosts = []
        if let frame = morphRestore {
            morphRestore = nil
            window?.setFrame(frame, display: false)
            placeItems()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { begin() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            timer?.invalidate()
            timer = nil
            tooltip?.close()
            return
        }
        if amount > 0 {
            // Zoomed already: grow at once, before the panel shows a frame at rest size.
            begin()
            placeItems()
        }
        startMorph()
        if amount > 0 || isMorphing { return }
        if window.frame.contains(NSEvent.mouseLocation) {
            // A rebuild under a resting cursor produces no mouseEntered.
            DispatchQueue.main.async { self.begin() }
        } else {
            // The cursor left while the strip was rebuilt: no tick runs to put away the label it handed over.
            tooltip?.orderOut(nil)
        }
    }

    private func begin() {
        guard let window, timer == nil else { return }
        if !isWide {
            topPadding = metrics.padding
            let rest = window.frame
            window.setFrame(
                NSRect(x: rest.minX, y: rest.minY - metrics.padding, width: metrics.magnifiedWidth, height: rest.height + 2 * metrics.padding),
                display: false)
        }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in autoreleasepool { self?.tick() } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let window, !StripItemView.isMovingStrip else {
            tooltip?.orderOut(nil)
            return
        }
        let mouse = NSEvent.mouseLocation
        if isWide { return tickWide(convert(window.convertPoint(fromScreen: mouse), from: nil)) }
        let frame = window.frame
        let restTop = frame.maxY - topPadding
        if let dragged = draggedIndex {
            tooltip?.orderOut(nil)
            stepReorder(dragged: dragged, cursor: restTop - mouse.y)
            return
        }

        let restBottom = frame.minY + topPadding
        let inside = mouse.x >= frame.minX - 2 && mouse.x <= frame.minX + metrics.magnifiedWidth
            && mouse.y >= restBottom - 14 && mouse.y <= restTop + 14

        amount += ((inside ? 1 : 0) - amount) * 0.3
        if inside { cursor = restTop - mouse.y }
        if !inside && amount < 0.01 && !isMorphing {
            finish()
        } else {
            placeItems()
            if inside {
                showTooltip(min(max(Int((cursor - metrics.size / 2 + metrics.step / 2) / metrics.step), 0), items.count - 1))
            } else {
                tooltip?.orderOut(nil)
            }
        }
    }

    /// Wide mode has no zoom: the label follows the tile under the cursor.
    private func tickWide(_ point: NSPoint) {
        if let dragged = draggedIndex {
            tooltip?.orderOut(nil)
            return stepReorderWide(dragged: dragged, point: point)
        }
        guard bounds.insetBy(dx: -2, dy: -2).contains(point) || isMorphing else { return finish() }
        placeItems()
        let half = metrics.gap / 2
        if let index = items.firstIndex(where: { !$0.view.isHidden && $0.view.frame.insetBy(dx: -half, dy: -half).contains(point) }) {
            showTooltip(index)
        } else {
            tooltip?.orderOut(nil)
        }
    }

    private func showTooltip(_ index: Int) {
        guard let window, items.indices.contains(index) else { return }
        let item = items[index]
        let detail = item.detail()
        let size = TooltipView.size(title: item.title, detail: detail, notes: item.notes)
        let tileMid = window.frame.minY + item.view.frame.midY
        var frame = NSRect(x: window.frame.minX + (isWide ? bounds.width : item.view.frame.maxX) + 8, y: tileMid - size.height / 2, width: size.width, height: size.height)
        // Long notes make a tall label. It stays on the screen, and its arrow keeps pointing at the tile.
        if let visible = window.screen?.visibleFrame {
            frame.origin.y = max(min(frame.minY, visible.maxY - 4 - frame.height), visible.minY + 4)
        }

        let panel = tooltip ?? makeOverlayPanel(frame: frame)
        if tooltip == nil {
            panel.ignoresMouseEvents = true
            panel.contentView = TooltipView(frame: NSRect(origin: .zero, size: size))
            tooltip = panel
        }
        panel.setFrame(frame, display: false)
        (panel.contentView as? TooltipView)?.show(title: item.title, detail: detail, notes: item.notes, arrowY: tileMid - frame.minY)
        panel.orderFrontRegardless()
    }

    private func finish() {
        guard let window else { return }
        timer?.invalidate()
        timer = nil
        amount = 0
        if !isWide {
            let grown = window.frame
            window.setFrame(
                NSRect(x: grown.minX, y: grown.minY + topPadding, width: metrics.size, height: grown.height - 2 * topPadding),
                display: false)
        }
        topPadding = 0
        tooltip?.orderOut(nil)
        placeItems()
    }

    private func restCenter(_ slot: Int) -> CGFloat { metrics.size / 2 + CGFloat(slot) * metrics.step }

    private func setFrame(of view: NSView, center: CGFloat, size: CGFloat) {
        view.frame = NSRect(x: 0, y: bounds.height - topPadding - center - size / 2, width: size, height: size)
    }

    /// The grid frames of the tiles in the given order, in view coordinates.
    private func gridFrames(_ tiles: [(group: String, header: Bool)]) -> [NSRect] {
        gridCells(tiles, columns: columns, metrics: metrics).cells.map {
            NSRect(x: $0.minX, y: bounds.height - topPadding - $0.maxY, width: $0.width, height: $0.height)
        }
    }

    /// A fisheye along the strip: the point under the cursor stays still and the rest slides apart.
    private func placeItems() {
        if isWide {
            let frames = gridFrames(items.map { ($0.group, $0.header) })
            for (index, item) in items.enumerated() { item.view.frame = frames[index] }
            applyMorph()
            return placeStripes()
        }
        let strength = (metrics.scale - 1) * amount
        var filled: CGFloat = 0
        for (index, item) in items.enumerated() {
            if index > 0 { filled += metrics.gap }
            let rest = filled + metrics.size / 2
            filled += metrics.size
            let offset = cursor - rest
            let distance = abs(offset)
            let center = cursor - (offset < 0 ? -1 : 1) * stretched(distance, strength: strength)
            let wave = distance < metrics.radius ? pow(cos(.pi * distance / (2 * metrics.radius)), 2) : 0
            setFrame(of: item.view, center: center, size: metrics.size * (1 + strength * wave))
        }
        applyMorph()
        placeStripes()
    }

    /// Each stripe sits in the middle of the gap below the last session of its topic.
    private func placeStripes() {
        for (index, item) in items.enumerated() {
            guard let stripe = item.stripe else { continue }
            stripe.isHidden = isMorphing || draggedIndex != nil
            // In wide mode the next topic's name marks the end.
            if isWide { stripe.isHidden = true }
            let top = item.view.frame.minY
            let bottom = index + 1 < items.count ? items[index + 1].view.frame.maxY : top - metrics.gap
            stripe.frame = NSRect(x: 4, y: (top + bottom) / 2 - 1, width: max(item.view.frame.width - 8, 0), height: 2)
        }
    }

    /// The integral of the size curve, so items neither overlap nor drift apart.
    private func stretched(_ distance: CGFloat, strength: CGFloat) -> CGFloat {
        guard distance < metrics.radius else { return distance + strength * metrics.radius / 2 }
        return distance + strength * (distance / 2 + metrics.radius / (2 * .pi) * sin(.pi * distance / metrics.radius))
    }

    func beginReorder(_ view: StripItemView) {
        guard draggedIndex == nil, let index = items.firstIndex(where: { $0.view === view }) else { return }
        begin()
        draggedIndex = index
        dropSlot = index
        addSubview(view, positioned: .above, relativeTo: nil)
        placeStripes()
    }

    /// The dragged tile follows the cursor and the others open a gap at the drop slot.
    private func stepReorder(dragged: Int, cursor: CGFloat) {
        let first = items.firstIndex { $0.view.reorders } ?? 1
        let last = items.lastIndex { $0.view.reorders } ?? items.count - 1
        dropSlot = min(max(Int(((cursor - metrics.size / 2) / metrics.step).rounded()), first), last)
        amount = 0
        for (index, item) in items.enumerated() {
            let isDragged = index == dragged
            let order = index < dragged ? index : index - 1
            let slot = isDragged ? dropSlot : (order < dropSlot ? order : order + 1)
            let current = bounds.height - topPadding - item.view.frame.midY
            let center = isDragged
                ? min(max(cursor, restCenter(first)), restCenter(last))
                : current + (restCenter(slot) - current) * 0.3
            let target = isDragged ? metrics.size * draggedScale : metrics.size
            setFrame(of: item.view, center: center, size: item.view.frame.width + (target - item.view.frame.width) * 0.3)
        }
    }

    /// The grid version of the drag: the drop slot is the nearest tile, and the others move to their cells in the new order.
    private func stepReorderWide(dragged: Int, point: NSPoint) {
        let first = items.firstIndex { $0.view.reorders } ?? 1
        let last = items.lastIndex { $0.view.reorders } ?? items.count - 1
        let rest = gridFrames(items.map { ($0.group, $0.header) })
        let distance = { (index: Int) in hypot(rest[index].midX - point.x, rest[index].midY - point.y) }
        dropSlot = (first...last).min { distance($0) < distance($1) } ?? dragged
        var order = Array(items.indices)
        order.remove(at: dragged)
        order.insert(dragged, at: dropSlot)
        // A dragged session joins the group it lands in.
        let tiles = order.enumerated().map { position, index -> (group: String, header: Bool) in
            let item = items[index]
            return (index == dragged && position > 0 && !item.header ? items[order[position - 1]].group : item.group, item.header)
        }
        for (position, target) in gridFrames(tiles).enumerated() {
            let view = items[order[position]].view
            if order[position] == dragged {
                let size = items[dragged].header ? rest[dragged].size : NSSize(width: metrics.size * draggedScale, height: metrics.size * draggedScale)
                view.frame = NSRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
            } else {
                let now = view.frame
                view.frame = NSRect(x: now.minX + (target.minX - now.minX) * 0.3, y: now.minY + (target.minY - now.minY) * 0.3,
                                    width: now.width + (target.width - now.width) * 0.3, height: now.height + (target.height - now.height) * 0.3)
            }
        }
    }

    func endReorder() {
        guard let dragged = draggedIndex else { return }
        draggedIndex = nil
        onReorder(dragged - leading, dropSlot - leading)
    }
}

class StripItemView: NSView {
    static var isMovingStrip = false
    var onClick: () -> Void = {}
    var onMoved: () -> Void = {}
    var onMenu: (NSEvent, NSView) -> Void = { _, _ in }
    /// False for the copies in the This week folder: their own tile is the one to drag.
    var canReorder = true
    var reorders: Bool { canReorder }
    private var lastMouse: NSPoint?
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func rightMouseDown(with event: NSEvent) { onMenu(event, self) }

    override func mouseDown(with event: NSEvent) {
        lastMouse = NSEvent.mouseLocation
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let last = lastMouse else { return }
        let now = NSEvent.mouseLocation
        let (dx, dy) = (now.x - last.x, now.y - last.y)
        if !didDrag && hypot(dx, dy) < 4 { return }
        didDrag = true
        if reorders {
            (superview as? StripView)?.beginReorder(self)
            return
        }
        StripItemView.isMovingStrip = true
        window.setFrameOrigin(NSPoint(x: window.frame.minX + dx, y: window.frame.minY + dy))
        lastMouse = now
    }

    override func mouseUp(with event: NSEvent) {
        StripItemView.isMovingStrip = false
        if !didDrag {
            onClick()
        } else if reorders {
            (superview as? StripView)?.endReorder()
        } else {
            onMoved()
        }
    }
}

final class RoosterView: StripItemView {
    override var reorders: Bool { false }

    override func draw(_ dirtyRect: NSRect) { drawLogo(in: bounds) }
}

/// The last tile. It starts a new Claude session and cannot be dragged.
final class PlusView: StripItemView {
    override var reorders: Bool { false }

    override func mouseDragged(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: 1, dy: 1)
        Palette.tile.setFill()
        tilePath(inner).fill()
        let arm = inner.width * 0.18
        let plus = NSBezierPath()
        plus.move(to: point(inner.midX - arm, inner.midY))
        plus.line(to: point(inner.midX + arm, inner.midY))
        plus.move(to: point(inner.midX, inner.midY - arm))
        plus.line(to: point(inner.midX, inner.midY + arm))
        plus.lineWidth = max(inner.width * 0.07, 1.5)
        plus.lineCapStyle = .round
        Palette.cream.setStroke()
        plus.stroke()
    }
}

/// A small orange spinner, the same size as the notification dot.
final class SpinnerView: NSView {
    private var timer: Timer?

    // The tile below handles every click.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }
        let timer = Timer(timeInterval: 1.0 / 24, repeats: true) { [weak self] _ in autoreleasepool { self?.needsDisplay = true } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        Palette.tile.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        let start = CGFloat(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)) * -360
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: NSPoint(x: bounds.midX, y: bounds.midY), radius: bounds.width * 0.3,
            startAngle: start, endAngle: start + 270)
        arc.lineWidth = bounds.width * 0.17
        arc.lineCapStyle = .round
        NSColor.systemOrange.setStroke()
        arc.stroke()
    }
}

/// A tile with a red dot when it needs the user and a spinner while it works.
/// A tile with a red dot when it needs the user, or a red badge with the number of things that wait for the user,
/// and a spinner while it works.
class TileView: StripItemView {
    private let status: String
    private let waiting: Int
    private let team: Int
    private let front: String?
    private var spinner: SpinnerView?

    private var showsCount: Bool { waiting > 0 && status != "snoozed" && status != "wip" }

    private var dotRect: NSRect {
        let side = bounds.width * 0.3
        return NSRect(x: bounds.maxX - side, y: bounds.maxY - side, width: side, height: side)
    }

    /// The badge has the top-right corner, so the spinner moves down.
    private var spinnerRect: NSRect { showsCount ? dotRect.offsetBy(dx: 0, dy: -(bounds.height - dotRect.height)) : dotRect }

    init(frame: NSRect, status: String, waiting: Int, team: Int = 0, front: String? = nil) {
        self.status = status
        self.waiting = waiting
        self.team = team
        self.front = front
        super.init(frame: frame)
        if status == "working" {
            let spinner = SpinnerView(frame: spinnerRect)
            addSubview(spinner)
            self.spinner = spinner
        }
    }

    required init?(coder: NSCoder) { nil }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        spinner?.frame = spinnerRect
    }

    /// A border around the tile of the session you look at; a faint one while another app is in front.
    func drawFrontBorder() {
        guard let front else { return }
        let border = tilePath(bounds.insetBy(dx: 1.25, dy: 1.25))
        border.lineWidth = 2.5
        Palette.terracotta.withAlphaComponent(front == "active" ? 1 : 0.45).setStroke()
        border.stroke()
    }

    func drawNotificationDot() {
        if showsCount {
            drawPill(waiting > 99 ? "99+" : String(waiting), color: .systemRed)
        } else if status == "needs-me" {
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        } else if team > 0 && status != "snoozed" {
            // Waiting for team: nothing waits on you, but a teammate owes the next step.
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        } else if status == "wip" || status == "shell" {
            drawPill("wip", color: .systemGray)
        }
    }

    private func drawPill(_ text: String, color: NSColor) {
        let height = bounds.width * 0.38
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: height * 0.68, weight: .semibold), .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let width = max(height, size.width + height * 0.55)
        let badge = NSRect(x: bounds.maxX - width, y: bounds.maxY - height, width: width, height: height)
        color.setFill()
        NSBezierPath(roundedRect: badge, xRadius: height / 2, yRadius: height / 2).fill()
        (text as NSString).draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2), withAttributes: attributes)
    }
}

final class FaceView: TileView {
    private let face: Face
    private let image: NSImage?

    init(frame: NSRect, face: Face) {
        self.face = face
        image = face.image
        super.init(frame: frame, status: face.status, waiting: face.waiting, team: face.team, front: face.front)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: 1, dy: 1)
        NSGraphicsContext.saveGraphicsState()
        tilePath(inner).addClip()
        (face.color ?? Palette.tile).setFill()
        inner.fill()
        let fraction: CGFloat = face.status == "snoozed" ? 0.4 : 1
        if let image {
            image.draw(in: inner, from: .zero, operation: .sourceOver, fraction: fraction)
        } else {
            drawEmoji(face.emoji, in: inner)
        }
        NSGraphicsContext.restoreGraphicsState()
        drawFrontBorder()
        drawNotificationDot()
    }
}

func drawEmoji(_ emoji: String, in rect: NSRect) {
    let text = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: rect.height * 0.6)])
    let size = text.size()
    text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
}

/// A folder tile with a small preview of its first four sessions.
final class TopicView: TileView {
    private let previews: [(image: NSImage?, emoji: String, color: NSColor?)]

    /// An open topic shows its sessions beside it, so only a closed one carries their border.
    init(frame: NSRect, members: [Face], collapsed: Bool) {
        previews = members.prefix(4).map { ($0.image, $0.emoji, $0.color) }
        let statuses = members.map(\.status)
        let waiting = members.filter { $0.status != "snoozed" && $0.status != "wip" }.reduce(0) { $0 + $1.waiting }
        let status = ["needs-me", "working", "wip", "shell"].first(where: statuses.contains) ?? "quiet"
        super.init(
            frame: frame, status: status,
            waiting: waiting, team: members.filter { $0.status != "snoozed" }.reduce(0) { $0 + $1.team },
            front: collapsed ? members.lazy.compactMap(\.front).first : nil)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: 1, dy: 1)
        NSGraphicsContext.saveGraphicsState()
        tilePath(inner).addClip()
        Palette.folder.setFill()
        inner.fill()
        let gap = inner.width * 0.07
        let cell = (inner.width - 3 * gap) / 2
        for (index, preview) in previews.enumerated() {
            let rect = NSRect(
                x: inner.minX + gap + CGFloat(index % 2) * (cell + gap),
                y: inner.maxY - (gap + cell) * CGFloat(index / 2 + 1), width: cell, height: cell)
            NSGraphicsContext.saveGraphicsState()
            tilePath(rect).addClip()
            (preview.color ?? Palette.tile).setFill()
            rect.fill()
            if let image = preview.image {
                image.draw(in: rect)
            } else {
                drawEmoji(preview.emoji, in: rect)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGraphicsContext.restoreGraphicsState()
        drawFrontBorder()
        drawNotificationDot()
    }
}

/// A topic in wide mode: its name, with an arrow that shows whether it is open, and the count of its sessions when shut.
final class TopicLabelView: StripItemView {
    private let text: String

    init(frame: NSRect, name: String, members: [Face], collapsed: Bool) {
        text = collapsed ? "▸ \(name) · \(members.count)" : "▾ \(name)"
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: 1, dy: 1)
        Palette.tile.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: inner, xRadius: inner.height / 3, yRadius: inner.height / 3).fill()
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(10, (inner.height * 0.6).rounded()), weight: .semibold),
            .foregroundColor: Palette.cream, .paragraphStyle: style,
        ]
        let height = text.size(withAttributes: attributes).height
        text.draw(in: NSRect(x: inner.minX + 6, y: inner.midY - height / 2, width: inner.width - 12, height: height), withAttributes: attributes)
    }
}

/// The label beside a hovered picture, like the one the Dock shows. A session's notes follow below its status.
final class TooltipView: NSView {
    private static let arrow: CGFloat = 6
    private static let padding: CGFloat = 11
    private static let maxWidth: CGFloat = 360
    private static let lineStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()
    private static let notesStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.paragraphSpacing = 4
        return style
    }()
    private static let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: lineStyle,
    ]
    private static let detailAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.white.withAlphaComponent(0.7), .paragraphStyle: lineStyle,
    ]
    static let notesAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white.withAlphaComponent(0.92), .paragraphStyle: notesStyle,
    ]

    private var title = ""
    private var detail = ""
    private var notes = ""
    private var arrowY: CGFloat?

    func show(title: String, detail: String, notes: String, arrowY: CGFloat) {
        self.title = title
        self.detail = detail
        self.notes = notes
        self.arrowY = arrowY
        needsDisplay = true
    }

    private static func headerHeight(_ detail: String) -> CGFloat { detail.isEmpty ? 28 : 44 }

    static func notesHeight(_ notes: String, width: CGFloat) -> CGFloat {
        ceil((notes as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: notesAttributes).height)
    }

    static func size(title: String, detail: String, notes: String) -> NSSize {
        let widest = max((title as NSString).size(withAttributes: titleAttributes).width, (detail as NSString).size(withAttributes: detailAttributes).width)
        guard !notes.isEmpty else {
            return NSSize(width: min(ceil(widest), maxWidth) + 2 * padding + arrow, height: headerHeight(detail))
        }
        return NSSize(width: maxWidth + 2 * padding + arrow, height: headerHeight(detail) + notesHeight(notes, width: maxWidth) + 12)
    }

    override func draw(_ dirtyRect: NSRect) {
        let pill = NSRect(x: Self.arrow, y: 0, width: bounds.width - Self.arrow, height: bounds.height)
        Palette.tooltip.setFill()
        NSBezierPath(roundedRect: pill, xRadius: 7, yRadius: 7).fill()
        let tip = min(max(arrowY ?? bounds.midY, Self.arrow + 6), bounds.height - Self.arrow - 6)
        let pointer = NSBezierPath()
        pointer.move(to: NSPoint(x: 0, y: tip))
        pointer.line(to: NSPoint(x: Self.arrow + 1, y: tip + Self.arrow))
        pointer.line(to: NSPoint(x: Self.arrow + 1, y: tip - Self.arrow))
        pointer.close()
        pointer.fill()

        let width = pill.width - 2 * Self.padding
        let x = pill.minX + Self.padding
        let top = bounds.height
        if detail.isEmpty {
            (title as NSString).draw(in: NSRect(x: x, y: top - 23, width: width, height: 18), withAttributes: Self.titleAttributes)
        } else {
            (title as NSString).draw(in: NSRect(x: x, y: top - 22, width: width, height: 18), withAttributes: Self.titleAttributes)
            (detail as NSString).draw(in: NSRect(x: x, y: top - 38, width: width, height: 16), withAttributes: Self.detailAttributes)
        }
        guard !notes.isEmpty else { return }
        let header = Self.headerHeight(detail)
        NSColor.white.withAlphaComponent(0.12).setFill()
        NSRect(x: x, y: top - header + 1, width: width, height: 1).fill()
        let height = Self.notesHeight(notes, width: width)
        (notes as NSString).draw(
            with: NSRect(x: x, y: top - header - 4 - height, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: Self.notesAttributes)
    }
}

/// The stripe under the last session of an expanded topic.
final class TopicEndView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        Palette.folder.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 1, yRadius: 1).fill()
    }
}

final class FlashView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        Palette.flash.withAlphaComponent(0.1).setFill()
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 12, yRadius: 12)
        outline.fill()
        outline.lineWidth = 8
        Palette.flash.setStroke()
        outline.stroke()
    }
}

// MARK: - Colors

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

extension NSColor {
    /// A color from "#rrggbb".
    convenience init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }
}

// MARK: - Menus and text input

final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("ActionItem is built in code") }

    @objc private func run() { handler() }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// A one-line text field beside a tile. Enter or clicking away saves, and Esc cancels.
final class TitleEditor: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    private let panel: KeyablePanel
    private let field: NSTextField
    private let onCommit: (String) -> Void
    private let onClose: () -> Void
    private let previousApp = NSWorkspace.shared.frontmostApplication
    private var isDone = false

    init(text: String, placeholder: String, beside tile: NSRect, onCommit: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        let size = NSSize(width: 320, height: 28)
        panel = KeyablePanel(
            contentRect: NSRect(origin: NSPoint(x: tile.maxX + 8, y: tile.midY - size.height / 2), size: size),
            styleMask: [.borderless], backing: .buffered, defer: false)
        field = NSTextField(frame: NSRect(origin: .zero, size: size))
        self.onCommit = onCommit
        self.onClose = onClose
        super.init()
        field.stringValue = text
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: 13)
        field.bezelStyle = .roundedBezel
        field.delegate = self
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = field
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        field.currentEditor()?.selectAll(nil)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            end(save: true)
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            end(save: false)
            return true
        }
        return false
    }

    func windowDidResignKey(_ notification: Notification) { end(save: true) }

    private func end(save: Bool) {
        guard !isDone else { return }
        isDone = true
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        panel.close()
        if save { onCommit(text) }
        previousApp?.activate()
        onClose()
    }
}

/// A date and time picker beside a tile. Enter or Set saves, Esc or clicking away cancels.
final class DateEditor: NSObject, NSWindowDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        var onCancel: () -> Void = {}
        override func cancelOperation(_ sender: Any?) { onCancel() }
    }

    private let panel: Panel
    private let picker: NSDatePicker
    private let onCommit: (Date) -> Void
    private let onClose: () -> Void
    private let previousApp = NSWorkspace.shared.frontmostApplication
    private var isDone = false

    init(date: Date, beside tile: NSRect, onCommit: @escaping (Date) -> Void, onClose: @escaping () -> Void) {
        let size = NSSize(width: 260, height: 40)
        panel = Panel(
            contentRect: NSRect(origin: NSPoint(x: tile.maxX + 8, y: tile.midY - size.height / 2), size: size),
            styleMask: [.borderless], backing: .buffered, defer: false)
        picker = NSDatePicker(frame: NSRect(x: 8, y: 8, width: 170, height: 24))
        self.onCommit = onCommit
        self.onClose = onClose
        super.init()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.dateValue = date
        let button = NSButton(title: "Set", target: self, action: #selector(save))
        button.keyEquivalent = "\r"
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 186, y: 6, width: 66, height: 28)
        let box = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        box.material = .popover
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 8
        box.addSubview(picker)
        box.addSubview(button)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = box
        panel.onCancel = { [weak self] in self?.end(save: false) }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(picker)
    }

    @objc private func save() { end(save: true) }

    func windowDidResignKey(_ notification: Notification) { end(save: false) }

    private func end(save: Bool) {
        guard !isDone else { return }
        isDone = true
        panel.close()
        if save { onCommit(picker.dateValue) }
        previousApp?.activate()
        onClose()
    }
}

// MARK: - App

// MARK: License

/// Where the Buy button goes, and the page that hands out license keys after payment.
let siteURL = URL(string: "https://roostmac.com/")!

/// Roost is free for 14 days with every session. After that it shows up to three sessions, unless it has a license.
/// A license key is "ROOST1-<id>-<signature>": an Ed25519 signature of "roost1:<id>", checked on this Mac only.
enum License {
    static let trialDays = 14
    static let freeSessions = 3
    private static let publicKey = try! Curve25519.Signing.PublicKey(
        rawRepresentation: Data(base64Encoded: "2yPZ4oZr3AktwwHNR26Jt1qp8gYcS4DWZBTvA+ooW3k=")!)

    /// The license id when the key is genuine.
    static func verify(_ key: String) -> String? {
        let parts = key.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-", maxSplits: 2).map(String.init)
        guard parts.count == 3, parts[0] == "ROOST1", parts[1].range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil else { return nil }
        var base64 = parts[2].replacingOccurrences(of: "_", with: "/").replacingOccurrences(of: "-", with: "+")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let signature = Data(base64Encoded: base64), signature.count == 64,
            publicKey.isValidSignature(signature, for: Data("roost1:\(parts[1])".utf8)) else { return nil }
        return parts[1]
    }

    static var key: String? {
        get { UserDefaults.standard.string(forKey: "licenseKey").flatMap { verify($0) == nil ? nil : $0 } }
        set { UserDefaults.standard.set(newValue, forKey: "licenseKey") }
    }

    static var isLicensed: Bool { key != nil }

    /// The first launch starts the trial.
    static var trialStart: Date {
        if let start = UserDefaults.standard.object(forKey: "trialStart") as? Date { return start }
        let now = Date()
        UserDefaults.standard.set(now, forKey: "trialStart")
        return now
    }

    static var trialDaysLeft: Int {
        let end = trialStart.addingTimeInterval(TimeInterval(trialDays * 86_400))
        return max(0, Int(ceil(end.timeIntervalSinceNow / 86_400)))
    }

    /// True when the strip shows only the free sessions.
    static var isLimited: Bool { !isLicensed && trialDaysLeft == 0 }

    static func openBuyPage() { NSWorkspace.shared.open(siteURL.appendingPathComponent("buy")) }
}

/// The tile after the free sessions: how many more sessions a license shows.
final class LockView: StripItemView {
    var count = 0
    override var reorders: Bool { false }

    override func mouseDragged(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: 1, dy: 1)
        Palette.tile.setFill()
        tilePath(inner).fill()
        let text = "+\(count)" as NSString
        let font = NSFont.systemFont(ofSize: max(inner.height * 0.34, 8), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Palette.cream]
        let size = text.size(withAttributes: attributes)
        text.draw(at: point(inner.midX - size.width / 2, inner.midY - size.height / 2), withAttributes: attributes)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var strips: [NSPanel] = []
    private var flashes: [NSPanel] = []
    private var faces: [Face] = []
    private var topics: [Topic] = []
    private var signature = ""
    private var terminalFailed = false
    private var latest: [String: Face] = [:]
    private var appliesNextPoll = false
    /// The session you just clicked, until Terminal confirms it: a poll in flight still names the old tab.
    private var clickedFront: (id: String, until: Date)?
    /// How many tiles of the This week folder head the strip; a drag counts its slots after them.
    private var weekTiles = 0
    private var editor: TitleEditor?
    private var dateEditor: DateEditor?

    /// Wide mode shows the strip as a grid of three tiles per row, so every topic can stay open.
    private var isWide: Bool {
        get { UserDefaults.standard.bool(forKey: "wideMode") }
        set { UserDefaults.standard.set(newValue, forKey: "wideMode") }
    }

    /// A click on the rooster folds every other tile into it, and the next click brings them back.
    private var isFolded: Bool {
        get { UserDefaults.standard.bool(forKey: "stripFolded") }
        set { UserDefaults.standard.set(newValue, forKey: "stripFolded") }
    }
    private var isFolding = false

    private var perchOffset: NSPoint {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: "perchX") != nil else { return NSPoint(x: 8, y: 34) }
            return NSPoint(x: defaults.double(forKey: "perchX"), y: defaults.double(forKey: "perchY"))
        }
        set {
            UserDefaults.standard.set(newValue.x, forKey: "perchX")
            UserDefaults.standard.set(newValue.y, forKey: "perchY")
        }
    }

    /// A roost://activate?key=… link, from the page after payment, licenses Roost. It may also launch it.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(openURL(_:reply:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc private func openURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let url = URLComponents(string: text),
            url.host == "activate", let key = url.queryItems?.first(where: { $0.name == "key" })?.value else { return }
        activate(key: key)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = License.trialStart
        buildMenu()
        layoutStrips()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        startServerIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func screensChanged() { layoutStrips() }

    /// Without these menu items, Cmd+C, Cmd+V and Cmd+Q do nothing in a text field.
    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Roost", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    // MARK: Strip layout

    private func layoutStrips() {
        let screens = NSScreen.screens
        while strips.count > screens.count { strips.removeLast().close() }
        while strips.count < screens.count {
            strips.append(makeOverlayPanel(frame: NSRect(x: 0, y: 0, width: 40, height: 40)))
        }
        for (panel, screen) in zip(strips, screens) {
            layout(strip: panel, on: screen)
        }
    }

    /// Opens or shuts a topic and saves the new state; the rebuilt strip animates the change.
    private func setCollapsed(_ topicId: String, _ collapsed: Bool) {
        guard let index = topics.firstIndex(where: { $0.id == topicId }) else { return }
        topics[index].collapsed = collapsed
        signature = currentSignature(faces: faces, topics: topics)
        post("api/topics/\(topicId)", ["collapsed": collapsed])
        layoutStrips()
    }

    /// Picks the largest tile size at which the rooster, every entry and the plus tile fit on the smallest screen.
    /// The rooster sits on top, then one tile per topic and visible session, then the plus tile.
    private func layout(strip panel: NSPanel, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let offset = perchOffset
        let room = visible.maxY - offset.y - floorOf(screen) - stripBottomMargin
        let week = weekEntries()
        let all = week + entries(faces: stripFaces, topics: topics)
        let locked = isFolded ? 0 : shownFaces.count - stripFaces.count
        let columns = isWide ? wideColumns : 1
        // A topic and its sessions share a group, so in wide mode each topic starts a row, under its name.
        let slots = all.enumerated().map { index, entry -> (group: String, header: Bool) in
            if case .topic(let topic, _) = entry { return (index < week.count ? "week" : topic.id, isWide) }
            return (index < week.count ? "week" : entry.memberOf ?? "loose", false)
        }
        // In the single column the rooster tops the strip and the plus tile ends it; in wide mode they share the top row.
        // The extra gap leaves room for a stripe under the last topic.
        let heightOf = { (count: Int, tiles: TileMetrics) in
            let ends = [(group: String, header: Bool)](repeating: ("ends", false), count: locked > 0 ? 3 : 2)
            let all = self.isWide ? ends + slots.prefix(count) : [ends[0]] + slots.prefix(count) + ends.dropFirst()
            return gridCells(all, columns: columns, metrics: tiles).height + (self.isWide ? 0 : tiles.gap)
        }
        // Like the Dock: the largest tiles at which every entry fits, and at the smallest size the rest is cut off.
        // Half points, so the grid ends within a few points of the bottom.
        var size = min(floor(room / CGFloat(minimumTileCount)), largestTile)
        while size > smallestTile && heightOf(all.count, TileMetrics(size: size)) > room { size -= 0.5 }
        let tiles = TileMetrics(size: max(size, smallestTile))
        var count = all.count
        while count > 0 && heightOf(count, tiles) > room { count -= 1 }
        let shown = isFolded ? [] : Array(all.prefix(count))
        weekTiles = min(week.count, shown.count)
        let height = isFolded ? tiles.size : heightOf(count, tiles)
        let width = isFolded ? tiles.size : CGFloat(columns) * tiles.step - tiles.gap
        let old = panel.contentView as? StripView
        let oldTiles = old?.snapshot() ?? [:]
        panel.setFrame(NSRect(x: visible.minX + offset.x, y: visible.maxY - offset.y - height, width: width, height: height), display: false)

        let content = StripView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.metrics = tiles
        content.columns = columns
        content.leading = isWide ? (locked > 0 ? 3 : 2) : 1
        content.foldsIntoRooster = isFolding
        content.onReorder = { [weak self] from, to in self?.reorder(from: from, to: to) }
        let itemFrame = NSRect(x: 0, y: 0, width: tiles.size, height: tiles.size)

        let rooster = RoosterView(frame: itemFrame)
        rooster.onClick = { [weak self] in
            guard let self else { return }
            self.isFolded.toggle()
            self.isFolding = true
            self.layoutStrips()
            self.isFolding = false
        }
        rooster.onMenu = { [weak self] event, view in self?.showRoosterMenu(event, view) }
        rooster.onMoved = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.remember(position: panel)
            DispatchQueue.main.async { self.layoutStrips() }
        }
        content.add(item: rooster, title: "Roost", group: "ends") { [weak self] in self?.summary ?? "" }
        let addPlus = { [weak self] in
            let plus = PlusView(frame: itemFrame)
            plus.onClick = { [weak self, weak plus] in
                if let self, let plus { self.showStartMenu(beside: plus) }
            }
            plus.onMenu = { [weak self] _, view in self?.showStartMenu(beside: view) }
            content.add(item: plus, title: "New Session", group: "ends") { "Start Claude in a folder" }
            guard locked > 0 else { return }
            let lock = LockView(frame: itemFrame)
            lock.count = locked
            lock.onClick = { License.openBuyPage() }
            lock.onMenu = { [weak self] event, view in self?.showRoosterMenu(event, view) }
            content.add(item: lock, title: "\(locked) more session\(locked == 1 ? "" : "s")", group: "ends") {
                "The free trial has ended. Roost shows \(License.freeSessions) sessions; a license shows them all. Click to buy one."
            }
        }
        if isWide && !isFolded { addPlus() }

        for (index, entry) in shown.enumerated() {
            let inWeek = index < week.count
            switch entry {
            case .face(let face):
                let view = FaceView(frame: itemFrame, face: face)
                view.canReorder = !inWeek
                view.onClick = { [weak self] in
                    self?.showFront(face.id)
                    self?.post("api/sessions/\(face.id)/open")
                }
                view.onMenu = { [weak self] event, view in self?.showMenu(for: face, event, view) }
                let next = index + 1 < shown.count ? shown[index + 1].memberOf : nil
                // A copy has an id of its own, so a topic that folds shut does not fold it too.
                content.add(item: view, title: face.title, sessionId: inWeek ? weekCopyId(face.id) : face.id,
                            endsTopic: inWeek ? index == week.count - 1 : face.topic != nil && next != face.topic,
                            notes: inWeek ? agendaText([face]) { $0.dueThisWeek } : face.notes, group: slots[index].group) { [weak self] in (self?.latest[face.id] ?? face).detail }
            case .topic(let topic, let members) where inWeek:
                let view = topicView(topic, members: members, frame: itemFrame)
                view.canReorder = false
                view.onClick = { [weak self] in self?.setWeekCollapsed(!topic.collapsed) }
                content.add(item: view, title: topic.name, notes: agendaText(members) { $0.dueThisWeek }, group: slots[index].group,
                            header: slots[index].header) {
                    "\(members.count) session\(members.count == 1 ? "" : "s") with something due before Monday"
                }
            case .topic(let topic, let members):
                let view = topicView(topic, members: members, frame: itemFrame)
                view.onClick = { [weak self] in self?.setCollapsed(topic.id, !topic.collapsed) }
                view.onMenu = { [weak self] event, view in self?.showMenu(for: topic, event, view) }
                content.add(item: view, title: topic.name, group: slots[index].group, header: slots[index].header) { [weak self] in
                    topicDetail(members.map { self?.latest[$0.id] ?? $0 }, collapsed: topic.collapsed)
                }
            }
        }
        if !isWide && !isFolded { addPlus() }
        old?.handOver(to: content, tiles: oldTiles)
        panel.contentView = content
        showUnlessFullscreen(panel, on: screen)
    }

    /// A fullscreen video or app covers its screen, so the strip on that screen steps aside until it leaves.
    private func showUnlessFullscreen(_ panel: NSPanel, on screen: NSScreen) {
        if isFullscreen(screen) { panel.orderOut(nil) } else if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func hideOverFullscreen() {
        for (panel, screen) in zip(strips, NSScreen.screens) { showUnlessFullscreen(panel, on: screen) }
    }

    /// True when the screen shows a fullscreen space. macOS takes the Dock's window off such a space,
    /// and the fullscreen app spans the screen's full width; its toolbar may push the page window down.
    private func isFullscreen(_ screen: NSScreen) -> Bool {
        guard let primary = NSScreen.screens.first,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        let frame = screen.frame
        let whole = CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        let me = ProcessInfo.processInfo.processIdentifier
        let rects = windows.compactMap { window -> (owner: String, layer: Int, pid: Int32, rect: CGRect)? in
            guard let bounds = window[kCGWindowBounds as String] as? NSDictionary, let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return (window[kCGWindowOwnerName as String] as? String ?? "", window[kCGWindowLayer as String] as? Int ?? 0,
                    window[kCGWindowOwnerPID as String] as? Int32 ?? 0, rect)
        }
        let dockHere = rects.contains { $0.owner == "Dock" && $0.layer == 20 && $0.rect == whole }
        let spanning = rects.contains { $0.layer == 0 && $0.pid != me && $0.rect.minX == whole.minX && $0.rect.width == whole.width && $0.rect.intersects(whole) }
        return !dockHere && spanning
    }

    /// The lowest point the strip may reach. A Dock at the bottom keeps the whole width of its band out of the visible frame,
    /// but it sits in the middle: unless its icons reach the strip, the strip may go down to the screen's edge.
    private func floorOf(_ screen: NSScreen) -> CGFloat {
        let visible = screen.visibleFrame
        guard visible.minY > screen.frame.minY, let dock = UserDefaults(suiteName: "com.apple.dock") else { return visible.minY }
        let pinned = (dock.array(forKey: "persistent-apps") as? [[String: Any]] ?? []).compactMap {
            ($0["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
        }
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier)
        let others = (dock.array(forKey: "persistent-others") ?? []).count
        // Finder, the Trash, three recent apps and the dividers on top of the apps and folders.
        let icons = CGFloat(Set(pinned + running).count + others + 6)
        let tile = dock.double(forKey: "tilesize") > 0 ? CGFloat(dock.double(forKey: "tilesize")) : 48
        let dockLeft = screen.frame.midX - icons * tile * 1.1 / 2
        // The widest strip: three of the largest tiles.
        let stripRight = visible.minX + perchOffset.x + CGFloat(wideColumns) * largestTile * 1.15
        return dockLeft > stripRight ? screen.frame.minY : visible.minY
    }

    /// A folder tile in the single column; in wide mode the topic's name above its sessions.
    private func topicView(_ topic: Topic, members: [Face], frame: NSRect) -> StripItemView {
        isWide ? TopicLabelView(frame: frame, name: topic.name, members: members, collapsed: topic.collapsed)
            : TopicView(frame: frame, members: members, collapsed: topic.collapsed)
    }

    private var summary: String {
        if terminalFailed { return "Cannot read Terminal. Allow it in Privacy & Security, Automation." }
        let needing = faces.filter { $0.status == "needs-me" }.count
        let working = faces.filter { $0.status == "working" }.count
        let snoozed = faces.filter { $0.status == "snoozed" }.count
        var parts = [needing == 0 ? "Nobody needs you" : "\(needing) need\(needing == 1 ? "s" : "") you"]
        if working > 0 { parts.append("\(working) working") }
        let wip = faces.filter { $0.status == "wip" }.count
        if wip > 0 { parts.append("\(wip) work in progress") }
        if snoozed > 0 { parts.append("\(snoozed) snoozed (under +)") }
        if !License.isLicensed {
            let days = License.trialDaysLeft
            parts.append(days > 0 ? "Trial: \(days) day\(days == 1 ? "" : "s") left" : "Free: \(License.freeSessions) sessions")
        }
        return parts.joined(separator: " · ")
    }

    /// One offset from the top-left corner serves every screen.
    private func remember(position panel: NSPanel) {
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let topPadding = (panel.contentView as? StripView)?.topPadding ?? 0
        perchOffset = NSPoint(x: panel.frame.minX - visible.minX, y: visible.maxY - (panel.frame.maxY - topPadding))
    }

    /// Applies a drop locally at once, then saves the order and any change of topic.
    /// A snoozed session leaves the strip. The Snoozed menu under the plus tile lists it.
    private var shownFaces: [Face] { faces.filter { $0.status != "snoozed" } }

    /// The sessions with a tile: every shown one, or only the free ones once the trial is over without a license.
    private var stripFaces: [Face] { License.isLimited ? Array(shownFaces.prefix(License.freeSessions)) : shownFaces }

    private var weekCollapsed: Bool {
        get { UserDefaults.standard.object(forKey: "thisWeekCollapsed") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "thisWeekCollapsed") }
    }

    private func weekCopyId(_ id: String) -> String { "\(thisWeekTopicId):\(id)" }

    /// Folds the This week folder open or shut, like a topic.
    private func setWeekCollapsed(_ collapsed: Bool) {
        weekCollapsed = collapsed
        layoutStrips()
    }

    /// A folder on top with a copy of every session that has something due this week, soonest first.
    private func weekEntries() -> [Entry] {
        let members = stripFaces.filter { !$0.dueThisWeek.isEmpty }.sorted { $0.dueThisWeek[0].at < $1.dueThisWeek[0].at }
        guard !members.isEmpty else { return [] }
        let topic = Topic(id: thisWeekTopicId, name: "This week", collapsed: weekCollapsed)
        return [.topic(topic, members: members)] + (topic.collapsed ? [] : members.map(Entry.face))
    }

    private func reorder(from slot: Int, to target: Int) {
        let (from, to) = (slot - weekTiles, target - weekTiles)
        var list = entries(faces: stripFaces, topics: topics)
        guard from != to, list.indices.contains(from), list.indices.contains(to) else {
            layoutStrips()
            return
        }
        let moved = list.remove(at: from)
        list.insert(moved, at: to)

        var movedTopic: String?
        if case .topic(let topic, _) = moved { movedTopic = topic.id }
        var ids: [String] = []
        for entry in list {
            switch entry {
            case .topic(let topic, let members):
                // An expanded topic's sessions have their own tiles, except when the topic itself moves.
                if topic.collapsed || topic.id == movedTopic { ids += members.map(\.id) }
            case .face(let face):
                if face.topic == nil || face.topic != movedTopic { ids.append(face.id) }
            }
        }

        // The sessions a license would show keep their order after the free ones.
        let onStrip = Set(stripFaces.map(\.id))
        ids += shownFaces.filter { !onStrip.contains($0.id) }.map(\.id)

        // Each snoozed session keeps its place: right after the session it followed.
        for (index, face) in faces.enumerated() where face.status == "snoozed" {
            let at = faces[..<index].last { ids.contains($0.id) }.flatMap { ids.firstIndex(of: $0.id) }.map { $0 + 1 } ?? 0
            ids.insert(face.id, at: at)
        }

        let byId = Dictionary(uniqueKeysWithValues: faces.map { ($0.id, $0) })
        faces = ids.compactMap { byId[$0] }
        post("api/order", ["ids": ids])

        if case .face(let face) = moved {
            let joined = topicAfterDrop(of: face, at: to, in: list)
            if joined != face.topic, let index = faces.firstIndex(where: { $0.id == face.id }) {
                faces[index].topic = joined
                post("api/sessions/\(face.id)", ["topic": joined ?? NSNull()])
            }
        }
        signature = currentSignature(faces: faces, topics: topics)
        layoutStrips()
    }

    /// A tile joins a topic when it lands under the topic's tile or between two of its sessions.
    private func topicAfterDrop(of face: Face, at index: Int, in list: [Entry]) -> String? {
        let above = index > 0 ? list[index - 1] : nil
        let below = index + 1 < list.count ? list[index + 1] : nil
        if case .topic(let topic, _)? = above, !topic.collapsed { return topic.id }
        if let topic = above?.memberOf, topic == below?.memberOf { return topic }
        if let own = face.topic, above?.memberOf == own { return own }
        return nil
    }

    // MARK: Menus

    private func showRoosterMenu(_ event: NSEvent, _ view: NSView) {
        let menu = NSMenu()
        let wide = ActionItem("Wide Mode") { [weak self] in
            guard let self else { return }
            self.isWide.toggle()
            self.layoutStrips()
        }
        wide.state = isWide ? .on : .off
        menu.addItem(wide)
        menu.addItem(ActionItem("Restart All Sessions…") { [weak self] in self?.confirmRestartAll() })
        menu.addItem(ActionItem("Connect to Claude Code…") { [weak self] in self?.connectClaude() })
        menu.addItem(.separator())
        if License.isLicensed {
            let licensed = NSMenuItem(title: "Licensed. Thank you!", action: nil, keyEquivalent: "")
            licensed.isEnabled = false
            menu.addItem(licensed)
        } else {
            let days = License.trialDaysLeft
            menu.addItem(ActionItem(days > 0 ? "Buy Roost… (trial: \(days) day\(days == 1 ? "" : "s") left)" : "Buy Roost…") { License.openBuyPage() })
            menu.addItem(ActionItem("Enter License…") { [weak self] in self?.askLicense() })
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem("Quit Roost") { NSApp.terminate(nil) })
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    // MARK: License and setup

    private func askLicense() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Enter your Roost license"
        alert.informativeText = "Paste the key from the page after your purchase, or from your receipt email."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "ROOST1-…"
        if let copied = NSPasteboard.general.string(forType: .string), License.verify(copied) != nil { field.stringValue = copied }
        alert.accessoryView = field
        alert.addButton(withTitle: "Activate")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn { activate(key: field.stringValue) }
    }

    private func activate(key: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        if License.verify(key) != nil {
            License.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
            layoutStrips()
            alert.messageText = "Roost is licensed"
            alert.informativeText = "Thank you! Every session now has a tile."
        } else {
            alert.alertStyle = .warning
            alert.messageText = "This license key is not valid"
            alert.informativeText = "Copy the whole key, from ROOST1- to the end, and try again. Lost it? Reply to your receipt email."
        }
        alert.runModal()
    }

    /// The first time, Roost offers to add its skill and hook to Claude Code, so sessions set their own pictures, notes and badges.
    private func offerClaudeSetup() {
        guard !UserDefaults.standard.bool(forKey: "claudeSetupAsked") else { return }
        UserDefaults.standard.set(true, forKey: "claudeSetupAsked")
        connectClaude()
    }

    private func connectClaude() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Connect Roost to Claude Code?"
        alert.informativeText = "Roost adds the roost skill to ~/.claude/skills and a hook to ~/.claude/settings.json (a backup is kept). Then each session sets its own picture, color and notes, and its badge counts what waits for you. Sessions that start after this pick it up."
        alert.addButton(withTitle: "Connect")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn, let (node, root) = serverPaths() else { return }
        let setup = Process()
        setup.executableURL = URL(fileURLWithPath: node)
        setup.arguments = ["\(root)/src/setup.js", root, node]
        let output = Pipe()
        setup.standardOutput = output
        setup.standardError = output
        let done = NSAlert()
        do {
            try setup.run()
            setup.waitUntilExit()
            let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            done.messageText = setup.terminationStatus == 0 ? "Roost is connected to Claude Code" : "Roost could not connect to Claude Code"
            done.informativeText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            done.messageText = "Roost could not connect to Claude Code"
            done.informativeText = error.localizedDescription
        }
        done.runModal()
    }

    /// Terminal quits and opens every Claude session in it again, for a Terminal setting that needs a fresh start.
    private func confirmRestartAll() {
        URLSession.shared.dataTask(with: serverURL.appendingPathComponent("api/restart-all")) { [weak self] data, _, _ in
            let plan = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            DispatchQueue.main.async { self?.askRestartAll(plan) }
        }.resume()
    }

    private func askRestartAll(_ plan: [String: Any]) {
        let count = plan["sessions"] as? Int ?? 0
        let busy = plan["busy"] as? [String] ?? []
        let alert = NSAlert()
        if plan["running"] as? Bool == true {
            alert.messageText = "A restart is already running."
            alert.runModal()
            return
        }
        guard count > 0 else {
            alert.messageText = "No Claude session runs in a Terminal tab."
            alert.runModal()
            return
        }
        alert.messageText = "Restart \(count) Claude session\(count == 1 ? "" : "s")?"
        let rearm = plan["rearm"] as? Int ?? 0
        var info = "Terminal quits, then opens each session again where it was. Sessions in screen, such as agents, keep running."
        if rearm > 0 { info += " \(rearm) had background work, such as a shell, a loop or open items; they get a prompt to start it again." }
        if !busy.isEmpty { info += "\n\nWorking now: \(busy.joined(separator: ", ")). Restarting now stops their turn." }
        let others = plan["others"] as? [String] ?? []
        if !others.isEmpty { info += "\n\nThese other tabs close, and what runs in them stops:\n" + others.map { "• \($0)" }.joined(separator: "\n") }
        let viewers = plan["viewers"] as? Int ?? 0
        if viewers > 0 { info += "\n\n\(viewers) agent viewer tab\(viewers == 1 ? "" : "s") close; the agents keep running." }
        alert.informativeText = info
        if !busy.isEmpty { alert.addButton(withTitle: "Restart When Done") }
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let answer = alert.runModal()
        let first = NSApplication.ModalResponse.alertFirstButtonReturn
        let second = NSApplication.ModalResponse(rawValue: first.rawValue + 1)
        if busy.isEmpty, answer == first { post("api/restart-all", ["force": true]) }
        if !busy.isEmpty, answer == first { post("api/restart-all", ["wait": true]) }
        if !busy.isEmpty, answer == second { post("api/restart-all", ["force": true]) }
    }

    /// The menu waits for the folder list and the recent sessions, so it opens at the tile rather than at the click event.
    private func showStartMenu(beside view: NSView) {
        var locations: [String] = []
        var recent: [[String: Any]] = []
        let group = DispatchGroup()
        group.enter()
        URLSession.shared.dataTask(with: serverURL.appendingPathComponent("api/locations")) { data, _, _ in
            let root = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            locations = root?["locations"] as? [String] ?? []
            group.leave()
        }.resume()
        group.enter()
        URLSession.shared.dataTask(with: serverURL.appendingPathComponent("api/recent")) { data, _, _ in
            let root = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            recent = root?["sessions"] as? [[String: Any]] ?? []
            group.leave()
        }.resume()
        group.notify(queue: .main) { [weak self, weak view] in
            guard let self, let view, view.window != nil else { return }
            self.startMenu(locations, recent: recent).popUp(positioning: nil, at: point(view.bounds.maxX + 4, view.bounds.maxY), in: view)
        }
    }

    private func menuItem(_ name: String, note: String, action: @escaping () -> Void) -> ActionItem {
        let item = ActionItem(name, handler: action)
        let title = NSMutableAttributedString(string: name, attributes: [.font: NSFont.menuFont(ofSize: 0)])
        title.append(NSAttributedString(string: "  \(note)", attributes: [.font: NSFont.menuFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]))
        item.attributedTitle = title
        return item
    }

    private func startMenu(_ locations: [String], recent: [[String: Any]]) -> NSMenu {
        let menu = NSMenu()
        for path in locations {
            let parent = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
            menu.addItem(menuItem((path as NSString).lastPathComponent, note: parent) { [weak self] in self?.start(in: path) })
        }
        if !locations.isEmpty { menu.addItem(.separator()) }
        let sessions = recent.compactMap { session -> (id: String, title: String, at: Double)? in
            guard let id = session["id"] as? String, let title = session["title"] as? String, let at = session["lastAt"] as? Double else { return nil }
            return (id, title, at)
        }
        if !sessions.isEmpty {
            let item = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for session in sessions {
                let short = session.title.count > 60 ? String(session.title.prefix(59)) + "…" : session.title
                submenu.addItem(menuItem(short, note: Self.when(session.at)) { [weak self] in
                    self?.post("api/resume", ["id": session.id])
                })
            }
            item.submenu = submenu
            menu.addItem(item)
        }
        let snoozed = faces.filter { $0.status == "snoozed" }
        if !snoozed.isEmpty {
            let item = NSMenuItem(title: "Snoozed", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for face in snoozed {
                let short = face.title.count > 60 ? String(face.title.prefix(59)) + "…" : face.title
                let entry = menuItem(short, note: face.snoozeNote) {}
                let actions = NSMenu()
                actions.addItem(ActionItem("Wake") { [weak self] in self?.post("api/sessions/\(face.id)/wake") })
                actions.addItem(ActionItem("Open") { [weak self] in self?.post("api/sessions/\(face.id)/open") })
                entry.submenu = actions
                submenu.addItem(entry)
            }
            item.submenu = submenu
            menu.addItem(item)
        }
        menu.addItem(ActionItem("New Location…") { [weak self] in self?.chooseLocation() })
        return menu
    }

    private static func when(_ milliseconds: Double) -> String {
        let date = Date(timeIntervalSince1970: milliseconds / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if Calendar.current.isDateInToday(date) { return "today \(formatter.string(from: date))" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday \(formatter.string(from: date))" }
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    private func chooseLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Start Claude Here"
        panel.message = "Choose the folder for the new Claude session."
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { start(in: url.path) }
    }

    private func start(in path: String) { post("api/start", ["cwd": path]) }

    private func screenRect(of view: NSView) -> NSRect {
        view.window?.convertToScreen(view.convert(view.bounds, to: nil)) ?? .zero
    }

    private func askForText(_ text: String, placeholder: String, beside view: NSView, onCommit: @escaping (String) -> Void) {
        editor = TitleEditor(
            text: text, placeholder: placeholder, beside: screenRect(of: view), onCommit: onCommit,
            onClose: { [weak self] in self?.editor = nil })
        editor?.show()
    }

    func buildMenu(for face: Face, beside view: NSView) -> NSMenu {
        let menu = NSMenu()
        let path = "api/sessions/\(face.id)"
        menu.addItem(ActionItem("Open") { [weak self] in self?.post("\(path)/open") })
        menu.addItem(ActionItem("Rename…") { [weak self, weak view] in
            guard let self, let view else { return }
            self.askForText(face.title, placeholder: "Title", beside: view) { title in
                if title != face.title { self.post(path, ["title": title == face.autoTitle ? "" : title]) }
            }
        })
        menu.addItem(.separator())
        if face.status == "needs-me" && face.waitingFor == nil {
            menu.addItem(ActionItem("Mark as Seen") { [weak self] in self?.post("\(path)/seen") })
        }
        if face.status == "snoozed" {
            menu.addItem(ActionItem("Wake") { [weak self] in self?.post("\(path)/wake") })
        }
        if face.status == "wip" {
            menu.addItem(ActionItem("Not in Progress") { [weak self] in self?.post(path, ["wip": NSNull()]) })
        } else if face.status == "needs-me" || face.status == "quiet" {
            // For work Claude waits on without saying so: the mark ends when the session starts its next turn.
            menu.addItem(ActionItem("Work in Progress (until it continues)") { [weak self] in self?.post(path, ["wip": "marked by you"]) })
        }
        let snooze = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for (title, until) in Self.snoozeChoices() {
            choices.addItem(ActionItem(title) { [weak self] in self?.post(path, ["snoozeUntil": until]) })
        }
        choices.addItem(.separator())
        let header = NSMenuItem(title: "Every Week", action: nil, keyEquivalent: "")
        header.isEnabled = false
        choices.addItem(header)
        for (rule, title, _) in Face.snoozeRuleTitles {
            let isOn = face.snoozeRules.contains(rule)
            let toggle = ActionItem(title) { [weak self] in
                let rules = isOn ? face.snoozeRules.filter { $0 != rule } : face.snoozeRules + [rule]
                self?.post(path, ["snoozeRules": rules])
            }
            toggle.state = isOn ? .on : .off
            choices.addItem(toggle)
        }
        snooze.submenu = choices
        menu.addItem(snooze)

        let deadline = NSMenuItem(title: face.deadline == nil ? "Deadline" : "Deadline: \(dueText(face.deadline!))", action: nil, keyEquivalent: "")
        let dates = NSMenu()
        for (title, at) in Self.deadlineChoices() {
            dates.addItem(ActionItem(title) { [weak self] in self?.post(path, ["deadline": at]) })
        }
        dates.addItem(ActionItem("Pick a Date…") { [weak self, weak view] in
            guard let self, let view else { return }
            let start = face.deadline.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Self.deadlineChoices()[0].1.date
            self.dateEditor = DateEditor(date: start, beside: self.screenRect(of: view), onCommit: { date in
                self.post(path, ["deadline": (date.timeIntervalSince1970 * 1000).rounded()])
            }, onClose: { [weak self] in self?.dateEditor = nil })
            self.dateEditor?.show()
        })
        if face.deadline != nil {
            dates.addItem(.separator())
            dates.addItem(ActionItem("Clear Deadline") { [weak self] in self?.post(path, ["deadline": NSNull()]) })
        }
        deadline.submenu = dates
        menu.addItem(deadline)

        let move = NSMenuItem(title: "Move to Topic", action: nil, keyEquivalent: "")
        let destinations = NSMenu()
        for topic in topics where topic.id != face.topic {
            destinations.addItem(ActionItem(topic.name) { [weak self] in self?.post(path, ["topic": topic.id]) })
        }
        if !topics.isEmpty { destinations.addItem(.separator()) }
        destinations.addItem(ActionItem("New Topic…") { [weak self, weak view] in
            guard let self, let view else { return }
            self.askForText("", placeholder: "Topic name", beside: view) { name in
                if !name.isEmpty { self.post("api/topics", ["name": name, "sessionIds": [face.id]]) }
            }
        })
        if face.topic != nil {
            destinations.addItem(ActionItem("Remove from Topic") { [weak self] in self?.post(path, ["topic": NSNull()]) })
        }
        move.submenu = destinations
        menu.addItem(move)
        return menu
    }

    func buildMenu(for topic: Topic, beside view: NSView) -> NSMenu {
        let menu = NSMenu()
        let path = "api/topics/\(topic.id)"
        menu.addItem(ActionItem(topic.collapsed ? "Expand" : "Collapse") { [weak self] in
            self?.setCollapsed(topic.id, !topic.collapsed)
        })
        menu.addItem(ActionItem("Rename…") { [weak self, weak view] in
            guard let self, let view else { return }
            self.askForText(topic.name, placeholder: "Topic name", beside: view) { name in
                if !name.isEmpty && name != topic.name { self.post(path, ["name": name]) }
            }
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Delete Topic") { [weak self] in self?.post("\(path)/delete") })
        return menu
    }

    private func showMenu(for face: Face, _ event: NSEvent, _ view: NSView) {
        NSMenu.popUpContextMenu(buildMenu(for: face, beside: view), with: event, for: view)
    }

    private func showMenu(for topic: Topic, _ event: NSEvent, _ view: NSView) {
        NSMenu.popUpContextMenu(buildMenu(for: topic, beside: view), with: event, for: view)
    }

    /// 18:00 today (while it is still ahead), tomorrow, this Friday, next Monday and next Friday.
    private static func deadlineChoices() -> [(String, Double)] {
        let now = Date()
        let calendar = Calendar.current
        func evening(_ day: Date) -> Date { calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day }
        func next(_ weekday: Int, after day: Date) -> Date {
            calendar.nextDate(after: day, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime) ?? day
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let friday = next(6, after: calendar.startOfDay(for: now).addingTimeInterval(-1))
        let monday = next(2, after: now)
        var days: [Date] = []
        if evening(now) > now { days.append(evening(now)) }
        days.append(evening(tomorrow))
        days.append(evening(friday))
        days.append(evening(monday))
        days.append(evening(next(6, after: monday)))
        var seen = Set<Date>()
        return days.filter { $0 > now && seen.insert($0).inserted }.sorted().map { (dueText($0.timeIntervalSince1970 * 1000), $0.timeIntervalSince1970 * 1000) }
    }

    private static func snoozeChoices() -> [(String, Double)] {
        let now = Date()
        var tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        tomorrow = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let calendar = Calendar.current
        // Weekday 7 is Saturday and 2 is Monday. On a weekend, the next choice is Monday instead.
        let isWeekend = calendar.isDateInWeekend(now)
        let next = calendar.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0, weekday: isWeekend ? 2 : 7), matchingPolicy: .nextTime) ?? now
        func later(_ component: Calendar.Component, _ value: Int) -> Double {
            (calendar.date(byAdding: component, value: value, to: now) ?? now).timeIntervalSince1970 * 1000
        }
        return [
            ("1 Hour", (now.timeIntervalSince1970 + 3600) * 1000),
            ("3 Hours", (now.timeIntervalSince1970 + 3 * 3600) * 1000),
            ("Tomorrow 9:00", tomorrow.timeIntervalSince1970 * 1000),
            (isWeekend ? "Until Monday 9:00" : "Until the Weekend (Sat 9:00)", next.timeIntervalSince1970 * 1000),
            ("For 2 Days", later(.day, 2)),
            ("For 3 Days", later(.day, 3)),
            ("For 4 Days", later(.day, 4)),
            ("For 1 Week", later(.day, 7)),
            ("For 2 Weeks", later(.day, 14)),
            ("For 1 Month", later(.month, 1)),
        ]
    }

    // MARK: Server

    private func startServerIfNeeded() {
        ping { [weak self] isUp in
            guard let self else { return }
            if !isUp { self.spawnServer() }
            self.connectWhenUp()
        }
    }

    private func ping(_ done: @escaping (Bool) -> Void) {
        URLSession.shared.dataTask(with: serverURL.appendingPathComponent("api/health")) { _, response, _ in
            let isUp = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { done(isUp) }
        }.resume()
    }

    /// Node and the server: a build from a clone names them in Info.plist; the downloaded app carries both inside.
    private func serverPaths() -> (node: String, root: String)? {
        let info = Bundle.main.infoDictionary ?? [:]
        if let node = info["RoostNode"] as? String, let root = info["RoostRoot"] as? String { return (node, root) }
        guard let resources = Bundle.main.resourceURL else { return nil }
        return (resources.appendingPathComponent("node/bin/node").path, resources.appendingPathComponent("server").path)
    }

    private func spawnServer() {
        guard let (node, root) = serverPaths() else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".roost")
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let log = home.appendingPathComponent("server.log")
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }

        let server = Process()
        server.executableURL = URL(fileURLWithPath: node)
        server.arguments = ["\(root)/src/server.js"]
        // The flags a session from the + tile starts with, for example --dangerously-skip-permissions. None by default.
        if let flags = UserDefaults.standard.string(forKey: "claudeArgs") {
            server.environment = ProcessInfo.processInfo.environment.merging(["ROOST_CLAUDE_ARGS": flags]) { $1 }
        }
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            server.standardOutput = handle
            server.standardError = handle
        }
        try? server.run()
    }

    private func connectWhenUp() {
        ping { [weak self] isUp in
            guard let self else { return }
            if isUp {
                self.pollFaces()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.offerClaudeSetup() }
                // A strip nobody touches gets no events, so AppKit never empties its autorelease pool: each tick empties its own.
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    autoreleasepool {
                        self?.pollFaces()
                        self?.hideOverFullscreen()
                    }
                }
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
                ) { [weak self] _ in self?.hideOverFullscreen() }
                // Switching apps moves the border between full and faint; ask at once instead of at the next poll.
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
                ) { [weak self] _ in self?.pollFaces(fresh: true) }
                self.waitForFlash()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.connectWhenUp() }
            }
        }
    }

    private func pollFaces(fresh: Bool = false) {
        let appearance = URLQueryItem(name: "appearance", value: NSApp.effectiveAppearance.isDark ? "dark" : "light")
        let url = serverURL.appendingPathComponent("api/sessions").appending(queryItems: fresh ? [appearance, URLQueryItem(name: "fresh", value: "1")] : [appearance])
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let sessions = root["sessions"] as? [[String: Any]]
            else { return }
            let faces = sessions.compactMap(Face.init)
            let topics = (root["topics"] as? [[String: Any]] ?? []).compactMap(Topic.init)
            let terminalFailed = root["terminalFailed"] as? Bool ?? false
            DispatchQueue.main.async { autoreleasepool { self?.show(faces: faces, topics: topics, terminalFailed: terminalFailed) } }
        }.resume()
    }

    private func withFront(_ id: String, in faces: [Face]) -> [Face] {
        faces.map { face in
            var face = face
            face.front = face.id == id ? "active" : nil
            return face
        }
    }

    /// Moves the border at the click, before Terminal has brought the tab forward.
    private func showFront(_ id: String) {
        clickedFront = (id, Date().addingTimeInterval(2))
        faces = withFront(id, in: faces)
        signature = currentSignature(faces: faces, topics: topics)
        layoutStrips()
    }

    private func currentSignature(faces: [Face], topics: [Topic]) -> String {
        (faces.map(\.signature) + topics.map(\.signature)).joined(separator: ",")
    }

    private func show(faces: [Face], topics: [Topic], terminalFailed: Bool) {
        var faces = faces
        if let clicked = clickedFront {
            if Date() < clicked.until, faces.first(where: { $0.front != nil })?.id != clicked.id {
                faces = withFront(clicked.id, in: faces)
            } else {
                clickedFront = nil
            }
        }
        self.terminalFailed = terminalFailed
        // The time counters change on every poll, so tooltips read them here instead of rebuilding the strip.
        latest = Dictionary(faces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let next = currentSignature(faces: faces, topics: topics)
        // Background changes wait for the cursor to leave. The user's own action does not.
        let isBusy = StripItemView.isMovingStrip || strips.contains { ($0.contentView as? StripView)?.isBusy == true }
        if next == signature || (isBusy && !appliesNextPoll) { return }
        appliesNextPoll = false
        signature = next
        self.faces = faces
        self.topics = topics
        layoutStrips()
    }

    private func post(_ path: String, _ body: [String: Any] = [:]) {
        var request = URLRequest(url: serverURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.appliesNextPoll = true
                self?.pollFaces()
            }
        }.resume()
    }

    /// The server answers this request when any client opens a session.
    private func waitForFlash() {
        URLSession.shared.dataTask(with: serverURL.appendingPathComponent("api/flash")) { [weak self] data, _, error in
            let root = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let bounds = root?["bounds"] as? [CGFloat]
            DispatchQueue.main.asyncAfter(deadline: .now() + (error == nil ? 0 : 1)) {
                if let bounds { self?.flash(terminalBounds: bounds) }
                self?.waitForFlash()
            }
        }.resume()
    }

    /// Terminal reports left, top, right, bottom with y growing down from the primary screen's top.
    private func flash(terminalBounds b: [CGFloat]) {
        guard b.count == 4, let primary = NSScreen.screens.first else { return }
        let frame = NSRect(x: b[0], y: primary.frame.height - b[3], width: b[2] - b[0], height: b[3] - b[1]).insetBy(dx: -6, dy: -6)
        let panel = makeOverlayPanel(frame: frame)
        panel.ignoresMouseEvents = true
        panel.contentView = FlashView(frame: NSRect(origin: .zero, size: frame.size))
        panel.orderFrontRegardless()
        flashes.append(panel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.9
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.close()
                self?.flashes.removeAll { $0 === panel }
            })
        }
    }
}

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--verify-license" {
    print(License.verify(CommandLine.arguments[2]) ?? "invalid")
    exit(0)
}

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--render-icon", let pixels = Int(CommandLine.arguments[2]) {
    try renderIcon(pixels: pixels, to: CommandLine.arguments[3])
    exit(0)
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApp.setActivationPolicy(.regular)
NSApp.run()
