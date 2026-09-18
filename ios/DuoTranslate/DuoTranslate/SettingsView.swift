import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: TranslationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var keyVisible = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if keyVisible {
                                TextField("sk-…", text: $viewModel.apiKey)
                            } else {
                                SecureField("sk-…", text: $viewModel.apiKey)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button { keyVisible.toggle() } label: {
                            Image(systemName: keyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("使用 iOS Keychain 永久保存在本机，不同步到 iCloud。")
                }

                Section {
                    Picker("模型", selection: $viewModel.realtimeModel) {
                        ForEach(RealtimeModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    Picker("语音音色", selection: $viewModel.realtimeVoice) {
                        ForEach(RealtimeVoice.allCases) { voice in
                            Text(voice.title).tag(voice)
                        }
                    }
                    Picker("翻译角色", selection: $viewModel.interpreterRole) {
                        ForEach(InterpreterRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    Button { viewModel.previewVoice() } label: {
                        Label(
                            viewModel.isPreviewingVoice
                                ? "\(viewModel.previewStatus) · 停止"
                                : "试听 \(viewModel.realtimeVoice.title)",
                            systemImage: viewModel.isPreviewingVoice ? "stop.circle.fill" : "play.circle.fill"
                        )
                    }
                    .disabled(viewModel.isSessionActive)
                    Text(viewModel.isSessionActive
                         ? "请先结束翻译会话，再试听音色。"
                         : "中法双语示例，不录音、不保存记录。试听会使用 API 额度。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    if let error = viewModel.previewError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Text(viewModel.interpreterRole.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                } header: {
                    Text("模型、音色与角色")
                } footer: {
                    Text("保存到本机，下次会话生效。Mini 更轻量；模型可用性取决于 API 账号权限。角色仅调整翻译风格，所有语音仍只作为待翻译内容。")
                }

                Section("语音边界检测") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("停顿时长")
                            Spacer()
                            Text("\(viewModel.silenceDuration, specifier: "%.1f") 秒")
                                .foregroundStyle(AppTheme.blue)
                        }
                        Slider(value: $viewModel.silenceDuration, in: 0.3...2.0, step: 0.1)
                        HStack {
                            Text("更快响应")
                            Spacer()
                            Text("更完整表达")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    }
                }

                Section {
                    Picker("语音输出", selection: $viewModel.useSpeaker) {
                        Text("扬声器").tag(true)
                        Text("听筒 / 已连接耳机").tag(false)
                    }
                } header: {
                    Text("声音播放")
                } footer: {
                    Text("默认使用扬声器。保存后立即生效；选择听筒时，如已连接耳机，将跟随系统音频路由。音量通过手机音量键调节。")
                }

                Section("翻译行为") {
                    Toggle("播放结束后自动恢复收音", isOn: $viewModel.autoResume)
                    Toggle("显示对话转录", isOn: $viewModel.showTranscript)
                }

                Section {
                    Button("清空当前转录", role: .destructive) { viewModel.clearCurrentTranscript() }
                }
            }
            .navigationTitle("设置")
            .onChange(of: viewModel.realtimeVoice) { _, _ in viewModel.stopVoicePreview() }
            .onChange(of: viewModel.realtimeModel) { _, _ in viewModel.stopVoicePreview() }
            .onChange(of: viewModel.useSpeaker) { _, _ in viewModel.stopVoicePreview() }
            .onDisappear { viewModel.stopVoicePreview() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await viewModel.saveSettings() } }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
