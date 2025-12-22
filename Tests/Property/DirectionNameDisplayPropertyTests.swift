import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Direction Name Display
/// **Feature: stick-interaction-enhancement, Property 8: Direction Name Display Correctness**
final class DirectionNameDisplayPropertyTests: XCTestCase {
    
    // MARK: - Property 8: Direction Name Display Correctness
    
    /// **Feature: stick-interaction-enhancement, Property 8: Direction Name Display Correctness**
    /// **Validates: Requirements 6.2**
    ///
    /// *For any* StickDirection, the displayed name should match the expected localized string
    /// (e.g., .up → "↑ 上", .upRight → "↗ 右上").
    func testDirectionNameDisplayCorrectness() {
        // Define expected mappings for direction names
        let expectedShortLabels: [StickDirection: String] = [
            .up: "↑",
            .down: "↓",
            .left: "←",
            .right: "→",
            .upLeft: "↖",
            .upRight: "↗",
            .downLeft: "↙",
            .downRight: "↘"
        ]
        
        let expectedLocalizedNames: [StickDirection: String] = [
            .up: "上",
            .down: "下",
            .left: "左",
            .right: "右",
            .upLeft: "左上",
            .upRight: "右上",
            .downLeft: "左下",
            .downRight: "右下"
        ]
        
        property("Direction short label matches expected value") <- forAll { (direction: StickDirection) in
            let actualShortLabel = direction.shortLabel
            let expectedShortLabel = expectedShortLabels[direction]!
            return actualShortLabel == expectedShortLabel
        }
        
        property("Direction localized name matches expected value") <- forAll { (direction: StickDirection) in
            let actualLocalizedName = direction.localizedName
            let expectedLocalizedName = expectedLocalizedNames[direction]!
            return actualLocalizedName == expectedLocalizedName
        }
    }
    
    /// Additional property: All directions have non-empty display names
    func testAllDirectionsHaveNonEmptyDisplayNames() {
        property("All directions have non-empty short labels") <- forAll { (direction: StickDirection) in
            return !direction.shortLabel.isEmpty
        }
        
        property("All directions have non-empty localized names") <- forAll { (direction: StickDirection) in
            return !direction.localizedName.isEmpty
        }
    }
    
    /// Additional property: Short labels are single characters (arrow symbols)
    func testShortLabelsAreSingleCharacters() {
        property("Short labels are single characters") <- forAll { (direction: StickDirection) in
            return direction.shortLabel.count == 1
        }
    }
    
    /// Additional property: Cardinal directions have simple names, diagonals have compound names
    func testCardinalVsDiagonalNaming() {
        property("Cardinal directions have single-character localized names") <- forAll { (direction: StickDirection) in
            if direction.isCardinal {
                return direction.localizedName.count == 1
            }
            return true
        }
        
        property("Diagonal directions have two-character localized names") <- forAll { (direction: StickDirection) in
            if direction.isDiagonal {
                return direction.localizedName.count == 2
            }
            return true
        }
    }
}
