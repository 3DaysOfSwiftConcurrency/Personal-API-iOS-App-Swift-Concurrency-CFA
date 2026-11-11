import SwiftUI
import UIKit

/// The full rounded surface is the text view, including its internal padding.
/// Natiove text selection and scrolling handle touches without an extra tap recognizer.
struct JournalTextEditor: UIViewRepresentable {
  @Binding var text: String
  @Binding var isEditing: Bool
  let isEnabled: Bool
  let textColor: UIColor
  let placeholderColor: UIColor
  let surfaceColor: UIColor
  let accentColor: UIColor
  var placeholderText = "Write about a moment in your life. In detail."
  var accessibilityName = "Journal entry"
  var onSend: (() -> Void)? = nil

  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> Editor {
    let view = Editor()
    view.delegate = context.coordinator
    return view
  }
  func updateUIView(_ view: Editor, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self
    if view.text != text { view.text = text }
    view.accessibilityLabel = accessibilityName
    view.placeholder.text = placeholderText
    view.returnKeyType = onSend == nil ? .default : .send
    view.placeholder.isHidden = !text.isEmpty
    view.isEditable = isEnabled
    view.textColor = textColor
    view.placeholder.textColor = placeholderColor
    view.backgroundColor = surfaceColor
    view.tintColor = accentColor
    // Only Done requests a resignation. Native touches own acquisition of focus.
    // Never change the responder synchronously inside a SwiftUI update.
    if !isEditing && view.isFirstResponder {
      // Intentionally one-turn and unretained: weak UIKit references make late execution a no-op.
      Task { @MainActor [weak view, weak coordinator] in
        guard let view, let coordinator, !coordinator.parent.isEditing else { return }
        view.resignFirstResponder()
      }
    }
  }
  static func dismantleUIView(_ view: Editor, coordinator: Coordinator) {
    view.delegate = nil
    view.restoreScrollTouchDelay()
  }
  final class Coordinator: NSObject, UITextViewDelegate {
    var parent: JournalTextEditor
    init(_ parent: JournalTextEditor) { self.parent = parent }
    func textView(
      _ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String
    ) -> Bool {
      if text == "\n", let onSend = parent.onSend {
        onSend()
        return false
      }
      return true
    }
    func textViewDidChange(_ textView: UITextView) {
      (textView as? Editor)?.placeholder.isHidden = !textView.text.isEmpty
      parent.text = textView.text
    }
    func textViewDidBeginEditing(_ textView: UITextView) { parent.isEditing = true }
    func textViewDidEndEditing(_ textView: UITextView) { parent.isEditing = false }
  }
  final class Editor: UITextView {
    let placeholder = UILabel()
    private weak var containingScrollView: UIScrollView?
    // Several chat editors can share one enclosing scroll view. Restore its
    // original behaviour only when the final editor releases it.
    private final class TouchDelayLease {
      let originalValue: Bool
      var users = 1
      init(originalValue: Bool) { self.originalValue = originalValue }
    }
    private static let touchDelayLeases = NSMapTable<UIScrollView, TouchDelayLease>(
      keyOptions: .weakMemory, valueOptions: .strongMemory)

    init() {
      super.init(frame: .zero, textContainer: nil)
      font = .preferredFont(forTextStyle: .body)
      adjustsFontForContentSizeCategory = true
      textContainerInset = UIEdgeInsets(top: 20, left: 12, bottom: 20, right: 12)
      layer.cornerRadius = 18
      clipsToBounds = true
      keyboardDismissMode = .interactive
      delaysContentTouches = false
      accessibilityLabel = "Moment text"
      placeholder.text = "Write about a moment in your life. In detail."
      placeholder.font = font
      placeholder.adjustsFontForContentSizeCategory = true
      placeholder.numberOfLines = 0
      placeholder.isUserInteractionEnabled = false
      placeholder.isAccessibilityElement = false
      addSubview(placeholder)
    }
    required init?(coder: NSCoder) { fatalError("Use init()") }
    override func layoutSubviews() {
      super.layoutSubviews()
      let x = textContainerInset.left + textContainer.lineFragmentPadding
      let width = max(
        0, bounds.width - x - textContainerInset.right - textContainer.lineFragmentPadding)
      placeholder.frame = CGRect(
        x: x, y: textContainerInset.top, width: width,
        height: placeholder.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
          .height)
    }
    override func didMoveToWindow() {
      super.didMoveToWindow()
      restoreScrollTouchDelay()
      guard window != nil else { return }
      var ancestor = superview
      while let candidate = ancestor {
        if let scroll = candidate as? UIScrollView {
          containingScrollView = scroll
          if let lease = Self.touchDelayLeases.object(forKey: scroll) {
            lease.users += 1
          } else {
            Self.touchDelayLeases.setObject(
              TouchDelayLease(originalValue: scroll.delaysContentTouches), forKey: scroll)
          }
          scroll.delaysContentTouches = false
          break
        }
        ancestor = candidate.superview
      }
    }
    func restoreScrollTouchDelay() {
      if let scroll = containingScrollView,
        let lease = Self.touchDelayLeases.object(forKey: scroll)
      {
        lease.users -= 1
        if lease.users == 0 {
          scroll.delaysContentTouches = lease.originalValue
          Self.touchDelayLeases.removeObject(forKey: scroll)
        }
      }
      containingScrollView = nil
    }
  }
}
