import SwiftUI

struct SidebarSettings: View {
    @ObservedObject var viewModel: ConversionViewModel
    let currentLanguage: AppLanguage

    let themeLabel: String
    let themeSystemLabel: String
    let themeLightLabel: String
    let themeDarkLabel: String

    @Binding var appTheme: Int
    @Binding var presetPendingDeletion: ConversionPreset?
    @Binding var presetNameInput: String
    @Binding var percentageInput: String
    @Binding var widthInput: String
    @Binding var heightInput: String
    @Binding var isQualityHelpPresented: Bool
    @Binding var isMetadataHelpPresented: Bool
    @Binding var isSuffixHelpPresented: Bool
    @Binding var isResizeHelpPresented: Bool

    let commitAllResizeInputs: () -> Void
    let commitPercentageInput: () -> Void
    let commitWidthInput: () -> Void
    let commitHeightInput: () -> Void

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Réglages")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            Text(themeLabel)
                            Picker(themeLabel, selection: $appTheme) {
                                Text(themeSystemLabel).tag(0)
                                Text(themeLightLabel).tag(1)
                                Text(themeDarkLabel).tag(2)
                            }
                            .pickerStyle(.segmented)
                        }

                        Picker(L10n.text("settings.preset.label", language: currentLanguage), selection: Binding<UUID?>(
                            get: { viewModel.selectedPresetID },
                            set: { viewModel.applyPreset(id: $0) }
                        )) {
                            Text(L10n.text("settings.preset.current", language: currentLanguage)).tag(UUID?.none)
                            ForEach(viewModel.presets) { preset in
                                Text(viewModel.displayName(for: preset)).tag(Optional(preset.id))
                            }
                        }

                        if let selectedPreset = viewModel.selectedPreset, viewModel.canDeleteSelectedPreset {
                            Button(role: .destructive) {
                                presetPendingDeletion = selectedPreset
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help(L10n.text("settings.preset.delete_help", language: currentLanguage))
                        }

                        TextField(L10n.text("settings.preset.new_name.placeholder", language: currentLanguage), text: $presetNameInput)

                        Button(L10n.text("button.save", language: currentLanguage)) {
                            commitAllResizeInputs()
                            viewModel.saveCurrentPreset(named: presetNameInput)
                            if viewModel.globalError == nil {
                                presetNameInput = ""
                            }
                        }
                        .disabled(presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    HStack {
                        labelWithInfo(
                            L10n.text("settings.quality.label", language: currentLanguage),
                            help: L10n.text("settings.quality.help", language: currentLanguage),
                            isPresented: $isQualityHelpPresented
                        )

                        Slider(
                            value: Binding(
                                get: { viewModel.settings.quality },
                                set: { viewModel.updateQuality($0) }
                            ),
                            in: 0.1...1.0,
                            step: 0.05
                        )

                        Text("\(Int(viewModel.settings.quality * 100))%")
                            .font(.system(.body, design: .monospaced))
                    }

                    Toggle(
                        isOn: Binding(
                            get: { viewModel.settings.removeMetadata },
                            set: { viewModel.updateRemoveMetadata($0) }
                        )
                    ) {
                        labelWithInfo(
                            L10n.text("settings.metadata.label", language: currentLanguage),
                            help: L10n.text("settings.metadata.help", language: currentLanguage),
                            isPresented: $isMetadataHelpPresented
                        )
                    }
                    .toggleStyle(.checkbox)

                    HStack {
                        labelWithInfo(
                            L10n.text("settings.suffix.label", language: currentLanguage),
                            help: L10n.text("settings.suffix.help", language: currentLanguage),
                            isPresented: $isSuffixHelpPresented
                        )

                        Picker(L10n.text("settings.suffix.label", language: currentLanguage), selection: Binding(
                            get: { viewModel.settings.suffixMode },
                            set: { viewModel.updateSuffixMode($0) }
                        )) {
                            ForEach(SuffixMode.allCases) { mode in
                                Text(mode.localizedTitle).tag(mode)
                            }
                        }
                    }

                    HStack {
                        labelWithInfo(
                            L10n.text("settings.resize.label", language: currentLanguage),
                            help: L10n.text("settings.resize.help", language: currentLanguage),
                            isPresented: $isResizeHelpPresented
                        )

                        Picker(L10n.text("settings.resize.label", language: currentLanguage), selection: Binding(
                            get: { viewModel.settings.resizeSettings.mode },
                            set: { viewModel.updateResizeMode($0) }
                        )) {
                            ForEach(ResizeMode.allCases) { mode in
                                Text(mode.localizedTitle).tag(mode)
                            }
                        }

                        switch viewModel.settings.resizeSettings.mode {
                        case .percentage:
                            HStack {
                                Text("%")
                                AppKitCommitTextField(
                                    placeholder: "100",
                                    text: $percentageInput,
                                    onCommit: commitPercentageInput
                                )
                            }

                        case .width:
                            HStack {
                                Text("px")
                                AppKitCommitTextField(
                                    placeholder: "1920",
                                    text: $widthInput,
                                    onCommit: commitWidthInput
                                )
                            }

                        case .height:
                            HStack {
                                Text("px")
                                AppKitCommitTextField(
                                    placeholder: "1080",
                                    text: $heightInput,
                                    onCommit: commitHeightInput
                                )
                            }

                        case .original:
                            EmptyView()
                        }

                        if viewModel.settings.resizeSettings.mode == .width ||
                            viewModel.settings.resizeSettings.mode == .height {
                            Toggle(L10n.text("settings.keep_aspect_ratio", language: currentLanguage), isOn: Binding(
                                get: { viewModel.settings.resizeSettings.keepAspectRatio },
                                set: { viewModel.updateKeepAspectRatio($0) }
                            ))
                        }
                    }

                    HStack {
                        Text(L10n.text("settings.output.label", language: currentLanguage))

                        Text(viewModel.settings.outputFolder?.path ?? L10n.text("settings.output.none", language: currentLanguage))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(L10n.text("button.choose", language: currentLanguage)) {
                            viewModel.selectOutputFolder()
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labelWithInfo(_ title: String, help: String, isPresented: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: isPresented, arrowEdge: .bottom) {
                Text(help)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: 280, alignment: .leading)
            }
        }
    }
}
