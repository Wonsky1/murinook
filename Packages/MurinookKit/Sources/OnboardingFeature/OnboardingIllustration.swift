import MurinookDesignSystem
import SwiftUI

struct OnboardingIllustration: View {
    let step: Int

    private var symbol: String {
        switch step {
        case 0: "square.on.square"
        case 1: "clock.arrow.circlepath"
        case 2: "tray.full.fill"
        default: "keyboard"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17)
                .fill(LinearGradient(
                    colors: [Color(red: 0.94, green: 0.95, blue: 0.99), Color(red: 0.79, green: 0.83, blue: 0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 170, height: 170)
                .offset(x: 56, y: 74)
            diagram
                .padding(16)
                .rotationEffect(.degrees(step == 2 ? -2 : 0))
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MurinookPalette.accent)
                .frame(width: 38, height: 38)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.75), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 9, y: 4)
                .offset(x: -12, y: -12)
        }
    }

    @ViewBuilder
    private var diagram: some View {
        switch step {
        case 0, 1: ClipboardDiagram()
        case 2: ShelfDiagram()
        default: KeyboardDiagram()
        }
    }
}

private struct ClipboardDiagram: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Circle().fill(Color(red: 0.94, green: 0.39, blue: 0.35)).frame(width: 6, height: 6)
                Circle().fill(Color(red: 0.94, green: 0.72, blue: 0.22)).frame(width: 6, height: 6)
                Circle().fill(Color(red: 0.27, green: 0.72, blue: 0.39)).frame(width: 6, height: 6)
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(MurinookPalette.soft)
            }
            Divider().padding(.bottom, 1)
            diagramRow(symbol: "text.alignleft", title: "Murinook.diagram.note", preview: "Murinook.diagram.notePreview", tint: MurinookPalette.accent)
            diagramRow(symbol: "link", title: "Murinook.diagram.link", preview: "Murinook.diagram.linkPreview", tint: .indigo)
            diagramRow(symbol: "photo", title: "Murinook.diagram.image", preview: "Murinook.diagram.imagePreview", tint: MurinookPalette.warm)
        }
        .padding(13)
        .background(MurinookPalette.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.8), lineWidth: 1))
        .shadow(color: Color(red: 0.18, green: 0.22, blue: 0.38).opacity(0.13), radius: 15, y: 8)
    }

    private func diagramRow(symbol: String, title: String, preview: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(tint)
                .frame(width: 25, height: 25).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title), bundle: .module).font(.system(size: 11, weight: .semibold))
                Text(LocalizedStringKey(preview), bundle: .module).font(.system(size: 8)).foregroundStyle(MurinookPalette.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ShelfDiagram: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.35)).frame(width: 23)
                .overlay(alignment: .center) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(MurinookPalette.accent)
                }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Murinook.diagram.shelf", bundle: .module).font(.system(size: 11, weight: .bold))
                    Spacer(minLength: 0)
                    Image(systemName: "ellipsis").font(.system(size: 11, weight: .semibold)).foregroundStyle(MurinookPalette.muted)
                }
                shelfTile("doc.text.fill", "Murinook.diagram.file", .orange)
                shelfTile("photo.fill", "Murinook.diagram.image", .teal)
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(MurinookPalette.accent)
                    Text("Murinook.diagram.drop", bundle: .module).foregroundStyle(MurinookPalette.muted)
                }.font(.system(size: 8, weight: .medium)).padding(.top, 2)
            }
            .padding(11)
            .background(MurinookPalette.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.13), radius: 12, y: 7)
        }
    }

    private func shelfTile(_ symbol: String, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(LocalizedStringKey(title), bundle: .module).lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(7)
        .background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct KeyboardDiagram: View {
    private let keys = ["⌃", "⌥", "V"]

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                .font(.system(size: 23, weight: .light)).foregroundStyle(MurinookPalette.accent)
            HStack(spacing: 6) {
                ForEach(keys, id: \.self) { key in
                    Text(key).font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(MurinookPalette.text.opacity(0.72))
                        .frame(width: 38, height: 36)
                        .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(MurinookPalette.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                }
            }
            Text("Murinook.diagram.shortcut", bundle: .module)
                .font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MurinookPalette.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MurinookPalette.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 13, y: 7)
    }
}
