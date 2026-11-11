import SwiftUI

struct JournalEntriesView: View {
  @State private var viewModel = JournalEntriesViewModel()
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    List {
      Group {
        Section {
          Text("Refine your words as your life unfolds. Tap an entry to edit or delete it.")
            .foregroundStyle(theme.palette.secondary)
        }
        if viewModel.isLoading { ProgressView() }
        if let error = viewModel.error {
          Section {
            Text(error).foregroundStyle(theme.palette.error)
            Button("Try again") { viewModel.requestRefresh() }
          }
        }
        if viewModel.entries.isEmpty && !viewModel.isLoading && viewModel.error == nil {
          Text("Your first Moment starts today. Add an entry in Training.")
            .foregroundStyle(theme.palette.secondary)
        }
        ForEach(viewModel.entries) { entry in
          NavigationLink {
            EditJournalEntryView(entry: entry)
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundStyle(theme.palette.secondary)
              Text(entry.text).lineLimit(3).foregroundStyle(theme.palette.primary)
            }.padding(.vertical, 6)
          }
        }
      }
      .listRowBackground(theme.palette.surface)
    }
    .scrollContentBackground(.hidden).background(theme.palette.background)
    .toolbarBackground(theme.palette.background, for: .navigationBar)
    .navigationTitle("Journal entries").navigationBarTitleDisplayMode(.inline)
    .task { await viewModel.refresh() }
    .refreshable { await viewModel.refresh() }
  }
}
