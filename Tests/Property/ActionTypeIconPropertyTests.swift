import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Action Type Icon Selection
/// **Feature: stick-interaction-enhancement, Property 9: Action Type Icon Selection**
final class ActionTypeIconPropertyTests: XCTestCase {
    
    // MARK: - Property 9: Action Type Icon Selection
    
    /// **Feature: stick-interaction-enhancement, Property 9: Action Type Icon Selection**
    /// **Validates: Requirements 6.3**
    ///
    /// *For any* Mapping action type, the displayed icon should correctly correspond to the action category:
    /// keyboard icon for keyPress/keyRelease, mouse icon for mouseButton, list icon for macro, code icon for script.
    func testActionTypeIconSelection() {
        // Test keyPress actions have keyboard icon
        property("KeyPress actions have keyboard icon") <- forAll { (keyAction: KeyAction) in
            let action = Action.keyPress(keyAction)
            return action.typeIcon == "keyboard"
        }
        
        // Test keyRelease actions have keyboard icon
        property("KeyRelease actions have keyboard icon") <- forAll { (keyAction: KeyAction) in
            let action = Action.keyRelease(keyAction)
            return action.typeIcon == "keyboard"
        }
        
        // Test mouseButton actions have mouse icon
        property("MouseButton actions have mouse icon") <- forAll { (mouseButton: MouseButton) in
            let action = Action.mouseButton(MouseButtonAction(button: mouseButton))
            return action.typeIcon == "computermouse"
        }
        
        // Test mouseMove actions have arrow icon
        property("MouseMove actions have arrow icon") <- forAll { (sensitivity: Double, deadzone: Double) in
            let action = Action.mouseMove(MouseMoveAction(sensitivity: sensitivity, deadzone: deadzone, curve: .linear))
            return action.typeIcon == "arrow.up.left.and.arrow.down.right"
        }
        
        // Test mouseScroll actions have scroll icon
        property("MouseScroll actions have scroll icon") <- forAll { (scrollDirection: ScrollDirection) in
            let action = Action.mouseScroll(MouseScrollAction(direction: scrollDirection, amount: 1.0))
            return action.typeIcon == "scroll"
        }
        
        // Test macro actions have list icon
        property("Macro actions have list icon") <- forAll { (macro: Macro) in
            let action = Action.macro(macro)
            return action.typeIcon == "list.bullet.rectangle"
        }
        
        // Test script actions have code icon
        property("Script actions have code icon") <- forAll { (script: Script) in
            let action = Action.script(script)
            return action.typeIcon == "chevron.left.forwardslash.chevron.right"
        }
    }
    
    /// Additional property: All action types have non-empty icons
    func testAllActionsHaveNonEmptyIcons() {
        property("KeyPress actions have non-empty icon") <- forAll { (keyAction: KeyAction) in
            let action = Action.keyPress(keyAction)
            return !action.typeIcon.isEmpty
        }
        
        property("Macro actions have non-empty icon") <- forAll { (macro: Macro) in
            let action = Action.macro(macro)
            return !action.typeIcon.isEmpty
        }
    }
}


