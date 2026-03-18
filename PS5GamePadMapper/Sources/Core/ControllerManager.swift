import Foundation
import IOKit
import IOKit.hid

/// DualSense controller HID identifiers
private enum DualSenseHID {
    static let vendorID: Int32 = 0x054C  // Sony
    static let productID_USB: Int32 = 0x0CE6  // DualSense USB
    static let productID_BT: Int32 = 0x0CE6   // DualSense Bluetooth (same product ID)
    
    // HID Report structure offsets for USB mode (64 bytes)
    enum USBReport {
        static let reportID: Int = 0
        static let leftStickX: Int = 1
        static let leftStickY: Int = 2
        static let rightStickX: Int = 3
        static let rightStickY: Int = 4
        static let l2Trigger: Int = 5
        static let r2Trigger: Int = 6
        static let buttons1: Int = 8   // D-pad + Square, Cross, Circle, Triangle
        static let buttons2: Int = 9   // L1, R1, L2, R2, Share, Options, L3, R3
        static let buttons3: Int = 10  // PS, Touchpad, Counter
        static let batteryLevel: Int = 53
    }
    
    // HID Report structure offsets for Bluetooth full mode (78 bytes)
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
    
    // HID Report structure offsets for Bluetooth simple mode (10 bytes)
    // This is the default mode when connected via Bluetooth without special setup
    enum BTSimpleReport {
        static let reportID: Int = 0
        static let leftStickX: Int = 1
        static let leftStickY: Int = 2
        static let rightStickX: Int = 3
        static let rightStickY: Int = 4
        static let buttons1: Int = 5   // D-pad + face buttons
        static let buttons2: Int = 6   // Shoulder + options/share
        static let buttons3: Int = 7   // L3/R3 + PS + touchpad
        static let l2Trigger: Int = 8
        static let r2Trigger: Int = 9
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
    public var onControllerReconnected: ((Controller) -> Void)?
    
    /// Callback for button input events (legacy - use addButtonInputHandler for multiple handlers)
    public var onButtonInput: ((RawButtonInput) -> Void)?
    
    /// Callback for axis input events (legacy - use addAxisInputHandler for multiple handlers)
    public var onAxisInput: ((RawAxisInput) -> Void)?
    
    /// Multiple button input handlers (keyed by identifier)
    private var buttonInputHandlers: [String: (RawButtonInput) -> Void] = [:]
    
    /// Multiple axis input handlers (keyed by identifier)
    private var axisInputHandlers: [String: (RawAxisInput) -> Void] = [:]
    
    /// Add a button input handler with an identifier
    public func addButtonInputHandler(id: String, handler: @escaping (RawButtonInput) -> Void) {
        buttonInputHandlers[id] = handler
        NSLog("[DEBUG] ControllerManager: ➕ Added button input handler: %@, total: %d", id, buttonInputHandlers.count)
    }
    
    /// Remove a button input handler by identifier
    public func removeButtonInputHandler(id: String) {
        buttonInputHandlers.removeValue(forKey: id)
        NSLog("[DEBUG] ControllerManager: ➖ Removed button input handler: %@, total: %d", id, buttonInputHandlers.count)
    }
    
    /// Add an axis input handler with an identifier
    public func addAxisInputHandler(id: String, handler: @escaping (RawAxisInput) -> Void) {
        axisInputHandlers[id] = handler
    }
    
    /// Remove an axis input handler by identifier
    public func removeAxisInputHandler(id: String) {
        axisInputHandlers.removeValue(forKey: id)
    }
    
    private var hidManager: IOHIDManager?
    private var deviceStates: [String: DeviceState] = [:]
    private var previouslyConnectedDevices: Set<String> = []
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
            for button in ButtonType.allCases {
                buttonStates[button] = false
            }
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
    
    public func startDiscovery() {
        NSLog("[DEBUG] ControllerManager: 🔍 Starting HID discovery...")
        guard hidManager == nil else {
            NSLog("[DEBUG] ControllerManager: ⚠️ HID Manager already exists")
            return
        }
        
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else {
            NSLog("[DEBUG] ControllerManager: ❌ Failed to create HID Manager")
            return
        }
        
        NSLog("[DEBUG] ControllerManager: ✅ HID Manager created")
        
        let matchingCriteria: [[String: Any]] = [
            [
                kIOHIDVendorIDKey as String: DualSenseHID.vendorID,
                kIOHIDProductIDKey as String: DualSenseHID.productID_USB
            ]
        ]
        
        NSLog("[DEBUG] ControllerManager: 🎮 Looking for Sony DualSense (VendorID: 0x054C, ProductID: 0x0CE6)")
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingCriteria as CFArray)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            NSLog("[DEBUG] ControllerManager: 📱 Device matching callback triggered!")
            guard let context = context else { return }
            let manager = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleDeviceConnected(device)
        }, context)
        
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            NSLog("[DEBUG] ControllerManager: 📱 Device removal callback triggered!")
            guard let context = context else { return }
            let manager = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleDeviceDisconnected(device)
        }, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        NSLog("[DEBUG] ControllerManager: ✅ Scheduled on main run loop")
        
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            NSLog("[DEBUG] ControllerManager: ❌ Failed to open HID Manager: \(result)")
        } else {
            NSLog("[DEBUG] ControllerManager: ✅ HID Manager opened successfully")
        }
        
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            NSLog("[DEBUG] ControllerManager: 📱 Found \(devices.count) already connected devices")
            for device in devices {
                handleDeviceConnected(device)
            }
        } else {
            NSLog("[DEBUG] ControllerManager: 📱 No devices currently connected")
        }
    }
    
    public func stopDiscovery() {
        guard let manager = hidManager else { return }
        
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
        deviceStates.removeAll()
        connectedControllers.removeAll()
    }


    // MARK: - Device Connection Handling
    
    private func handleDeviceConnected(_ device: IOHIDDevice) {
        let deviceId = getDeviceId(device)
        NSLog("[DEBUG] ControllerManager: 🎮 Device connected! ID: \(deviceId)")
        
        if deviceStates[deviceId] != nil {
            NSLog("[DEBUG] ControllerManager: ⚠️ Device already tracked, skipping")
            return
        }
        
        let isReconnection = previouslyConnectedDevices.contains(deviceId)
        let connectionType = determineConnectionType(device)
        let name = getDeviceName(device) ?? "DualSense Controller"
        NSLog("[DEBUG] ControllerManager: 🎮 Device name: \(name), connection: \(connectionType)")
        
        let batteryLevel = readBatteryLevel(device)
        
        let controller = Controller(
            deviceId: deviceId,
            name: name,
            connectionType: connectionType,
            batteryLevel: batteryLevel
        )
        
        let state = DeviceState(device: device, controller: controller)
        deviceStates[deviceId] = state
        NSLog("[DEBUG] ControllerManager: ✅ Device state stored, total devices: \(deviceStates.count)")
        
        registerDeviceInputCallback(device)
        
        previouslyConnectedDevices.insert(deviceId)
        connectedControllers.append(controller)
        
        DispatchQueue.main.async { [weak self] in
            if isReconnection {
                self?.onControllerReconnected?(controller)
            }
            self?.onControllerConnected?(controller)
        }
    }
    
    private func registerDeviceInputCallback(_ device: IOHIDDevice) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let maxReportSize = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int ?? 128
        NSLog("[DEBUG] ControllerManager: 📦 Max input report size: \(maxReportSize)")
        
        let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReportSize)
        reportBuffer.initialize(repeating: 0, count: maxReportSize)
        
        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            maxReportSize,
            { context, _, sender, _, _, report, reportLength in
                guard let context = context else { return }
                let manager = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
                
                guard let senderDevice = sender else { return }
                let device = Unmanaged<IOHIDDevice>.fromOpaque(senderDevice).takeUnretainedValue()
                
                manager.handleInputReport(device: device, report: report, length: reportLength)
            },
            context
        )
        
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if openResult == kIOReturnSuccess {
            NSLog("[DEBUG] ControllerManager: ✅ Device opened successfully with seize option")
        } else {
            let openResult2 = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            if openResult2 == kIOReturnSuccess {
                NSLog("[DEBUG] ControllerManager: ✅ Device opened successfully without seize option")
            } else {
                NSLog("[DEBUG] ControllerManager: ⚠️ Failed to open device: \(openResult2)")
            }
        }
    }
    
    private func handleDeviceDisconnected(_ device: IOHIDDevice) {
        let deviceId = getDeviceId(device)
        
        guard let state = deviceStates[deviceId] else { return }
        
        let controller = state.controller
        
        deviceStates.removeValue(forKey: deviceId)
        connectedControllers.removeAll { $0.deviceId == deviceId }
        
        DispatchQueue.main.async { [weak self] in
            self?.onControllerDisconnected?(controller)
        }
    }
    
    private func determineConnectionType(_ device: IOHIDDevice) -> ConnectionType {
        if let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String {
            if transport.lowercased().contains("bluetooth") {
                return .bluetooth
            }
        }
        
        if let reportSize = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int {
            if reportSize > 70 {
                return .bluetooth
            }
        }
        
        return .usb
    }
    
    private func getDeviceId(_ device: IOHIDDevice) -> String {
        let vendorId = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productId = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let locationId = IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? Int ?? 0
        
        return "\(vendorId)-\(productId)-\(locationId)"
    }
    
    private func getDeviceName(_ device: IOHIDDevice) -> String? {
        return IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
    }
    
    private func readBatteryLevel(_ device: IOHIDDevice) -> Int? {
        return nil
    }


    // MARK: - Input Report Handling
    
    private static var inputReportCount: Int = 0
    
    private func handleInputReport(device: IOHIDDevice, report: UnsafePointer<UInt8>, length: CFIndex) {
        let deviceId = getDeviceId(device)
        guard let state = deviceStates[deviceId] else {
            ControllerManager.inputReportCount += 1
            if ControllerManager.inputReportCount % 500 == 1 {
                NSLog("[DEBUG] ControllerManager: ⚠️ No device state for ID: \(deviceId)")
            }
            return
        }
        
        ControllerManager.inputReportCount += 1
        if ControllerManager.inputReportCount % 100 == 1 {
            NSLog("[DEBUG] ControllerManager: 📦 Input report #\(ControllerManager.inputReportCount), length: \(length)")
        }
        
        let timestamp = mach_absolute_time()
        let reportData = UnsafeBufferPointer(start: report, count: Int(length))
        
        // Handle different report formats based on length
        // 10 bytes: Bluetooth simple mode (most common for BT connection)
        // 64 bytes: USB mode
        // 78 bytes: Bluetooth full mode
        
        if length >= 10 && length < 64 {
            // Bluetooth simple report format (10 bytes)
            parseSimpleBluetoothReport(reportData: reportData, state: state, timestamp: timestamp)
        } else if length >= 64 && length < 78 {
            // USB report format (64 bytes)
            parseUSBReport(reportData: reportData, state: state, timestamp: timestamp)
        } else if length >= 78 {
            // Bluetooth full report format (78 bytes)
            parseBluetoothFullReport(reportData: reportData, state: state, timestamp: timestamp)
        }
    }
    
    /// Parse simple Bluetooth report format (10 bytes)
    /// DualSense BT Simple Mode Layout:
    /// Byte 0: Report ID (0x01)
    /// Byte 1: Left stick X (0-255, center 128)
    /// Byte 2: Left stick Y (0-255, center 128)
    /// Byte 3: Right stick X (0-255, center 128)
    /// Byte 4: Right stick Y (0-255, center 128)
    /// Byte 5: D-pad (lower 4 bits: 0-7=directions, 8=neutral) + face buttons (upper 4 bits)
    /// Byte 6: L1(0x01) R1(0x02) L2btn(0x04) R2btn(0x08) Share(0x10) Options(0x20) L3(0x40) R3(0x80)
    /// Byte 7: PS(0x01) Touchpad(0x02) + Counter(bits 2-7)
    /// Byte 8: L2 trigger analog (0-255)
    /// Byte 9: R2 trigger analog (0-255)
    private func parseSimpleBluetoothReport(reportData: UnsafeBufferPointer<UInt8>, state: DeviceState, timestamp: UInt64) {
        guard reportData.count >= 10 else { return }
        
        // Debug: Print raw report data every 500 reports (reduced frequency)
        if ControllerManager.inputReportCount % 500 == 1 {
            let hexString = reportData.prefix(min(reportData.count, 10)).map { String(format: "%02X", $0) }.joined(separator: " ")
            NSLog("[DEBUG] ControllerManager: 📦 Raw BT Simple report (len=\(reportData.count)): \(hexString)")
        }
        
        // Sticks (bytes 1-4)
        let leftStickXRaw = Int16(reportData[1]) - 128
        let leftStickYRaw = Int16(reportData[2]) - 128
        let rightStickXRaw = Int16(reportData[3]) - 128
        let rightStickYRaw = Int16(reportData[4]) - 128
        
        emitAxisIfChanged(axis: .leftStickX, rawValue: leftStickXRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .leftStickY, rawValue: leftStickYRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .rightStickX, rawValue: rightStickXRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .rightStickY, rawValue: rightStickYRaw, state: state, timestamp: timestamp)
        
        // Triggers (bytes 8-9)
        let l2Raw = Int16(reportData[8])
        let r2Raw = Int16(reportData[9])
        emitAxisIfChanged(axis: .l2Trigger, rawValue: l2Raw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .r2Trigger, rawValue: r2Raw, state: state, timestamp: timestamp)
        
        // Buttons
        let buttons1 = reportData[5]  // D-pad + face buttons
        let buttons2 = reportData[6]  // Shoulder + L3/R3 + Share/Options
        let buttons3 = reportData[7] & 0x03  // Only lower 2 bits: PS + Touchpad (upper bits are counter)
        
        parseButtonsSimpleBT(buttons1: buttons1, buttons2: buttons2, buttons3: buttons3, state: state, timestamp: timestamp)
    }
    
    /// Parse buttons for simple Bluetooth mode (different bit layout than USB/full BT)
    private func parseButtonsSimpleBT(buttons1: UInt8, buttons2: UInt8, buttons3: UInt8, state: DeviceState, timestamp: UInt64) {
        // D-pad (lower 4 bits of buttons1)
        let dpadValue = buttons1 & 0x0F
        parseDPad(dpadValue: dpadValue, state: state, timestamp: timestamp)
        
        // Face buttons (upper 4 bits of buttons1)
        emitButtonIfChanged(button: .square, isPressed: (buttons1 & 0x10) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .cross, isPressed: (buttons1 & 0x20) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .circle, isPressed: (buttons1 & 0x40) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .triangle, isPressed: (buttons1 & 0x80) != 0, state: state, timestamp: timestamp)
        
        // Shoulder buttons and others (buttons2)
        emitButtonIfChanged(button: .l1, isPressed: (buttons2 & 0x01) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r1, isPressed: (buttons2 & 0x02) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .l2, isPressed: (buttons2 & 0x04) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r2, isPressed: (buttons2 & 0x08) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .share, isPressed: (buttons2 & 0x10) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .options, isPressed: (buttons2 & 0x20) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .l3, isPressed: (buttons2 & 0x40) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r3, isPressed: (buttons2 & 0x80) != 0, state: state, timestamp: timestamp)
        
        // PS and touchpad (buttons3 - already masked to lower 2 bits)
        emitButtonIfChanged(button: .ps, isPressed: (buttons3 & 0x01) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .touchpad, isPressed: (buttons3 & 0x02) != 0, state: state, timestamp: timestamp)
    }
    
    /// Parse USB report format (64 bytes)
    private func parseUSBReport(reportData: UnsafeBufferPointer<UInt8>, state: DeviceState, timestamp: UInt64) {
        guard reportData.count >= 11 else { return }
        
        let leftStickXRaw = Int16(reportData[DualSenseHID.USBReport.leftStickX]) - 128
        let leftStickYRaw = Int16(reportData[DualSenseHID.USBReport.leftStickY]) - 128
        let rightStickXRaw = Int16(reportData[DualSenseHID.USBReport.rightStickX]) - 128
        let rightStickYRaw = Int16(reportData[DualSenseHID.USBReport.rightStickY]) - 128
        
        emitAxisIfChanged(axis: .leftStickX, rawValue: leftStickXRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .leftStickY, rawValue: leftStickYRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .rightStickX, rawValue: rightStickXRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .rightStickY, rawValue: rightStickYRaw, state: state, timestamp: timestamp)
        
        let l2Raw = Int16(reportData[DualSenseHID.USBReport.l2Trigger])
        let r2Raw = Int16(reportData[DualSenseHID.USBReport.r2Trigger])
        emitAxisIfChanged(axis: .l2Trigger, rawValue: l2Raw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .r2Trigger, rawValue: r2Raw, state: state, timestamp: timestamp)
        
        let buttons1 = reportData[DualSenseHID.USBReport.buttons1]
        let buttons2 = reportData[DualSenseHID.USBReport.buttons2]
        let buttons3 = reportData[DualSenseHID.USBReport.buttons3]
        
        parseButtons(buttons1: buttons1, buttons2: buttons2, buttons3: buttons3, state: state, timestamp: timestamp)
    }
    
    /// Parse Bluetooth full report format (78 bytes)
    private func parseBluetoothFullReport(reportData: UnsafeBufferPointer<UInt8>, state: DeviceState, timestamp: UInt64) {
        guard reportData.count >= 12 else { return }
        
        let leftStickXRaw = Int16(reportData[DualSenseHID.BTReport.leftStickX]) - 128
        let leftStickYRaw = Int16(reportData[DualSenseHID.BTReport.leftStickY]) - 128
        let rightStickXRaw = Int16(reportData[DualSenseHID.BTReport.rightStickX]) - 128
        let rightStickYRaw = Int16(reportData[DualSenseHID.BTReport.rightStickY]) - 128
        
        emitAxisIfChanged(axis: .leftStickX, rawValue: leftStickXRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .leftStickY, rawValue: leftStickYRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .rightStickX, rawValue: rightStickXRaw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .rightStickY, rawValue: rightStickYRaw, state: state, timestamp: timestamp)
        
        let l2Raw = Int16(reportData[DualSenseHID.BTReport.l2Trigger])
        let r2Raw = Int16(reportData[DualSenseHID.BTReport.r2Trigger])
        emitAxisIfChanged(axis: .l2Trigger, rawValue: l2Raw, state: state, timestamp: timestamp)
        emitAxisIfChanged(axis: .r2Trigger, rawValue: r2Raw, state: state, timestamp: timestamp)
        
        let buttons1 = reportData[DualSenseHID.BTReport.buttons1]
        let buttons2 = reportData[DualSenseHID.BTReport.buttons2]
        let buttons3 = reportData[DualSenseHID.BTReport.buttons3]
        
        parseButtons(buttons1: buttons1, buttons2: buttons2, buttons3: buttons3, state: state, timestamp: timestamp)
    }
    
    /// Parse button bytes (common for all report formats)
    private func parseButtons(buttons1: UInt8, buttons2: UInt8, buttons3: UInt8, state: DeviceState, timestamp: UInt64) {
        // D-pad (lower 4 bits of buttons1)
        let dpadValue = buttons1 & ButtonMask.dpadMask
        parseDPad(dpadValue: dpadValue, state: state, timestamp: timestamp)
        
        // Face buttons (upper 4 bits of buttons1)
        emitButtonIfChanged(button: .square, isPressed: (buttons1 & ButtonMask.square) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .cross, isPressed: (buttons1 & ButtonMask.cross) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .circle, isPressed: (buttons1 & ButtonMask.circle) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .triangle, isPressed: (buttons1 & ButtonMask.triangle) != 0, state: state, timestamp: timestamp)
        
        // Shoulder buttons (buttons2)
        emitButtonIfChanged(button: .l1, isPressed: (buttons2 & ButtonMask.l1) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r1, isPressed: (buttons2 & ButtonMask.r1) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .l2, isPressed: (buttons2 & ButtonMask.l2) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r2, isPressed: (buttons2 & ButtonMask.r2) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .share, isPressed: (buttons2 & ButtonMask.share) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .options, isPressed: (buttons2 & ButtonMask.options) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .l3, isPressed: (buttons2 & ButtonMask.l3) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .r3, isPressed: (buttons2 & ButtonMask.r3) != 0, state: state, timestamp: timestamp)
        
        // PS and touchpad (buttons3)
        emitButtonIfChanged(button: .ps, isPressed: (buttons3 & ButtonMask.ps) != 0, state: state, timestamp: timestamp)
        emitButtonIfChanged(button: .touchpad, isPressed: (buttons3 & ButtonMask.touchpad) != 0, state: state, timestamp: timestamp)
    }
    
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


    // MARK: - Event Emission
    
    private func emitAxisIfChanged(axis: AxisType, rawValue: Int16, state: DeviceState, timestamp: UInt64) {
        let lastValue = state.lastAxisValues[axis] ?? (axis.isTrigger ? 0 : 128)
        
        // Only emit if value changed significantly (threshold of 2 to reduce noise)
        if abs(Int(rawValue) - Int(lastValue)) > 2 {
            state.lastAxisValues[axis] = rawValue
            
            let input = RawAxisInput(axis: axis, rawValue: rawValue, timestamp: timestamp)
            
            // Capture all handlers before async dispatch
            let legacyCallback = self.onAxisInput
            let handlers = self.axisInputHandlers
            
            inputQueue.async {
                // Call legacy callback if set
                legacyCallback?(input)
                
                // Call all registered handlers
                for (_, handler) in handlers {
                    handler(input)
                }
            }
        }
    }
    
    private func emitButtonIfChanged(button: ButtonType, isPressed: Bool, state: DeviceState, timestamp: UInt64) {
        let wasPressed = state.buttonStates[button] ?? false
        
        if isPressed != wasPressed {
            state.buttonStates[button] = isPressed
            NSLog("[DEBUG] ControllerManager: 🎮 Button \(button.rawValue) changed: \(isPressed ? "PRESSED" : "RELEASED")")
            
            if isPressed {
                state.buttonPressTimestamps[button] = timestamp
            } else {
                state.buttonPressTimestamps.removeValue(forKey: button)
            }
            
            let input = RawButtonInput(button: button, isPressed: isPressed, timestamp: timestamp)
            
            // Capture all handlers before async dispatch
            let legacyCallback = self.onButtonInput
            let handlers = self.buttonInputHandlers
            
            let totalHandlers = (legacyCallback != nil ? 1 : 0) + handlers.count
            NSLog("[DEBUG] ControllerManager: 📤 Dispatching to %d handler(s)", totalHandlers)
            
            // Dispatch to input queue for processing
            inputQueue.async {
                // Call legacy callback if set
                legacyCallback?(input)
                
                // Call all registered handlers
                for (handlerId, handler) in handlers {
                    NSLog("[DEBUG] ControllerManager: 🔄 Executing handler: %@", handlerId)
                    handler(input)
                }
            }
        }
    }
    
    // MARK: - Public Utilities
    
    public func isButtonPressed(_ button: ButtonType, controllerId: String? = nil) -> Bool {
        let targetId = controllerId ?? connectedControllers.first?.deviceId
        guard let id = targetId, let state = deviceStates[id] else { return false }
        return state.buttonStates[button] ?? false
    }
    
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
    
    public func getAxisValue(_ axis: AxisType, controllerId: String? = nil) -> Int16? {
        let targetId = controllerId ?? connectedControllers.first?.deviceId
        guard let id = targetId, let state = deviceStates[id] else { return nil }
        return state.lastAxisValues[axis]
    }
    
    public func refreshController(_ controllerId: String) {
        // Battery level is updated automatically from HID reports
    }
}
