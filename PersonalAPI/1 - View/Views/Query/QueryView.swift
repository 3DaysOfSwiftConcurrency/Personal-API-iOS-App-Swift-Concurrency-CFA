import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct QueryView: View {
  @Environment(ThemeStore.self) private var theme
  @State private var viewModel = QueryViewModel()
  var body: some View {
    @Bindable var viewModel = viewModel
    NavigationStack {
      GeometryReader { viewport in
        ScrollViewReader { scroll in
          ScrollView {
            VStack(alignment: .leading, spacing: 28) {
              if viewModel.turns.isEmpty {
                Text("My life.\nMy Moments").font(.largeTitle.bold())
                Text("Search your own personal API and ask questions about your life.")
                  .foregroundStyle(theme.palette.secondary)
              }
              // The draft keeps its row identity when it becomes a saved turn.
              ForEach(0..<viewModel.rowCount, id: \.self) { index in
                VStack(alignment: .leading, spacing: 24) {
                  let turn = index < viewModel.turns.count ? viewModel.turns[index] : nil
                  JournalTextEditor(
                    text: turn.map { .constant($0.question) }
                      ?? Binding(
                        get: {
                          viewModel.submittedTurnCount == viewModel.turns.count
                            ? viewModel.submittedText : viewModel.question
                        },
                        set: { viewModel.question = $0 }),
                    isEditing: turn == nil ? $viewModel.isQuestionFocused : .constant(false),
                    isEnabled: turn == nil && !viewModel.isConversationOperationInProgress,
                    textColor: UIColor(theme.palette.primary),
                    placeholderColor: UIColor(theme.palette.secondary),
                    surfaceColor: UIColor(theme.palette.surface),
                    accentColor: UIColor(theme.palette.interactiveAccent),
                    placeholderText: "Ask about your life…",
                    accessibilityName: "Chat question",
                    onSend: { viewModel.submitQuestion() }
                  )
                  .frame(height: 174)
                  if let turn {
                    if viewModel.activeTurnID == turn.id {
                      ProgressView("Thinking…")
                    } else {
                      ChatAnswerView(
                        turn: turn, answer: viewModel.answer(for: turn),
                        failureDetails: viewModel.failureDetails(for: turn),
                        isLatest: turn.id == viewModel.turns.last?.id, isConversationOperationInProgress: viewModel.isConversationOperationInProgress,
                        retry: { viewModel.answerAgain() },
                        logMoment: viewModel.showMomentEntry,
                        markUseful: { viewModel.markUseful(turn.id) },
                        showFeedback: { viewModel.showFeedback(turn) })
                    }
                  } else if !viewModel.isConversationOperationInProgress {
                    Button {
                      viewModel.submitQuestion()
                    } label: {
                      Label("Ask Personal API", systemImage: "arrow.up")
                        .frame(maxWidth: .infinity).padding(8)
                    }
                    .buttonStyle(PersonalAPIButtonStyle(appearance: .outlined))
                    .disabled(!viewModel.canSearch)
                  }
                }
                .id(index)
              }
              if viewModel.isConversationOperationInProgress {
                Button("Stop", systemImage: "stop.circle") { viewModel.cancelSearch() }
              }
              if let error = viewModel.error {
                Text(error).foregroundStyle(theme.palette.error)
                if !viewModel.loaded { Button("Retry loading chats") { viewModel.retryLoading() } }
              }
              // The scroll target includes breathing room below the submit button.
              Color.clear.frame(height: 20).id("bottom")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .topLeading)
          }
          .defaultScrollAnchor(.bottom)
          .scrollDismissesKeyboard(.interactively)
          .scrollBounceBehavior(.always, axes: .vertical)
          .id(viewModel.conversationID)
          .onAppear { scroll.scrollTo("bottom", anchor: .bottom) }
          .onChange(of: viewport.size.height) { oldHeight, newHeight in
            if viewModel.isQuestionFocused && newHeight < oldHeight {
              scroll.scrollTo("bottom", anchor: .bottom)
            }
          }
        }
      }
      .background(theme.palette.background)
      .toolbarBackground(theme.palette.background, for: .navigationBar, .tabBar)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("PERSONAL API")
            .font(.caption).tracking(4)
            .foregroundStyle(theme.palette.secondary)
            .accessibilityAddTraits(.isHeader)
        }
        ToolbarItem(placement: .topBarLeading) {
          Menu {
            Button("New chat", systemImage: "square.and.pencil") { viewModel.newChat() }
            Button("Saved chats", systemImage: "clock") { viewModel.showsHistory = true }
            Button("Export chats", systemImage: "square.and.arrow.up") {
              viewModel.requestExport()
            }
          } label: {
            Image(systemName: "bubble.left.and.bubble.right").frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel("Conversation menu").disabled(viewModel.isConversationOperationInProgress)
        }
        if viewModel.isQuestionFocused {
          ToolbarItem(placement: .topBarTrailing) {
            DoneButton { viewModel.isQuestionFocused = false }
              .accessibilityHint("Dismisses the keyboard")
          }
        }
      }
      .navigationTitle("Personal API").navigationBarTitleDisplayMode(.inline)
      .task { await viewModel.load() }
      .onDisappear(perform: viewModel.disappeared)
    }
    .sheet(isPresented: $viewModel.showsMemoryEntry) {
      TrainingView(presentedFromChat: true)
    }
    .sheet(isPresented: $viewModel.showsHistory) {
      ConversationHistoryView(selection: $viewModel.historySelection)
    }
    .onChange(of: viewModel.historySelection) { viewModel.openSelectedHistory() }
    .sheet(item: $viewModel.feedbackTurn) { turn in
      AnswerFeedbackView(conversationID: viewModel.conversationID, turnID: turn.id)
    }
    .fileExporter(
      isPresented: $viewModel.showsExport, document: viewModel.exportDocument, contentType: .json,
      defaultFilename: "PersonalAPI-Conversations", onCompletion: viewModel.exportFinished
    )
    .toolbar(.visible, for: .tabBar)
  }
}
