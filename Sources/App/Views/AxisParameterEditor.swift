import SwiftUI
import PS5GamePadMapperCore

/// Editor for axis parameters (deadzone, sensitivity, curve)
/// Requirements: 19.4 - Provide input fields for deadzone, sensitivity, and curve type
struct AxisParameterEditor: View {
    @Binding var deadzone: Double
    @Binding var sensitivity: Double
    @Binding var responseCurve: ResponseCurveOption
    @Binding var exponentialPower: Double
    let onParametersChanged: () -> Void
    
    // Validation state
    @State private var deadzoneError: String?
    @State private var sensitivityError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Deadzone
            deadzoneSection
            
            // Sensitivity
            sensitivitySection
            
            // Response Curve
            responseCurveSection
        }
    }
    
    // MARK: - Deadzone Section
    
    private var deadzoneSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Deadzone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Range: 0.0 - 0.5")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Slider(
                    value: $deadzone,
                    in: AxisConfig.deadzoneRange,
                    step: 0.01
                )
                .onChange(of: deadzone) { newValue in
                    validateDeadzone(newValue)
                    onParametersChanged()
                }
                
                TextField("", value: $deadzone, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
            
            if let error = deadzoneError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            
            // Visual representation
            DeadzoneVisualization(deadzone: deadzone)
                .frame(height: 30)
        }
    }
    
    // MARK: - Sensitivity Section
    
    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Sensitivity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Range: 0.1 - 10.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Slider(
                    value: $sensitivity,
                    in: AxisConfig.sensitivityRange,
                    step: 0.1
                )
                .onChange(of: sensitivity) { newValue in
                    validateSensitivity(newValue)
                    onParametersChanged()
                }
                
                TextField("", value: $sensitivity, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
            
            if let error = sensitivityError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            
            // Sensitivity indicator
            SensitivityIndicator(sensitivity: sensitivity)
                .frame(height: 20)
        }
    }
    
    // MARK: - Response Curve Section
    
    private var responseCurveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Curve")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Curve Type", selection: $responseCurve) {
                ForEach(ResponseCurveOption.allCases) { curve in
                    Text(curve.rawValue).tag(curve)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: responseCurve) { _ in
                onParametersChanged()
            }
            
            if responseCurve == .exponential {
                HStack {
                    Text("Power:")
                        .font(.caption)
                    
                    Slider(value: $exponentialPower, in: 1.5...4.0, step: 0.1)
                        .onChange(of: exponentialPower) { _ in
                            onParametersChanged()
                        }
                    
                    Text("\(String(format: "%.1f", exponentialPower))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 30)
                }
            }
            
            // Curve visualization
            ResponseCurveVisualization(
                curve: responseCurve,
                power: exponentialPower
            )
            .frame(height: 80)
        }
    }
    
    // MARK: - Validation
    
    private func validateDeadzone(_ value: Double) {
        if let error = AxisConfig.validateDeadzone(value) {
            deadzoneError = error.localizedDescription
        } else {
            deadzoneError = nil
        }
    }
    
    private func validateSensitivity(_ value: Double) {
        if let error = AxisConfig.validateSensitivity(value) {
            sensitivityError = error.localizedDescription
        } else {
            sensitivityError = nil
        }
    }
}

// MARK: - Deadzone Visualization

struct DeadzoneVisualization: View {
    let deadzone: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                // Deadzone area (center)
                let deadzoneWidth = geometry.size.width * deadzone
                let centerX = geometry.size.width / 2
                
                Rectangle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: deadzoneWidth)
                    .position(x: centerX, y: geometry.size.height / 2)
                
                // Center line
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 1)
                    .position(x: centerX, y: geometry.size.height / 2)
                
                // Labels
                HStack {
                    Text("-1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Sensitivity Indicator

struct SensitivityIndicator: View {
    let sensitivity: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                // Sensitivity bar
                let normalizedSensitivity = (sensitivity - 0.1) / (10.0 - 0.1)
                Rectangle()
                    .fill(sensitivityColor)
                    .frame(width: geometry.size.width * normalizedSensitivity)
                    .cornerRadius(4)
                
                // Label
                HStack {
                    Spacer()
                    Text(sensitivityLabel)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                }
            }
        }
    }
    
    private var sensitivityColor: Color {
        if sensitivity < 1.0 {
            return .blue
        } else if sensitivity < 3.0 {
            return .green
        } else if sensitivity < 6.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var sensitivityLabel: String {
        if sensitivity < 1.0 {
            return "Low"
        } else if sensitivity < 3.0 {
            return "Normal"
        } else if sensitivity < 6.0 {
            return "High"
        } else {
            return "Very High"
        }
    }
}

// MARK: - Response Curve Visualization

struct ResponseCurveVisualization: View {
    let curve: ResponseCurveOption
    let power: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                Path { path in
                    // Vertical lines
                    for i in 0...4 {
                        let x = geometry.size.width * CGFloat(i) / 4
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    // Horizontal lines
                    for i in 0...4 {
                        let y = geometry.size.height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                
                // Curve
                Path { path in
                    let steps = 50
                    for i in 0...steps {
                        let input = Double(i) / Double(steps)
                        let output = calculateOutput(input: input)
                        
                        let x = geometry.size.width * CGFloat(input)
                        let y = geometry.size.height * (1 - CGFloat(output))
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
                
                // Labels
                VStack {
                    HStack {
                        Text("Output")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Input")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(4)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
        }
    }
    
    private func calculateOutput(input: Double) -> Double {
        switch curve {
        case .linear:
            return input
        case .exponential:
            return pow(input, power)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AxisParameterEditor(
            deadzone: .constant(0.15),
            sensitivity: .constant(2.0),
            responseCurve: .constant(.linear),
            exponentialPower: .constant(2.0),
            onParametersChanged: {}
        )
        
        Divider()
        
        AxisParameterEditor(
            deadzone: .constant(0.1),
            sensitivity: .constant(5.0),
            responseCurve: .constant(.exponential),
            exponentialPower: .constant(2.5),
            onParametersChanged: {}
        )
    }
    .padding()
    .frame(width: 400)
}
