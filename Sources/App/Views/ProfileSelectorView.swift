import SwiftUI
import PS5GamePadMapperCore

/// Profile selector dropdown for switching between profiles
/// Requirements: 18.5 - Display dropdown list of available profiles
struct ProfileSelectorView: View {
    @Binding var selectedProfile: Profile?
    let profiles: [Profile]
    let onProfileSelected: (Profile) -> Void
    
    var body: some View {
        HStack {
            Text("Profile:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Menu {
                if profiles.isEmpty {
                    Text("No profiles available")
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
                    // Create new profile action - to be implemented in Mapping Editor
                }) {
                    Label("Create New Profile...", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text(selectedProfile?.name ?? "Select Profile")
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
