import SwiftUI

struct RootView: View {
    @EnvironmentObject private var viewModel: TranslationViewModel
    @State private var selection: AppTab = .translation

    var body: some View {
        TabView(selection: $selection) {
            TranslationView()
                .tag(AppTab.translation)
                .tabItem { Label("翻译", systemImage: "waveform.and.mic") }

            RecordsView()
                .tag(AppTab.records)
                .tabItem { Label("记录", systemImage: "doc.text") }
        }
        .tint(AppTheme.navy)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}

