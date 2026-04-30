import SwiftUI

struct KaraokeView: View {
    let segments: [TranscriptSegment]
    let currentTime: Double
    var onSeek: ((Double) -> Void)? = nil
    var isBedtime: Bool = false

    private var sortedSegments: [TranscriptSegment] {
        segments.sorted { $0.start < $1.start }
    }

    private var activeIndex: Int? {
        let segs = sortedSegments
        guard !segs.isEmpty else { return nil }
        return segs.lastIndex(where: { $0.start <= currentTime })
    }

    var body: some View {
        let segs = sortedSegments
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Spacer().frame(height: 60).id("top-pad")
                    ForEach(Array(segs.enumerated()), id: \.offset) { idx, seg in
                        Button {
                            onSeek?(seg.start)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(idx == activeIndex ? Color.accentColor : Color.clear)
                                    .frame(width: 4)
                                    .padding(.top, 4)
                                Text(seg.trimmedText)
                                    .font(.rounded(fontSize(idx: idx), weight: weight(idx: idx)))
                                    .foregroundStyle(color(idx: idx))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.trailing, 16)
                                    .animation(.easeInOut(duration: 0.25), value: activeIndex)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .id(idx)
                    }
                    Spacer().frame(height: 200).id("bottom-pad")
                }
            }
            .onChange(of: activeIndex) { _, newIdx in
                guard let newIdx else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    proxy.scrollTo(newIdx, anchor: .center)
                }
            }
            .onAppear {
                if let idx = activeIndex {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    private func fontSize(idx: Int) -> CGFloat {
        guard let active = activeIndex else { return 16 }
        let dist = abs(idx - active)
        switch dist {
        case 0:  return 22
        case 1:  return 18
        case 2:  return 16
        default: return 15
        }
    }

    private func weight(idx: Int) -> Font.Weight {
        idx == activeIndex ? .semibold : .regular
    }

    private func color(idx: Int) -> Color {
        let base: Color = isBedtime ? .white : .appInk
        guard let active = activeIndex else { return base.opacity(0.45) }
        let dist = abs(idx - active)
        switch dist {
        case 0:  return base
        case 1:  return base.opacity(0.65)
        case 2:  return base.opacity(0.4)
        default: return base.opacity(0.25)
        }
    }
}
