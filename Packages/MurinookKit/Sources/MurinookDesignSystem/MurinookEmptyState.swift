import AppKit
import SwiftUI

public struct MurinookSectionTitle: View {
    private let title: Text
    private let subtitle: Text?

    public init(_ title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.system(size: 22, weight: .semibold)).tracking(-0.77)
            if let subtitle { subtitle.font(.system(size: 11)).foregroundStyle(MurinookPalette.muted) }
        }
    }
}

public struct MurinookEmptyState: View {
    private let symbol: String
    private let title: Text
    private let message: Text
    private let actionTitle: Text?
    private let action: (() -> Void)?

    public init(symbol: String, title: Text, message: Text,
                actionTitle: Text? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label { title } icon: { Image(systemName: symbol) }
        } description: {
            message
        } actions: {
            if let actionTitle, let action {
                Button(action: action) { actionTitle }.buttonStyle(MurinookButtonStyle(variant: .primary))
            }
        }
        .foregroundStyle(MurinookPalette.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
