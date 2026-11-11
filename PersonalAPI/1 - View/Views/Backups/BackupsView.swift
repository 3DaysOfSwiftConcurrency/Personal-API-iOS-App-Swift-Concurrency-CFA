import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BackupsView: View {
  @State private var viewModel = BackupsViewModel()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    @Bindable var viewModel = viewModel
    Form {
      Group {
        Section("iCloud sync") {
          Text(viewModel.syncStatus)
          if let issue = viewModel.syncIssue {
            Text(issue.guidance)
              .foregroundStyle(theme.palette.secondary)
            if let details = issue.details {
              DisclosureGroup("Error details") {
                Text(details).font(.footnote).textSelection(.enabled)
              }
            }
            if issue.offersSettings, let url = URL(string: UIApplication.openSettingsURLString) {
              Link("Open app settings", destination: url)
                .foregroundStyle(theme.palette.interactiveAccent)
              Text(
                "This opens Personal API’s settings. For your Apple Account, return to the main Settings screen and tap your name."
              )
              .font(.footnote).foregroundStyle(theme.palette.secondary)
            }
          }
          if let status = viewModel.accountStatus { Text(status).font(.footnote) }
          Button("Check iCloud account again") { viewModel.requestSyncCheck() }
            .foregroundStyle(theme.palette.interactiveAccent)
            .disabled(viewModel.isCheckingAccount)
          if viewModel.isCheckingAccount { ProgressView("Checking iCloud…") }
          Text(
            "Journal entries, facts and chats sync through your private iCloud database. Changes and deletions can reach your other devices."
          )
          .font(.footnote).foregroundStyle(theme.palette.secondary)
        }
        Section("Recovery backups") {
          Text(viewModel.status)
          if let date = viewModel.lastBackup {
            LabeledContent("Last snapshot", value: date.formatted())
          }
          Button("Back up now") { viewModel.requestBackup() }
            .disabled(viewModel.isWorking)
          Text(
            "While you use the app, changed data is backed up at most once every 24 hours. Manual backup runs immediately. Latest, Previous and weekly recovery copies are kept in iCloud Drive when available. Weekly copies are retained until you remove them."
          )
          .font(.footnote).foregroundStyle(theme.palette.secondary)
        }
        Section("Restore") {
          Button("Choose recovery file") { viewModel.importing = true }
            .disabled(viewModel.isWorking)
          Text(
            "Choose a JSON recovery file from Personal API in iCloud Drive. Dataset exports are separate and cannot be restored here."
          )
          .font(.footnote).foregroundStyle(theme.palette.secondary)
          if let preview = viewModel.preview {
            Text(preview.createdAt.formatted())
            Text(
              "\(preview.moments.count) journal entries · \(preview.facts.count) facts · \(preview.conversations.count) chats"
            )
            Button("Restore this snapshot", role: .destructive) {
              viewModel.confirmingRestore = true
            }
            .disabled(viewModel.isWorking)
            Button("Cancel") { viewModel.discardPreview() }
          }
        }
        Section("On this device") {
          ForEach(viewModel.localCopies) { copy in
            Button(copy.name) { viewModel.requestInspect(copy.url) }
              .disabled(viewModel.isWorking)
          }
        }
        if viewModel.isWorking { ProgressView() }
        if let error = viewModel.error {
          Section {
            Text(viewModel.errorTitle).font(.headline).foregroundStyle(theme.palette.error)
            Text(viewModel.errorGuidance).foregroundStyle(theme.palette.secondary)
            DisclosureGroup("Technical details") {
              Text(error).font(.footnote).textSelection(.enabled)
            }
          }
        }
      }.listRowBackground(theme.palette.surface)
    }
    .scrollContentBackground(.hidden)
    .background(theme.palette.background)
    .navigationTitle("Backups")
    .task(id: scenePhase) {
      if scenePhase == .active { await viewModel.load() }
    }
    .alert("iCloud account check finished", isPresented: $viewModel.showingAccountCheckResult) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(viewModel.accountCheckResult)
    }
    .fileImporter(
      isPresented: $viewModel.importing, allowedContentTypes: [.json],
      onCompletion: viewModel.importFinished
    )
    .confirmationDialog(
      "Replace current data with this snapshot?", isPresented: $viewModel.confirmingRestore,
      titleVisibility: .visible
    ) {
      Button("Replace and restore", role: .destructive) { viewModel.requestRestore() }
    } message: {
      Text(
        "This replaces journal entries, facts and chats, and syncs that change to iCloud. A local copy of the current data is saved first. The restored colour theme applies when you next open the app."
      )
    }
  }
}
