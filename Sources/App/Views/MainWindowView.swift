import SwiftUI
import PS5GamePadMapperCore

/// Main window view combining all UI components
/// Requirements: 18.1, 18.2, 18.3, 18.4, 18.5
struct MainWindowView: View {
    @StateObject private var viewModel: MainWindowViewModel
    @State private var showMappingEditor = false
    
    /// Initialize with the app coordinator
    init(coordinator: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: MainWindowViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with controller status and profile selector
            TopBarView(
                controller: viewModel.connectedController,
                selectedProfile: $viewModel.selectedProfile,
                profiles: viewModel.profiles,
                onProfileSelected: viewModel.selectProfile
            )
            .padding()
            
            Divider()
            
            // Main content area
            HSplitView {
                // Controller visualization
                VStack {
                    Text("Controller")
                        .font(.headline)
                        .padding(.top)
                    
                    ControllerVisualizationView(
                        selectedInput: $viewModel.selectedInput,
                        onInputSelected: viewModel.selectInput,
                        pressedButtons: viewModel.pressedButtons,
                        axisValues: viewModel.axisValues
                    )
                    .padding()
                }
                .frame(minWidth: 400)
                
                // Mapping detail panel with edit button
                VStack {
                    MappingDetailPanel(
                        selectedInput: viewModel.selectedInput,
                        mapping: viewModel.selectedMapping
                    )
                    
                    if viewModel.selectedInput != nil {
                        Button("Edit Mapping") {
                            showMappingEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom)
                    }
                }
                .frame(minWidth: 250, maxWidth: 300)
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .sheet(isPresented: $showMappingEditor) {
            if let input = viewModel.selectedInput {
                MappingEditorView(
                    input: input,
                    currentMapping: viewModel.selectedMapping,
                    availableMacros: viewModel.selectedProfile?.macros ?? [],
                    availableScripts: viewModel.selectedProfile?.scripts ?? [],
                    onMappingChanged: { mapping in
                        viewModel.updateMapping(for: input, mapping: mapping)
                    }
                )
            }
        }
    }
}

/// Top bar containing controller status and profile selector
struct TopBarView: View {
    let controller: Controller?
    @Binding var selectedProfile: Profile?
    let profiles: [Profile]
    let onProfileSelected: (Profile) -> Void
    
    var body: some View {
        HStack {
            ControllerStatusView(controller: controller)
            
            Spacer()
            
            ProfileSelectorView(
                selectedProfile: $selectedProfile,
                profiles: profiles,
                onProfileSelected: onProfileSelected
            )
        }
    }
}

/// View model for the main window
/// Uses the AppCoordinator for all core functionality
@MainActor
class MainWindowViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var connectedController: Controller?
    @Published var selectedProfile: Profile?
    @Published var profiles: [Profile] = []
    @Published var selectedInput: InputSource?
    @Published var pressedButtons: Set<ButtonType> = []
    @Published var axisValues: [AxisType: Double] = [:]
    
    // MARK: - Private Properties
    
    /// Reference to the app coordinator (owned by AppState)
    private let coordinator: AppCoordinator
    
    // MARK: - Computed Properties
    
    var selectedMapping: Mapping? {
        guard let input = selectedInput,
              let profile = selectedProfile else {
            return nil
        }
        return profile.mappings.first { $0.input == input }
    }
    
    // MARK: - Initialization
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        
        setupCallbacks()
        loadProfiles()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        // Coordinator handles controller discovery
        // Just ensure we're connected to callbacks
    }
    
    func stopMonitoring() {
        // Coordinator manages lifecycle
    }
    
    func selectProfile(_ profile: Profile) {
        selectedProfile = profile
        coordinator.profileManager.setActiveProfile(profile)
    }
    
    func selectInput(_ input: InputSource) {
        selectedInput = input
    }
    
    /// Update or remove a mapping for the given input
    /// Requirements: 19.2 - Apply change immediately without requiring a save action
    func updateMapping(for input: InputSource, mapping: Mapping?) {
        guard var profile = selectedProfile else { return }
        
        // Remove existing mapping for this input
        profile.mappings.removeAll { $0.input == input }
        
        // Add new mapping if provided
        if let mapping = mapping {
            profile.mappings.append(mapping)
        }
        
        // Update the profile
        selectedProfile = profile
        
        // Save immediately
        do {
            try coordinator.profileManager.saveProfile(profile)
            // Re-activate the profile to apply changes
            coordinator.profileManager.setActiveProfile(profile)
        } catch {
            print("Failed to save profile: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCallbacks() {
        // Controller connection callbacks
        coordinator.controllerManager.onControllerConnected = { [weak self] controller in
            Task { @MainActor in
                self?.connectedController = controller
            }
        }
        
        coordinator.controllerManager.onControllerDisconnected = { [weak self] _ in
            Task { @MainActor in
                self?.connectedController = nil
                self?.pressedButtons.removeAll()
                self?.axisValues.removeAll()
            }
        }
        
        // Button input callback for UI visualization
        coordinator.controllerManager.onButtonInput = { [weak self] rawInput in
            Task { @MainActor in
                guard let self = self else { return }
                if rawInput.isPressed {
                    self.pressedButtons.insert(rawInput.button)
                } else {
                    self.pressedButtons.remove(rawInput.button)
                }
            }
        }
        
        // Axis input callback for UI visualization
        coordinator.controllerManager.onAxisInput = { [weak self] rawInput in
            Task { @MainActor in
                guard let self = self else { return }
                let config = self.coordinator.getAxisConfig(for: rawInput.axis)
                let processed = self.coordinator.inputProcessor.processAxisInput(rawInput, config: config)
                self.axisValues[rawInput.axis] = processed.normalizedValue
            }
        }
        
        // Update UI when profile changes
        coordinator.profileManager.onProfileDidChange = { [weak self] profile in
            Task { @MainActor in
                self?.selectedProfile = profile
            }
        }
        
        // Update connected controller from coordinator
        if let controller = coordinator.controllerManager.connectedControllers.first {
            connectedController = controller
        }
    }
    
    private func loadProfiles() {
        profiles = coordinator.profileManager.profiles
        
        // Select active profile if available
        if let activeProfile = coordinator.profileManager.activeProfile {
            selectedProfile = activeProfile
        } else if let firstProfile = profiles.first {
            selectedProfile = firstProfile
            coordinator.profileManager.setActiveProfile(firstProfile)
        }
    }
}

#Preview {
    MainWindowView(coordinator: AppCoordinator())
}
