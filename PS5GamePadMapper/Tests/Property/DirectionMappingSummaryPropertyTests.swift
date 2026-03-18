import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Direction Mapping Summary Correctness
/// **Feature: stick-interaction-enhancement, Property 1: Direction Mapping Summary Correctness**
final class DirectionMappingSummaryPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Direction Mapping Summary Correctness
    
    /// **Feature: stick-interaction-enhancement, Property 1: Direction Mapping Summary Correctness**
    /// **Validates: Requirements 2.1, 2.4**
    ///
    /// *For any* set of direction mappings for a stick, the summary displayed in the detail panel
    /// should correctly show the count of configured directions and include all configured direction names.
    func testDirectionMappingSummaryCorrectness() {
        // Test with full direction mappings (all 8 directions)
        property("Full direction mappings show correct count 8/8") <- forAll { (fullMappings: FullStickDirectionMappings) in
            let mappingDict = self.convertToMappingDict(fullMappings.mappings)
            let summary = DirectionMappingSummary.summary(from: mappingDict)
            return summary == "8/8 方向"
        }
        
        // Test with partial direction mappings
        property("Partial direction mappings show correct count") <- forAll { (partialMappings: PartialDirectionMappings) in
            let mappingDict = self.convertToMappingDict(partialMappings.mappings)
            let expectedCount = partialMappings.mappings.count
            let summary = DirectionMappingSummary.summary(from: mappingDict)
            return summary == "\(expectedCount)/8 方向"
        }
        
        // Test with empty mappings
        property("Empty mappings show '未配置'") <- forAll { (_: StickType) in
            let emptyDict: [StickDirection: Mapping] = [:]
            let summary = DirectionMappingSummary.summary(from: emptyDict)
            return summary == "未配置"
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 1: Direction Mapping Summary Correctness**
    /// **Validates: Requirements 2.1, 2.4**
    ///
    /// Test that configured direction names are correctly listed
    func testConfiguredDirectionNamesCorrectness() {
        property("Configured direction names match actual mapped directions") <- forAll { (partialMappings: PartialDirectionMappings) in
            let mappingDict = self.convertToMappingDict(partialMappings.mappings)
            let configuredNames = DirectionMappingSummary.configuredDirectionNames(from: mappingDict)
            
            // Get expected direction names from the mappings
            let expectedDirections = Set(partialMappings.mappings.map { $0.direction })
            let expectedNames = Set(expectedDirections.map { $0.localizedName })
            let actualNames = Set(configuredNames)
            
            return actualNames == expectedNames
        }
        
        property("Full mappings include all 8 direction names") <- forAll { (fullMappings: FullStickDirectionMappings) in
            let mappingDict = self.convertToMappingDict(fullMappings.mappings)
            let configuredNames = DirectionMappingSummary.configuredDirectionNames(from: mappingDict)
            
            // All 8 directions should be present
            let allDirectionNames = Set(StickDirection.allCases.map { $0.localizedName })
            let actualNames = Set(configuredNames)
            
            return actualNames == allDirectionNames
        }
    }
    
    /// Test that count matches dictionary size
    func testCountMatchesDictionarySize() {
        property("Summary count matches dictionary size") <- forAll { (partialMappings: PartialDirectionMappings) in
            let mappingDict = self.convertToMappingDict(partialMappings.mappings)
            let count = mappingDict.count
            
            if count == 0 {
                let summary = DirectionMappingSummary.summary(from: mappingDict)
                return summary == "未配置"
            } else {
                let summary = DirectionMappingSummary.summary(from: mappingDict)
                return summary == "\(count)/8 方向"
            }
        }
    }
    
    /// Test that direction names are sorted by angle
    func testDirectionNamesSortedByAngle() {
        property("Direction names are sorted by center angle") <- forAll { (fullMappings: FullStickDirectionMappings) in
            let mappingDict = self.convertToMappingDict(fullMappings.mappings)
            let configuredNames = DirectionMappingSummary.configuredDirectionNames(from: mappingDict)
            
            // Get directions sorted by angle
            let sortedDirections = mappingDict.keys.sorted { $0.centerAngle < $1.centerAngle }
            let expectedNames = sortedDirections.map { $0.localizedName }
            
            return configuredNames == expectedNames
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert array of DirectionMapping to dictionary format used by DirectionMappingSummary
    private func convertToMappingDict(_ mappings: [DirectionMapping]) -> [StickDirection: Mapping] {
        var dict: [StickDirection: Mapping] = [:]
        for dirMapping in mappings {
            dict[dirMapping.direction] = dirMapping.toMapping()
        }
        return dict
    }
}
