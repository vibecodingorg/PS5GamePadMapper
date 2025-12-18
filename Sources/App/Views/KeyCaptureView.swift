import SwiftUI
import Carbon.HIToolbox
import PS5GamePadMapperCore

/// View for capturing keyboard input for key mapping
/// Requirements: 19.3 - Provide a key capture interface to record the target key
struct KeyCaptureView: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: KeyModifiers
    @Binding var isCapturing: Bool
    let onKeyChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Key")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                // Key display
                Text(keyDisplayString)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 100, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCapturing ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isCapturing ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // Capture button
                Button(isCapturing ? "Cancel" : "Capture") {
                    isCapturing.toggle()
                }
                .buttonStyle(.bordered)
            }
            
            if isCapturing {
                Text("Press any key to capture...")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .background(
            KeyCaptureHandler(
                isCapturing: $isCapturing,
                onKeyCaptured: { capturedKeyCode, capturedModifiers in
                    keyCode = capturedKeyCode
                    modifiers = capturedModifiers
                    isCapturing = false
                    onKeyChanged()
                }
            )
        )
    }
    
    private var keyDisplayString: String {
        var parts: [String] = []
        
        // Add modifiers
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        
        // Add key name
        parts.append(KeyCodeHelper.keyName(for: keyCode))
        
        return parts.joined(separator: " + ")
    }
}

/// NSViewRepresentable for capturing keyboard events
struct KeyCaptureHandler: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onKeyCaptured: (UInt16, KeyModifiers) -> Void
    
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyCaptured = onKeyCaptured
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isCapturing = isCapturing
        nsView.onKeyCaptured = onKeyCaptured
        
        if isCapturing {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// Custom NSView for capturing keyboard events
class KeyCaptureNSView: NSView {
    var isCapturing: Bool = false
    var onKeyCaptured: ((UInt16, KeyModifiers) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isCapturing else {
            super.keyDown(with: event)
            return
        }
        
        // Ignore modifier-only key presses
        let modifierOnlyKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        if modifierOnlyKeyCodes.contains(event.keyCode) {
            return
        }
        
        // Convert NSEvent modifiers to KeyModifiers
        var keyModifiers: KeyModifiers = []
        if event.modifierFlags.contains(.command) {
            keyModifiers.insert(.command)
        }
        if event.modifierFlags.contains(.control) {
            keyModifiers.insert(.control)
        }
        if event.modifierFlags.contains(.option) {
            keyModifiers.insert(.option)
        }
        if event.modifierFlags.contains(.shift) {
            keyModifiers.insert(.shift)
        }
        
        onKeyCaptured?(event.keyCode, keyModifiers)
    }
    
    override func flagsChanged(with event: NSEvent) {
        // Don't capture modifier-only presses
        super.flagsChanged(with: event)
    }
}

/// Modifier keys selector with checkboxes
/// Requirements: 19.3 - Support modifier key combinations
struct ModifierKeysSelector: View {
    @Binding var modifiers: KeyModifiers
    let onModifiersChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modifier Keys")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                ModifierToggle(
                    label: "⌘ Command",
                    isOn: Binding(
                        get: { modifiers.contains(.command) },
                        set: { newValue in
                            if newValue {
                                modifiers.insert(.command)
                            } else {
                                modifiers.remove(.command)
                            }
                            onModifiersChanged()
                        }
                    )
                )
                
                ModifierToggle(
                    label: "⌃ Control",
                    isOn: Binding(
                        get: { modifiers.contains(.control) },
                        set: { newValue in
                            if newValue {
                                modifiers.insert(.control)
                            } else {
                                modifiers.remove(.control)
                            }
                            onModifiersChanged()
                        }
                    )
                )
                
                ModifierToggle(
                    label: "⌥ Option",
                    isOn: Binding(
                        get: { modifiers.contains(.option) },
                        set: { newValue in
                            if newValue {
                                modifiers.insert(.option)
                            } else {
                                modifiers.remove(.option)
                            }
                            onModifiersChanged()
                        }
                    )
                )
                
                ModifierToggle(
                    label: "⇧ Shift",
                    isOn: Binding(
                        get: { modifiers.contains(.shift) },
                        set: { newValue in
                            if newValue {
                                modifiers.insert(.shift)
                            } else {
                                modifiers.remove(.shift)
                            }
                            onModifiersChanged()
                        }
                    )
                )
            }
        }
    }
}

struct ModifierToggle: View {
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.checkbox)
            .font(.caption)
    }
}

/// Helper for converting key codes to display names
enum KeyCodeHelper {
    /// Common key code to name mappings
    static let keyNames: [UInt16: String] = [
        // Letters
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".",
        
        // Special keys
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        
        // Arrow keys
        123: "←", 124: "→", 125: "↓", 126: "↑",
        
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        
        // Numpad
        82: "Num 0", 83: "Num 1", 84: "Num 2", 85: "Num 3", 86: "Num 4",
        87: "Num 5", 88: "Num 6", 89: "Num 7", 91: "Num 8", 92: "Num 9",
        65: "Num .", 67: "Num *", 69: "Num +", 75: "Num /", 78: "Num -",
        76: "Num Enter", 81: "Num =",
        
        // Other
        114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete",
        119: "End", 121: "Page Down", 71: "Clear",
        
        // Media keys
        10: "§", 50: "`"
    ]
    
    /// Get the display name for a key code
    static func keyName(for keyCode: UInt16) -> String {
        return keyNames[keyCode] ?? "Key \(keyCode)"
    }
    
    /// Get the key code for a character (if available)
    static func keyCode(for character: String) -> UInt16? {
        let uppercased = character.uppercased()
        return keyNames.first { $0.value == uppercased }?.key
    }
}

#Preview {
    VStack(spacing: 20) {
        KeyCaptureView(
            keyCode: .constant(49),
            modifiers: .constant([]),
            isCapturing: .constant(false),
            onKeyChanged: {}
        )
        
        KeyCaptureView(
            keyCode: .constant(0),
            modifiers: .constant([.command, .shift]),
            isCapturing: .constant(true),
            onKeyChanged: {}
        )
        
        ModifierKeysSelector(
            modifiers: .constant([.command, .shift]),
            onModifiersChanged: {}
        )
    }
    .padding()
    .frame(width: 400)
}
