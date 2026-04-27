import SwiftUI

struct EpisodeRow: View {
    let episode: Episode
    @State private var dm = DownloadManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if episode.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(episode.title)
                        .font(.body)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let level = episode.level {
                        Text(level.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    if let dur = episode.durationSeconds {
                        Label("\(dur / 60) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(episode.publishedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DownloadIndicator(episode: episode, dm: dm)
                .frame(width: 28, height: 28)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct DownloadIndicator: View {
    let episode: Episode
    let dm: DownloadManager

    var body: some View {
        if episode.localAudioPath != nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 22))
        } else if let p = dm.progress[episode.id] {
            CircularProgressView(progress: p)
        } else {
            Button {
                dm.startDownload(episode: episode)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
        }
    }
}
