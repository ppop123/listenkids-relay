import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let series: SeriesGroup
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                LazyVStack(spacing: 0) {
                    ForEach(Array(series.episodes.enumerated()), id: \.element.id) { idx, ep in
                        NavigationLink {
                            PlayerView(episode: ep)
                        } label: {
                            ChapterRow(
                                episode: ep,
                                partNumber: ep.partNumber ?? (idx + 1)
                            )
                        }
                        .buttonStyle(.plain)
                        if idx < series.episodes.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 14) {
            cover
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            VStack(spacing: 6) {
                Text(series.title)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if let author = series.author {
                    Text(author)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if let level = series.level {
                        Text(level.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(level.tint)
                            .clipShape(Capsule())
                    }
                    Text(series.partsLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
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
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        let tint = series.level?.tint ?? Color.accentColor
        return ZStack {
            LinearGradient(
                colors: [tint, tint.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Text(initials)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let level = series.level {
                    Text(level.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var initials: String {
        series.title.split(separator: " ").prefix(3).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

private struct ChapterRow: View {
    let episode: Episode
    let partNumber: Int
    @State private var dm = DownloadManager.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(partNumber)")
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let dur = episode.durationSeconds {
                    Text("\(dur / 60) min")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            DownloadIndicatorMini(episode: episode, dm: dm)
                .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct DownloadIndicatorMini: View {
    let episode: Episode
    let dm: DownloadManager

    var body: some View {
        if episode.localAudioPath != nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        } else if let p = dm.progress[episode.id] {
            CircularProgressView(progress: p, size: 18, lineWidth: 2)
        } else {
            Button {
                dm.startDownload(episode: episode)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor.opacity(0.85))
            }
            .buttonStyle(.borderless)
        }
    }
}
