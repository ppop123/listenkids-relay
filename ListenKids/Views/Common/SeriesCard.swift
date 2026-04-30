import SwiftUI

struct SeriesCard: View {
    let series: SeriesGroup
    var size: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(series.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let level = series.level {
                        Text(level.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(level.tint)
                            .clipShape(Capsule())
                    }
                    Text(series.partsLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, alignment: .leading)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let url = series.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        let tint = series.level?.tint ?? Color.accentColor
        return ZStack {
            LinearGradient(
                colors: [tint, tint.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 4) {
                Text(initials)
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let level = series.level {
                    Text(level.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var initials: String {
        let words = series.title
            .split(separator: " ")
            .prefix(3)
            .compactMap { $0.first }
            .map { String($0) }
        return words.joined().uppercased()
    }
}
