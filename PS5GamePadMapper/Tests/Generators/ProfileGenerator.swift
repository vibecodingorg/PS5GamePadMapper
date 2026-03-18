import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - ButtonType Generator

extension ButtonType: Arbitrary {
    public static var arbitrary: Gen<ButtonType> {
        Gen.fromElements(of: ButtonType.allCases)
    }
}

// MARK: - AxisType Generator

extension AxisType: Arbitrary {
    public static var arbitrary: Gen<AxisType> {
        Gen.fromElements(of: AxisType.allCases)
    }
}

// MARK: - KeyModifiers Generator

extension KeyModifiers: Arbitrary {
    public static var arbitrary: Gen<KeyModifiers> {
        Gen.fromElements(in: 0...15).map { KeyModifiers(rawValue: UInt32($0)) }
    }
}

// MARK: - ResponseCurve Generator

extension ResponseCurve: Arbitrary {
    public static var arbitrary: Gen<ResponseCurve> {
        Gen.one(of: [
            Gen.pure(.linear),
            Gen.fromElements(of: [1.5, 2.0, 2.5]).map { ResponseCurve.exponential(power: $0) }
        ])
    }
}

// MARK: - ScrollDirection Generator

extension ScrollDirection: Arbitrary {
    public static var arbitrary: Gen<ScrollDirection> {
        Gen.fromElements(of: [.up, .down, .left, .right])
    }
}

// MARK: - KeyAction Generator

extension KeyAction: Arbitrary {
    public static var arbitrary: Gen<KeyAction> {
        Gen.zip(
            Gen.fromElements(in: 0...50).map { UInt16($0) },
            KeyModifiers.arbitrary
        ).map { KeyAction(keyCode: $0.0, modifiers: $0.1) }
    }
}

// MARK: - MouseButtonAction Generator

extension MouseButtonAction: Arbitrary {
    public static var arbitrary: Gen<MouseButtonAction> {
        MouseButton.arbitrary.map { MouseButtonAction(button: $0) }
    }
}

// MARK: - MouseMoveAction Generator

extension MouseMoveAction: Arbitrary {
    public static var arbitrary: Gen<MouseMoveAction> {
        Gen.zip(
            Gen.fromElements(of: [0.5, 1.0, 2.0, 5.0]),
            Gen.fromElements(of: [0.0, 0.1, 0.2, 0.3]),
            ResponseCurve.arbitrary
        ).map { MouseMoveAction(sensitivity: $0.0, deadzone: $0.1, curve: $0.2) }
    }
}

// MARK: - MouseScrollAction Generator

extension MouseScrollAction: Arbitrary {
    public static var arbitrary: Gen<MouseScrollAction> {
        Gen.zip(
            ScrollDirection.arbitrary,
            Gen.fromElements(of: [0.5, 1.0, 2.0])
        ).map { MouseScrollAction(direction: $0.0, amount: $0.1) }
    }
}

// MARK: - TriggerMode Generator

extension TriggerMode: Arbitrary {
    public static var arbitrary: Gen<TriggerMode> {
        Gen.fromElements(of: [
            TriggerMode.press,
            TriggerMode.release,
            TriggerMode.toggle,
            TriggerMode.hold(threshold: 0.5),
            TriggerMode.hold(threshold: 1.0)
        ])
    }
}

// MARK: - InputSource Generator

extension InputSource: Arbitrary {
    public static var arbitrary: Gen<InputSource> {
        Gen.one(of: [
            ButtonType.arbitrary.map { InputSource.button($0) },
            AxisType.arbitrary.map { InputSource.axis($0) },
            DirectionInput.arbitrary.map { InputSource.direction($0) },
            StickType.arbitrary.map { InputSource.stick($0) }
        ])
    }
}

// MARK: - Script Generator

extension Script: Arbitrary {
    public static var arbitrary: Gen<Script> {
        Gen.zip(
            Gen.fromElements(of: ["Script1", "Test", "Auto", "Custom"]),
            Gen.fromElements(of: ["pressKey('a')", "sleep(100)", "mouseClick('left')"])
        ).map { Script(id: UUID(), name: $0.0, source: $0.1) }
    }
}

// MARK: - Action Generator (simplified - no nested Macro/Script)

extension Action: Arbitrary {
    public static var arbitrary: Gen<Action> {
        Gen.one(of: [
            KeyAction.arbitrary.map { Action.keyPress($0) },
            MouseButtonAction.arbitrary.map { Action.mouseButton($0) },
            MouseMoveAction.arbitrary.map { Action.mouseMove($0) },
            MouseScrollAction.arbitrary.map { Action.mouseScroll($0) }
        ])
    }
}

// MARK: - Mapping Generator

extension Mapping: Arbitrary {
    public static var arbitrary: Gen<Mapping> {
        Gen.zip(
            InputSource.arbitrary,
            TriggerMode.arbitrary,
            Action.arbitrary
        ).map { Mapping(input: $0.0, trigger: $0.1, action: $0.2) }
    }
}

// MARK: - ApplicationBinding Generator

extension ApplicationBinding: Arbitrary {
    public static var arbitrary: Gen<ApplicationBinding> {
        Gen.fromElements(of: ["com.app.test", "com.game.fps", "com.tool.dev"])
            .map { ApplicationBinding(bundleIdentifier: $0, profileId: UUID()) }
    }
}

// MARK: - StickMappingMode Generator

extension StickMappingMode: Arbitrary {
    public static var arbitrary: Gen<StickMappingMode> {
        Gen.fromElements(of: [.direction, .mouse])
    }
}

// MARK: - Profile Generator (simplified for fast execution)

extension Profile: Arbitrary {
    public static var arbitrary: Gen<Profile> {
        Gen.compose { c in
            // Generate small fixed-size arrays for speed
            let mappingCount: Int = c.generate(using: Gen.fromElements(in: 0...3))
            let macroCount: Int = c.generate(using: Gen.fromElements(in: 0...2))
            let scriptCount: Int = c.generate(using: Gen.fromElements(in: 0...2))
            
            var mappings: [Mapping] = []
            for _ in 0..<mappingCount {
                mappings.append(c.generate())
            }
            
            var macros: [Macro] = []
            for _ in 0..<macroCount {
                macros.append(c.generate())
            }
            
            var scripts: [Script] = []
            for _ in 0..<scriptCount {
                scripts.append(c.generate())
            }
            
            let hasBindings: Bool = c.generate()
            var bindings: [ApplicationBinding]? = nil
            if hasBindings {
                bindings = [c.generate()]
            }
            
            // Generate optional stickModes
            let hasStickModes: Bool = c.generate()
            var stickModes: [StickType: StickMappingMode]? = nil
            if hasStickModes {
                stickModes = [:]
                for stick in StickType.allCases {
                    let hasMode: Bool = c.generate()
                    if hasMode {
                        stickModes?[stick] = c.generate()
                    }
                }
            }
            
            return Profile(
                id: UUID(),
                name: c.generate(using: Gen.fromElements(of: ["Profile1", "Test", "Game", "Default"])),
                mappings: mappings,
                macros: macros,
                scripts: scripts,
                applicationBindings: bindings,
                stickModes: stickModes
            )
        }
    }
}
