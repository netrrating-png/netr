import SwiftUI
import LucideIcons

/// A SwiftUI view that renders a Lucide icon by its kebab-case identifier.
/// Usage: `LucideIcon("star")`, `LucideIcon("map-pin", size: 24)`
struct LucideIcon: View {
    let name: String
    var size: CGFloat

    init(_ name: String, size: CGFloat = 17) {
        self.name = name
        self.size = size
    }

    var body: some View {
        if let image = UIImage(lucideId: name) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
