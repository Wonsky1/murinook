import SwiftUI

/// Localizes generated image names while preserving the user's text and file names.
public struct MurinookContentTitle: View {
    private let title: String
    private let kindIdentifier: String
    public init(_ title: String, kindIdentifier: String) {
        self.title = title; self.kindIdentifier = kindIdentifier
    }
    public var body: some View {
        if title == "Image", kindIdentifier == "image" {
            Text("contentTitle.image", bundle: .module)
        } else {
            Text(title)
        }
    }
}
