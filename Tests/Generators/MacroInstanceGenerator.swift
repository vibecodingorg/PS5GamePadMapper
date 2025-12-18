import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - Macro Instance Generators

/// Generator for creating random MacroInstance objects for testing
extension MacroInstance: Arbitrary {
    public static var arbitrary: Gen<MacroInstance> {
        return Macro.arbitrary.map { macro in
            MacroInstance(macro: macro)
        }
    }
}

/// Generator for pairs of macros for parallel execution testing
public struct MacroPair {
    public let macro1: Macro
    public let macro2: Macro
    
    public init(macro1: Macro, macro2: Macro) {
        self.macro1 = macro1
        self.macro2 = macro2
    }
}

extension MacroPair: Arbitrary {
    public static var arbitrary: Gen<MacroPair> {
        return Gen<MacroPair>.compose { c in
            let macro1 = c.generate(using: Macro.arbitrary)
            let macro2 = c.generate(using: Macro.arbitrary)
            return MacroPair(macro1: macro1, macro2: macro2)
        }
    }
}

/// Generator for a list of macros for parallel execution testing
public struct MacroList {
    public let macros: [Macro]
    
    public init(macros: [Macro]) {
        self.macros = macros
    }
}

extension MacroList: Arbitrary {
    public static var arbitrary: Gen<MacroList> {
        return Gen<Int>.fromElements(in: 2...5).flatMap { count in
            Gen<MacroList>.compose { c in
                var macros: [Macro] = []
                for _ in 0..<count {
                    macros.append(c.generate(using: Macro.arbitrary))
                }
                return MacroList(macros: macros)
            }
        }
    }
}

// MARK: - Simple Sequence Macro Generator

/// Generator for simple sequence macros (no loops) for deterministic testing
public struct SimpleSequenceMacro {
    public let macro: Macro
    
    public init(macro: Macro) {
        self.macro = macro
    }
}

extension SimpleSequenceMacro: Arbitrary {
    public static var arbitrary: Gen<SimpleSequenceMacro> {
        return Gen<Int>.fromElements(in: 1...5).flatMap { stepCount in
            let steps = (0..<stepCount).map { _ -> MacroStep in
                // Only use delay steps for simple testing
                .delay(milliseconds: 1)
            }
            let macro = Macro(name: "TestMacro", steps: steps, type: .sequence)
            return Gen.pure(SimpleSequenceMacro(macro: macro))
        }
    }
}

/// Generator for macros with key presses for interruption testing
public struct KeyPressMacro {
    public let macro: Macro
    public let keyCode: UInt16
    
    public init(macro: Macro, keyCode: UInt16) {
        self.macro = macro
        self.keyCode = keyCode
    }
}

extension KeyPressMacro: Arbitrary {
    public static var arbitrary: Gen<KeyPressMacro> {
        return Gen<UInt16>.fromElements(in: 0...50).map { keyCode in
            let steps: [MacroStep] = [
                .keyDown(keyCode: keyCode),
                .delay(milliseconds: 100),
                .keyUp(keyCode: keyCode)
            ]
            let macro = Macro(name: "KeyPressMacro", steps: steps, type: .sequence)
            return KeyPressMacro(macro: macro, keyCode: keyCode)
        }
    }
}
