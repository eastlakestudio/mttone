import SwiftUI

struct SpeakerDetailView: View {
    @Environment(DatabaseManager.self) private var databaseManager
    let contact: Contact
    
    @State private var clips: [SpeechClip] = []
    
    var body: some View {
        List {
            if clips.isEmpty {
                Text("暂无发言记录")
                    .foregroundColor(.secondary)
            } else {
                ForEach(clips) { clip in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(clip.cleanedText ?? clip.originalText)
                            .font(.body)
                        
                        HStack {
                            Text("时长: \(String(format: "%.1f", clip.endTime - clip.startTime))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            // 预留的音频播放按钮
                            Button(action: {
                                // TODO: 跨会议回放逻辑
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(contact.name)
        .onAppear {
            clips = databaseManager.fetchSpeechClips(forContact: contact.id)
        }
    }
}
