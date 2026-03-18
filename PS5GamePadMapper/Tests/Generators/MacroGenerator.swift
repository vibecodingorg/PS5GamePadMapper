import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - MouseButton Generator

extension MouseButton: Arbitrary {
    public static var arbitrary: Gen<MouseButton> {
        Gen.fromElements(of: [.left, .right, .middle])
    }
}

// MARK: - MacroStep Generator

extension MacroStep: Arbitrary {
    public static var arbitrary: Gen<MacroStep> {
        Gen.one(of: [
            // keyDown with valid key codes
            Gen.fromElements(in: 0...50).map { MacroStep.keyDown(keyCode: UInt16($0)) },
            // keyUp with valid key codes
            Gen.fromElements(in: 0...50).map { MacroStep.keyUp(keyCode: UInt16($0)) },
            // mouseClick
            MouseButton.arbitrary.map { MacroStep.mouseClick(button: $0) },
            // mouseMove with reasonable delta values
            Gen.zip(Gen.fromElements(in: -100...100), Gen.fromElements(in: -100...100))
                .map { MacroStep.mouseMove(dx: $0.0, dy: $0.1) },
            // delay with valid range
            Gen.fromElements(of: [10, 50, 100, 500, 1000]).map { MacroStep.delay(milliseconds: $0) }
        ])
    }
}

// MARK: - MacroType Generator

extension MacroType: Arbitrary {
    public static var arbitrary: Gen<MacroType> {
        Gen.fromElements(of: [
            MacroType.sequence,
            MacroType.toggle,
            MacroType.loop(interval: 50, maxCount: 10),
            MacroType.loop(interval: 100, maxCount: 0),
            MacroType.loop(interval: 500, maxCount: 5),
            MacroType.whileCondition(condition: "isButtonPressed(\"cross\")"),
            MacroType.whileCondition(condition: "isButtonPressed(\"circle\")"),
            MacroType.whileCondition(condition: "true"),
            MacroType.whileCondition(condition: "false")
        ])
    }
    
    /// Generator for whileCondition macros only
    public static var arbitraryWhileCondition: Gen<MacroType> {
        Gen.fromElements(of: [
            MacroType.whileCondition(condition: "isButtonPressed(\"cross\")"),
            MacroType.whileCondition(condition: "isButtonPressed(\"circle\")"),
            MacroType.whileCondition(condition: "isButtonPressed(\"square\")"),
            MacroType.whileCondition(condition: "isButtonPressed(\"triangle\")")
        ])
    }
}

// MARK: - Macro Generator (simplified for fast execution)

extension Macro: Arbitrary {
    public static var arbitrary: Gen<Macro> {
        Gen.compose { c in
            let stepCount: Int = c.generate(using: Gen.fromElements(in: 0...5))
            var steps: [MacroStep] = []
            for _ in 0..<stepCount {
                steps.append(c.generate())
            }
            
            return Macro(
                id: UUID(),
                name: c.generate(using: Gen.fromElements(of: ["Macro1", "Test", "Combo", "Turbo"])),
                steps: steps,
                type: c.generate()
            )
        }
    }
}
