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
            Text("映射详情")
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
            Text("输入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: inputIcon)
                    .foregroundColor(.blue)
                Text(inputName)
                    .font(.body)
            }
            
            Text("类型: \(inputType)")
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
        case .direction(let directionInput):
            return "\(directionInput.stick.displayName) \(directionInput.direction.displayName)"
        }
    }
    
    private var inputType: String {
        switch input {
        case .button:
            return "按钮"
        case .axis(let axisType):
            return axisType.isTrigger ? "扳机" : "摇杆"
        case .direction:
            return "方向"
        }
    }
    
    private var inputIcon: String {
        switch input {
        case .button:
            return "button.programmable"
        case .axis(let axisType):
            return axisType.isTrigger ? "slider.horizontal.3" : "circle.circle"
        case .direction:
            return "arrow.up.left.and.arrow.down.right"
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
                Text("触发模式")
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
                Text("动作")
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
            return "按下时"
        case .release:
            return "释放时"
        case .hold(let threshold):
            return "长按 (\(String(format: "%.1f", threshold))秒)"
        case .toggle:
            return "切换"
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
            return "按键: \(keyCodeDescription(keyAction))"
        case .keyRelease(let keyAction):
            return "释放键: \(keyCodeDescription(keyAction))"
        case .mouseButton(let mouseAction):
            return "鼠标 \(mouseAction.button.displayName)"
        case .mouseMove:
            return "鼠标移动"
        case .mouseScroll(let scrollAction):
            return "鼠标滚动 \(scrollAction.direction.displayName)"
        case .macro(let macro):
            return "宏: \(macro.name)"
        case .script(let script):
            return "脚本: \(script.name)"
        }
    }
    
    private var actionDetail: String? {
        switch mapping.action {
        case .keyPress(let keyAction), .keyRelease(let keyAction):
            if !keyAction.modifiers.isEmpty {
                return "修饰键: \(keyAction.modifiers.description)"
            }
            return nil
        case .mouseMove(let moveAction):
            return "灵敏度: \(String(format: "%.1f", moveAction.sensitivity)), 死区: \(String(format: "%.2f", moveAction.deadzone))"
        case .mouseScroll(let scrollAction):
            return "滚动量: \(String(format: "%.1f", scrollAction.amount))"
        case .macro(let macro):
            return "\(macro.steps.count) 步, \(macro.type.description)"
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
            
            Text("未配置映射")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("点击「编辑映射」来配置此输入")
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
            
            Text("未选择输入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("点击控制器上的按钮或摇杆来查看其映射")
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
        case .cross: return "叉键 (X)"
        case .circle: return "圆键 (O)"
        case .square: return "方键"
        case .triangle: return "三角键"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3 (左摇杆)"
        case .r3: return "R3 (右摇杆)"
        case .dpadUp: return "方向键 上"
        case .dpadDown: return "方向键 下"
        case .dpadLeft: return "方向键 左"
        case .dpadRight: return "方向键 右"
        case .share: return "分享键"
        case .options: return "选项键"
        case .ps: return "PS键"
        case .touchpad: return "触摸板"
        }
    }
}

extension AxisType {
    var displayName: String {
        switch self {
        case .leftStickX: return "左摇杆 X"
        case .leftStickY: return "左摇杆 Y"
        case .rightStickX: return "右摇杆 X"
        case .rightStickY: return "右摇杆 Y"
        case .l2Trigger: return "L2 扳机"
        case .r2Trigger: return "R2 扳机"
        }
    }
}

extension MouseButton {
    var displayName: String {
        switch self {
        case .left: return "左键"
        case .right: return "右键"
        case .middle: return "中键"
        }
    }
}

extension ScrollDirection {
    var displayName: String {
        switch self {
        case .up: return "向上"
        case .down: return "向下"
        case .left: return "向左"
        case .right: return "向右"
        }
    }
}

extension MacroType {
    var description: String {
        switch self {
        case .sequence:
            return "序列"
        case .loop(let interval, let maxCount):
            if maxCount == 0 {
                return "循环 (∞, \(interval)毫秒)"
            }
            return "循环 (\(maxCount)次, \(interval)毫秒)"
        case .toggle:
            return "切换"
        case .whileCondition(let condition):
            return "条件循环 (\(condition))"
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

extension StickType {
    var displayName: String {
        switch self {
        case .left: return "左摇杆"
        case .right: return "右摇杆"
        }
    }
}

extension StickDirection {
    var displayName: String {
        switch self {
        case .up: return "上"
        case .down: return "下"
        case .left: return "左"
        case .right: return "右"
        case .upLeft: return "左上"
        case .upRight: return "右上"
        case .downLeft: return "左下"
        case .downRight: return "右下"
        }
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
