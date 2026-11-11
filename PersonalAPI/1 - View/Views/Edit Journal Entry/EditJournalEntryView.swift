import SwiftUI

struct EditJournalEntryView: View {
  let entry: MomentSnapshot
  @State private var viewModel = EditJournalEntryViewModel()
  @Environment(\.dismiss) private var dismiss
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    @Bindable var viewModel = viewModel
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
          .font(.subheadline).foregroundStyle(theme.palette.secondary)
        JournalTextEditor(
          text: $viewModel.text, isEditing: $viewModel.editing,
          isEnabled: !viewModel.isWorking,
          textColor: UIColor(theme.palette.primary),
          placeholderColor: UIColor(theme.palette.secondary),
          surfaceColor: UIColor(theme.palette.surface),
          accentColor: UIColor(theme.palette.interactiveAccent)
        )
        .frame(minHeight: 260).disabled(viewModel.isWorking)
        Text(
          "Saving updates this journal entry and refreshes its derived information. Its original recorded date stays the same."
        )
        .font(.footnote).foregroundStyle(theme.palette.secondary)
        Button("Save changes") {
          viewModel.requestSave()
        }.buttonStyle(PersonalAPIButtonStyle(appearance: .outlined)).disabled(!viewModel.canSave)
        if viewModel.isWorking { ProgressView() }
        if let error = viewModel.error { Text(error).foregroundStyle(theme.palette.error) }
        Divider()
        Button("Delete journal entry", role: .destructive) { viewModel.confirmingDelete = true }
          .disabled(viewModel.isWorking)
      }.padding(24)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(theme.palette.background)
    .toolbarBackground(theme.palette.background, for: .navigationBar)
    .navigationTitle("Edit entry").navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
          viewModel.cancel()
        }.disabled(viewModel.isWorking).tint(theme.palette.interactiveAccent)
      }
      ToolbarItem(placement: .topBarTrailing) {
        if viewModel.editing {
          DoneButton { viewModel.editing = false }
        }
      }
    }
    .onAppear { viewModel.prepare(entry) }
    .onChange(of: viewModel.finished) { if viewModel.finished { dismiss() } }
    .confirmationDialog(
      "Delete this journal entry?", isPresented: $viewModel.confirmingDelete,
      titleVisibility: .visible
    ) {
      Button("Delete entry", role: .destructive) {
        viewModel.requestDelete()
      }
    } message: {
      Text(
        "This permanently removes the entry and its derived facts from your dataset. Saved chat conversations and previously exported files are kept."
      )
    }
    .confirmationDialog(
      "Discard your changes?", isPresented: $viewModel.confirmingDiscard, titleVisibility: .visible
    ) {
      Button("Discard changes", role: .destructive, action: viewModel.discard)
    }
  }
}
