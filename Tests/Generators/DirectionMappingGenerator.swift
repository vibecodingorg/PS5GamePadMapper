import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - DirectionMapping Wrapper

/// Represents a complete direction mapping configuration
/// Requirements: 2.2 - Direction mappings with various action types
public struct DirectionMapping: Equatable {
    public let stick: StickType
    public let direction: StickDirection
    public let threshold: Double
    public let action: Action
    public let triggerMode: TriggerMode
    
    public init(
        stick: StickType,
        direction: StickDirection,
        threshold: Double = 0.5,
        action: Action,
        triggerMode: TriggerMode = .press
    ) {
        self.stick = stick
        self.direction = direction
        self.threshold = max(0.1, min(0.9, threshold))
        self.action = action
        self.triggerMode = triggerMode
    }
    
    /// Convert to a Mapping with DirectionInput as input source
    public func toMapping() -> Mapping {
        let directionInput = DirectionInput(
            stick: stick,
            direction: direction,
            threshold: threshold
        )
        return Mapping(
            input: .direction(directionInput),
            trigger: triggerMode,
            action: action
        )
    }
}

// MARK: - DirectionMapping Generator

extension DirectionMapping: Arbitrary {
    public static var arbitrary: Gen<DirectionMapping> {
        Gen.compose { c in
            DirectionMapping(
                stick: c.generate(),
                direction: c.generate(),
                threshold: c.generate(using: Gen.fromElements(of: [0.1, 0.3, 0.5, 0.7, 0.9])),
                action: c.generate(),
                triggerMode: c.generate()
            )
        }
    }
}

// MARK: - Specialized Direction Mapping Generators

/// Generator for WASD-style cardinal direction mappings (key press actions only)
public struct WASDDirectionMapping: Arbitrary {
    public let mapping: DirectionMapping
    
    public static var arbitrary: Gen<WASDDirectionMapping> {
        Gen.zip(
            StickType.arbitrary,
            Gen.fromElements(of: [StickDirection.up, .down, .left, .right]),
            Gen.fromElements(of: [0.3, 0.5, 0.7]),
            // WASD key codes: W=13, A=0, S=1, D=2
            Gen.fromElements(of: [UInt16(13), UInt16(0), UInt16(1), UInt16(2)])
        ).map { (stick, direction, threshold, keyCode) in
            let action = Action.keyPress(KeyAction(keyCode: keyCode, modifiers: []))
            let mapping = DirectionMapping(
                stick: stick,
                direction: direction,
                threshold: threshold,
                action: action,
                triggerMode: .press
            )
            return WASDDirectionMapping(mapping: mapping)
        }
    }
}

/// Generator for diagonal direction mappings with various action types
public struct DiagonalDirectionMapping: Arbitrary {
    public let mapping: DirectionMapping
    
    public static var arbitrary: Gen<DiagonalDirectionMapping> {
        Gen.compose { c in
            let stick: StickType = c.generate()
            let direction = c.generate(using: Gen.fromElements(of: [
                StickDirection.upLeft, .upRight, .downLeft, .downRight
            ]))
            let threshold = c.generate(using: Gen.fromElements(of: [0.3, 0.5, 0.7]))
            let action: Action = c.generate()
            let triggerMode: TriggerMode = c.generate()
            
            let mapping = DirectionMapping(
                stick: stick,
                direction: direction,
                threshold: threshold,
                action: action,
                triggerMode: triggerMode
            )
            return DiagonalDirectionMapping(mapping: mapping)
        }
    }
}

/// Generator for a complete set of 8 direction mappings for a single stick
public struct FullStickDirectionMappings: Arbitrary {
    public let stick: StickType
    public let mappings: [DirectionMapping]
    
    public static var arbitrary: Gen<FullStickDirectionMappings> {
        Gen.compose { c in
            let stick: StickType = c.generate()
            
            // Generate a mapping for each of the 8 directions
            let mappings = StickDirection.allCases.map { direction -> DirectionMapping in
                let action: Action = c.generate()
                let triggerMode: TriggerMode = c.generate()
                let threshold = c.generate(using: Gen.fromElements(of: [0.3, 0.5, 0.7]))
                
                return DirectionMapping(
                    stick: stick,
                    direction: direction,
                    threshold: threshold,
                    action: action,
                    triggerMode: triggerMode
                )
            }
            
            return FullStickDirectionMappings(stick: stick, mappings: mappings)
        }
    }
}

/// Generator for partial direction mappings (some directions mapped, others not)
public struct PartialDirectionMappings: Arbitrary {
    public let stick: StickType
    public let mappings: [DirectionMapping]
    public let unmappedDirections: [StickDirection]
    
    public static var arbitrary: Gen<PartialDirectionMappings> {
        Gen.compose { c in
            let stick: StickType = c.generate()
            
            // Randomly select which directions to map (1-7 directions)
            let mappedCount = c.generate(using: Gen.fromElements(in: 1...7))
            let allDirections = StickDirection.allCases.shuffled()
            let mappedDirections = Array(allDirections.prefix(mappedCount))
            let unmappedDirections = Array(allDirections.dropFirst(mappedCount))
            
            let mappings = mappedDirections.map { direction -> DirectionMapping in
                let action: Action = c.generate()
                let triggerMode: TriggerMode = c.generate()
                let threshold = c.generate(using: Gen.fromElements(of: [0.3, 0.5, 0.7]))
                
                return DirectionMapping(
                    stick: stick,
                    direction: direction,
                    threshold: threshold,
                    action: action,
                    triggerMode: triggerMode
                )
            }
            
            return PartialDirectionMappings(
                stick: stick,
                mappings: mappings,
                unmappedDirections: unmappedDirections
            )
        }
    }
}

/// Generator for direction mappings with macro actions
public struct MacroDirectionMapping: Arbitrary {
    public let mapping: DirectionMapping
    
    public static var arbitrary: Gen<MacroDirectionMapping> {
        Gen.compose { c in
            let stick: StickType = c.generate()
            let direction: StickDirection = c.generate()
            let threshold = c.generate(using: Gen.fromElements(of: [0.3, 0.5, 0.7]))
            let macro: Macro = c.generate()
            let action = Action.macro(macro)
            
            let mapping = DirectionMapping(
                stick: stick,
                direction: direction,
                threshold: threshold,
                action: action,
                triggerMode: .press
            )
            return MacroDirectionMapping(mapping: mapping)
        }
    }
}

/// Generator for direction mappings with script actions
public struct ScriptDirectionMapping: Arbitrary {
    public let mapping: DirectionMapping
    
    public static var arbitrary: Gen<ScriptDirectionMapping> {
        Gen.compose { c in
            let stick: StickType = c.generate()
            let direction: StickDirection = c.generate()
            let threshold = c.generate(using: Gen.fromElements(of: [0.3, 0.5, 0.7]))
            let script: Script = c.generate()
            let action = Action.script(script)
            
            let mapping = DirectionMapping(
                stick: stick,
                direction: direction,
                threshold: threshold,
                action: action,
                triggerMode: .press
            )
            return ScriptDirectionMapping(mapping: mapping)
        }
    }
}
