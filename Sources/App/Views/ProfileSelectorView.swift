import SwiftUI
import PS5GamePadMapperCore

/// Profile selector dropdown for switching between profiles
/// Requirements: 18.5 - Display dropdown list of available profiles
struct ProfileSelectorView: View {
    @Binding var selectedProfile: Profile?
    let profiles: [Profile]
    let onProfileSelected: (Profile) -> Void
    var onCreateProfile: (() -> Void)?
    
    var body: some View {
        HStack {
            Text("配置文件:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Menu {
                if profiles.isEmpty {
                    Text("暂无配置文件")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(profiles) { profile in
                        Button(action: {
                            selectedProfile = profile
                            onProfileSelected(profile)
                        }) {
                            HStack {
                                Text(profile.name)
                                if selectedProfile?.id == profile.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(action: {
                    print("[ProfileSelectorView] 新建配置文件 button clicked, onCreateProfile is \(onCreateProfile == nil ? "nil" : "set")")
                    onCreateProfile?()
                }) {
                    Label("新建配置文件...", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text(selectedProfile?.name ?? "选择配置文件")
                        .frame(minWidth: 150, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
        }
    }
}

/// Sheet for creating a new profile
struct NewProfileSheet: View {
    @Binding var profileName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("新建配置文件")
                .font(.headline)
            
            TextField("配置文件名称", text: $profileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            HStack(spacing: 16) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("创建") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(minWidth: 300)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedProfile: Profile? = nil
        
        let profiles = [
            Profile(name: "Default"),
            Profile(name: "Gaming"),
            Profile(name: "Development")
        ]
        
        var body: some View {
            ProfileSelectorView(
                selectedProfile: $selectedProfile,
                profiles: profiles,
                onProfileSelected: { _ in }
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}
