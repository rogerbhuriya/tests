import XCTest

@testable import Lexical

@MainActor
final class TextTransformBoundsTests: XCTestCase {
  func testDocumentedTransformReachesInvalidCharacterIndex() throws {
    let theme = Theme()
    theme.root = [
      .textTransform: TextTransform.uppercase.rawValue
    ]

    let view = LexicalView(
      editorConfig: EditorConfig(theme: theme, plugins: []),
      featureFlags: FeatureFlags())
    view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)

    try view.textView.editor.update {
      guard let root = getRoot() else {
        XCTFail("missing root")
        return
      }
      let paragraph = createParagraphNode()
      let text = createTextNode(text: "a")
      try paragraph.append([text])
      try root.append([paragraph])
    }

    XCTAssertEqual(view.textView.textStorage.length, 2)
    view.textView.layoutManager.ensureGlyphs(
      forCharacterRange: NSRange(
        location: 0,
        length: view.textView.textStorage.length))
  }
}
