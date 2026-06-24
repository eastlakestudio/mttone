import SwiftUI

/// App 根视图：根据录音状态切换页面
struct ContentView: View {
    @Environment(DatabaseManager.self) private var databaseManager
    @State private var audioRecorder = AudioRecorder()
    @State private var recordingVM: RecordingViewModel?

    var body: some View {
        Group {
            if let vm = recordingVM {
                switch vm.meetingStatus {
                case .idle:
                    MeetingListView(recordingVM: vm)
                case .recording:
                    RecordingView(viewModel: vm)
                case .reviewing:
                    ReviewingView(viewModel: vm)
                }
            } else {
                ProgressView("正在初始化...")
            }
        }
        .onAppear {
            if recordingVM == nil {
                recordingVM = RecordingViewModel(
                    audioRecorder: audioRecorder,
                    databaseManager: databaseManager
                )
            }
        }
        .alert("错误", isPresented: .init(
            get: { 
                recordingVM?.errorAlert != nil || recordingVM?.audioPlayer.errorMessage != nil
            },
            set: { if !$0 { 
                recordingVM?.errorAlert = nil
                recordingVM?.audioPlayer.errorMessage = nil
            } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            if let msg = recordingVM?.errorAlert {
                Text(msg)
            } else if let playMsg = recordingVM?.audioPlayer.errorMessage {
                Text(playMsg)
            }
        }
    }
}
