import SwiftUI
@preconcurrency import PS5GamePadMapperCore

/// Direction selector view displaying 8 direction zones in a circular layout
/// Requirements: 3.1, 3.3, 3.4 - Visual interface for stick direction configuration
struct DirectionSelectorView: View {
    let stick: StickType
    let currentX: Double
    let currentY: Double
    let configuredDirections: Set<StickDirection>
    let onDirectionSelected: (StickDirection) -> Void
    let onDismiss: () -> Void
    
    // Size constants
    private let outerRadius: CGFloat = 120
    private let innerRadius: CGFloat = 30
    private let indicatorSize: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(stick == .left ? "左摇杆方向" : "右摇杆方向")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // Direction wheel
            ZStack {
                // Background circle
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                
                // Direction zones
                ForEach(StickDirection.allCases, id: \.self) { direction in
                    DirectionZoneView(
                        direction: direction,
                        outerRadius: outerRadius,
                        innerRadius: innerRadius,
                        isConfigured: configuredDirections.contains(direction),
                        isActive: isDirectionActive(direction),
                        onTap: { onDirectionSelected(direction) }
                    )
                }
                
                // Center deadzone indicator
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                
                // Current stick position indicator
                Circle()
                    .fill(Color.blue)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .offset(
                        x: currentX * (outerRadius - indicatorSize / 2),
                        y: -currentY * (outerRadius - indicatorSize / 2)
                    )
                    .shadow(color: .blue.opacity(0.5), radius: 4)
            }
            .frame(width: outerRadius * 2 + 20, height: outerRadius * 2 + 20)
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .green.opacity(0.3), label: "已配置")
                LegendItem(color: .blue.opacity(0.5), label: "当前激活")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Instructions
            Text("点击方向区域配置映射")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300, height: 350)
    }
    
    /// Check if a direction is currently active based on stick position
    private func isDirectionActive(_ direction: StickDirection) -> Bool {
        let magnitude = sqrt(currentX * currentX + currentY * currentY)
        guard magnitude > 0.3 else { return false }
        
        // Calculate angle (0-360, where 0 is right, counter-clockwise)
        var angle = atan2(currentY, currentX) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        // Check if angle falls within direction's zone
        let centerAngle = direction.centerAngle
        let halfZone: Double = direction.isCardinal ? 22.5 : 22.5
        
        var diff = abs(angle - centerAngle)
        if diff > 180 { diff = 360 - diff }
        
        return diff <= halfZone
    }
}

/// Individual direction zone in the selector
struct DirectionZoneView: View {
    let direction: StickDirection
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let isConfigured: Bool
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        DirectionZoneShape(
            direction: direction,
            outerRadius: outerRadius,
            innerRadius: innerRadius
        )
        .fill(zoneColor)
        .overlay(
            DirectionZoneShape(
                direction: direction,
                outerRadius: outerRadius,
                innerRadius: innerRadius
            )
            .stroke(isActive ? Color.blue : Color.gray.opacity(0.3), lineWidth: isActive ? 2 : 1)
        )
        .overlay(
            // Direction label
            directionLabel
                .position(labelPosition)
        )
        .contentShape(
            DirectionZoneShape(
                direction: direction,
                outerRadius: outerRadius,
                innerRadius: innerRadius
            )
        )
        .onTapGesture(perform: onTap)
    }
    
    private var zoneColor: Color {
        if isActive {
            return Color.blue.opacity(0.5)
        } else if isConfigured {
            return Color.green.opacity(0.3)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var directionLabel: some View {
        Text(direction.shortLabel)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(isActive ? .white : (isConfigured ? .green : .secondary))
    }
    
    private var labelPosition: CGPoint {
        let labelRadius = (outerRadius + innerRadius) / 2
        let angle = CGFloat(direction.centerAngle * .pi / 180)
        return CGPoint(
            x: outerRadius + CoreGraphics.cos(angle) * labelRadius,
            y: outerRadius - CoreGraphics.sin(angle) * labelRadius
        )
    }
}

/// Shape for a direction zone (pie slice)
struct DirectionZoneShape: Shape {
    let direction: StickDirection
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Calculate start and end angles (SwiftUI uses clockwise from 3 o'clock)
        // We need to convert from our counter-clockwise from right convention
        let centerAngle = direction.centerAngle
        let halfZone: Double = 22.5
        
        // Convert to SwiftUI angle convention (clockwise from right, negative Y is up)
        let startAngle = Angle(degrees: -(centerAngle + halfZone))
        let endAngle = Angle(degrees: -(centerAngle - halfZone))
        
        // Outer arc
        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        // Line to inner arc
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: false)
        
        path.closeSubpath()
        return path
    }
}

/// Legend item for the direction selector
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}

// MARK: - StickDirection Extensions

extension StickDirection {
    /// Short label for display in the direction selector
    var shortLabel: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .upLeft: return "↖"
        case .upRight: return "↗"
        case .downLeft: return "↙"
        case .downRight: return "↘"
        }
    }
}

#Preview {
    DirectionSelectorView(
        stick: .left,
        currentX: 0.5,
        currentY: 0.5,
        configuredDirections: [.up, .down, .left, .right],
        onDirectionSelected: { _ in },
        onDismiss: {}
    )
}
