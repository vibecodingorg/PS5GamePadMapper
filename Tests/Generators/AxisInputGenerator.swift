import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// Note: AxisType and ResponseCurve Arbitrary conformance is in ProfileGenerator.swift

// MARK: - AxisConfig Generator (valid configurations only)

extension AxisConfig: Arbitrary {
    public static var arbitrary: Gen<AxisConfig> {
        Gen.compose { c in
            // Generate valid deadzone (0.0 to 0.5)
            let deadzone = c.generate(using: Gen.fromElements(of: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]))
            // Generate valid sensitivity (0.1 to 10.0)
            let sensitivity = c.generate(using: Gen.fromElements(of: [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]))
            let curve: ResponseCurve = c.generate()
            
            return AxisConfig(deadzone: deadzone, sensitivity: sensitivity, curve: curve)
        }
    }
}

// MARK: - RawAxisInput Generator

extension RawAxisInput: Arbitrary {
    public static var arbitrary: Gen<RawAxisInput> {
        Gen.compose { c in
            let axis: AxisType = c.generate()
            let rawValue: Int16
            
            if axis.isTrigger {
                // Triggers use 0-255 range
                rawValue = Int16(c.generate(using: Gen.fromElements(in: 0...255)))
            } else {
                // Sticks use full Int16 range
                rawValue = c.generate(using: Gen.fromElements(in: Int16.min...Int16.max))
            }
            
            return RawAxisInput(
                axis: axis,
                rawValue: rawValue,
                timestamp: UInt64(c.generate(using: Gen.fromElements(in: 0...UInt32.max)))
            )
        }
    }
}

// MARK: - Specialized Generators

/// Generator for stick axis inputs only
struct StickAxisInput: Arbitrary {
    let input: RawAxisInput
    
    static var arbitrary: Gen<StickAxisInput> {
        Gen.compose { c in
            let axis = c.generate(using: Gen.fromElements(of: [
                AxisType.leftStickX, .leftStickY, .rightStickX, .rightStickY
            ]))
            let rawValue: Int16 = c.generate(using: Gen.fromElements(in: Int16.min...Int16.max))
            
            return StickAxisInput(input: RawAxisInput(
                axis: axis,
                rawValue: rawValue,
                timestamp: 0
            ))
        }
    }
}

/// Generator for trigger axis inputs only
struct TriggerAxisInput: Arbitrary {
    let input: RawAxisInput
    
    static var arbitrary: Gen<TriggerAxisInput> {
        Gen.compose { c in
            let axis = c.generate(using: Gen.fromElements(of: [
                AxisType.l2Trigger, .r2Trigger
            ]))
            let rawValue = Int16(c.generate(using: Gen.fromElements(in: 0...255)))
            
            return TriggerAxisInput(input: RawAxisInput(
                axis: axis,
                rawValue: rawValue,
                timestamp: 0
            ))
        }
    }
}
