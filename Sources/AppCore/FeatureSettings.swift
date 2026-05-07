import Foundation

public protocol FeatureSettings: Codable, Equatable, Sendable {
    static var featureId: String { get }
    static var defaultValue: Self { get }
}
