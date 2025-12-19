import SwiftUI
import PS5GamePadMapperCore

/// Settings view for configuring global application settings
struct SettingsView: View {
    @Binding var keyRepeatInterval: Double // in milliseconds
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Settings content
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("按键重复间隔 (切换模式)")
                            .font(.subheadline)
                        
                        HStack {
                            Slider(
                                value: $keyRepeatInterval,
                                in: 10...200,
                                step: 5
                            )
                            
                            Text("\(Int(keyRepeatInterval))ms")
                                .frame(width: 50, alignment: .trailing)
                                .monospacedDigit()
                        }
                        
                        Text("较小的值 = 更快的重复速度，可能被游戏检测\n较大的值 = 更慢的重复速度，更安全但响应较慢")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Preset buttons
                        HStack(spacing: 8) {
                            PresetButton(title: "快速 (16ms)", value: 16, selection: $keyRepeatInterval)
                            PresetButton(title: "正常 (33ms)", value: 33, selection: $keyRepeatInterval)
                            PresetButton(title: "安全 (50ms)", value: 50, selection: $keyRepeatInterval)
                            PresetButton(title: "慢速 (100ms)", value: 100, selection: $keyRepeatInterval)
                        }
                    }
                } header: {
                    Text("切换模式设置")
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
}

/// Preset button for quick interval selection
struct PresetButton: View {
    let title: String
    let value: Double
    @Binding var selection: Double
    
    var body: some View {
        Button(title) {
            selection = value
        }
        .buttonStyle(.bordered)
        .tint(selection == value ? .accentColor : nil)
    }
}

#Preview {
    SettingsView(
        keyRepeatInterval: .constant(16),
        onSave: {},
        onCancel: {}
    )
}
