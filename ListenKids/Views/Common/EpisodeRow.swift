import SwiftUI

struct EpisodeRow: View {
    let episode: Episode
    @State private var dm = DownloadManager.shared

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            badge
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.displayTitle)
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    if let dur = episode.durationSeconds {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text("\(dur / 60) min")
                                .font(.rounded(12, weight: .medium))
                        }
                        .foregroundStyle(Color.appMuted)
                    }
                    Text(episode.publishedAt, format: .dateTime.month(.abbreviated).day())
                        .font(.rounded(12, weight: .medium))
                        .foregroundStyle(Color.appMuted)
                    if episode.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                    }
                    Spacer(minLength: 0)
                }
            }
            DownloadIndicator(episode: episode, dm: dm)
                .frame(width: 28, height: 28)
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.appCardShadow, radius: 8, x: 0, y: 3)
    }

    private var badge: some View {
        let tint = episode.level?.tint ?? Color.appMuted
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.18))
            VStack(spacing: 0) {
                if let n = episode.displayNumber {
                    Text(n)
                        .font(.rounded(20, weight: .bold))
                        .foregroundStyle(tint)
                }
                if let l = episode.level {
                    Text(l.rawValue)
                        .font(.rounded(10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(tint)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(width: 60, height: 60)
    }
}

private struct DownloadIndicator: View {
    let episode: Episode
    let dm: DownloadManager

    var body: some View {
        if episode.localAudioPath != nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
        } else if let p = dm.progress[episode.id] {
            CircularProgressView(progress: p)
        } else {
            Button {
                dm.startDownload(episode: episode)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor.opacity(0.85))
            }
            .buttonStyle(.borderless)
        }
    }
}
