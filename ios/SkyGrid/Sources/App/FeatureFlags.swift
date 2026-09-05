import Foundation

/// Release guards for additive server-backed features. A flag stays off until its
/// corresponding server data has accumulated in production; this prevents a new
/// client from presenting every existing relationship as a zero-day streak.
enum FeatureFlags {
    static let buddyStreakVisible = false
}
