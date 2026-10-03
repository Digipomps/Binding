from pathlib import Path
p=Path('CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift');s=p.read_text().replace('import SwiftUI','import SwiftUI\nimport Combine',1)
pos=s.index('private func splitCellURLLocal')
s=s[:pos]+'''private struct SkeletonComposerFocus: Equatable {
    let fieldID: UUID
    var groupID: UUID?
    let revision: Int
}

private struct SkeletonComposerFocusKey: PreferenceKey {
    static var defaultValue: SkeletonComposerFocus? { nil }
    static func reduce(value: inout SkeletonComposerFocus?, nextValue: () -> SkeletonComposerFocus?) {
        value = nextValue() ?? value
    }
}

// Match an editor to the action already declared by its configuration. Only
// the nearest group containing both is revealed; unrelated form content is not.
private func skeletonComposerFieldIDs(in elements: SkeletonElementList) -> Set<UUID> {
    func actions(in element: SkeletonElement) -> [String] {
        switch element {
        case .Button(let button): return [button.keypath]
        case .HStack(let stack): return stack.elements.flatMap { actions(in: $0) }
        case .VStack(let stack): return stack.elements.flatMap { actions(in: $0) }
        default: return []
        }
    }
    let actionKeys = Set(elements.flatMap { actions(in: $0) })
    return Set(elements.compactMap { element -> UUID? in
        guard case .TextArea(let area) = element,
              let submit = area.submitActionKeypath, !submit.isEmpty,
              actionKeys.contains(submit) else { return nil }
        return area.id
    })
}

private struct SkeletonComposerScrollFocus: ViewModifier {
    let proxy: ScrollViewProxy
    @State private var focus: SkeletonComposerFocus?
    @State private var keyboardVisible = false

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onPreferenceChange(SkeletonComposerFocusKey.self) { value in
                focus = value
                if keyboardVisible { reveal(value) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                keyboardVisible = true
                reveal(focus)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
        #else
        content
        #endif
    }

    private func reveal(_ focus: SkeletonComposerFocus?) {
        guard let groupID = focus?.groupID else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            proxy.scrollTo(groupID, anchor: .bottom)
        }
    }
}

'''+s[pos:]
needle='''                .applySkeletonModifiers(v.modifiers, defaultAlignment: .topLeading)
            )''';assert needle in s
s=s.replace(needle,'''                .applySkeletonModifiers(v.modifiers, defaultAlignment: .topLeading)
                .id(v.id)
                .transformPreference(SkeletonComposerFocusKey.self) { focus in
                    if let fieldID = focus?.fieldID, focus?.groupID == nil,
                       skeletonComposerFieldIDs(in: v.elements).contains(fieldID) {
                        focus?.groupID = v.id
                    }
                }
            )''',1)
a=s.index('        case .ScrollView(let sc):');b=s.index('        case .Section(let sec):',a);t=s[a:b]
needle='''                    ScrollView(.vertical) {
                        VStack {
                            ForEach(restElements, id: \\.id) { el in
                                render(el)
                            }
                        }
                    }
                    .applySkeletonKeyboardDismissBehavior()
                    .applySkeletonModifiers(sc.modifiers)''';assert needle in t
replacement='''                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            VStack {
                                ForEach(restElements, id: \\.id) { el in
                                    render(el)
                                }
                            }
                        }
                        .applySkeletonKeyboardDismissBehavior()
                        .modifier(SkeletonComposerScrollFocus(proxy: proxy))
                    }
                    .applySkeletonModifiers(sc.modifiers)'''
t=t.replace(needle,replacement,1);s=s[:a]+t+s[b:]
a=s.index('private struct CellTextAreaView');b=s.index('private enum RichMarkdownEditorCommand',a);t=s[a:b]
t=t.replace('    @State private var text: String = ""','    @State private var text: String = ""\n    @FocusState private var isFocused: Bool',1)
t=t.replace('''        .task(id: refreshTaskID()) { await loadInitial() }''','''        .task(id: refreshTaskID()) { await loadInitial() }
        .preference(key: SkeletonComposerFocusKey.self,
                    value: isFocused ? SkeletonComposerFocus(fieldID: skeletonTextArea.id, revision: text.hashValue) : nil)''',1)
t=t.replace('''                    TextEditor(text: binding())
                        .font(editorFont)''','''                    TextEditor(text: binding())
                        .focused($isFocused)
                        .font(editorFont)''',1)
s=s[:a]+t+s[b:];p.write_text(s)
p=Path('Binding/BindingUITests/ParityNightUITests.swift');s=p.read_text();s=s.replace('''        XCTAssertTrue(send.isHittable, "The arrow referenced by the chat must remain reachable with the keyboard visible")
        capture(app, "chat-composer-and-send-with-keyboard")''','''        capture(app, "chat-composer-and-send-with-keyboard")
        XCTAssertTrue(send.isHittable, "The arrow referenced by the chat must remain reachable with the keyboard visible")''',1);p.write_text(s)
