import SwiftUI

struct MomentDetailView: View {
  let moment: MomentSnapshot
  @State private var viewModel = MomentDetailViewModel()
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    let displayed = viewModel.current(moment)
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if let notice = viewModel.sourceNotice(for: moment) {
          Text(notice).font(.footnote).foregroundStyle(theme.palette.secondary)
        }
        Text(displayed.text).font(.title3).textSelection(.enabled)
        Divider()
        LabeledContent("Captured", value: displayed.createdAt.formatted())
        if let date = displayed.happenedAt {
          LabeledContent(
            "Event date · you provided", value: date.formatted(date: .abbreviated, time: .omitted))
        }
        Text("Original text · \(displayed.source)").font(.caption).foregroundStyle(
          theme.palette.secondary)
        if let issue = displayed.analysisIssue { Text(issue).foregroundStyle(theme.palette.error) }
        if let analysis = displayed.analysis {
          Text("Derived metadata").font(.headline)
          Text(analysis.title)
          Text("\(analysis.processor) · v\(analysis.version)").font(.caption).foregroundStyle(
            theme.palette.secondary)
          Text("This title is derived from your words. Life Map identifies experiences separately.")
            .font(.footnote).foregroundStyle(theme.palette.secondary)
        } else {
          Text("Enrichment pending. Your original text is saved.").foregroundStyle(
            theme.palette.secondary)
        }
      }.padding(24)
    }
    .background(theme.palette.background)
    .toolbarBackground(theme.palette.background, for: .navigationBar)
    .task { await viewModel.load() }.navigationTitle("Moment").navigationBarTitleDisplayMode(
      .inline)
  }
}
