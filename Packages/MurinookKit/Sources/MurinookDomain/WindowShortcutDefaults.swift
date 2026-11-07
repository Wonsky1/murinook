import Foundation

public extension KeyCombination {
    /// Rectangle's recommended Control-Option bindings for the first-release window actions.
    static let windowDefaults: [ShortcutAction: KeyCombination] = [
        .windowLeftHalf: .init(keyCode: 123, modifiers: [.control, .option]),
        .windowRightHalf: .init(keyCode: 124, modifiers: [.control, .option]),
        .windowTopHalf: .init(keyCode: 126, modifiers: [.control, .option]),
        .windowBottomHalf: .init(keyCode: 125, modifiers: [.control, .option]),
        .windowTopLeft: .init(keyCode: 32, modifiers: [.control, .option]),
        .windowTopRight: .init(keyCode: 34, modifiers: [.control, .option]),
        .windowBottomLeft: .init(keyCode: 38, modifiers: [.control, .option]),
        .windowBottomRight: .init(keyCode: 40, modifiers: [.control, .option]),
        .windowFirstThird: .init(keyCode: 2, modifiers: [.control, .option]),
        .windowCenterThird: .init(keyCode: 3, modifiers: [.control, .option]),
        .windowLastThird: .init(keyCode: 5, modifiers: [.control, .option]),
        .windowMaximize: .init(keyCode: 36, modifiers: [.control, .option]),
        .windowCenter: .init(keyCode: 8, modifiers: [.control, .option]),
        .windowRestore: .init(keyCode: 51, modifiers: [.control, .option]),
        .windowNextDisplay: .init(keyCode: 124, modifiers: [.control, .option, .command]),
        .windowPreviousDisplay: .init(keyCode: 123, modifiers: [.control, .option, .command])
    ]
}
