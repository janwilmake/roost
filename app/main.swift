import AppKit

let serverURL = URL(string: "http://127.0.0.1:4777/")!
let largestTile: CGFloat = 40
let smallestTile: CGFloat = 22
let magnifiedSize: CGFloat = 80
let magnifyRadius: CGFloat = 110
/// Like the Dock, every tile shrinks when the strip has more tiles than the screen has room for.
var perchSize = largestTile
var stripGap: CGFloat { gap(for: perchSize) }
var stripStep: CGFloat { perchSize + stripGap }
var magnifiedScale: CGFloat { magnifiedSize / perchSize }
var magnifiedWidth: CGFloat { magnifiedSize + 4 }
var magnifyPadding: CGFloat { (magnifiedScale - 1) * magnifyRadius / 2 + 6 }
func gap(for tile: CGFloat) -> CGFloat { (tile * 0.15).rounded() }
let draggedScale: CGFloat = 1.25
let stripBottomMargin: CGFloat = 8

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
func drawLogo(in rect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    let toRect = NSAffineTransform()
    toRect.translateX(by: rect.minX, yBy: rect.minY)
    toRect.scale(by: rect.width / 100)
    toRect.concat()
    NSGradient(starting: Palette.terracotta, ending: Palette.deepTerracotta)?.draw(in: eggPath(), angle: -90)

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

    // The margin follows the macOS app icon grid.
    drawLogo(in: NSRect(x: 100, y: 100, width: 824, height: 824))
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
    let focusMs: Double
    let workMs: Double
    var topic: String?

    init?(_ json: [String: Any]) {
        guard let id = json["id"] as? String, let status = json["status"] as? String else { return nil }
        self.id = id
        self.status = status
        title = json["title"] as? String ?? ""
        autoTitle = json["autoTitle"] as? String ?? ""
        emoji = json["emoji"] as? String ?? ""
        photo = json["photo"] as? String
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
        focusMs = json["focusMs"] as? Double ?? 0
        workMs = json["workMs"] as? Double ?? 0
        topic = json["topic"] as? String
    }

    var signature: String { "\(id)|\(status)|\(emoji)|\(title)|\(since ?? 0)|\(topic ?? "")|\(photo?.hashValue ?? 0)|\(notes.hashValue)|\(waiting)" }

    var image: NSImage? {
        guard let base64 = photo?.split(separator: ",").last, let data = Data(base64Encoded: String(base64)) else { return nil }
        return NSImage(data: data)
    }

    var detail: String {
        let status = status == "snoozed" ? statusText : [statusText, Face.duration(since).map { "for \($0)" }].compactMap { $0 }.joined(separator: " ")
        let opened = Face.duration(openedAt).map { "open \($0)" } ?? ""
        let noted = Face.duration(notesAt).map { "notes \($0) old" } ?? ""
        let repeats = Face.rulesText(snoozeRules).map { "snoozes \($0)" } ?? ""
        return [status, repeats, folder, screenName ?? "", opened, Face.timeSpent(focusMs: focusMs, workMs: workMs), noted]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "you 25m · Claude 1h 10m": the time this tab was in front while you used the Mac, and the time Claude worked.
    static func timeSpent(focusMs: Double, workMs: Double) -> String {
        [focusMs >= 60000 ? "you \(span(focusMs))" : "", workMs >= 60000 ? "Claude \(span(workMs))" : ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func span(_ ms: Double) -> String {
        let minutes = Int(ms / 60000)
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 600 && minutes % 60 > 0 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes / 60)h"
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

    private var statusText: String {
        switch status {
        case "needs-me": return waitingFor.map { "Needs me · \($0)" } ?? "Needs me"
        case "working": return "Working"
        case "shell": return "Shell command running"
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

struct Topic {
    let id: String
    let name: String
    var collapsed: Bool

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
    let spent = Face.timeSpent(focusMs: members.reduce(0) { $0 + $1.focusMs }, workMs: members.reduce(0) { $0 + $1.workMs })
    if !spent.isEmpty { parts.append(spent) }
    parts.append(collapsed ? "click to expand" : "click to collapse")
    return parts.joined(separator: " · ")
}

// MARK: - Panels

func makeOverlayPanel(frame: NSRect) -> NSPanel {
    let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
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
        let detail: () -> String
        var reveal: CGFloat = 1
        var revealTarget: CGFloat = 1
    }

    var onReorder: (_ from: Int, _ to: Int) -> Void = { _, _ in }
    private var items: [Item] = []
    private var isRevealing = false
    private var onRevealDone: (() -> Void)?
    private var tooltip: NSPanel?
    private var timer: Timer?
    private var amount: CGFloat = 0
    private var cursor: CGFloat = 0
    private var draggedIndex: Int?
    private var dropSlot = 0
    private(set) var topPadding: CGFloat = 0

    var isBusy: Bool { timer != nil }

    func add(item view: StripItemView, title: String, sessionId: String? = nil, endsTopic: Bool = false, notes: String = "",
             detail: @escaping () -> String) {
        let stripe = endsTopic ? TopicEndView(frame: .zero) : nil
        items.append(Item(view: view, title: title, sessionId: sessionId, stripe: stripe, notes: notes, detail: detail))
        addSubview(view)
        if let stripe { addSubview(stripe) }
        placeItems()
    }

    /// Slides the given sessions out from under their topic tile.
    func animateIn(_ sessionIds: Set<String>) {
        for index in items.indices where items[index].sessionId.map(sessionIds.contains) == true {
            items[index].reveal = 0
        }
        startReveal()
    }

    /// Folds the given sessions into their topic tile, then calls `done`.
    func animateOut(_ sessionIds: Set<String>, done: (() -> Void)?) {
        for index in items.indices where items[index].sessionId.map(sessionIds.contains) == true {
            items[index].revealTarget = 0
        }
        onRevealDone = done
        startReveal()
    }

    private func startReveal() {
        isRevealing = true
        begin()
        placeItems()
    }

    /// Returns true when the finishing callback ran, because it replaces this view.
    private func stepReveal() -> Bool {
        var moving = false
        for index in items.indices where items[index].reveal != items[index].revealTarget {
            let gap = items[index].revealTarget - items[index].reveal
            if abs(gap) < 0.01 {
                items[index].reveal = items[index].revealTarget
            } else {
                items[index].reveal += gap * 0.25
                moving = true
            }
        }
        isRevealing = moving
        guard !moving, let done = onRevealDone else { return false }
        onRevealDone = nil
        done()
        return true
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
        // A rebuild under a resting cursor produces no mouseEntered.
        if window.frame.contains(NSEvent.mouseLocation) { DispatchQueue.main.async { self.begin() } }
    }

    private func begin() {
        guard let window, timer == nil else { return }
        topPadding = magnifyPadding
        let rest = window.frame
        window.setFrame(
            NSRect(x: rest.minX, y: rest.minY - magnifyPadding, width: magnifiedWidth, height: rest.height + 2 * magnifyPadding),
            display: false)
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let window, !StripItemView.isMovingStrip else {
            tooltip?.orderOut(nil)
            return
        }
        if stepReveal() { return }
        let mouse = NSEvent.mouseLocation
        let frame = window.frame
        let restTop = frame.maxY - topPadding
        if let dragged = draggedIndex {
            tooltip?.orderOut(nil)
            stepReorder(dragged: dragged, cursor: restTop - mouse.y)
            return
        }

        let restBottom = frame.minY + topPadding
        let inside = mouse.x >= frame.minX - 2 && mouse.x <= frame.minX + magnifiedWidth
            && mouse.y >= restBottom - 14 && mouse.y <= restTop + 14

        amount += ((inside ? 1 : 0) - amount) * 0.3
        if inside { cursor = restTop - mouse.y }
        if !inside && amount < 0.01 && !isRevealing {
            finish()
        } else {
            placeItems()
            if inside { showTooltip() } else { tooltip?.orderOut(nil) }
        }
    }

    private func showTooltip() {
        guard let window, !items.isEmpty else { return }
        let index = min(max(Int((cursor - perchSize / 2 + stripStep / 2) / stripStep), 0), items.count - 1)
        let item = items[index]
        let detail = item.detail()
        let size = TooltipView.size(title: item.title, detail: detail, notes: item.notes)
        let tileMid = window.frame.minY + item.view.frame.midY
        var frame = NSRect(x: window.frame.minX + item.view.frame.maxX + 8, y: tileMid - size.height / 2, width: size.width, height: size.height)
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
        let grown = window.frame
        window.setFrame(
            NSRect(x: grown.minX, y: grown.minY + topPadding, width: perchSize, height: grown.height - 2 * topPadding),
            display: false)
        topPadding = 0
        tooltip?.orderOut(nil)
        placeItems()
    }

    private func restCenter(_ slot: Int) -> CGFloat { perchSize / 2 + CGFloat(slot) * stripStep }

    private func setFrame(of view: NSView, center: CGFloat, size: CGFloat) {
        view.frame = NSRect(x: 0, y: bounds.height - topPadding - center - size / 2, width: size, height: size)
    }

    /// A fisheye along the strip: the point under the cursor stays still and the rest slides apart.
    private func placeItems() {
        let strength = (magnifiedScale - 1) * amount
        var filled: CGFloat = 0
        for (index, item) in items.enumerated() {
            if index > 0 { filled += stripGap * item.reveal }
            let rest = filled + perchSize * item.reveal / 2
            filled += perchSize * item.reveal
            let offset = cursor - rest
            let distance = abs(offset)
            let center = cursor - (offset < 0 ? -1 : 1) * stretched(distance, strength: strength)
            let wave = distance < magnifyRadius ? pow(cos(.pi * distance / (2 * magnifyRadius)), 2) : 0
            setFrame(of: item.view, center: center, size: perchSize * item.reveal * (1 + strength * wave))
            item.view.isHidden = item.reveal < 0.02
        }
        placeStripes()
    }

    /// Each stripe sits in the middle of the gap below the last session of its topic.
    private func placeStripes() {
        for (index, item) in items.enumerated() {
            guard let stripe = item.stripe else { continue }
            stripe.isHidden = isRevealing || draggedIndex != nil
            let top = item.view.frame.minY
            let bottom = index + 1 < items.count ? items[index + 1].view.frame.maxY : top - stripGap
            stripe.frame = NSRect(x: 4, y: (top + bottom) / 2 - 1, width: max(item.view.frame.width - 8, 0), height: 2)
        }
    }

    /// The integral of the size curve, so items neither overlap nor drift apart.
    private func stretched(_ distance: CGFloat, strength: CGFloat) -> CGFloat {
        guard distance < magnifyRadius else { return distance + strength * magnifyRadius / 2 }
        return distance + strength * (distance / 2 + magnifyRadius / (2 * .pi) * sin(.pi * distance / magnifyRadius))
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
        let last = items.lastIndex { $0.view.reorders } ?? items.count - 1
        dropSlot = min(max(Int(((cursor - perchSize / 2) / stripStep).rounded()), 1), last)
        amount = 0
        for (index, item) in items.enumerated() {
            let isDragged = index == dragged
            let order = index < dragged ? index : index - 1
            let slot = isDragged ? dropSlot : (order < dropSlot ? order : order + 1)
            let current = bounds.height - topPadding - item.view.frame.midY
            let center = isDragged
                ? min(max(cursor, restCenter(1)), restCenter(last))
                : current + (restCenter(slot) - current) * 0.3
            let target = isDragged ? perchSize * draggedScale : perchSize
            setFrame(of: item.view, center: center, size: item.view.frame.width + (target - item.view.frame.width) * 0.3)
        }
    }

    func endReorder() {
        guard let dragged = draggedIndex else { return }
        draggedIndex = nil
        onReorder(dragged - 1, dropSlot - 1)
    }
}

class StripItemView: NSView {
    static var isMovingStrip = false
    var onClick: () -> Void = {}
    var onMoved: () -> Void = {}
    var onMenu: (NSEvent, NSView) -> Void = { _, _ in }
    var reorders: Bool { true }
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
        let timer = Timer(timeInterval: 1.0 / 24, repeats: true) { [weak self] _ in self?.needsDisplay = true }
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
    private var spinner: SpinnerView?

    private var showsCount: Bool { waiting > 0 && status != "snoozed" }

    private var dotRect: NSRect {
        let side = bounds.width * 0.3
        return NSRect(x: bounds.maxX - side, y: bounds.maxY - side, width: side, height: side)
    }

    /// The badge has the top-right corner, so the spinner moves down.
    private var spinnerRect: NSRect { showsCount ? dotRect.offsetBy(dx: 0, dy: -(bounds.height - dotRect.height)) : dotRect }

    init(frame: NSRect, status: String, waiting: Int) {
        self.status = status
        self.waiting = waiting
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

    func drawNotificationDot() {
        if showsCount {
            drawCount()
        } else if status == "needs-me" {
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }
    }

    private func drawCount() {
        let text = waiting > 99 ? "99+" : String(waiting)
        let height = bounds.width * 0.38
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: height * 0.68, weight: .semibold), .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let width = max(height, size.width + height * 0.55)
        let badge = NSRect(x: bounds.maxX - width, y: bounds.maxY - height, width: width, height: height)
        NSColor.systemRed.setFill()
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
        super.init(frame: frame, status: face.status, waiting: face.waiting)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let inner = bounds.insetBy(dx: 1, dy: 1)
        NSGraphicsContext.saveGraphicsState()
        tilePath(inner).addClip()
        Palette.tile.setFill()
        inner.fill()
        let fraction: CGFloat = face.status == "snoozed" ? 0.4 : 1
        if let image {
            image.draw(in: inner, from: .zero, operation: .sourceOver, fraction: fraction)
        } else {
            drawEmoji(face.emoji, in: inner)
        }
        NSGraphicsContext.restoreGraphicsState()
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
    private let previews: [(image: NSImage?, emoji: String)]

    init(frame: NSRect, members: [Face]) {
        previews = members.prefix(4).map { ($0.image, $0.emoji) }
        let statuses = members.map(\.status)
        let waiting = members.filter { $0.status != "snoozed" }.reduce(0) { $0 + $1.waiting }
        super.init(
            frame: frame, status: statuses.contains("needs-me") ? "needs-me" : statuses.contains("working") ? "working" : "quiet",
            waiting: waiting)
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
            Palette.tile.setFill()
            rect.fill()
            if let image = preview.image {
                image.draw(in: rect)
            } else {
                drawEmoji(preview.emoji, in: rect)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGraphicsContext.restoreGraphicsState()
        drawNotificationDot()
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

// MARK: - Overview

extension NSColor {
    /// A color from "#rrggbb".
    convenience init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// One donut of the overview: how a total time splits over the sessions, with a legend that gives each time.
final class TimeChartView: NSView {
    struct Slice {
        let label: String
        let ms: Double
        let color: NSColor
    }

    static let height: CGFloat = 158
    private static let diameter: CGFloat = 104
    private static let rowHeight: CGFloat = 17
    private let title: String
    private let slices: [Slice]

    init(frame: NSRect, title: String, slices: [Slice]) {
        self.title = title
        self.slices = slices
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    /// The categorical palette, in fixed order: light and dark steps of blue, orange, aqua, yellow, magenta, green, violet.
    static let colors: [NSColor] = [
        ("#2a78d6", "#3987e5"), ("#eb6834", "#d95926"), ("#1baf7a", "#199e70"), ("#eda100", "#c98500"),
        ("#e87ba4", "#d55181"), ("#008300", "#008300"), ("#6250d6", "#9085e9"),
    ].map { light, dark in
        NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        }
    }
    static let other = NSColor(hex: "#898781")

    /// Picks up to seven sessions with the most time in either chart. Each keeps its color in both charts,
    /// in strip order, and the rest goes into "Other".
    static func charts(for faces: [Face]) -> (you: [Slice], claude: [Slice]) {
        let named = faces.filter { $0.focusMs + $0.workMs >= 60000 }
            .sorted { $0.focusMs + $0.workMs > $1.focusMs + $1.workMs }.prefix(colors.count).map(\.id)
        let chosen = faces.filter { named.contains($0.id) }
        func slices(_ time: (Face) -> Double) -> [Slice] {
            var result: [Slice] = []
            var rest = 0.0
            for face in faces {
                if let index = chosen.firstIndex(where: { $0.id == face.id }), time(face) >= 60000 {
                    // "Ernst Jan (Search X) · 15 seats" shows as "Ernst Jan (Search X)".
                    let label = face.title.components(separatedBy: " · ").first ?? face.title
                    result.append(Slice(label: label, ms: time(face), color: colors[index]))
                } else {
                    rest += time(face)
                }
            }
            if rest >= 60000 { result.append(Slice(label: "Other", ms: rest, color: other)) }
            return result
        }
        return (slices(\.focusMs), slices(\.workMs))
    }

    override func draw(_ dirtyRect: NSRect) {
        let total = slices.reduce(0) { $0 + $1.ms }
        let heading = total > 0 ? "\(title) · \(Face.span(total))" : title
        (heading as NSString).draw(at: .zero, withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.labelColor])

        let ring = NSRect(x: 0, y: 26, width: Self.diameter, height: Self.diameter)
        let center = NSPoint(x: ring.midX, y: ring.midY)
        let outer = Self.diameter / 2
        let inner = outer * 0.58
        guard total > 0 else {
            let track = NSBezierPath(ovalIn: ring.insetBy(dx: (outer - inner) / 2, dy: (outer - inner) / 2))
            track.lineWidth = outer - inner
            NSColor.separatorColor.setStroke()
            track.stroke()
            ("No time counted yet" as NSString).draw(
                at: NSPoint(x: ring.maxX + 16, y: ring.midY - 8),
                withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])
            return
        }

        // In a flipped view the angles run clockwise; -90° is the top.
        var start: CGFloat = -90
        for slice in slices {
            let end = start + 360 * CGFloat(slice.ms / total)
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
            path.appendArc(withCenter: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
            path.close()
            slice.color.setFill()
            path.fill()
            if slices.count > 1 {
                // A 2px gap in the window color between slices.
                NSColor.windowBackgroundColor.setStroke()
                path.lineWidth = 2
                path.stroke()
            }
            start = end
        }

        let legendX = ring.maxX + 18
        let legendWidth = bounds.width - legendX
        let truncating = NSMutableParagraphStyle()
        truncating.lineBreakMode = .byTruncatingTail
        let labelAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.labelColor, .paragraphStyle: truncating]
        let timeAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
        let rows = slices.count
        var y = ring.midY - CGFloat(rows) * Self.rowHeight / 2
        for slice in slices {
            slice.color.setFill()
            NSBezierPath(roundedRect: NSRect(x: legendX, y: y + 4, width: 9, height: 9), xRadius: 2, yRadius: 2).fill()
            let time = Face.span(slice.ms) as NSString
            let timeWidth = ceil(time.size(withAttributes: timeAttributes).width)
            time.draw(at: NSPoint(x: bounds.width - timeWidth, y: y), withAttributes: timeAttributes)
            (slice.label as NSString).draw(
                in: NSRect(x: legendX + 15, y: y, width: max(0, legendWidth - 15 - timeWidth - 8), height: Self.rowHeight),
                withAttributes: labelAttributes)
            y += Self.rowHeight
        }
    }
}

/// Closes on Escape, like a sheet.
final class OverviewPanel: NSPanel {
    override func cancelOperation(_ sender: Any?) { close() }
}

/// One session in the overview: picture, title, status and notes. A click opens the session.
final class OverviewRow: NSView {
    static let picture: CGFloat = 44
    static let inset: CGFloat = 12
    private static let titleAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor.labelColor]
    private static let detailAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.secondaryLabelColor]
    private static let notesAttributes: [NSAttributedString.Key: Any] = {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 4
        return [.font: NSFont.systemFont(ofSize: 12.5), .foregroundColor: NSColor.labelColor, .paragraphStyle: style]
    }()

    private let face: Face
    private let onOpen: () -> Void
    private var hovered = false {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    init(face: Face, width: CGFloat, onOpen: @escaping () -> Void) {
        self.face = face
        self.onOpen = onOpen
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height(for: face, width: width)))
        let picture = FaceView(frame: NSRect(x: Self.inset, y: Self.inset, width: Self.picture, height: Self.picture), face: face)
        picture.onClick = onOpen
        addSubview(picture)
    }

    required init?(coder: NSCoder) { nil }

    private static func textWidth(_ width: CGFloat) -> CGFloat { width - picture - 3 * inset }

    static func height(for face: Face, width: CGFloat) -> CGFloat {
        var text: CGFloat = 20 + 16
        if !face.notes.isEmpty {
            text += 8 + ceil((face.notes as NSString).boundingRect(
                with: NSSize(width: textWidth(width), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: notesAttributes).height)
        }
        return max(picture, text) + 2 * inset
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseUp(with event: NSEvent) { onOpen() }

    override func draw(_ dirtyRect: NSRect) {
        if hovered {
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 2), xRadius: 8, yRadius: 8).fill()
        }
        let x = Self.inset * 2 + Self.picture
        let width = Self.textWidth(bounds.width)
        (face.title as NSString).draw(
            with: NSRect(x: x, y: Self.inset, width: width, height: 20), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: Self.titleAttributes)
        (face.detail as NSString).draw(
            with: NSRect(x: x, y: Self.inset + 20, width: width, height: 16), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: Self.detailAttributes)
        guard !face.notes.isEmpty else { return }
        (face.notes as NSString).draw(
            with: NSRect(x: x, y: Self.inset + 44, width: width, height: bounds.height - Self.inset * 2 - 44),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: Self.notesAttributes)
    }
}

/// Every session in strip order, with its title, status and notes. The rooster opens it.
final class Overview: NSObject, NSWindowDelegate {
    private let panel: OverviewPanel
    private let scroll = NSScrollView()
    private var faces: [Face] = []
    private var topics: [Topic] = []
    var onOpen: (String) -> Void = { _ in }

    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = OverviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640), styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered, defer: false)
        super.init()
        panel.title = "Roost"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 360, height: 240)
        panel.delegate = self
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        panel.contentView = scroll
    }

    func toggle(faces: [Face], topics: [Topic], beside anchor: NSRect) {
        if panel.isVisible {
            panel.close()
            return
        }
        self.faces = faces
        self.topics = topics
        rebuild()
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let height = min(panel.frame.height, visible.height - 40)
        panel.setFrame(NSRect(x: anchor.maxX + 16, y: anchor.maxY - height, width: panel.frame.width, height: height), display: false)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func update(faces: [Face], topics: [Topic]) {
        self.faces = faces
        self.topics = topics
        if panel.isVisible { rebuild() }
    }

    func windowDidResize(_ notification: Notification) { rebuild() }

    private func rebuild() {
        let width = scroll.contentSize.width
        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        var y: CGFloat = 6
        if !faces.isEmpty {
            let (you, claude) = TimeChartView.charts(for: faces)
            let gap: CGFloat = 24
            let chartWidth = (width - 2 * OverviewRow.inset - gap) / 2
            for (index, (title, slices)) in [("Your time", you), ("Claude's time", claude)].enumerated() {
                let frame = NSRect(x: OverviewRow.inset + CGFloat(index) * (chartWidth + gap), y: y + 10, width: chartWidth, height: TimeChartView.height)
                document.addSubview(TimeChartView(frame: frame, title: title, slices: slices))
            }
            y += TimeChartView.height + 14
        }
        let expanded = topics.map { topic -> Topic in
            var open = topic
            open.collapsed = false
            return open
        }
        for entry in entries(faces: faces, topics: expanded) {
            switch entry {
            case .topic(let topic, let members):
                let header = NSTextField(labelWithString: "\(topic.name.uppercased())  ·  \(topicDetail(members, collapsed: false).components(separatedBy: " · ").dropLast().joined(separator: " · "))")
                header.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                header.textColor = .secondaryLabelColor
                header.frame = NSRect(x: OverviewRow.inset, y: y + 10, width: width - 2 * OverviewRow.inset, height: 16)
                document.addSubview(header)
                y += 30
            case .face(let face):
                let row = OverviewRow(face: face, width: width) { [weak self] in
                    self?.onOpen(face.id)
                    self?.panel.close()
                }
                row.frame.origin.y = y
                document.addSubview(row)
                y += row.frame.height
            }
        }
        if faces.isEmpty {
            let empty = NSTextField(labelWithString: "No Claude Code sessions are running.")
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: OverviewRow.inset, y: 16, width: width - 2 * OverviewRow.inset, height: 18)
            document.addSubview(empty)
            y = 50
        }
        document.setFrameSize(NSSize(width: width, height: max(y + 6, scroll.contentSize.height)))
        let origin = scroll.contentView.bounds.origin
        scroll.documentView = document
        scroll.contentView.scroll(to: NSPoint(x: 0, y: min(origin.y, max(0, document.frame.height - scroll.contentSize.height))))
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

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var strips: [NSPanel] = []
    private var flashes: [NSPanel] = []
    private var faces: [Face] = []
    private var topics: [Topic] = []
    private var signature = ""
    private var terminalFailed = false
    private var latest: [String: Face] = [:]
    private var appliesNextPoll = false
    private var isCollapsing = false
    private var editor: TitleEditor?
    private let overview = Overview()

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        overview.onOpen = { [weak self] id in self?.post("api/sessions/\(id)/open") }
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

    private func layoutStrips(revealing sessionIds: Set<String> = []) {
        isCollapsing = false
        let screens = NSScreen.screens
        fitTiles(on: screens)
        while strips.count > screens.count { strips.removeLast().close() }
        while strips.count < screens.count {
            strips.append(makeOverlayPanel(frame: NSRect(x: 0, y: 0, width: perchSize, height: perchSize)))
        }
        for (panel, screen) in zip(strips, screens) {
            layout(strip: panel, on: screen)
            if !sessionIds.isEmpty { (panel.contentView as? StripView)?.animateIn(sessionIds) }
        }
    }

    /// Animates a topic open or shut, and saves the new state.
    private func setCollapsed(_ topicId: String, _ collapsed: Bool) {
        guard !isCollapsing, let index = topics.firstIndex(where: { $0.id == topicId }) else { return }
        let members = Set(faces.filter { $0.topic == topicId }.map(\.id))
        let apply = { [weak self] in
            guard let self else { return }
            self.topics[index].collapsed = collapsed
            self.signature = self.currentSignature(faces: self.faces, topics: self.topics)
            self.post("api/topics/\(topicId)", ["collapsed": collapsed])
            self.layoutStrips(revealing: collapsed ? [] : members)
        }
        guard collapsed else {
            apply()
            return
        }
        isCollapsing = true
        var done: (() -> Void)? = apply
        for strip in strips {
            (strip.contentView as? StripView)?.animateOut(members, done: done)
            done = nil
        }
    }

    /// Picks the largest tile size at which the rooster, every entry and the plus tile fit on the smallest screen.
    private func fitTiles(on screens: [NSScreen]) {
        let room = (screens.map(\.visibleFrame.height).min() ?? 0) - perchOffset.y - stripBottomMargin
        let tiles = CGFloat(entries(faces: faces, topics: topics).count + 2)
        var size = largestTile
        while size > smallestTile && tiles * (size + gap(for: size)) > room { size -= 1 }
        perchSize = size
    }

    /// The rooster sits on top, then one tile per topic and visible session, then the plus tile.
    private func layout(strip panel: NSPanel, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let offset = perchOffset
        let capacity = max(0, Int((visible.height - offset.y - stripBottomMargin - perchSize - stripGap) / stripStep) - 1)
        let shown = Array(entries(faces: faces, topics: topics).prefix(capacity))
        // The extra gap leaves room for a stripe under a topic at the end of the sessions.
        let height = perchSize + CGFloat(shown.count + 1) * stripStep + stripGap
        panel.setFrame(NSRect(x: visible.minX + offset.x, y: visible.maxY - offset.y - height, width: perchSize, height: height), display: false)

        let content = StripView(frame: NSRect(x: 0, y: 0, width: perchSize, height: height))
        content.onReorder = { [weak self] from, to in self?.reorder(from: from, to: to) }
        let itemFrame = NSRect(x: 0, y: 0, width: perchSize, height: perchSize)

        let rooster = RoosterView(frame: itemFrame)
        rooster.onClick = { [weak self, weak rooster] in
            if let self, let rooster { self.overview.toggle(faces: self.faces.map { self.latest[$0.id] ?? $0 }, topics: self.topics, beside: self.screenRect(of: rooster)) }
        }
        rooster.onMenu = { [weak self] event, view in self?.showRoosterMenu(event, view) }
        rooster.onMoved = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.remember(position: panel)
            DispatchQueue.main.async { self.layoutStrips() }
        }
        content.add(item: rooster, title: "Roost") { [weak self] in self?.summary ?? "" }

        for (index, entry) in shown.enumerated() {
            switch entry {
            case .face(let face):
                let view = FaceView(frame: itemFrame, face: face)
                view.onClick = { [weak self] in self?.post("api/sessions/\(face.id)/open") }
                view.onMenu = { [weak self] event, view in self?.showMenu(for: face, event, view) }
                let next = index + 1 < shown.count ? shown[index + 1].memberOf : nil
                content.add(item: view, title: face.title, sessionId: face.id, endsTopic: face.topic != nil && next != face.topic,
                            notes: face.notes) { [weak self] in (self?.latest[face.id] ?? face).detail }
            case .topic(let topic, let members):
                let view = TopicView(frame: itemFrame, members: members)
                view.onClick = { [weak self] in self?.setCollapsed(topic.id, !topic.collapsed) }
                view.onMenu = { [weak self] event, view in self?.showMenu(for: topic, event, view) }
                content.add(item: view, title: topic.name) { [weak self] in
                    topicDetail(members.map { self?.latest[$0.id] ?? $0 }, collapsed: topic.collapsed)
                }
            }
        }
        let plus = PlusView(frame: itemFrame)
        plus.onClick = { [weak self, weak plus] in
            if let self, let plus { self.showStartMenu(beside: plus) }
        }
        plus.onMenu = { [weak self] _, view in self?.showStartMenu(beside: view) }
        content.add(item: plus, title: "New Session") { "Start Claude in a folder" }
        panel.contentView = content
        panel.orderFrontRegardless()
    }

    private var summary: String {
        if terminalFailed { return "Cannot read Terminal. Allow it in Privacy & Security, Automation." }
        let needing = faces.filter { $0.status == "needs-me" }.count
        let working = faces.filter { $0.status == "working" }.count
        let snoozed = faces.filter { $0.status == "snoozed" }.count
        var parts = [needing == 0 ? "Nobody needs you" : "\(needing) need\(needing == 1 ? "s" : "") you"]
        if working > 0 { parts.append("\(working) working") }
        if snoozed > 0 { parts.append("\(snoozed) snoozed") }
        return parts.joined(separator: " · ")
    }

    /// One offset from the top-left corner serves every screen.
    private func remember(position panel: NSPanel) {
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let topPadding = (panel.contentView as? StripView)?.topPadding ?? 0
        perchOffset = NSPoint(x: panel.frame.minX - visible.minX, y: visible.maxY - (panel.frame.maxY - topPadding))
    }

    /// Applies a drop locally at once, then saves the order and any change of topic.
    private func reorder(from: Int, to: Int) {
        var list = entries(faces: faces, topics: topics)
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
        menu.addItem(ActionItem("Overview") { [weak self, weak view] in
            guard let self, let view else { return }
            self.overview.toggle(faces: self.faces, topics: self.topics, beside: self.screenRect(of: view))
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Quit Roost") { NSApp.terminate(nil) })
        NSMenu.popUpContextMenu(menu, with: event, for: view)
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

    private func spawnServer() {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let node = info["RoostNode"] as? String, let root = info["RoostRoot"] as? String else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".roost")
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let log = home.appendingPathComponent("server.log")
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }

        let server = Process()
        server.executableURL = URL(fileURLWithPath: node)
        server.arguments = ["\(root)/src/server.js"]
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
                Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.pollFaces() }
                self.waitForFlash()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.connectWhenUp() }
            }
        }
    }

    private func pollFaces() {
        URLSession.shared.dataTask(with: serverURL.appendingPathComponent("api/sessions")) { [weak self] data, _, _ in
            guard let data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let sessions = root["sessions"] as? [[String: Any]]
            else { return }
            let faces = sessions.compactMap(Face.init)
            let topics = (root["topics"] as? [[String: Any]] ?? []).compactMap(Topic.init)
            let terminalFailed = root["terminalFailed"] as? Bool ?? false
            DispatchQueue.main.async { self?.show(faces: faces, topics: topics, terminalFailed: terminalFailed) }
        }.resume()
    }

    private func currentSignature(faces: [Face], topics: [Topic]) -> String {
        (faces.map(\.signature) + topics.map(\.signature)).joined(separator: ",")
    }

    private func show(faces: [Face], topics: [Topic], terminalFailed: Bool) {
        self.terminalFailed = terminalFailed
        // The time counters change on every poll, so tooltips read them here instead of rebuilding the strip.
        latest = Dictionary(faces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let next = currentSignature(faces: faces, topics: topics)
        // Background changes wait for the cursor to leave. The user's own action does not.
        let isBusy = StripItemView.isMovingStrip || strips.contains { ($0.contentView as? StripView)?.isBusy == true }
        if isCollapsing || next == signature || (isBusy && !appliesNextPoll) { return }
        appliesNextPoll = false
        signature = next
        self.faces = faces
        self.topics = topics
        layoutStrips()
        overview.update(faces: faces, topics: topics)
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

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--render-icon", let pixels = Int(CommandLine.arguments[2]) {
    try renderIcon(pixels: pixels, to: CommandLine.arguments[3])
    exit(0)
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApp.setActivationPolicy(.regular)
NSApp.run()
