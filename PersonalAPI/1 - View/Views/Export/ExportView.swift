import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
  @Environment(ThemeStore.self) private var theme
  @State private var viewModel = ExportViewModel()

  var body: some View {
    @Bindable var viewModel = viewModel
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          Text("A lifetime.\nOne file.").font(.largeTitle.bold())
          Text(
            "Every Moment you write adds to something uniquely yours: a dataset of your life, in your own words."
          )
          .foregroundStyle(theme.palette.secondary)

          VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "doc.text")
              .font(.largeTitle).foregroundStyle(theme.palette.interactiveAccent)
            Text("Your personal dataset").font(.title2.bold())
            Text(
              "\(viewModel.momentCount) \(viewModel.momentCount == 1 ? "Moment" : "Moments") · One JSON file"
            )
            .foregroundStyle(theme.palette.secondary)
            Text("Your words. Your experiences. Context for AI.")
              .font(.subheadline).foregroundStyle(theme.palette.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading).padding(24)
          .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: 18))

          Button {
            viewModel.requestExport()
          } label: {
            Label(
              viewModel.isExporting ? "Preparing your file…" : "Export your dataset",
              systemImage: "square.and.arrow.up"
            )
            .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(PersonalAPIButtonStyle(appearance: .outlined))
          .disabled(viewModel.isExporting)
          if viewModel.momentCount == 0 {
            Text(
              "Your file starts with your first Moment. Add one in Training to begin building your dataset."
            )
            .font(.subheadline).foregroundStyle(theme.palette.secondary)
          }
          if let message = viewModel.message {
            Text(message).font(.subheadline)
          }
          Divider()
          section(
            "Context for AI",
            text:
              "Give AI context about you, in your own words. Your personal dataset brings together the Moments you’ve recorded, ready to use as context in a compatible AI tool."
          )
          section(
            "What’s inside",
            text:
              "Your original Moments, their recorded dates and IDs, plus stored facts and derived metadata. Chat conversations are exported separately from the Personal API conversation menu."
          )
          section(
            "Why JSON?",
            text:
              "JSON is a structured text format that software can read. It keeps your words and their context together in one portable file. Each export is a snapshot of your dataset at that time."
          )
          section(
            "You choose what comes next",
            text:
              "Save a copy somewhere you control. Exporting doesn’t upload your dataset to an AI service or train a model. Compatibility and preparation depend on the tool you choose."
          )
        }
        .padding(24)
      }
      .background(theme.palette.background)
      .toolbarBackground(theme.palette.background, for: .navigationBar, .tabBar)
      .navigationTitle("Personal API").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("PERSONAL API")
            .font(.caption).tracking(4)
            .foregroundStyle(theme.palette.secondary)
            .accessibilityAddTraits(.isHeader)
        }
      }
      .fileExporter(
        isPresented: $viewModel.showsExporter, document: viewModel.document,
        contentType: .json, defaultFilename: viewModel.filename
      ) { viewModel.exportFinished($0) }
    }
  }

  private func section(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.headline)
      Text(text).foregroundStyle(theme.palette.secondary)
    }
  }
}
