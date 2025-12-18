import Foundation
import IOKit
import IOKit.hid

/// DualSense controller HID identifiers
private enum DualSenseHID {
    static let vendorID: Int32 = 0x054C  // Sony
    static let productID_USB: Int32 = 0x0CE6  // DualSense USB
    static let productID_BT: Int32 = 0x0CE6   // DualSense Bluetooth (same product ID)
    
    // HID Report structure offsets for USB mode
    enum USBReport {
        static let reportID: Int = 0
        static let leftStickX: Int = 1
        static let leftStickY: Int = 2
        static let rightStickX: Int = 3
        static let rightStickY: Int = 4
        static let l2Trigger: Int = 5
        static let r2Trigger: Int = 6
        static let buttons1: Int = 8   // Square, Cross, Circle, Triangle
        static let buttons2: Int = 9   // L1, R1, L2, R2, Share, Options, L3, R3
        static let buttons3: Int = 10  // PS, Touchpad, Counter
        static let batteryLevel: Int = 53
    }
    
    // HID Report structure offsets for Bluetooth mode
    enum BTReport {
        static let reportID: Int = 0
        static let leftStickX: Int = 2
        static let leftStickY: Int = 3
        static let rightStickX: Int = 4
        static let rightStickY: Int = 5
        static let l2Trigger: Int = 6
        static let r2Trigger: Int = 7
        static let buttons1: Int = 9
        static let buttons2: Int = 10
        static let buttons3: Int = 11
        static let batteryLevel: Int = 54
    }
}

/// Button bit masks for HID report parsing
private enum ButtonMask {
    // buttons1 byte - D-pad is in lower 4 bits, face buttons in upper 4 bits
    static let dpadMask: UInt8 = 0x0F
    static let square: UInt8 = 0x10
    static let cross: UInt8 = 0x20
    static let circle: UInt8 = 0x40
    static let triangle: UInt8 = 0x80
    
    // buttons2 byte
    static let l1: UInt8 = 0x01
    static let r1: UInt8 = 0x02
    static let l2: UInt8 = 0x04
    static let r2: UInt8 = 0x08
    static let share: UInt8 = 0x10
    static let options: UInt8 = 0x20
    static let l3: UInt8 = 0x40
    static let r3: UInt8 = 0x80
    
    // buttons3 byte
    static let ps: UInt8 = 0x01
    static let touchpad: UInt8 = 0x02
}

/// D-pad direction values (lower 4 bits of buttons1)
private enum DPadDirection: UInt8 {
    case up = 0
    case upRight = 1
    case right = 2
    case downRight = 3
    case down = 4
    case downLeft = 5
    case left = 6
    case upLeft = 7
    case neutral = 8
}

/// Controller Manager implementation using IOHIDManager
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 3.1, 3.3
public final class ControllerManager: ControllerManagerProtocol {
    
    // MARK: - Properties
    
    public private(set) var connectedControllers: [Controller] = []
    public var onControllerConnected: ((Controller) -> Void)?
    public var onControllerDisconnected: ((Controller) -> Void)?
    
    /// Callback for controller reconnection (for profile restoration)
    /// Requirements: 1.6
    public var onControllerReconnected: ((Controller) -> Void)?
    
    /// Callback for button input events
    public var onButtonInput: ((RawButtonInput) -> Void)?
    
    /// Callback for axis input events
    public var onAxisInput: ((RawAxisInput) -> Void)?
    
    private var hidManager: IOHIDManager?
    private var deviceStates: [String: DeviceState] = [:]
    private var previouslyConnectedDevices: Set<String> = []  // Track devices for reconnection detection
    private let inputQueue = DispatchQueue(label: "com.ps5gamepadmapper.input", qos: .userInteractive)
    
    /// Tracks the state of a connected device
    private class DeviceState {
        let device: IOHIDDevice
        var controller: Controller
        var buttonStates: [ButtonType: Bool] = [:]
        var buttonPressTimestamps: [ButtonType: UInt64] = [:]
        var lastAxisValues: [AxisType: Int16] = [:]
        
        init(device: IOHIDDevice, controller: Controller) {
            self.device = device
            self.controller = controller
            // Initialize all buttons as not pressed
            for button in ButtonType.allCases {
                buttonStates[button] = false
            }
            // Initialize all axes to neutral
            for axis in AxisType.allCases {
                lastAxisValues[axis] = axis.isTrigger ? 0 : 128
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        stopDiscovery()
    }
    
    // MARK: - ControllerManagerProtocol
    
    /// Start discovering DualSense controllers
    /// Requirements: 1.1, 1.2
    public func startDiscovery() {
        guard hidManager == nil else { return }
        
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else { return }
        
        // Set up matching criteria for Sony DualSense
        let matchingCriteria: [[String: Any]] = [
            [
                kIOHIDVendorIDKey as String: DualSenseHID.vendorID,
                kIOHIDProductIDKey as String: DualSenseHID.productID_USB
            ]
        ]
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingCriteria as CFArray)
        
        // Set up callbacks
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleDeviceConnected(device)
        }, context)
        
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleDeviceDisconnected(device)
        }, context)
        
        IOHIDManagerRegisterInputReportCallback(manager, { context, result, sender, type, reportID, report, reportLength in
            guard let context = context, let sender = sender else { return }
            let manager = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
            // Cast sender from UnsafeMutableRawPointer to IOHIDDevice
            let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
            manager.handleInputReport(device: device, report: report, length: reportLength)
        }, context)
        
        // Schedule on run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        // Open the manager
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            print("Failed to open HID Manager: \(result)")
        }
    }
    
    /// Stop discovering controllers
    public func stopDiscovery() {
        guard let manager = hidManager else { return }
        
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
        
        // Clear all device states
        deviceStates.removeAll()
        connectedControllers.removeAll()
    }

    
    // MARK: - Device Connection Handling
    
    /// Handle device connection
    /// Requirements: 1.1, 1.2, 1.3, 1.4, 1.6
    private func handleDeviceConnected(_ device: IOHIDDevice) {
        let deviceId = getDeviceId(device)
        
        // Check if this is a reconnection
        let isReconnection = previouslyConnectedDevices.contains(deviceId)
        
        // Determine connection type
        let connectionType = determineConnectionType(device)
        
        // Get device name
        let name = getDeviceName(device) ?? "DualSense Controller"
        
        // Read battery level if available
        let batteryLevel = readBatteryLevel(device)
        
        let controller = Controller(
            deviceId: deviceId,
            name: name,
            connectionType: connectionType,
            batteryLevel: batteryLevel
        )
        
        // Store device state
        let state = DeviceState(device: device, controller: controller)
        deviceStates[deviceId] = state
        
        // Track this device for future reconnection detection
        previouslyConnectedDevices.insert(deviceId)
        
        // Update connected controllers list
        connectedControllers.append(controller)
        
        // Notify appropriate callback
        DispatchQueue.main.async { [weak self] in
            if isReconnection {
                // Reconnection - trigger profile restoration
                self?.onControllerReconnected?(controller)
            }
            // Always call connected callback
            self?.onControllerConnected?(controller)
        }
    }
    
    /// Handle device disconnection
    /// Requirements: 1.5
    private func handleDeviceDisconnected(_ device: IOHIDDevice) {
        let deviceId = getDeviceId(device)
        
        guard let state = deviceStates[deviceId] else { return }
        
        let controller = state.controller
        
        // Remove from tracking
        deviceStates.removeValue(forKey: deviceId)
        connectedControllers.removeAll { $0.deviceId == deviceId }
        
        // Notify callback
        DispatchQueue.main.async { [weak self] in
            self?.onControllerDisconnected?(controller)
        }
    }
    
    /// Determine if device is connected via USB or Bluetooth
    /// Requirements: 1.3
    private func determineConnectionType(_ device: IOHIDDevice) -> ConnectionType {
        // Check transport property
        if let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String {
            if transport.lowercased().contains("bluetooth") {
                return .bluetooth
            }
        }
        
        // Check report descriptor size - Bluetooth reports are typically larger
        if let reportSize = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int {
            // DualSense USB reports are typically 64 bytes, Bluetooth are 78 bytes
            if reportSize > 70 {
                return .bluetooth
            }
        }
        
        return .usb
    }
    
    /// Get unique device identifier
    private func getDeviceId(_ device: IOHIDDevice) -> String {
        let vendorId = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productId = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let locationId = IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? Int ?? 0
        
        return "\(vendorId)-\(productId)-\(locationId)"
    }
    
    /// Get device name from HID properties
    private func getDeviceName(_ device: IOHIDDevice) -> String? {
        return IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
    }
    
    /// Read battery level from device
    /// Requirements: 1.4
    private func readBatteryLevel(_ device: IOHIDDevice) -> Int? {
        // Battery level is typically read from HID reports, not properties
        // Return nil initially, will be updated from input reports
        return nil
    }
    
    // MARK: - Input Report Handling
    
    /// Handle HID input report
    /// Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.3
    private func handleInputReport(device: IOHIDDevice, report: UnsafePointer<UInt8>, length: CFIndex) {
        let deviceId = getDeviceId(device)
        guard let state = deviceStates[deviceId] else { return }
        
        let timestamp = mach_absolute_time()
        let reportData = UnsafeBufferPointer(start: report, count: Int(length))
        
        // Determine offsets based on connection type
        let offsets: (
            leftStickX: Int, leftStickY: Int,
            rightStickX: Int, rightStickY: Int,
            l2Trigger: Int, r2Trigger: Int,
            buttons1: Int, buttons2: Int, buttons3: Int,
            batteryLevel: Int
        )
        
        if state.controller.connectionType == .bluetooth && length > 70 {
            offsets = (
                DualSenseHID.BTReport.leftStickX,
                DualSenseHID.BTReport.leftStickY,
                DualSenseHID.BTReport.rightStickX,
                DualSenseHID.BTReport.rightStickY,
                DualSenseHID.BTReport.l2Trigger,
                DualSenseHID.BTReport.r2Trigger,
                DualSenseHID.BTReport.buttons1,
                DualSenseHID.BTReport.buttons2,
                DualSenseHID.BTReport.buttons3,
                DualSenseHID.BTReport.batteryLevel
            )
        } else {
            offsets = (
                DualSenseHID.USBReport.leftStickX,
                DualSenseHID.USBReport.leftStickY,
                DualSenseHID.USBReport.rightStickX,
                DualSenseHID.USBReport.rightStickY,
                DualSenseHID.USBReport.l2Trigger,
                DualSenseHID.USBReport.r2Trigger,
                DualSenseHID.USBReport.buttons1,
                DualSenseHID.USBReport.buttons2,
                DualSenseHID.USBReport.buttons3,
                DualSenseHID.USBReport.batteryLevel
            )
        }
        
        // Ensure report is long enough
        guard Int(length) > max(offsets.buttons3, offsets.batteryLevel) else { return }
        
        // Parse axis values
        parseAxisInputs(reportData: reportData, offsets: offsets, state: state, timestamp: timestamp)
        
        // Parse button states
        parseButtonInputs(reportData: reportData, offsets: offsets, state: state, timestamp: timestamp)
        
        // Update battery level if available
        updateBatteryLevel(reportData: reportData, offset: offsets.batteryLevel, state: state)
    }

    
    // MARK: - Axis Input Parsing
    
    /// Parse axis inputs from HID report
    /// Requirements: 3.1, 3.3
    private func parseAxisInputs(
        reportData: UnsafeBufferPointer<UInt8>,
        offsets: (leftStickX: Int, leftStickY: Int, rightStickX: Int, rightStickY: Int,
                  l2Trigger: Int, r2Trigger: Int, buttons1: Int, buttons2: Int, buttons3: Int, batteryLevel: Int),
        state: DeviceState,
        timestamp: UInt64
    ) {
        // Left stick X (0-255, center at 128)
        let leftStickXRaw = Int16(reportData[offsets.leftStickX]) - 128
        emitAxisIfChanged(axis: .leftStickX, rawValue: leftStickXRaw, state: state, timestamp: timestamp)
        
        // Left stick Y (0-255, center at 128, inverted)
        let leftStickYRaw = Int16(reportData[offsets.leftStickY]) - 128
        emitAxisIfChanged(axis: .leftStickY, rawValue: leftStickYRaw, state: state, timestamp: timestamp)
        
        // Right stick X (0-255, center at 128)
        let rightStickXRaw = Int16(reportData[offsets.rightStickX]) - 128
        emitAxisIfChanged(axis: .rightStickX, rawValue: rightStickXRaw, state: state, timestamp: timestamp)
        
        // Right stick Y (0-255, center at 128, inverted)
        let rightStickYRaw = Int16(reportData[offsets.rightStickY]) - 128
        emitAxisIfChanged(axis: .rightStickY, rawValue: rightStickYRaw, state: state, timestamp: timestamp)
        
        // L2 trigger (0-255)
        let l2Raw = Int16(reportData[offsets.l2Trigger])
        emitAxisIfChanged(axis: .l2Trigger, rawValue: l2Raw, state: state, timestamp: timestamp)
        
        // R2 trigger (0-255)
        let r2Raw = Int16(reportData[offsets.r2Trigger])
        emitAxisIfChanged(axis: .r2Trigger, rawValue: r2Raw, state: state, timestamp: timestamp)
    }
    
    /// Emit axis input if value changed
    private func emitAxisIfChanged(axis: AxisType, rawValue: Int16, state: DeviceState, timestamp: UInt64) {
        let lastValue = state.lastAxisValues[axis] ?? (axis.isTrigger ? 0 : 128)
        
        // Only emit if value changed significantly (threshold of 2 to reduce noise)
        if abs(Int(rawValue) - Int(lastValue)) > 2 {
            state.lastAxisValues[axis] = rawValue
            
            let input = RawAxisInput(axis: axis, rawValue: rawValue, timestamp: timestamp)
            
            inputQueue.async { [weak self] in
                self?.onAxisInput?(input)
            }
        }
    }
    
    // MARK: - Button Input Parsing
    
    /// Parse button inputs from HID report
    /// Requirements: 2.1, 2.2, 2.3, 2.4
    private func parseButtonInputs(
        reportData: UnsafeBufferPointer<UInt8>,
        offsets: (leftStickX: Int, leftStickY: Int, rightStickX: Int, rightStickY: Int,
                  l2Trigger: Int, r2Trigger: Int, buttons1: Int, buttons2: Int, buttons3: Int, batteryLevel: Int),
        state: DeviceState,
        timestamp: UInt64
    ) {
        let buttons1 = reportData[offsets.buttons1]
        let buttons2 = reportData[offsets.buttons2]
        let buttons3 = reportData[offsets.buttons3]
        
        // Parse D-pad (lower 4 bits of buttons1)
        let dpadValue = buttons1 & ButtonMask.dpadMask
        parseDPad(dpadValue: dpadValue, state: state, timestamp: timestamp)
        
        // Parse face buttons (upper 4 bits of buttons1)
        emitButtonIfChanged(button: .square, isPressed: (buttons1 & ButtonMask.square) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .cross, isPressed: (buttons1 & ButtonMask.cross) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .circle, isPressed: (buttons1 & ButtonMask.circle) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .triangle, isPressed: (buttons1 & ButtonMask.triangle) != 0, state: state, timestamp: timestamp)
        
        // Parse shoulder and stick buttons (buttons2)
        emitButtonIfChanged(button: .l1, isPressed: (buttons2 & ButtonMask.l1) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r1, isPressed: (buttons2 & ButtonMask.r1) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .l2, isPressed: (buttons2 & ButtonMask.l2) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r2, isPressed: (buttons2 & ButtonMask.r2) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .share, isPressed: (buttons2 & ButtonMask.share) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .options, isPressed: (buttons2 & ButtonMask.options) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .l3, isPressed: (buttons2 & ButtonMask.l3) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r3, isPressed: (buttons2 & ButtonMask.r3) != 0, state: state, timestamp: timestamp)
        
        // Parse PS and touchpad buttons (buttons3)
        emitButtonIfChanged(button: .ps, isPressed: (buttons3 & ButtonMask.ps) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .touchpad, isPressed: (buttons3 & ButtonMask.touchpad) != 0, state: state, timestamp: timestamp)
    }
    
    /// Parse D-pad direction
    private func parseDPad(dpadValue: UInt8, state: DeviceState, timestamp: UInt64) {
        let direction = DPadDirection(rawValue: dpadValue) ?? .neutral
        
        let upPressed = direction == .up || direction == .upLeft || direction == .upRight
        let downPressed = direction == .down || direction == .downLeft || direction == .downRight
        let leftPressed = direction == .left || direction == .upLeft || direction == .downLeft
        let rightPressed = direction == .right || direction == .upRight || direction == .downRight
        
        emitButtonIfChanged(button: .dpadUp, isPressed: upPressed, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .dpadDown, isPressed: downPressed, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .dpadLeft, isPressed: leftPressed, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .dpadRight, isPressed: rightPressed, state: state, timestamp: timestamp)
    }
    
    /// Emit button input if state changed
    /// Requirements: 2.1, 2.2, 2.3
    private func emitButtonIfChanged(button: ButtonType, isPressed: Bool, state: DeviceState, timestamp: UInt64) {
        let wasPressed = state.buttonStates[button] ?? false
        
        if isPressed != wasPressed {
            state.buttonStates[button] = isPressed
            
            if isPressed {
                // Record press timestamp for hold duration tracking
                state.buttonPressTimestamps[button] = timestamp
            } else {
                // Clear press timestamp on release
                state.buttonPressTimestamps.removeValue(forKey: button)
            }
            
            let input = RawButtonInput(button: button, isPressed: isPressed, timestamp: timestamp)
            
            inputQueue.async { [weak self] in
                self?.onButtonInput?(input)
            }
        }
    }
    
    // MARK: - Battery Level
    
    /// Update battery level from HID report
    /// Requirements: 1.4
    private func updateBatteryLevel(reportData: UnsafeBufferPointer<UInt8>, offset: Int, state: DeviceState) {
        guard offset < reportData.count else { return }
        
        let batteryByte = reportData[offset]
        // Battery level is in lower 4 bits, multiply by 10 to get percentage (0-100)
        let batteryLevel = Int(batteryByte & 0x0F) * 10
        
        // Only update if changed
        if state.controller.batteryLevel != batteryLevel {
            let updatedController = Controller(
                deviceId: state.controller.deviceId,
                name: state.controller.name,
                connectionType: state.controller.connectionType,
                batteryLevel: batteryLevel
            )
            state.controller = updatedController
            
            // Update in connected controllers list
            if let index = connectedControllers.firstIndex(where: { $0.deviceId == state.controller.deviceId }) {
                connectedControllers[index] = updatedController
            }
        }
    }
    
    // MARK: - Public Utilities
    
    /// Get current button state for a specific button
    /// Requirements: 2.3
    public func isButtonPressed(_ button: ButtonType, controllerId: String? = nil) -> Bool {
        let targetId = controllerId ?? connectedControllers.first?.deviceId
        guard let id = targetId, let state = deviceStates[id] else { return false }
        return state.buttonStates[button] ?? false
    }
    
    /// Get hold duration for a button
    /// Requirements: 2.3
    public func getButtonHoldDuration(_ button: ButtonType, controllerId: String? = nil) -> TimeInterval? {
        let targetId = controllerId ?? connectedControllers.first?.deviceId
        guard let id = targetId, let state = deviceStates[id] else { return nil }
        
        guard let pressTimestamp = state.buttonPressTimestamps[button] else { return nil }
        
        let currentTime = mach_absolute_time()
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        
        let elapsedNanos = (currentTime - pressTimestamp) * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        return TimeInterval(elapsedNanos) / 1_000_000_000.0
    }
    
    /// Get current axis value
    public func getAxisValue(_ axis: AxisType, controllerId: String? = nil) -> Int16? {
        let targetId = controllerId ?? connectedControllers.first?.deviceId
        guard let id = targetId, let state = deviceStates[id] else { return nil }
        return state.lastAxisValues[axis]
    }
    
    /// Refresh controller information (e.g., battery level)
    public func refreshController(_ controllerId: String) {
        // Battery level is updated automatically from HID reports
        // This method can be used for manual refresh if needed
    }
}
