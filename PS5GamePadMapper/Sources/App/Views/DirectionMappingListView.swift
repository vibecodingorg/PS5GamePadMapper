import SwiftUI
import PS5GamePadMapperCore

/// Direction mapping list view displaying all 8 direction mappings in a scrollable list
/// Requirements: 6.1 - Display scrollable list of all configured direction mappings
struct DirectionMappingListView: View {
    let directionMappings: [StickDirection: Mapping]
    let onDirectionTapped: (StickDirection) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(StickDirection.allCases, id: \.self) { direction in
                    DirectionMappingRow(
                        direction: direction,
                        mapping: directionMappings[direction],
                        onTap: { onDirectionTapped(direction) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Single direction mapping row displaying direction info and action
/// Requirements: 6.2-6.8 - Display direction name, action type icon, action description
struct DirectionMappingRow: View {
    let direction: StickDirection
    let mapping: Mapping?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Direction icon and name
                HStack(spacing: 6) {
                    Text(direction.shortLabel)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 20)
                    
                    Text(direction.localizedName)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .frame(width: 70, alignment: .leading)
                
                Spacer()
                
                // Action type icon and description
                if let mapping = mapping {
                    HStack(spacing: 8) {
                        Image(systemName: mapping.action.typeIcon)
                            .foregroundColor(mapping.action.typeColor)
                            .frame(width: 20)
                        
                        Text(mapping.action.displayDescription)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "minus")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Text("未配置")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Extensions for Display (App-specific)

extension Action {
    /// Color for the action type icon (UI-specific, not in Core)
    var typeColor: Color {
        switch self {
        case .keyPress, .keyRelease:
            return .blue
        case .mouseButton, .mouseMove, .mouseScroll:
            return .purple
        case .macro:
            return .orange
        case .script:
            return .green
        }
    }
}

#Preview {
    let sampleMappings: [StickDirection: Mapping] = [
        .up: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .up)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 13, modifiers: []))
        ),
        .down: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .down)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 1, modifiers: []))
        ),
        .left: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .left)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 0, modifiers: []))
        ),
        .right: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .right)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 2, modifiers: []))
        ),
        .upRight: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .upRight)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 13, modifiers: [.shift]))
        ),
        .downLeft: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .downLeft)),
            trigger: .press,
            action: .mouseButton(MouseButtonAction(button: .left))
        )
    ]
    
    return DirectionMappingListView(
        directionMappings: sampleMappings,
        onDirectionTapped: { direction in
            print("Tapped: \(direction)")
        }
    )
    .frame(width: 300, height: 400)
    .padding()
}
