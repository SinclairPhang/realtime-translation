import SwiftUI

@main
struct DuoTranslateApp: App {
    @StateObject private var sessionStore: SessionStore
    @StateObject private var viewModel: TranslationViewModel

    init() {
        let store = SessionStore()
        _sessionStore = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: TranslationViewModel(sessionStore: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
                .environmentObject(viewModel)
        }
    }
}

