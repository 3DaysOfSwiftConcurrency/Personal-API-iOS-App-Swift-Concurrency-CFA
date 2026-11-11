import SwiftUI

struct LifeMapView: View {
  @Environment(ThemeStore.self) private var theme
  @State private var viewModel = LifeMapViewModel()
  @State private var selected: LifeMapPoint?
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Your life,\ntaking shape.").font(.largeTitle.bold())
          Text(
            "\(viewModel.entryCount) journal entries · \(viewModel.points.count) identified Moments"
          )
          .foregroundStyle(theme.palette.secondary)
          Text("Tap a Moment to see the words behind it.").font(.subheadline).foregroundStyle(
            theme.palette.secondary)
          if viewModel.isReading {
            ProgressView(
              "Reading your journal… \(viewModel.attemptedCount) of \(viewModel.entryCount)")
          }
          if !viewModel.points.isEmpty {
            // A wrapping constellation stays readable at large text sizes.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], spacing: 28) {
              ForEach(viewModel.points) { point in
                Button {
                  selected = point
                } label: {
                  VStack(spacing: 12) {
                    Circle().fill(theme.palette.interactiveAccent).frame(width: 12, height: 12)
                      .shadow(color: theme.palette.accent.opacity(0.8), radius: 12)
                    Text(point.title).font(.subheadline).multilineTextAlignment(.center)
                      .foregroundStyle(theme.palette.primary).fixedSize(
                        horizontal: false, vertical: true)
                  }.frame(maxWidth: .infinity, minHeight: 92).padding(12)
                    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain)
              }
            }
          } else if !viewModel.isReading {
            ContentUnavailableView(
              viewModel.entryCount == 0
                ? "Your map starts with a Moment" : "No Moments identified yet",
              systemImage: "sparkles",
              description: Text("Record experiences in Training, then return here to explore them.")
            )
          }
          if viewModel.failedCount > 0 {
            Text(
              "\(viewModel.processedCount) entries read · \(viewModel.failedCount) couldn’t be processed"
            )
            .font(.subheadline).foregroundStyle(theme.palette.secondary)
          }
          if let issue = viewModel.issue {
            Text(issue).foregroundStyle(theme.palette.secondary)
            Button("Try again") { viewModel.requestRefresh() }.disabled(viewModel.isReading)
          }
          Text(
            "AI interpretations, grounded in your original words. Related entries may describe the same event; this experiment does not merge them yet."
          )
          .font(.footnote).foregroundStyle(theme.palette.secondary)
        }.padding(24)
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
      .task { await viewModel.refresh() }
      .refreshable { await viewModel.refresh() }
      .sheet(item: $selected) { point in
        NavigationStack {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              Text(point.title).font(.title.bold())
              Text("FROM YOUR JOURNAL").font(.caption).tracking(2).foregroundStyle(
                theme.palette.secondary)
              Text(point.passage).textSelection(.enabled)
              Text(
                "Recorded \(point.source.createdAt.formatted(date: .abbreviated, time: .omitted))"
              )
              .font(.caption).foregroundStyle(theme.palette.secondary)
              NavigationLink("Read original entry") { MomentDetailView(moment: point.source) }
            }.padding(24)
          }
          .background(theme.palette.background)
          .toolbarBackground(theme.palette.background, for: .navigationBar)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              DoneButton { selected = nil }
            }
          }
        }
      }
    }
  }
}
