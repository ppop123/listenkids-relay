import SwiftUI

struct SleepTimerSheet: View {
    let engine: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    private let options: [TimeInterval] = [10 * 60, 20 * 60, 30 * 60, 45 * 60]

    var body: some View {
        NavigationStack {
            List {
                if let end = engine.sleepEndsAt {
                    Section {
                        HStack {
                            Image(systemName: "moon.fill").foregroundStyle(.tint)
                            Text("Active until \(end.formatted(.dateTime.hour().minute()))")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
                Section {
                    ForEach(options, id: \.self) { sec in
                        Button {
                            engine.startSleepTimer(seconds: sec)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "moon").foregroundStyle(.tint)
                                Text("\(Int(sec) / 60) min")
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                }
                if engine.sleepEndsAt != nil {
                    Section {
                        Button(role: .destructive) {
                            engine.cancelSleepTimer()
                            dismiss()
                        } label: {
                            Text("Cancel sleep timer")
                        }
                    }
                }
            }
            .navigationTitle("Sleep timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
