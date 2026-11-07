import CoreGraphics

/// Local diagnostic metadata. The engine emits only static stages, action/error
/// identifiers, PIDs, AX status codes, and numerical geometry—not window content.
public struct WindowManagementDiagnostic: Sendable {
    public let stage: String
    public let fields: [String: String]

    static func frameFields(_ frame: CGRect, prefix: String) -> [String: String] {
        ["\(prefix)X": String(Double(frame.minX)), "\(prefix)Y": String(Double(frame.minY)),
         "\(prefix)Width": String(Double(frame.width)), "\(prefix)Height": String(Double(frame.height))]
    }
}
