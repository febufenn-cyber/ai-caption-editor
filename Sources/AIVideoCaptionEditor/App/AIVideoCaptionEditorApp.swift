import SwiftUI

@main
struct AIVideoCaptionEditorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1200, minHeight: 760)
        }
        .windowResizability(.contentSize)
    }
}
