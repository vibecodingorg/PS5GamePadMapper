import Foundation

/// Keyboard key action
public struct KeyAction: Codable, Equatable {
    public let keyCode: UInt16
    public let modifiers: KeyModifiers
    
    public init(keyCode: UInt16, modifiers: KeyModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// Mouse button action
public struct MouseButtonAction: Codable, Equatable {
    public let button: MouseButton
    
    public init(button: MouseButton) {
        self.button = button
    }
}

/// Mouse movement action
public struct MouseMoveAction: Codable, Equatable {
    public let sensitivity: Double
    public let deadzone: Double
    public let curve: ResponseCurve
    
    public init(sensitivity: Double = 1.0, deadzone: Double = 0.1, curve: ResponseCurve = .linear) {
        self.sensitivity = sensitivity
        self.deadzone = deadzone
        self.curve = curve
    }
}

/// Mouse scroll action
public struct MouseScrollAction: Codable, Equatable {
    public let direction: ScrollDirection
    public let amount: Double
    
    public init(direction: ScrollDirection, amount: Double = 1.0) {
        self.direction = direction
        self.amount = amount
    }
}

/// Trigger mode for mappings
/// Requirements: 4.5 - Support Press, Release, and Hold trigger types
public enum TriggerMode: Codable, Equatable {
    case press
    case release
    case hold(threshold: TimeInterval)
    case toggle
}

/// Input source for mappings
public enum InputSource: Codable, Equatable, Hashable {
    case button(ButtonType)
    case axis(AxisType)
    case direction(DirectionInput)
    case stick(StickType)  // For UI selection state - Requirements: 1.1
}

/// All possible mapping actions
public enum Action: Codable, Equatable {
    case keyPress(KeyAction)
    case keyRelease(KeyAction)
    case mouseButton(MouseButtonAction)
    case mouseMove(MouseMoveAction)
    case mouseScroll(MouseScrollAction)
    case macro(Macro)
    case script(Script)
    
    /// Icon name for the action type (SF Symbol name)
    /// Requirements: 6.3 - Show action type icon (keyboard, mouse, macro, script)
    public var typeIcon: String {
        switch self {
        case .keyPress, .keyRelease:
            return "keyboard"
        case .mouseButton:
            return "computermouse"
        case .mouseMove:
            return "arrow.up.left.and.arrow.down.right"
        case .mouseScroll:
            return "scroll"
        case .macro:
            return "list.bullet.rectangle"
        case .script:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    /// Display description for the action
    /// Requirements: 6.4-6.7 - Show key name, mouse button, macro name, script name
    public var displayDescription: String {
        switch self {
        case .keyPress(let keyAction):
            return formatKeyAction(keyAction)
        case .keyRelease(let keyAction):
            return formatKeyAction(keyAction)
        case .mouseButton(let mouseAction):
            return mouseAction.button.localizedDisplayName
        case .mouseMove:
            return "鼠标移动"
        case .mouseScroll(let scrollAction):
            return "滚动\(scrollAction.direction.localizedDisplayName)"
        case .macro(let macro):
            return macro.name
        case .script(let script):
            return script.name
        }
    }
    
    /// Format key action with modifiers
    /// Requirements: 6.4 - Show key name and modifier keys (e.g., "W", "⌘+Shift+A")
    private func formatKeyAction(_ keyAction: KeyAction) -> String {
        let keyName = Self.keyCodeToName(keyAction.keyCode)
        let modifierString = keyAction.modifiers.displayString
        
        if modifierString.isEmpty {
            return keyName
        } else {
            return "\(modifierString)+\(keyName)"
        }
    }
    
    /// Convert key code to human-readable name
    public static func keyCodeToName(_ keyCode: UInt16) -> String {
        let keyNames: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            51: "Delete", 53: "Escape", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyNames[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - KeyModifiers Display Extension

extension KeyModifiers {
    /// Display string for modifiers
    /// Requirements: 6.4 - Show modifier keys in format like "⌘+Shift"
    public var displayString: String {
        var parts: [String] = []
        if contains(.command) { parts.append("⌘") }
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        return parts.joined(separator: "+")
    }
}

// MARK: - MouseButton Display Extension

extension MouseButton {
    /// Localized display name for mouse button
    /// Requirements: 6.5 - Show mouse button name (e.g., "鼠标左键")
    public var localizedDisplayName: String {
        switch self {
        case .left: return "鼠标左键"
        case .right: return "鼠标右键"
        case .middle: return "鼠标中键"
        }
    }
}

// MARK: - ScrollDirection Display Extension

extension ScrollDirection {
    /// Localized display name for scroll direction
    public var localizedDisplayName: String {
        switch self {
        case .up: return "向上"
        case .down: return "向下"
        case .left: return "向左"
        case .right: return "向右"
        }
    }
}
