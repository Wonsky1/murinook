import MurinookDomain
import SwiftUI

func localizedClipTitle(_ clip: Clip) -> Text {
    if clip.kind == .image && clip.title == "Image" { return Text("clip.title.image", bundle: .module) }
    if clip.title == "Content", clip.preview.isEmpty { return Text("clip.title.content", bundle: .module) }
    return Text(clip.title)
}
