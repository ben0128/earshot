// PROTOTYPE — throwaway, not production code. Do not build on this.
// Question: what should Earshot's menu bar menu look like?
// Three structurally different variants, switched from the orange "◆ PROTOTYPE" item at the bottom of the menu:
//   A  Sound-menu clone — section headers + checkmark lists (like the AirPods block in macOS Sound), vertical EQ sliders
//   B  Control panel    — segmented controls / switches / horizontal EQ rows; the menu stays open while you adjust
//   C  Minimal          — only Noise Control at top level; Immersion / EQ (presets + sliders) / More live in submenus
// Verdict 2026-10-29: B won (now the default). Second question: what should the live-battery status icon look like?
// Icon styles and a fake battery level are switched from the same PROTOTYPE submenu.
// Fake in-memory state, no Bluetooth. Writes are simulated: shown in the grey state rows and appended to the log.
// Run: ./prototype/menu/run.sh
import AppKit

struct FakeState {
    var anc = 1                 // Px7 S3 wire values: 0 off, 1 ANC, 2 pass-through
    var immersionOn = false
    var immersionPreset = 1     // 0 Focused, 1 Balanced, 2 Expanded
    var eq = [0, 0, 0, 0, 0]    // -60...60, assumed 0.1 dB
    var trueSound = false
    var wear = true
    var wearSensitivity = 2
    var standbyMinutes = 15
    var voicePrompts = true
    var quickButton = 0         // 0 noise control, 1 voice assistant
    var name = "Px7 S3"
    var battery = 40
    var startAtLogin = true
}

let variants: [(key: String, name: String)] = [("A", "Sound-menu clone"), ("B", "Control panel"), ("C", "Minimal")]
let ancOrder: [(value: Int, title: String, short: String, symbol: String)] = [
    (1, "Noise Cancellation", "ANC", "person.wave.2"),
    (2, "Pass-Through", "Pass-Through", "ear"),
    (0, "Off", "Off", "circle.slash"),
]
let immersionNames = ["Focused", "Balanced", "Expanded"]
let immersionSymbols = ["smallcircle.filled.circle", "circle.circle", "circle.dashed"]
let presets: [(name: String, eq: [Int])] = [
    ("Flat", [0, 0, 0, 0, 0]),
    ("Bass Boost", [40, 25, 0, 0, 0]),
    ("Vocal", [-10, 0, 25, 20, 0]),
    ("Treble Boost", [0, 0, 0, 20, 40]),
]

@MainActor
final class Act: NSObject {
    let f: @MainActor (Any?) -> Void
    init(_ f: @escaping @MainActor (Any?) -> Void) { self.f = f }
    @objc func run(_ sender: Any?) { f(sender) }
}

func db(_ v: Int) -> String { String(format: "%+.1f", Double(v) / 10) }

let iconStyles = ["Headband gauge", "Earcup badge", "Glyph + %"]

func drawCentered(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor) {
    let str = NSAttributedString(string: text, attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold),
        .foregroundColor: color,
    ])
    let sz = str.size()
    str.draw(at: NSPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2))
}

// 1. The headband arc doubles as the battery gauge; the number sits between the ear cups.
func headbandIcon(battery b: Int, ink: NSColor) -> NSImage {
    NSImage(size: NSSize(width: 30, height: 18), flipped: false) { _ in
        let c = NSPoint(x: 15, y: 7)
        let track = NSBezierPath()
        track.appendArc(withCenter: c, radius: 11.5, startAngle: 180, endAngle: 0, clockwise: true)
        track.lineWidth = 2
        ink.withAlphaComponent(0.3).setStroke()
        track.stroke()
        let fill = NSBezierPath()
        fill.appendArc(withCenter: c, radius: 11.5, startAngle: 180, endAngle: 180 - 180 * CGFloat(b) / 100, clockwise: true)
        fill.lineWidth = 2
        fill.lineCapStyle = .round
        ink.setStroke()
        fill.stroke()
        ink.setFill()
        for x in [1.0, 24.5] as [CGFloat] {
            NSBezierPath(roundedRect: NSRect(x: x, y: 0.5, width: 4.5, height: 9), xRadius: 2, yRadius: 2).fill()
        }
        drawCentered("\(b)", in: NSRect(x: 5.5, y: 0, width: 19, height: 11), size: 9, color: ink)
        return true
    }
}

// 2. Nibble-style: the number inside an ear-cup outline that fills from the bottom.
func earcupIcon(battery b: Int, ink: NSColor) -> NSImage {
    NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
        let cup = NSRect(x: 1, y: 0.75, width: 18, height: 14)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: cup, xRadius: 6, yRadius: 6).addClip()
        ink.withAlphaComponent(0.35).setFill()
        NSRect(x: cup.minX, y: cup.minY, width: cup.width, height: cup.height * CGFloat(b) / 100).fill()
        NSGraphicsContext.restoreGraphicsState()
        ink.setStroke()
        let outline = NSBezierPath(roundedRect: cup.insetBy(dx: 0.6, dy: 0.6), xRadius: 6, yRadius: 6)
        outline.lineWidth = 1.2
        outline.stroke()
        let band = NSBezierPath()
        band.appendArc(withCenter: NSPoint(x: 10, y: 12), radius: 5.5, startAngle: 150, endAngle: 30, clockwise: true)
        band.lineWidth = 1.5
        band.stroke()
        drawCentered("\(b)", in: cup, size: 8.5, color: ink)
        return true
    }
}

// 3. Baseline for comparison — what HeadBridge and most apps do: SF Symbol + "NN%".
func glyphIcon(battery b: Int, ink: NSColor) -> NSImage {
    let text = NSAttributedString(string: "\(b)%", attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
        .foregroundColor: ink,
    ])
    let tw = text.size().width
    return NSImage(size: NSSize(width: 18 + tw, height: 18), flipped: false) { _ in
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
        NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)?
            .draw(in: NSRect(x: 0, y: 2, width: 15, height: 14))
        text.draw(at: NSPoint(x: 17, y: (18 - text.size().height) / 2))
        return true
    }
}

@main
@MainActor
final class Prototype: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = Prototype()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    var statusItem: NSStatusItem!
    let menu = NSMenu()
    var s = FakeState()
    var variant = "B"
    var iconStyle = 0
    var drainTimer: Timer?
    var lastWrite = "—"
    var acts: [Act] = []
    var stateRows: [NSMenuItem] = []
    let logPath = CommandLine.arguments.dropFirst().first

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
        log("launched")
    }

    // Template image (follows light/dark menu bar) unless low, where it turns red like Nibble's icon.
    func updateIcon() {
        let low = s.battery <= 15
        let ink: NSColor = low ? .systemRed : .black
        let img: NSImage
        switch iconStyle {
        case 1: img = earcupIcon(battery: s.battery, ink: ink)
        case 2: img = glyphIcon(battery: s.battery, ink: ink)
        default: img = headbandIcon(battery: s.battery, ink: ink)
        }
        img.isTemplate = !low
        statusItem.button?.image = img
    }

    func toggleDrain() {
        if let t = drainTimer {
            t.invalidate()
            drainTimer = nil
            return
        }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.s.battery = self.s.battery <= 0 ? 100 : self.s.battery - 1
                self.updateIcon()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        drainTimer = t
    }

    // Rebuilt on every open, like Nibble: values are read when the menu opens, never polled.
    func menuNeedsUpdate(_ m: NSMenu) {
        guard m === menu else { return }
        acts.removeAll()
        m.removeAllItems()
        m.minimumWidth = 300
        switch variant {
        case "B": buildB(m)
        case "C": buildC(m)
        default: buildA(m)
        }
        m.addItem(.separator())
        m.addItem(item("Start at Login", state: s.startAtLogin) { [self] _ in s.startAtLogin.toggle(); write("startAtLogin=\(s.startAtLogin) (local)") })
        m.addItem(item("Quit Earshot") { _ in NSApp.terminate(nil) })
        addPrototypeBar(m)
        log("menu opened")
    }

    // MARK: variants

    func buildA(_ m: NSMenu) {
        m.addItem(headerItem())
        m.addItem(.separator())
        m.addItem(.sectionHeader(title: "Noise Control"))
        for o in ancOrder {
            m.addItem(item(o.title, symbol: o.symbol, state: s.anc == o.value) { [self] _ in s.anc = o.value; write("03:02 anc=\(o.value)") })
        }
        m.addItem(.separator())
        m.addItem(.sectionHeader(title: "True Immersion"))
        m.addItem(item("Off", symbol: "circle.slash", state: !s.immersionOn) { [self] _ in s.immersionOn = false; write("04:2D immersion=off") })
        for (i, p) in immersionNames.enumerated() {
            m.addItem(item(p, symbol: immersionSymbols[i], state: s.immersionOn && s.immersionPreset == i) { [self] _ in
                s.immersionOn = true; s.immersionPreset = i; write("04:2D on + 04:2F preset=\(i)")
            })
        }
        m.addItem(.separator())
        m.addItem(.sectionHeader(title: "EQ"))
        m.addItem(eqVerticalItem())
        m.addItem(.separator())
        m.addItem(submenuItem("More", symbol: "ellipsis.circle", moreMenu(includeToggles: true)))
    }

    func buildB(_ m: NSMenu) {
        m.addItem(headerItem())
        m.addItem(.separator())
        m.addItem(.sectionHeader(title: "Noise Control"))
        m.addItem(segmentItem(ancOrder.map(\.short), selected: ancOrder.firstIndex { $0.value == s.anc } ?? 0) { [self] i in
            s.anc = ancOrder[i].value; write("03:02 anc=\(s.anc)")
        })
        m.addItem(.sectionHeader(title: "True Immersion"))
        m.addItem(segmentItem(["Off"] + immersionNames, selected: s.immersionOn ? s.immersionPreset + 1 : 0) { [self] i in
            if i == 0 { s.immersionOn = false; write("04:2D immersion=off") }
            else { s.immersionOn = true; s.immersionPreset = i - 1; write("04:2D on + 04:2F preset=\(i - 1)") }
        })
        m.addItem(.sectionHeader(title: "EQ"))
        m.addItem(eqRowsItem())
        m.addItem(.separator())
        m.addItem(switchRow("Wear Sensor", on: s.wear) { [self] on in s.wear = on; write("0A:02 wear=\(on)") })
        m.addItem(switchRow("Voice Prompts", on: s.voicePrompts) { [self] on in s.voicePrompts = on; write("04:08 prompts=\(on)") })
        m.addItem(submenuItem("More", symbol: "ellipsis.circle", moreMenu(includeToggles: false)))
    }

    func buildC(_ m: NSMenu) {
        m.addItem(headerItem())
        m.addItem(.separator())
        for o in ancOrder {
            m.addItem(item(o.title, symbol: o.symbol, state: s.anc == o.value) { [self] _ in s.anc = o.value; write("03:02 anc=\(o.value)") })
        }
        m.addItem(.separator())
        let imm = NSMenu()
        imm.addItem(item("Off", state: !s.immersionOn) { [self] _ in s.immersionOn = false; write("04:2D immersion=off") })
        for (i, p) in immersionNames.enumerated() {
            imm.addItem(item(p, symbol: immersionSymbols[i], state: s.immersionOn && s.immersionPreset == i) { [self] _ in
                s.immersionOn = true; s.immersionPreset = i; write("04:2D on + 04:2F preset=\(i)")
            })
        }
        m.addItem(submenuItem("True Immersion: \(s.immersionOn ? immersionNames[s.immersionPreset] : "Off")", symbol: "circle.circle", imm))
        let eq = NSMenu()
        eq.addItem(item("True Sound (bypass EQ)", state: s.trueSound) { [self] _ in s.trueSound.toggle(); write("04:2B trueSound=\(s.trueSound)") })
        eq.addItem(.separator())
        eq.addItem(.sectionHeader(title: "Presets (stored on this Mac)"))
        for p in presets {
            eq.addItem(item(p.name, state: s.eq == p.eq) { [self] _ in s.eq = p.eq; write("04:29 eq=\(eqText()) (\(p.name))") })
        }
        eq.addItem(.separator())
        eq.addItem(.sectionHeader(title: "Custom"))
        eq.addItem(eqVerticalItem())
        let presetName = s.trueSound ? "True Sound" : (presets.first { $0.eq == s.eq }?.name ?? "Custom")
        m.addItem(submenuItem("EQ: \(presetName)", symbol: "slider.vertical.3", eq))
        m.addItem(submenuItem("More", symbol: "ellipsis.circle", moreMenu(includeToggles: true)))
    }

    // MARK: shared pieces

    func headerItem() -> NSMenuItem {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 44))
        let icon = NSImageView(frame: NSRect(x: 14, y: 8, width: 28, height: 28))
        icon.image = NSImage(systemSymbolName: "headphones.circle.fill", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        let name = NSTextField(labelWithString: s.name)
        name.font = .boldSystemFont(ofSize: 13)
        name.frame = NSRect(x: 50, y: 13, width: 150, height: 18)
        let batt = NSTextField(labelWithString: "\(s.battery)%")
        batt.alignment = .right
        batt.textColor = .secondaryLabelColor
        batt.frame = NSRect(x: 200, y: 13, width: 54, height: 18)
        let bimg = NSImageView(frame: NSRect(x: 258, y: 12, width: 28, height: 20))
        bimg.image = NSImage(systemSymbolName: "battery.50percent", accessibilityDescription: nil)
        bimg.contentTintColor = .secondaryLabelColor
        for sub in [icon, name, batt, bimg] as [NSView] { v.addSubview(sub) }
        let it = NSMenuItem()
        it.view = v
        return it
    }

    // Graphic-EQ look: five vertical sliders. Writes on release, not while dragging.
    func eqVerticalItem() -> NSMenuItem {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 172))
        var sliders: [NSSlider] = []
        var values: [NSTextField] = []
        for i in 0..<5 {
            let x = CGFloat(24 + i * 54)
            let val = NSTextField(labelWithString: db(s.eq[i]))
            val.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            val.alignment = .center
            val.frame = NSRect(x: x - 10, y: 150, width: 48, height: 14)
            let sl = NSSlider(value: Double(s.eq[i]), minValue: -60, maxValue: 60, target: nil, action: nil)
            sl.isVertical = true
            sl.frame = NSRect(x: x + 4, y: 50, width: 20, height: 96)
            sl.isContinuous = true
            sl.isEnabled = !s.trueSound
            wire(sl) { [self] _ in
                let n = Int(sl.doubleValue.rounded())
                val.stringValue = db(n)
                if NSApp.currentEvent?.type == .leftMouseUp { s.eq[i] = n; write("04:29 eq=\(eqText())") }
            }
            let lbl = NSTextField(labelWithString: "B\(i + 1)")
            lbl.font = .systemFont(ofSize: 10)
            lbl.textColor = .secondaryLabelColor
            lbl.alignment = .center
            lbl.frame = NSRect(x: x - 10, y: 34, width: 48, height: 14)
            for sub in [val, sl, lbl] as [NSView] { v.addSubview(sub) }
            sliders.append(sl)
            values.append(val)
        }
        let tsLabel = NSTextField(labelWithString: "True Sound")
        tsLabel.frame = NSRect(x: 14, y: 8, width: 80, height: 18)
        let ts = NSSwitch(frame: NSRect(x: 94, y: 6, width: 40, height: 22))
        ts.controlSize = .small
        ts.state = s.trueSound ? .on : .off
        wire(ts) { [self] _ in
            s.trueSound = ts.state == .on
            sliders.forEach { $0.isEnabled = !s.trueSound }
            write("04:2B trueSound=\(s.trueSound)")
        }
        let reset = NSButton(title: "Reset", target: nil, action: nil)
        reset.bezelStyle = .rounded
        reset.controlSize = .small
        reset.frame = NSRect(x: 222, y: 6, width: 64, height: 22)
        wire(reset) { [self] _ in
            s.eq = [0, 0, 0, 0, 0]
            sliders.forEach { $0.doubleValue = 0 }
            values.forEach { $0.stringValue = db(0) }
            write("04:29 eq=\(eqText()) (reset)")
        }
        for sub in [tsLabel, ts, reset] as [NSView] { v.addSubview(sub) }
        let it = NSMenuItem()
        it.view = v
        return it
    }

    // Mixer-row look: one horizontal slider per band.
    func eqRowsItem() -> NSMenuItem {
        let rowH: CGFloat = 24
        let h = rowH * 5 + 36
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: h))
        var sliders: [NSSlider] = []
        var values: [NSTextField] = []
        for i in 0..<5 {
            let y = h - CGFloat(i + 1) * rowH - 2
            let lbl = NSTextField(labelWithString: "B\(i + 1)")
            lbl.font = .systemFont(ofSize: 11)
            lbl.textColor = .secondaryLabelColor
            lbl.frame = NSRect(x: 14, y: y + 3, width: 28, height: 16)
            let sl = NSSlider(value: Double(s.eq[i]), minValue: -60, maxValue: 60, target: nil, action: nil)
            sl.frame = NSRect(x: 44, y: y, width: 186, height: 22)
            sl.isContinuous = true
            sl.isEnabled = !s.trueSound
            let val = NSTextField(labelWithString: "\(db(s.eq[i])) dB")
            val.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            val.alignment = .right
            val.frame = NSRect(x: 232, y: y + 3, width: 54, height: 16)
            wire(sl) { [self] _ in
                let n = Int(sl.doubleValue.rounded())
                val.stringValue = "\(db(n)) dB"
                if NSApp.currentEvent?.type == .leftMouseUp { s.eq[i] = n; write("04:29 eq=\(eqText())") }
            }
            for sub in [lbl, sl, val] as [NSView] { v.addSubview(sub) }
            sliders.append(sl)
            values.append(val)
        }
        let tsLabel = NSTextField(labelWithString: "True Sound")
        tsLabel.frame = NSRect(x: 14, y: 8, width: 80, height: 18)
        let ts = NSSwitch(frame: NSRect(x: 94, y: 6, width: 40, height: 22))
        ts.controlSize = .small
        ts.state = s.trueSound ? .on : .off
        wire(ts) { [self] _ in
            s.trueSound = ts.state == .on
            sliders.forEach { $0.isEnabled = !s.trueSound }
            write("04:2B trueSound=\(s.trueSound)")
        }
        let reset = NSButton(title: "Reset", target: nil, action: nil)
        reset.bezelStyle = .rounded
        reset.controlSize = .small
        reset.frame = NSRect(x: 222, y: 6, width: 64, height: 22)
        wire(reset) { [self] _ in
            s.eq = [0, 0, 0, 0, 0]
            sliders.forEach { $0.doubleValue = 0 }
            values.forEach { $0.stringValue = "\(db(0)) dB" }
            write("04:29 eq=\(eqText()) (reset)")
        }
        for sub in [tsLabel, ts, reset] as [NSView] { v.addSubview(sub) }
        let it = NSMenuItem()
        it.view = v
        return it
    }

    func segmentItem(_ labels: [String], selected: Int, _ pick: @escaping @MainActor (Int) -> Void) -> NSMenuItem {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let seg = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        seg.selectedSegment = selected
        seg.segmentDistribution = .fillEqually
        seg.frame = NSRect(x: 14, y: 4, width: 272, height: 24)
        wire(seg) { _ in pick(seg.selectedSegment) }
        v.addSubview(seg)
        let it = NSMenuItem()
        it.view = v
        return it
    }

    func switchRow(_ title: String, on: Bool, _ flip: @escaping @MainActor (Bool) -> Void) -> NSMenuItem {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        let lbl = NSTextField(labelWithString: title)
        lbl.frame = NSRect(x: 14, y: 5, width: 200, height: 18)
        let sw = NSSwitch(frame: NSRect(x: 246, y: 3, width: 40, height: 22))
        sw.controlSize = .small
        sw.state = on ? .on : .off
        wire(sw) { _ in flip(sw.state == .on) }
        v.addSubview(lbl)
        v.addSubview(sw)
        let it = NSMenuItem()
        it.view = v
        return it
    }

    func moreMenu(includeToggles: Bool) -> NSMenu {
        let m = NSMenu()
        if includeToggles {
            m.addItem(item("Wear Sensor", state: s.wear) { [self] _ in s.wear.toggle(); write("0A:02 wear=\(s.wear)") })
        }
        let sens = NSMenu()
        for (i, n) in ["Low", "Medium", "High"].enumerated() {
            sens.addItem(item(n, state: s.wearSensitivity == i + 1) { [self] _ in s.wearSensitivity = i + 1; write("0A:04 sensitivity=\(i + 1)") })
        }
        m.addItem(submenuItem("Wear Sensitivity", sens))
        let standby = NSMenu()
        for mins in [5, 15, 30, 60] {
            standby.addItem(item("\(mins) min", state: s.standbyMinutes == mins) { [self] _ in s.standbyMinutes = mins; write("02:05 standby=\(mins)") })
        }
        m.addItem(submenuItem("Auto Standby", standby))
        if includeToggles {
            m.addItem(item("Voice Prompts", state: s.voicePrompts) { [self] _ in s.voicePrompts.toggle(); write("04:08 prompts=\(s.voicePrompts)") })
        }
        let quick = NSMenu()
        for (i, n) in ["Noise Control", "Voice Assistant"].enumerated() {
            quick.addItem(item(n, state: s.quickButton == i) { [self] _ in s.quickButton = i; write("08:2A quick=\(i)") })
        }
        m.addItem(submenuItem("Quick Button", quick))
        m.addItem(.separator())
        let devices = NSMenu()
        devices.addItem(item("MacBook Air (this Mac)", symbol: "laptopcomputer", state: true))
        devices.addItem(item("iPhone", symbol: "iphone"))
        devices.addItem(.separator())
        devices.addItem(item("Switching: optional, pending M0"))
        m.addItem(submenuItem("Connected Devices", devices))
        m.addItem(item("Rename…") { [self] _ in rename() })
        let info = NSMenu()
        for line in ["Model: Px7 S3", "Firmware: 3.17.4.17", "Codec: AAC", "Compatibility: Verified"] { info.addItem(item(line)) }
        m.addItem(submenuItem("Info", info))
        return m
    }

    func rename() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Rename headphones"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = s.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            s.name = field.stringValue
            write("05:02 name=\(s.name)")
        }
    }

    // The switcher: visually distinct so it's obviously not part of the design being judged.
    func addPrototypeBar(_ m: NSMenu) {
        m.addItem(.separator())
        let name = variants.first { $0.key == variant }?.name ?? ""
        let sw = NSMenu()
        for v in variants {
            sw.addItem(item("\(v.key) — \(v.name)", state: v.key == variant) { [self] _ in variant = v.key; log("switched to \(v.key)") })
        }
        sw.addItem(.separator())
        sw.addItem(item("Next variant →") { [self] _ in
            let i = variants.firstIndex { $0.key == variant } ?? 0
            variant = variants[(i + 1) % variants.count].key
            log("switched to \(variant)")
        })
        sw.addItem(.separator())
        sw.addItem(.sectionHeader(title: "Status icon"))
        for (i, n) in iconStyles.enumerated() {
            sw.addItem(item("\(i + 1). \(n)", state: iconStyle == i) { [self] _ in iconStyle = i; updateIcon(); log("icon \(n)") })
        }
        let batt = NSMenu()
        for b in [100, 72, 40, 15, 5] {
            batt.addItem(item("\(b)%", state: s.battery == b) { [self] _ in s.battery = b; updateIcon() })
        }
        batt.addItem(.separator())
        batt.addItem(item("Simulate drain (−1% every 0.5 s)", state: drainTimer != nil) { [self] _ in toggleDrain() })
        sw.addItem(submenuItem("Fake battery: \(s.battery)%", batt))
        let bar = submenuItem("", sw)
        bar.attributedTitle = NSAttributedString(
            string: "◆ PROTOTYPE · Variant \(variant) — \(name)",
            attributes: [.foregroundColor: NSColor.systemOrange, .font: NSFont.boldSystemFont(ofSize: 12)])
        m.addItem(bar)
        stateRows = (0..<3).map { _ in NSMenuItem() }
        stateRows.forEach(m.addItem)
        refreshStateRows()
    }

    // MARK: plumbing

    func item(_ title: String, symbol: String? = nil, state: Bool = false, _ f: (@MainActor (Any?) -> Void)? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let f {
            let a = Act(f)
            acts.append(a)
            it.target = a
            it.action = #selector(Act.run(_:))
        }
        it.state = state ? .on : .off
        if let symbol { it.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return it
    }

    func submenuItem(_ title: String, symbol: String? = nil, _ sub: NSMenu) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.submenu = sub
        if let symbol { it.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return it
    }

    func wire(_ c: NSControl, _ f: @escaping @MainActor (Any?) -> Void) {
        let a = Act(f)
        acts.append(a)
        c.target = a
        c.action = #selector(Act.run(_:))
    }

    func eqText() -> String { "[" + s.eq.map(String.init).joined(separator: ",") + "]" }

    func write(_ what: String) {
        lastWrite = what
        log("WRITE \(what)")
        refreshStateRows()
    }

    func refreshStateRows() {
        guard stateRows.count == 3 else { return }
        let anc = ["off", "ANC", "pass"][s.anc]
        let imm = s.immersionOn ? immersionNames[s.immersionPreset].lowercased() : "off"
        let lines = [
            "anc=\(anc) imm=\(imm) trueSound=\(s.trueSound ? "on" : "off")",
            "eq=\(eqText())",
            "last write: \(lastWrite)",
        ]
        for (row, line) in zip(stateRows, lines) {
            row.attributedTitle = NSAttributedString(string: line, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        }
    }

    func log(_ line: String) {
        guard let logPath else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) [\(variant)] \(line)\n".utf8)
        if let h = FileHandle(forWritingAtPath: logPath) {
            h.seekToEndOfFile()
            h.write(data)
            try? h.close()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
}
