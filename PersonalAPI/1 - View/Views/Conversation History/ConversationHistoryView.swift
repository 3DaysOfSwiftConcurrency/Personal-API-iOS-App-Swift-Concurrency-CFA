import SwiftUI

struct ConversationHistoryView: View {
  @Binding var selection: UUID?
  @State private var viewModel = ConversationHistoryViewModel()
  @Environment(\.dismiss) private var dismiss
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    @Bindable var viewModel = viewModel
    NavigationStack {
      List {
        Group {
          if let error = viewModel.error { Text(error).foregroundStyle(theme.palette.error) }
          if viewModel.conversations.isEmpty { Text("Your conversations will appear here.") }
          ForEach(viewModel.conversations) { chat in
            Button {
              selection = chat.id
              dismiss()
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(chat.title)
                Text(chat.updatedAt, style: .date).font(.caption).foregroundStyle(
                  theme.palette.secondary)
              }
            }.disabled(viewModel.isBusy)
              .swipeActions {
                Button("Delete", role: .destructive) { viewModel.pendingDeletion = chat.id }
                  .disabled(viewModel.isBusy)
              }
          }
        }
        .listRowBackground(theme.palette.surface)
      }
      .scrollContentBackground(.hidden)
      .background(theme.palette.background)
      .toolbarBackground(theme.palette.background, for: .navigationBar)
      .navigationTitle("Saved chats")
      .toolbar { DoneButton(action: { dismiss() }) }
      .task { await viewModel.load() }
      .confirmationDialog(
        "Delete this conversation? Your journal entries will remain.",
        isPresented: Binding(
          get: { viewModel.pendingDeletion != nil },
          set: { if !$0 { viewModel.pendingDeletion = nil } })
      ) {
        Button("Delete conversation", role: .destructive) { viewModel.deletePending() }
      }
    }
  }
}
