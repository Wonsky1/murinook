import SwiftUI

/// A small common motion vocabulary; system Reduce Motion wins everywhere.
public enum MurinookMotion {
    public static func settle(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.92)
    }
    public static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16)
    }
}
