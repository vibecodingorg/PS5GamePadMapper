import SwiftUI
import AppKit
import PS5GamePadMapperCore

/// Custom NSWindow subclass that always accepts key status
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override var acceptsFirstResponder: Bool { true }
}

/// Wrapper to make StickType work with sheet(item:)
struct StickTypeWrapper: Identifiable {
    let stick: StickType
    var id: String { stick.rawValue }
}

/// Main window view combining all UI components
/// Requirements: 18.1, 18.2, 18.3, 18.4, 18.5
/// Requirements: 3.1, 3.2, 3.4, 3.5 - Direction selector integration
struct MainWindowView: View {
    @StateObject private var viewModel: MainWindowViewModel
    @State private var showMappingEditor = false
    @State private var showDebugPanel = false
    @State private var editingMacro: Macro?
    @State private var editingScript: Script?
    
    // Direction selector state - use wrapper for sheet(item:)
    @State private var directionSelectorStick: StickTypeWrapper?
    
    // Settings state
    @State private var showSettings = false
    @State private var keyRepeatInterval: Double = 16 // milliseconds
    
    // Window controller for macro editor
    @State private var macroEditorWindow: NSWindow?
    
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
                onProfileSelected: viewModel.selectProfile,
                onCreateProfile: viewModel.createProfile
            )
            .padding()
            
            Divider()
            
            // Main content area
            HSplitView {
                // Controller visualization
                VStack {
                    Text("控制器")
                        .font(.headline)
                        .padding(.top)
                    
                    ControllerVisualizationView(
                        selectedInput: $viewModel.selectedInput,
                        onInputSelected: viewModel.selectInput,
                        pressedButtons: viewModel.pressedButtons,
                        axisValues: viewModel.axisValues,
                        configuredDirections: viewModel.configuredDirections,
                        onStickDirectionTapped: { stick in
                            print("[MainWindowView] Stick tapped: \(stick)")
                            directionSelectorStick = StickTypeWrapper(stick: stick)
                        }
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
                        Button("编辑映射") {
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
        .toolbar {
            ToolbarItemGroup {
                Button {
                    editingMacro = nil
                    editingScript = nil
                    openMacroEditorWindow()
                } label: {
                    Label("宏编辑器", systemImage: "list.bullet.rectangle")
                }
                .help("创建或编辑宏和脚本")
                
                Button {
                    showDebugPanel = true
                } label: {
                    Label("调试面板", systemImage: "ladybug")
                }
                .help("查看输入事件和调试信息")
                
                Button {
                    showSettings = true
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .help("配置应用设置")
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
            macroEditorWindow?.close()
        }
        .sheet(isPresented: $showMappingEditor) {
            if let input = viewModel.selectedInput {
                let macros = viewModel.selectedProfile?.macros ?? []
                let scripts = viewModel.selectedProfile?.scripts ?? []
                let _ = print("[MainWindowView] Opening MappingEditorView - profile: \(viewModel.selectedProfile?.name ?? "nil"), macros: \(macros.count), scripts: \(scripts.count)")
                MappingEditorView(
                    input: input,
                    currentMapping: viewModel.selectedMapping,
                    availableMacros: macros,
                    availableScripts: scripts,
                    onMappingChanged: { mapping in
                        viewModel.updateMapping(for: input, mapping: mapping)
                    }
                )
            }
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(item: $directionSelectorStick) { wrapper in
            DirectionSelectorView(
                stick: wrapper.stick,
                currentX: viewModel.axisValues[wrapper.stick == .left ? .leftStickX : .rightStickX] ?? 0,
                currentY: -(viewModel.axisValues[wrapper.stick == .left ? .leftStickY : .rightStickY] ?? 0),
                configuredDirections: viewModel.configuredDirections[wrapper.stick] ?? [],
                availableMacros: viewModel.selectedProfile?.macros ?? [],
                availableScripts: viewModel.selectedProfile?.scripts ?? [],
                directionMappings: viewModel.getDirectionMappings(for: wrapper.stick),
                onMappingChanged: { direction, mapping in
                    let input = InputSource.direction(DirectionInput(stick: wrapper.stick, direction: direction))
                    viewModel.updateMapping(for: input, mapping: mapping)
                },
                onDismiss: {
                    directionSelectorStick = nil
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                keyRepeatInterval: $keyRepeatInterval,
                onSave: {
                    // Apply settings to EventEmitter
                    viewModel.setKeyRepeatInterval(keyRepeatInterval)
                    showSettings = false
                },
                onCancel: {
                    showSettings = false
                }
            )
        }
    }
    
    /// Open macro editor in a separate window to avoid sheet keyboard input issues
    private func openMacroEditorWindow() {
        // Close existing window if any
        macroEditorWindow?.close()
        
        // Create window first so we can reference it in closures
        let window = KeyableWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 600),
                                   styleMask: [.titled, .closable, .resizable],
                                   backing: .buffered,
                                   defer: false)
        window.title = "宏/脚本编辑器"
        window.center()
        window.isReleasedWhenClosed = false
        
        macroEditorWindow = window
        
        let editorView = MacroEditorView(
            macro: $editingMacro,
            script: $editingScript,
            onSave: { [weak viewModel, weak window] macro, script in
                viewModel?.saveMacroOrScript(macro: macro, script: script)
                window?.close()
            },
            onCancel: { [weak window] in
                window?.close()
            }
        )
        
        let hostingController = NSHostingController(rootView: editorView)
        window.contentViewController = hostingController
        
        // Show window and activate
        window.orderFront(nil)
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// Top bar containing controller status and profile selector
struct TopBarView: View {
    let controller: Controller?
    @Binding var selectedProfile: Profile?
    let profiles: [Profile]
    let onProfileSelected: (Profile) -> Void
    var onCreateProfile: ((String) -> Void)?
    
    @State private var showingNewProfileSheet = false
    @State private var newProfileName = ""
    
    var body: some View {
        HStack {
            ControllerStatusView(controller: controller)
            
            Spacer()
            
            ProfileSelectorView(
                selectedProfile: $selectedProfile,
                profiles: profiles,
                onProfileSelected: onProfileSelected,
                onCreateProfile: {
                    print("[TopBarView] onCreateProfile callback triggered")
                    showingNewProfileSheet = true
                }
            )
        }
        .sheet(isPresented: $showingNewProfileSheet) {
            NewProfileSheet(
                profileName: $newProfileName,
                onSave: {
                    print("[TopBarView] NewProfileSheet onSave - name: \(newProfileName)")
                    if !newProfileName.trimmingCharacters(in: .whitespaces).isEmpty {
                        onCreateProfile?(newProfileName)
                    }
                    showingNewProfileSheet = false
                    newProfileName = ""
                },
                onCancel: {
                    print("[TopBarView] NewProfileSheet onCancel")
                    showingNewProfileSheet = false
                    newProfileName = ""
                }
            )
        }
        .onChange(of: showingNewProfileSheet) { newValue in
            print("[TopBarView] showingNewProfileSheet changed to: \(newValue)")
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
    
    /// Get configured directions for each stick from the current profile
    /// Requirements: 3.3 - Visually indicate which directions have configured mappings
    var configuredDirections: [StickType: Set<StickDirection>] {
        guard let profile = selectedProfile else {
            return [:]
        }
        
        var result: [StickType: Set<StickDirection>] = [.left: [], .right: []]
        
        for mapping in profile.mappings {
            if case .direction(let dirInput) = mapping.input {
                result[dirInput.stick, default: []].insert(dirInput.direction)
            }
        }
        
        return result
    }
    
    /// Get all direction mappings for a specific stick
    func getDirectionMappings(for stick: StickType) -> [StickDirection: Mapping] {
        guard let profile = selectedProfile else {
            return [:]
        }
        
        var result: [StickDirection: Mapping] = [:]
        
        for mapping in profile.mappings {
            if case .direction(let dirInput) = mapping.input, dirInput.stick == stick {
                result[dirInput.direction] = mapping
            }
        }
        
        return result
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
    
    /// Set the key repeat interval for toggle mode
    /// - Parameter interval: Interval in milliseconds
    func setKeyRepeatInterval(_ intervalMs: Double) {
        let intervalSeconds = intervalMs / 1000.0
        coordinator.eventEmitter.setKeyRepeatInterval(intervalSeconds)
        print("[MainWindowViewModel] Key repeat interval set to \(intervalMs)ms")
    }
    
    /// Create a new profile with the given name
    func createProfile(name: String) {
        print("[MainWindowViewModel] createProfile called - name: \(name)")
        
        let newProfile = Profile(name: name)
        
        do {
            try coordinator.profileManager.saveProfile(newProfile)
            print("[MainWindowViewModel] New profile saved successfully")
            
            // Add to local profiles array
            profiles.append(newProfile)
            
            // Select the new profile
            selectedProfile = newProfile
            coordinator.profileManager.setActiveProfile(newProfile)
            
            print("[MainWindowViewModel] New profile created and selected: \(newProfile.name)")
        } catch {
            print("[MainWindowViewModel] ERROR: Failed to create profile: \(error)")
        }
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
    
    /// Save a macro or script to the current profile
    func saveMacroOrScript(macro: Macro?, script: Script?) {
        print("[MainWindowViewModel] saveMacroOrScript called - macro: \(macro?.name ?? "nil"), script: \(script?.name ?? "nil")")
        
        guard var profile = selectedProfile else {
            print("[MainWindowViewModel] ERROR: No selectedProfile!")
            return
        }
        
        print("[MainWindowViewModel] Current profile: \(profile.name), macros: \(profile.macros.count), scripts: \(profile.scripts.count)")
        
        if let macro = macro {
            // Update or add macro
            if let index = profile.macros.firstIndex(where: { $0.id == macro.id }) {
                print("[MainWindowViewModel] Updating existing macro at index \(index)")
                profile.macros[index] = macro
            } else {
                print("[MainWindowViewModel] Adding new macro")
                profile.macros.append(macro)
            }
        }
        
        if let script = script {
            // Update or add script
            if let index = profile.scripts.firstIndex(where: { $0.id == script.id }) {
                print("[MainWindowViewModel] Updating existing script at index \(index)")
                profile.scripts[index] = script
            } else {
                print("[MainWindowViewModel] Adding new script")
                profile.scripts.append(script)
            }
        }
        
        print("[MainWindowViewModel] After update - macros: \(profile.macros.count), scripts: \(profile.scripts.count)")
        
        // Save immediately
        do {
            try coordinator.profileManager.saveProfile(profile)
            print("[MainWindowViewModel] Profile saved successfully")
            
            // Update local profiles array to stay in sync
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
                print("[MainWindowViewModel] Updated profiles array at index \(index)")
            }
            
            // Update selectedProfile after saving to ensure consistency
            selectedProfile = profile
            print("[MainWindowViewModel] Updated selectedProfile - macros: \(selectedProfile?.macros.count ?? 0), scripts: \(selectedProfile?.scripts.count ?? 0)")
            
            // Re-activate the profile to apply changes
            coordinator.profileManager.setActiveProfile(profile)
            print("[MainWindowViewModel] Profile re-activated")
        } catch {
            print("[MainWindowViewModel] ERROR: Failed to save profile: \(error)")
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
        
        // Button input callback for UI visualization - use addButtonInputHandler to support multiple handlers
        coordinator.controllerManager.addButtonInputHandler(id: "MainWindowView") { [weak self] rawInput in
            Task { @MainActor in
                guard let self = self else { return }
                if rawInput.isPressed {
                    self.pressedButtons.insert(rawInput.button)
                } else {
                    self.pressedButtons.remove(rawInput.button)
                }
            }
        }
        
        // Axis input callback for UI visualization - use addAxisInputHandler to support multiple handlers
        coordinator.controllerManager.addAxisInputHandler(id: "MainWindowView") { [weak self] rawInput in
            Task { @MainActor in
                guard let self = self else { return }
                let config = self.coordinator.getAxisConfig(for: rawInput.axis)
                let processed = self.coordinator.inputProcessor.processAxisInput(rawInput, config: config)
                self.axisValues[rawInput.axis] = processed.normalizedValue
            }
        }
        
        // Update UI when profile changes - use addProfileDidChangeHandler to avoid overwriting AppCoordinator's callback
        coordinator.profileManager.addProfileDidChangeHandler(id: "MainWindowView") { [weak self] profile in
            Task { @MainActor in
                guard let self = self else { return }
                // Only update if the profile is different to avoid unnecessary re-renders
                if self.selectedProfile?.id != profile?.id || self.selectedProfile != profile {
                    self.selectedProfile = profile
                    // Also update the profiles array to stay in sync
                    if let profile = profile,
                       let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                        self.profiles[index] = profile
                    }
                }
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
