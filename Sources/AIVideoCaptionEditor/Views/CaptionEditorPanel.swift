import SwiftUI

struct CaptionEditorPanel: View {
    @ObservedObject var viewModel: EditorViewModel

    @State private var draftText = ""
    @State private var draftStart = ""
    @State private var draftEnd = ""

    private var selectedCaption: Caption? {
        guard let id = viewModel.timelineController.selectedCaptionID else { return nil }
        return viewModel.captionModel.captions.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Captions") {
                List(selection: selectionBinding) {
                    ForEach(viewModel.captionModel.captions) { caption in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Timecode.format(caption.startTime)) - \(Timecode.format(caption.endTime))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if caption.styleOverride != nil {
                                    Text("OVERRIDE")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            Text(caption.text)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .tag(caption.id)
                    }
                }
                .frame(minHeight: 180)
            }

            GroupBox("Caption Inspector") {
                if let selectedCaption {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Caption text", text: $draftText)
                            .onSubmit {
                                viewModel.updateCaptionText(id: selectedCaption.id, text: draftText)
                            }

                        HStack {
                            TextField("Start", text: $draftStart)
                                .onSubmit {
                                    viewModel.updateCaptionStart(id: selectedCaption.id, from: draftStart)
                                }
                            TextField("End", text: $draftEnd)
                                .onSubmit {
                                    viewModel.updateCaptionEnd(id: selectedCaption.id, from: draftEnd)
                                }
                        }

                        HStack {
                            Button("Apply Text") {
                                viewModel.updateCaptionText(id: selectedCaption.id, text: draftText)
                            }
                            Button("Apply Time") {
                                viewModel.updateCaptionStart(id: selectedCaption.id, from: draftStart)
                                viewModel.updateCaptionEnd(id: selectedCaption.id, from: draftEnd)
                            }
                            Spacer()
                            Button("Create Override") {
                                viewModel.createOverrideForSelectedCaption()
                            }
                            Button("Clear Override") {
                                viewModel.clearOverrideForSelectedCaption()
                            }
                        }
                    }
                    .onAppear {
                        loadDraft(from: selectedCaption)
                    }
                } else {
                    Text("Select a caption block from the list or timeline")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Subtitle Style") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Preset", selection: presetBinding) {
                        ForEach(viewModel.styleManager.presetNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    TextField("Font", text: styleBinding(\.fontName))

                    HStack {
                        Text("Size")
                        Slider(value: styleBinding(\.fontSize), in: 18...96)
                        Text(String(format: "%.0f", viewModel.styleManager.globalStyle.fontSize))
                            .frame(width: 36)
                    }

                    HStack {
                        Text("Stroke")
                        Slider(value: styleBinding(\.strokeWidth), in: 0...10)
                        Text(String(format: "%.1f", viewModel.styleManager.globalStyle.strokeWidth))
                            .frame(width: 36)
                    }

                    HStack {
                        Text("Shadow")
                        Slider(value: styleBinding(\.shadowRadius), in: 0...16)
                        Text(String(format: "%.1f", viewModel.styleManager.globalStyle.shadowRadius))
                            .frame(width: 36)
                    }

                    HStack {
                        Text("BG")
                        Slider(value: backgroundOpacityBinding, in: 0...1)
                        Text(String(format: "%.2f", viewModel.styleManager.globalStyle.backgroundColor.alpha))
                            .frame(width: 36)
                    }

                    Picker("Alignment", selection: styleBinding(\.alignment)) {
                        ForEach(CaptionAlignment.allCases, id: \.self) { alignment in
                            Text(alignment.rawValue.capitalized).tag(alignment)
                        }
                    }

                    Picker("Animation", selection: styleBinding(\.animation)) {
                        ForEach(CaptionAnimationKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                }
                .font(.caption)
            }

            GroupBox("Lyrics Alignment") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $viewModel.lyricsText)
                        .font(.body.monospaced())
                        .frame(minHeight: 86)

                    HStack {
                        Button("Auto Align") {
                            viewModel.applyLyricsAlignment()
                        }
                        Button("Nudge -10ms") {
                            viewModel.nudgeSelectedCaption(by: -0.01)
                        }
                        Button("Nudge +10ms") {
                            viewModel.nudgeSelectedCaption(by: 0.01)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: viewModel.timelineController.selectedCaptionID) { _, _ in
            if let selectedCaption {
                loadDraft(from: selectedCaption)
            }
        }
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.timelineController.selectedCaptionID },
            set: { viewModel.selectCaption($0) }
        )
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: { viewModel.styleManager.globalStyle.name },
            set: { viewModel.styleManager.applyPreset(named: $0) }
        )
    }

    private var backgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.styleManager.globalStyle.backgroundColor.alpha },
            set: { value in
                viewModel.updateGlobalStyle { style in
                    style.backgroundColor.alpha = value
                }
            }
        )
    }

    private func styleBinding<Value>(_ keyPath: WritableKeyPath<CaptionStyle, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.styleManager.globalStyle[keyPath: keyPath] },
            set: { value in
                viewModel.updateGlobalStyle { style in
                    style[keyPath: keyPath] = value
                }
            }
        )
    }

    private func loadDraft(from caption: Caption) {
        draftText = caption.text
        draftStart = Timecode.format(caption.startTime)
        draftEnd = Timecode.format(caption.endTime)
    }
}
