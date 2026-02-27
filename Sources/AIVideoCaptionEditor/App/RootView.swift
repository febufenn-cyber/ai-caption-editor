import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject private var viewModel = EditorViewModel()
    @State private var isImportPresented = false

    var body: some View {
        VStack(spacing: 10) {
            EditorToolbar(viewModel: viewModel) {
                isImportPresented = true
            }

            HSplitView {
                PlayerPane(viewModel: viewModel)
                    .frame(minWidth: 560, minHeight: 360)

                CaptionEditorPanel(viewModel: viewModel)
                    .frame(minWidth: 360)
                    .padding(.leading, 8)
            }
            .frame(minHeight: 360)

            TimelinePane(viewModel: viewModel)
                .frame(minHeight: 220)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.1),
                    Color(red: 0.07, green: 0.1, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .fileImporter(
            isPresented: $isImportPresented,
            allowedContentTypes: [.mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.importVideo(url: url)
                }
            case .failure(let error):
                viewModel.statusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard
                    let data,
                    let filePath = String(data: data, encoding: .utf8),
                    let url = URL(string: filePath)
                else {
                    return
                }

                Task {
                    await viewModel.importVideo(url: url)
                }
            }
            return true
        }
    }
}
