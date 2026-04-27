import SwiftUI

struct TranscriptView: View {
    let text: String
    @AppStorage("transcriptFontSize") private var fontSize: Double = 18
    @State private var modeStore = AppModeStore.shared

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: CGFloat(fontSize)))
                .lineSpacing(8)
                .padding()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(modeStore.current == .bedtime ? .white.opacity(0.85) : .primary)
        }
        .background(modeStore.current == .bedtime
            ? Color(red: 0.05, green: 0.02, blue: 0.0)
            : Color(.systemBackground))
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    fontSize = max(12, fontSize - 2)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                Button {
                    fontSize = min(36, fontSize + 2)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
            }
        }
    }
}
