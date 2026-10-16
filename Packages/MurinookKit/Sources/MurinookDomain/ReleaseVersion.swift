import Foundation

public struct ReleaseVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    private enum Identifier: Sendable, Equatable {
        case numeric(UInt64)
        case text(String)
    }

    private let major: UInt64
    private let minor: UInt64
    private let patch: UInt64
    private let prerelease: [Identifier]
    public let description: String
    public var isPrerelease: Bool { !prerelease.isEmpty }

    public init?(_ string: String) {
        let raw = string.hasPrefix("v") ? String(string.dropFirst()) : string
        guard !raw.isEmpty, raw.utf8.count <= 128 else { return nil }
        let pieces = raw.split(separator: "+", omittingEmptySubsequences: false)
        guard pieces.count <= 2, pieces.allSatisfy({ !$0.isEmpty }) else { return nil }
        let baseAndPre = pieces[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard baseAndPre.count <= 2 else { return nil }
        let numbers = baseAndPre[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              let major = Self.parseNumeric(numbers[0]),
              let minor = Self.parseNumeric(numbers[1]),
              let patch = Self.parseNumeric(numbers[2]) else { return nil }

        let prerelease: [Identifier]
        if baseAndPre.count == 2 {
            let identifiers = baseAndPre[1].split(separator: ".", omittingEmptySubsequences: false)
            guard !identifiers.isEmpty else { return nil }
            var parsed: [Identifier] = []
            for identifier in identifiers {
                guard !identifier.isEmpty, identifier.utf8.allSatisfy(Self.isIdentifierByte) else { return nil }
                if identifier.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) {
                    guard identifier.count == 1 || identifier.first != "0",
                          let value = UInt64(identifier) else { return nil }
                    parsed.append(.numeric(value))
                } else {
                    parsed.append(.text(String(identifier)))
                }
            }
            prerelease = parsed
        } else {
            prerelease = []
        }

        if pieces.count == 2 {
            let build = pieces[1].split(separator: ".", omittingEmptySubsequences: false)
            guard !build.isEmpty, build.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy(Self.isIdentifierByte) }) else { return nil }
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.description = raw
    }

    private static func parseNumeric(_ value: Substring) -> UInt64? {
        guard !value.isEmpty, value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              value.count == 1 || value.first != "0" else { return nil }
        return UInt64(value)
    }

    private static func isIdentifierByte(_ byte: UInt8) -> Bool {
        (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 45
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch && lhs.prerelease == rhs.prerelease
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) {
            if left == right { continue }
            switch (left, right) {
            case let (.numeric(a), .numeric(b)): return a < b
            case (.numeric, .text): return true
            case (.text, .numeric): return false
            case let (.text(a), .text(b)): return a < b
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}
