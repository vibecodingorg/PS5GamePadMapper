import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - StickType Generator

extension StickType: Arbitrary {
    public static var arbitrary: Gen<StickType> {
        Gen.fromElements(of: StickType.allCases)
    }
}

// MARK: - StickDirection Generator

extension StickDirection: Arbitrary {
    public static var arbitrary: Gen<StickDirection> {
        Gen.fromElements(of: StickDirection.allCases)
    }
}

// MARK: - DirectionInput Generator

extension DirectionInput: Arbitrary {
    public static var arbitrary: Gen<DirectionInput> {
        Gen.zip(
            StickType.arbitrary,
            StickDirection.arbitrary,
            // Generate threshold values including edge cases and out-of-range values
            Gen.fromElements(of: [-0.5, 0.0, 0.05, 0.1, 0.3, 0.5, 0.7, 0.9, 0.95, 1.0, 1.5])
        ).map { DirectionInput(stick: $0.0, direction: $0.1, threshold: $0.2) }
    }
}
