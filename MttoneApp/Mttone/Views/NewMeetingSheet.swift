import SwiftUI

/// 新建会议配置弹窗
struct NewMeetingSheet: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("会议信息") {
                    TextField("会议主题", text: $viewModel.formTitle)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    TextField("会议地点", text: $viewModel.formLocation)

                    TextField("参会人（可选）", text: $viewModel.formAttendees)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section("高级选项") {
                    Toggle("延续上一次会议", isOn: $viewModel.shouldExtendLastMeeting)
                }

                Section {
                    Text("录音将使用设备麦克风采集音频，并通过 Apple 语音识别引擎进行实时转写。所有数据均在本地处理，不上传云端。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建会议录制")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始录音") {
                        Task {
                            await viewModel.startRecording()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
