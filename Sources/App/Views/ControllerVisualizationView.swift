import SwiftUI
import PS5GamePadMapperCore

/// Interactive controller visualization showing all mappable inputs
/// Requirements: 18.2, 18.3 - Display controller visualization with clickable inputs
/// Requirements: 3.1, 3.4 - Support direction selector for sticks
struct ControllerVisualizationView: View {
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    
    // Track which inputs are currently pressed (for visual feedback)
    var pressedButtons: Set<ButtonType> = []
    var axisValues: [AxisType: Double] = [:]
    
    // Direction mapping support
    var configuredDirections: [StickType: Set<StickDirection>] = [:]
    var onStickDirectionTapped: ((StickType) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Controller body outline - background fill
                ControllerBodyShape()
                    .fill(Color(NSColor.controlBackgroundColor))
                
                // Controller body outline - stroke
                ControllerBodyShape()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                
                // Left stick
                StickView(
                    label: "L",
                    stickType: .left,
                    axisX: .leftStickX,
                    axisY: .leftStickY,
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    onDirectionTapped: onStickDirectionTapped,
                    valueX: axisValues[.leftStickX] ?? 0,
                    valueY: axisValues[.leftStickY] ?? 0,
                    hasDirectionMappings: !(configuredDirections[.left]?.isEmpty ?? true)
                )
                .position(x: width * 0.25, y: height * 0.45)
                
                // Right stick
                StickView(
                    label: "R",
                    stickType: .right,
                    axisX: .rightStickX,
                    axisY: .rightStickY,
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    onDirectionTapped: onStickDirectionTapped,
                    valueX: axisValues[.rightStickX] ?? 0,
                    valueY: axisValues[.rightStickY] ?? 0,
                    hasDirectionMappings: !(configuredDirections[.right]?.isEmpty ?? true)
                )
                .position(x: width * 0.75, y: height * 0.65)
                
                // D-Pad
                DPadView(
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    pressedButtons: pressedButtons
                )
                .position(x: width * 0.25, y: height * 0.7)
                
                // Face buttons
                FaceButtonsView(
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    pressedButtons: pressedButtons
                )
                .position(x: width * 0.75, y: height * 0.4)
                
                // Shoulder buttons (L1, R1)
                ShoulderButtonView(
                    button: .l1,
                    label: "L1",
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    isPressed: pressedButtons.contains(.l1)
                )
                .position(x: width * 0.2, y: height * 0.12)
                
                ShoulderButtonView(
                    button: .r1,
                    label: "R1",
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    isPressed: pressedButtons.contains(.r1)
                )
                .position(x: width * 0.8, y: height * 0.12)
                
                // Triggers (L2, R2)
                TriggerView(
                    axis: .l2Trigger,
                    button: .l2,
                    label: "L2",
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    value: axisValues[.l2Trigger] ?? 0,
                    isPressed: pressedButtons.contains(.l2)
                )
                .position(x: width * 0.2, y: height * 0.02)
                
                TriggerView(
                    axis: .r2Trigger,
                    button: .r2,
                    label: "R2",
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    value: axisValues[.r2Trigger] ?? 0,
                    isPressed: pressedButtons.contains(.r2)
                )
                .position(x: width * 0.8, y: height * 0.02)
                
                // Center buttons
                CenterButtonsView(
                    selectedInput: $selectedInput,
                    onInputSelected: onInputSelected,
                    pressedButtons: pressedButtons
                )
                .position(x: width * 0.5, y: height * 0.35)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1.5, contentMode: .fit)
    }
}

/// Controller body shape
struct ControllerBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Simplified controller outline
        path.move(to: CGPoint(x: w * 0.1, y: h * 0.3))
        path.addQuadCurve(to: CGPoint(x: w * 0.3, y: h * 0.1),
                          control: CGPoint(x: w * 0.1, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.1))
        path.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.3),
                          control: CGPoint(x: w * 0.9, y: h * 0.1))
        path.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.9),
                          control: CGPoint(x: w * 0.95, y: h * 0.6))
        path.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.85),
                          control: CGPoint(x: w * 0.7, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.85))
        path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.9),
                          control: CGPoint(x: w * 0.3, y: h * 0.95))
        path.addQuadCurve(to: CGPoint(x: w * 0.1, y: h * 0.3),
                          control: CGPoint(x: w * 0.05, y: h * 0.6))
        path.closeSubpath()
        
        return path
    }
}

/// Analog stick visualization with direction mapping support
/// Requirements: 3.1, 3.4 - Tap gesture to open direction selector for sticks
struct StickView: View {
    let label: String
    let stickType: StickType
    let axisX: AxisType
    let axisY: AxisType
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    var onDirectionTapped: ((StickType) -> Void)?
    let valueX: Double
    let valueY: Double
    var hasDirectionMappings: Bool = false
    
    private var isSelected: Bool {
        if case .axis(let type) = selectedInput {
            return type == axisX || type == axisY
        }
        if case .direction(let dirInput) = selectedInput {
            return dirInput.stick == stickType
        }
        return false
    }
    
    var body: some View {
        ZStack {
            // Stick base
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 70, height: 70)
            
            // Direction indicator ring (shows if direction mappings exist)
            if hasDirectionMappings {
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 3)
                    .frame(width: 70, height: 70)
            }
            
            // Stick position indicator
            Circle()
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.6))
                .frame(width: 40, height: 40)
                .offset(x: valueX * 12, y: valueY * 12)
            
            // Label
            Text(label)
                .font(.caption2)
                .foregroundColor(.white)
                .offset(x: valueX * 12, y: valueY * 12)
            
            // Direction mode indicator
            if hasDirectionMappings {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8))
                    .foregroundColor(.green)
                    .offset(x: 25, y: -25)
            }
        }
        .onTapGesture {
            // Single tap selects axis for axis mapping
            selectedInput = .axis(axisX)
            onInputSelected(.axis(axisX))
        }
        .onTapGesture(count: 2) {
            // Double tap opens direction selector
            onDirectionTapped?(stickType)
        }
        .contextMenu {
            Button("轴映射") {
                selectedInput = .axis(axisX)
                onInputSelected(.axis(axisX))
            }
            Button("方向映射") {
                onDirectionTapped?(stickType)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 35)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .help("单击: 轴映射 | 双击/右键: 方向映射")
    }
}

/// D-Pad visualization
struct DPadView: View {
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let pressedButtons: Set<ButtonType>
    
    var body: some View {
        VStack(spacing: 0) {
            DPadButton(button: .dpadUp, label: "↑", selectedInput: $selectedInput,
                       onInputSelected: onInputSelected, isPressed: pressedButtons.contains(.dpadUp))
            
            HStack(spacing: 0) {
                DPadButton(button: .dpadLeft, label: "←", selectedInput: $selectedInput,
                           onInputSelected: onInputSelected, isPressed: pressedButtons.contains(.dpadLeft))
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 25, height: 25)
                
                DPadButton(button: .dpadRight, label: "→", selectedInput: $selectedInput,
                           onInputSelected: onInputSelected, isPressed: pressedButtons.contains(.dpadRight))
            }
            
            DPadButton(button: .dpadDown, label: "↓", selectedInput: $selectedInput,
                       onInputSelected: onInputSelected, isPressed: pressedButtons.contains(.dpadDown))
        }
    }
}

struct DPadButton: View {
    let button: ButtonType
    let label: String
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let isPressed: Bool
    
    private var isSelected: Bool {
        if case .button(let type) = selectedInput {
            return type == button
        }
        return false
    }
    
    var body: some View {
        Rectangle()
            .fill(isPressed ? Color.blue.opacity(0.7) : (isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.4)))
            .frame(width: 25, height: 25)
            .overlay(
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isPressed || isSelected ? .white : .secondary)
            )
            .onTapGesture {
                selectedInput = .button(button)
                onInputSelected(.button(button))
            }
    }
}

/// Face buttons (X, O, Square, Triangle)
struct FaceButtonsView: View {
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let pressedButtons: Set<ButtonType>
    
    var body: some View {
        VStack(spacing: 5) {
            FaceButton(button: .triangle, label: "△", color: .green,
                       selectedInput: $selectedInput, onInputSelected: onInputSelected,
                       isPressed: pressedButtons.contains(.triangle))
            
            HStack(spacing: 25) {
                FaceButton(button: .square, label: "□", color: .pink,
                           selectedInput: $selectedInput, onInputSelected: onInputSelected,
                           isPressed: pressedButtons.contains(.square))
                
                FaceButton(button: .circle, label: "○", color: .red,
                           selectedInput: $selectedInput, onInputSelected: onInputSelected,
                           isPressed: pressedButtons.contains(.circle))
            }
            
            FaceButton(button: .cross, label: "✕", color: .blue,
                       selectedInput: $selectedInput, onInputSelected: onInputSelected,
                       isPressed: pressedButtons.contains(.cross))
        }
    }
}

struct FaceButton: View {
    let button: ButtonType
    let label: String
    let color: Color
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let isPressed: Bool
    
    private var isSelected: Bool {
        if case .button(let type) = selectedInput {
            return type == button
        }
        return false
    }
    
    var body: some View {
        Circle()
            .fill(isPressed ? color : (isSelected ? color.opacity(0.5) : Color.gray.opacity(0.3)))
            .frame(width: 30, height: 30)
            .overlay(
                Text(label)
                    .font(.caption)
                    .foregroundColor(isPressed || isSelected ? .white : color)
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                selectedInput = .button(button)
                onInputSelected(.button(button))
            }
    }
}

/// Shoulder button (L1, R1)
struct ShoulderButtonView: View {
    let button: ButtonType
    let label: String
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let isPressed: Bool
    
    private var isSelected: Bool {
        if case .button(let type) = selectedInput {
            return type == button
        }
        return false
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isPressed ? Color.blue.opacity(0.7) : (isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.4)))
            .frame(width: 60, height: 20)
            .overlay(
                Text(label)
                    .font(.caption)
                    .foregroundColor(isPressed || isSelected ? .white : .secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                selectedInput = .button(button)
                onInputSelected(.button(button))
            }
    }
}

/// Trigger visualization (L2, R2)
struct TriggerView: View {
    let axis: AxisType
    let button: ButtonType
    let label: String
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let value: Double
    let isPressed: Bool
    
    private var isSelected: Bool {
        if case .axis(let type) = selectedInput {
            return type == axis
        }
        if case .button(let type) = selectedInput {
            return type == button
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Trigger bar showing analog value
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 30)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.6))
                    .frame(width: 50, height: CGFloat(value * 30))
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            selectedInput = .axis(axis)
            onInputSelected(.axis(axis))
        }
    }
}

/// Center buttons (Share, Options, PS, Touchpad)
struct CenterButtonsView: View {
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let pressedButtons: Set<ButtonType>
    
    var body: some View {
        VStack(spacing: 10) {
            // Touchpad
            CenterButton(button: .touchpad, label: "Touchpad", width: 80, height: 30,
                         selectedInput: $selectedInput, onInputSelected: onInputSelected,
                         isPressed: pressedButtons.contains(.touchpad))
            
            HStack(spacing: 30) {
                CenterButton(button: .share, label: "Share", width: 40, height: 20,
                             selectedInput: $selectedInput, onInputSelected: onInputSelected,
                             isPressed: pressedButtons.contains(.share))
                
                CenterButton(button: .ps, label: "PS", width: 25, height: 25,
                             selectedInput: $selectedInput, onInputSelected: onInputSelected,
                             isPressed: pressedButtons.contains(.ps), isCircle: true)
                
                CenterButton(button: .options, label: "Options", width: 40, height: 20,
                             selectedInput: $selectedInput, onInputSelected: onInputSelected,
                             isPressed: pressedButtons.contains(.options))
            }
        }
    }
}

struct CenterButton: View {
    let button: ButtonType
    let label: String
    let width: CGFloat
    let height: CGFloat
    @Binding var selectedInput: InputSource?
    let onInputSelected: (InputSource) -> Void
    let isPressed: Bool
    var isCircle: Bool = false
    
    private var isSelected: Bool {
        if case .button(let type) = selectedInput {
            return type == button
        }
        return false
    }
    
    var body: some View {
        Group {
            if isCircle {
                Circle()
                    .fill(isPressed ? Color.blue.opacity(0.7) : (isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.4)))
                    .frame(width: width, height: height)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPressed ? Color.blue.opacity(0.7) : (isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.4)))
                    .frame(width: width, height: height)
            }
        }
        .overlay(
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(isPressed || isSelected ? .white : .secondary)
        )
        .onTapGesture {
            selectedInput = .button(button)
            onInputSelected(.button(button))
        }
    }
}

#Preview {
    ControllerVisualizationView(
        selectedInput: .constant(.button(.cross)),
        onInputSelected: { _ in },
        pressedButtons: [.cross, .l1],
        axisValues: [.leftStickX: 0.5, .leftStickY: -0.3, .l2Trigger: 0.7],
        configuredDirections: [.left: [.up, .down, .left, .right]],
        onStickDirectionTapped: { _ in }
    )
    .frame(width: 600, height: 400)
    .padding()
}
