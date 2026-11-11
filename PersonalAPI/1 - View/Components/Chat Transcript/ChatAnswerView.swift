import SwiftUI

struct ChatAnswerView: View {
  let turn: ChatTurn
  let answer: String
  let failureDetails: String?
  let isLatest: Bool
  let isBusy: Bool
  let retry: () -> Void
  let logMoment: () -> Void
  let markUseful: () -> Void
  let showFeedback: () -> Void
  @Environment(ThemeStore.self) private var theme
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Label("Personal API", systemImage: "sparkles").font(.headline)
      Text(answer).textSelection(.enabled)
      if let details = failureDetails {
        DisclosureGroup("What happened?") {
          Text(details).font(.caption)
        }.font(.subheadline).foregroundStyle(theme.palette.secondary)
      }
      if turn.result?.generatedAnswer?.contextLimited == true {
        Text("This answer used excerpts. Some journal text was outside the answer context.")
          .font(.caption).foregroundStyle(theme.palette.secondary)
      }
      if let result = turn.result, !result.evidence.isEmpty {
        DisclosureGroup("Sources") {
          ForEach(result.evidence) { evidence in
            NavigationLink {
              if evidence.moment.source == "personal-fact" {
                ScrollView {
                  Text(evidence.moment.text).textSelection(.enabled).padding(24)
                }.navigationTitle("Fact").navigationBarTitleDisplayMode(.inline)
              } else {
                MomentDetailView(moment: evidence.moment)
              }
            } label: {
              Text(evidence.moment.text).lineLimit(3)
                .multilineTextAlignment(.leading).padding(.vertical, 8)
            }
          }
        }.font(.subheadline).foregroundStyle(theme.palette.secondary)
      }
      if isLatest {
        Button {
          retry()
        } label: {
          Label("Answer again", systemImage: "arrow.clockwise")
            .foregroundStyle(theme.palette.interactiveAccent)
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
        .opacity(isBusy ? 0.4 : 1)
        .disabled(isBusy)
        Button {
          logMoment()
        } label: {
          Label("Log a moment about this", systemImage: "square.and.pencil")
            .foregroundStyle(theme.palette.interactiveAccent)
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
        .opacity(isBusy ? 0.4 : 1)
        .disabled(isBusy)
        if turn.result?.needsMoreMemories == true {
          Text("The more you log, the more useful your Personal API can become.")
            .font(.caption).foregroundStyle(theme.palette.secondary)
        }
      }
      if turn.result?.generatedAnswer != nil {
        HStack {
          Button("Useful", systemImage: "hand.thumbsup") {
            markUseful()
          }
          Button("Not helpful", systemImage: "hand.thumbsdown") {
            showFeedback()
          }
        }.font(.caption).buttonStyle(PersonalAPIButtonStyle(appearance: .bordered)).disabled(isBusy)
        if turn.feedback != nil {
          Text("Feedback saved for this answer.").font(.caption)
            .foregroundStyle(theme.palette.secondary)
        }
      }
    }
  }
}
