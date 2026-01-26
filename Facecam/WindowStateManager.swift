import AppKit

struct WindowState: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let shape: String

    var frame: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }

    init(frame: NSRect, shape: CameraShape) {
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.size.width
        self.height = frame.size.height
        self.shape = shape.rawValue
    }

    var cameraShape: CameraShape {
        CameraShape(rawValue: shape) ?? .circle
    }
}

class WindowStateManager {
    static let shared = WindowStateManager()
    private let maxSlots = 10
    private let userDefaultsKey = "WindowStatePresets"

    private init() {}

    func saveState(_ state: WindowState, toSlot slot: Int) {
        guard slot >= 1 && slot <= maxSlots else { return }

        var presets = loadAllPresets()
        presets[String(slot)] = state

        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func loadState(fromSlot slot: Int) -> WindowState? {
        guard slot >= 1 && slot <= maxSlots else { return nil }

        let presets = loadAllPresets()
        return presets[String(slot)]
    }

    func hasState(inSlot slot: Int) -> Bool {
        loadState(fromSlot: slot) != nil
    }

    func clearState(inSlot slot: Int) {
        guard slot >= 1 && slot <= maxSlots else { return }

        var presets = loadAllPresets()
        presets.removeValue(forKey: String(slot))

        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func savedSlots() -> [Int] {
        let presets = loadAllPresets()
        return presets.keys.compactMap { Int($0) }.sorted()
    }

    private func loadAllPresets() -> [String: WindowState] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let presets = try? JSONDecoder().decode([String: WindowState].self, from: data) else {
            return [:]
        }
        return presets
    }
}
