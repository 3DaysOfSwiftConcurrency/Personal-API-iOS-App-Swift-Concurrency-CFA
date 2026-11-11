import SwiftUI

struct SettingsView: View {
  @State private var viewModel = SettingsViewModel()
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    @Bindable var viewModel = viewModel
    NavigationStack {
      Form {
        Group {
          Section("Privacy") {
            Toggle(
              "Face ID / device passcode",
              isOn: Binding(
                get: { viewModel.lockEnabled },
                set: { value in viewModel.requestLockEnabled(value) })
            ).disabled(viewModel.authenticating)
            Text(
              "Locks when the app enters the background. Your preview is hidden whenever the app is inactive."
            ).font(.footnote).foregroundStyle(theme.palette.secondary)
            if let error = viewModel.authenticationError {
              Text(error).foregroundStyle(theme.palette.error)
            }
          }
          Section("Your data") {
            NavigationLink("Manage journal entries") { JournalEntriesView() }
            LabeledContent("Storage", value: "On this device")
            NavigationLink("iCloud sync and recovery backups") { BackupsView() }
            Button("Export your dataset · JSON") {
              viewModel.requestExport()
            }.disabled(viewModel.isWorking)
            Text(
              "Includes original Moments, profile facts, IDs, dates and derived metadata. Save a copy somewhere you control."
            ).font(.footnote).foregroundStyle(theme.palette.secondary)
          }
          Section("Intelligence") {
            LabeledContent("Processor", value: "Local extractive v1")
            Button("Regenerate derived metadata") { viewModel.requestRegenerate() }.disabled(
              viewModel.isWorking)
            if let error = viewModel.enrichmentError {
              Text(error).foregroundStyle(theme.palette.error)
            }
            Text(
              "Original words are preserved. Life Map uses on-device AI to identify experiences."
            )
            .font(.footnote).foregroundStyle(theme.palette.secondary)
          }
          Section("Personal API · 0.1") {
            LabeledContent("Moments", value: "\(viewModel.momentCount)")
            LabeledContent("Personal facts", value: "\(viewModel.factCount)")
            Text("Build the dataset of yourself that future AI will be able to interrogate.")
          }
          Section("Colour Themes") {
            ForEach(AppColourTheme.all) { option in
              Button {
                theme.palette = option
              } label: {
                HStack {
                  Text(option.name)
                  Spacer()
                  if theme.palette == option {
                    Image(systemName: "checkmark")
                      .foregroundStyle(theme.palette.interactiveAccent)
                      .accessibilityHidden(true)
                  }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
              }
              .buttonStyle(.automatic)
              .accessibilityAddTraits(theme.palette == option ? .isSelected : [])
            }
          }
          if viewModel.isWorking { ProgressView() }
          if let message = viewModel.message { Section { Text(message) } }
        }
        .listRowBackground(theme.palette.surface)
      }.scrollContentBackground(.hidden).background(theme.palette.background)
        .toolbarBackground(theme.palette.background, for: .navigationBar, .tabBar).navigationTitle(
          "Settings"
        )
        .fileExporter(
          isPresented: $viewModel.exporting, document: viewModel.document, contentType: .json,
          defaultFilename: viewModel.filename
        ) { result in
          viewModel.exportFinished(result)
        }
    }
  }
}
