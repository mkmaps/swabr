import SwabrCore
import SwiftUI

struct TreemapView: View {
    let entries: [DiskEntry]
    let checked: Set<String>
    let canCheck: Bool
    let toggle: (String) -> Void
    let open: (DiskEntry) -> Void

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: 8, dy: 8)
            let tiles = Treemap.layout(entries.map { Double($0.bytes) }, in: rect)
            ZStack(alignment: .topLeading) {
                ForEach(tiles, id: \.index) { tile in
                    let e = entries[tile.index]
                    TileView(entry: e, color: color(for: tile.index), checked: checked.contains(e.path))
                        .frame(width: max(tile.rect.width - 2, 0), height: max(tile.rect.height - 2, 0))
                        .offset(x: tile.rect.minX + 1, y: tile.rect.minY + 1)
                        .onTapGesture(count: 2) { open(e) }
                        .onTapGesture { if canCheck { toggle(e.path) } }
                        .help("\(e.name) · \(DiskSize.format(e.bytes))\n"
                              + (canCheck ? String(localized: "Klick: auswählen · Doppelklick: öffnen") : String(localized: "Doppelklick: öffnen")))
                }
            }
        }
        .overlay {
            if entries.isEmpty { ContentUnavailableView("Leer", systemImage: "square.dashed") }
        }
    }

    private func color(for index: Int) -> Color {
        Color(hue: Double((index * 47) % 360) / 360, saturation: 0.45, brightness: 0.85)
    }
}

private struct TileView: View {
    let entry: DiskEntry
    let color: Color
    let checked: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.gradient)
                    .strokeBorder(checked ? Color.accentColor : .clear, lineWidth: 3)
                if geo.size.width > 60 && geo.size.height > 34 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name).font(.caption.bold()).lineLimit(1)
                        Text(DiskSize.format(entry.bytes)).font(.caption2)
                    }
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(5)
                }
                if checked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .contentShape(.rect)
    }
}
