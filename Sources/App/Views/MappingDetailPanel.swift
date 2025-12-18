import SwiftUI
import PS5GamePadMapperCore

/// Panel displaying details of the selected input mapping
/// Requirements: 18.4 - Display input name, type, action, trigger mode
struct MappingDetailPanel: View {
    let selectedInput: InputSource?
    let mapping: Mapping?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Mapping Details")
                .font(.headline)
            
            Divider()
            
            if let input = selectedInput {
                // Input information
                InputInfoSection(input: input)
                
                Divider()
                
                // Mapping information
                if let mapping = mapping {
                    MappingInfoSection(mapping: mapping)
                } else {
                    NoMappingView()
                }
            } else {
                NoSelectionView()
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 250)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// Section displaying input information
struct InputInfoSection: View {
    let input: InputSource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: inputIcon)
                    .foregroundColor(.blue)
                Text(inputName)
                    .font(.body)
            }
            
            Text("Type: \(inputType)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var inputName: String {
        switch input {
        case .button(let buttonType):
            return buttonType.displayName
        case .axis(let axisType):
            return axisType.displayName
        }
    }
    
    private var inputType: String {
        switch input {
        case .button:
            return "Button"
        case .axis(let axisType):
            return axisType.isTrigger ? "Trigger" : "Analog Stick"
        }
    }
    
    private var inputIcon: String {
        switch input {
        case .button:
            return "button.programmable"
        case .axis(let axisType):
            return axisType.isTrigger ? "slider.horizontal.3" : "circle.circle"
        }
    }
}

/// Section displaying mapping configuration
struct MappingInfoSection: View {
    let mapping: Mapping
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trigger mode
            VStack(alignment: .leading, spacing: 4) {
                Text("Trigger Mode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: triggerIcon)
                        .foregroundColor(.orange)
                    Text(triggerDescription)
                        .font(.body)
                }
            }
            
            Divider()
            
            // Action
            VStack(alignment: .leading, spacing: 4) {
                Text("Action")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: actionIcon)
                        .foregroundColor(.green)
                    Text(actionDescription)
                        .font(.body)
                }
                
                if let actionDetail = actionDetail {
                    Text(actionDetail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
            }
        }
    }
    
    private var triggerIcon: String {
        switch mapping.trigger {
        case .press:
            return "hand.tap"
        case .release:
            return "hand.raised"
        case .hold:
            return "hand.point.down"
        case .toggle:
            return "switch.2"
        }
    }
    
    private var triggerDescription: String {
        switch mapping.trigger {
        case .press:
            return "On Press"
        case .release:
            return "On Release"
        case .hold(let threshold):
            return "Hold (\(String(format: "%.1f", threshold))s)"
        case .toggle:
            return "Toggle"
        }
    }
    
    private var actionIcon: String {
        switch mapping.action {
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
    
    private var actionDescription: String {
        switch mapping.action {
        case .keyPress(let keyAction):
            return "Key Press: \(keyCodeDescription(keyAction))"
        case .keyRelease(let keyAction):
            return "Key Release: \(keyCodeDescription(keyAction))"
        case .mouseButton(let mouseAction):
            return "Mouse \(mouseAction.button.displayName)"
        case .mouseMove:
            return "Mouse Move"
        case .mouseScroll(let scrollAction):
            return "Mouse Scroll \(scrollAction.direction.displayName)"
        case .macro(let macro):
            return "Macro: \(macro.name)"
        case .script(let script):
            return "Script: \(script.name)"
        }
    }
    
    private var actionDetail: String? {
        switch mapping.action {
        case .keyPress(let keyAction), .keyRelease(let keyAction):
            if !keyAction.modifiers.isEmpty {
                return "Modifiers: \(keyAction.modifiers.description)"
            }
            return nil
        case .mouseMove(let moveAction):
            return "Sensitivity: \(String(format: "%.1f", moveAction.sensitivity)), Deadzone: \(String(format: "%.2f", moveAction.deadzone))"
        case .mouseScroll(let scrollAction):
            return "Amount: \(String(format: "%.1f", scrollAction.amount))"
        case .macro(let macro):
            return "\(macro.steps.count) steps, \(macro.type.description)"
        case .script:
            return nil
        default:
            return nil
        }
    }
    
    private func keyCodeDescription(_ keyAction: KeyAction) -> String {
        // Common key code mappings
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
        return keyNames[keyAction.keyCode] ?? "Key \(keyAction.keyCode)"
    }
}

/// View shown when no mapping is configured
struct NoMappingView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.dashed")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Mapping Configured")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Click 'Edit Mapping' to configure this input")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

/// View shown when no input is selected
struct NoSelectionView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Input Selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Click on a button or axis on the controller to view its mapping")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Display Name Extensions

extension ButtonType {
    var displayName: String {
        switch self {
        case .cross: return "Cross (X)"
        case .circle: return "Circle (O)"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3 (Left Stick)"
        case .r3: return "R3 (Right Stick)"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .share: return "Share"
        case .options: return "Options"
        case .ps: return "PS Button"
        case .touchpad: return "Touchpad"
        }
    }
}

extension AxisType {
    var displayName: String {
        switch self {
        case .leftStickX: return "Left Stick X"
        case .leftStickY: return "Left Stick Y"
        case .rightStickX: return "Right Stick X"
        case .rightStickY: return "Right Stick Y"
        case .l2Trigger: return "L2 Trigger"
        case .r2Trigger: return "R2 Trigger"
        }
    }
}

extension MouseButton {
    var displayName: String {
        switch self {
        case .left: return "Left Click"
        case .right: return "Right Click"
        case .middle: return "Middle Click"
        }
    }
}

extension ScrollDirection {
    var displayName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

extension MacroType {
    var description: String {
        switch self {
        case .sequence:
            return "Sequence"
        case .loop(let interval, let maxCount):
            if maxCount == 0 {
                return "Loop (∞, \(interval)ms)"
            }
            return "Loop (\(maxCount)x, \(interval)ms)"
        case .toggle:
            return "Toggle"
        case .whileCondition(let condition):
            return "While (\(condition))"
        }
    }
}

extension KeyModifiers {
    var description: String {
        var parts: [String] = []
        if contains(.command) { parts.append("⌘") }
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        return parts.joined(separator: " + ")
    }
}

#Preview {
    HStack {
        MappingDetailPanel(
            selectedInput: .button(.cross),
            mapping: Mapping(
                input: .button(.cross),
                trigger: .press,
                action: .keyPress(KeyAction(keyCode: 49, modifiers: []))
            )
        )
        
        MappingDetailPanel(
            selectedInput: .axis(.leftStickX),
            mapping: Mapping(
                input: .axis(.leftStickX),
                trigger: .press,
                action: .mouseMove(MouseMoveAction(sensitivity: 2.0, deadzone: 0.15, curve: .linear))
            )
        )
        
        MappingDetailPanel(
            selectedInput: .button(.l1),
            mapping: nil
        )
        
        MappingDetailPanel(
            selectedInput: nil,
            mapping: nil
        )
    }
    .padding()
}
