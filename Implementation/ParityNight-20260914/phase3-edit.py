from pathlib import Path
p=Path('CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift')
s=p.read_text()
pos=s.index('private func splitCellURLLocal')
s=s[:pos]+'''// Native defaults preserve explicit Skeleton styling while keeping controls recognizable.
private func skeletonHorizontalAlignment(_ value: String?) -> HorizontalAlignment {
    switch value {
    case "center": return .center
    case "trailing": return .trailing
    default: return .leading
    }
}

private func skeletonVerticalAlignment(_ value: String?) -> VerticalAlignment {
    switch value {
    case "top": return .top
    case "bottom": return .bottom
    default: return .center
    }
}

private struct SkeletonDefaultControlChrome: ViewModifier {
    let modifiers: SkeletonModifiers?

    func body(content: Content) -> some View {
        if modifiers?.background == nil && (modifiers?.borderWidth ?? 0) <= 0 {
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
        } else {
            content
        }
    }
}

'''+s[pos:]
s=s.replace('func applySkeletonModifiers(_ modifiers: SkeletonModifiers?) -> AnyView {','func applySkeletonModifiers(_ modifiers: SkeletonModifiers?, defaultAlignment: Alignment = .center) -> AnyView {',1)
s=s.replace('default: return .center } }\n        func mapV','default: return defaultAlignment } }\n        func mapV',1)
s=s.replace('case "bottom": return .bottom; default: return .center } }','case "bottom": return .bottom; default: return defaultAlignment } }',1)
s=s.replace('HStack(alignment: .center, spacing: h.spacing','HStack(alignment: skeletonVerticalAlignment(h.modifiers?.vAlignment), spacing: h.spacing',1)
s=s.replace('''                .frame(maxWidth: .infinity, alignment: .center)
                .applySkeletonModifiers(h.modifiers)''','''                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: skeletonHorizontalAlignment(h.modifiers?.hAlignment), vertical: .center))
                .applySkeletonModifiers(h.modifiers, defaultAlignment: .leading)''',1)
s=s.replace('VStack(alignment: .center, spacing: v.spacing','VStack(alignment: skeletonHorizontalAlignment(v.modifiers?.hAlignment), spacing: v.spacing',1)
s=s.replace('''                .frame(maxWidth: .infinity, alignment: .center)
                .applySkeletonModifiers(v.modifiers)''','''                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: skeletonHorizontalAlignment(v.modifiers?.hAlignment), vertical: .top))
                .applySkeletonModifiers(v.modifiers, defaultAlignment: .topLeading)''',1)
s=s.replace('''                VStack(alignment: .center, spacing: 8) {
                    if let header = sec.header { render(header) }''','''                VStack(alignment: skeletonHorizontalAlignment(sec.modifiers?.hAlignment), spacing: 8) {
                    if let header = sec.header { render(header).font(.headline).padding(.bottom, 4) }''',1)
s=s.replace('''                .applySkeletonModifiers(sec.modifiers)''','''                .frame(maxWidth: .infinity, alignment: .leading)
                .applySkeletonModifiers(sec.modifiers, defaultAlignment: .topLeading)''',1)
# Text should have an intrinsic width; otherwise badges and HStack labels consume equal half-widths.
a=s.index('private struct CellTextView: View');b=s.index('private struct CellActionButtonView',a)
t=s[a:b].replace('            .frame(maxWidth: .infinity, alignment: .center)\n','',1);s=s[:a]+t+s[b:]
# Style the button label so its padding and background are inside the actual hit region.
s=s.replace('''                CellActionButtonView(skeletonButton: resolvedButton, userInfoValue: userInfoValue)
                    .applySkeletonModifiers(resolvedButton.modifiers)''','''                CellActionButtonView(skeletonButton: resolvedButton, userInfoValue: userInfoValue)''',1)
a=s.index('private struct CellActionButtonView');b=s.index('    private var actionID:',a);t=s[a:b]
t=t.replace('''            }
        }
        .buttonStyle(.plain)''','''            }
            .modifier(SkeletonDefaultControlChrome(modifiers: skeletonButton.modifiers))
            .applySkeletonModifiers(skeletonButton.modifiers)
            .contentShape(RoundedRectangle(cornerRadius: CGFloat(skeletonButton.modifiers?.cornerRadius ?? 8)))
        }
        .buttonStyle(.plain)''',1);s=s[:a]+t+s[b:]
# Unstyled fields have native chrome; explicit configuration chrome is left in control.
a=s.index('private struct CellTextFieldView');b=s.index('private struct CellTextAreaView',a);t=s[a:b]
t=t.replace('                .focused($isFocused)','                .textFieldStyle(.plain)\n                .modifier(SkeletonDefaultControlChrome(modifiers: skeletonTextField.modifiers))\n                .focused($isFocused)',1)
x=t.index('        // seed from userInfoValue if available');y=t.index('        // then try to fetch from remote',x)
t=t[:x]+'''        if let context = userInfoValue, let key = skeletonTextField.sourceKeypath,
           !key.hasPrefix("cell://") {
            text = skeletonEditableStringValue(context[key]) ?? ""
            return
        }
        if text.isEmpty, skeletonTextField.sourceKeypath == nil {
            text = skeletonTextField.text ?? ""
        }
'''+t[y:];s=s[:a]+t+s[b:]
a=s.index('private struct CellTextAreaView');b=s.index('private enum RichMarkdownEditorCommand',a);t=s[a:b]
t=t.replace('''        .frame(maxWidth: .infinity, alignment: .center)''','''        .modifier(SkeletonDefaultControlChrome(modifiers: skeletonTextArea.modifiers))
        .frame(maxWidth: .infinity, alignment: .leading)''',1)
x=t.index('    private var plainEditorBody: some View {');y=t.index('    #if os(macOS)\n    private func richToolbarButton',x)
t=t[:x]+'''    private var editorFont: Font {
        if let size = skeletonTextArea.modifiers?.fontSize {
            return .system(size: CGFloat(size), weight: weightFrom(skeletonTextArea.modifiers?.fontWeight))
        }
        return fontFromStyle(skeletonTextArea.modifiers?.fontStyle ?? "body")
    }

    private var plainEditorBody: some View {
        // The measuring text sets the viewport, while TextEditor retains editing,
        // selection and scrolling. A short draft no longer fills all spare height.
        Text(text.isEmpty ? " " : text)
            .font(editorFont)
            .lineLimit(skeletonTextArea.maxLines.map { max(1, $0) })
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: minHeight(), maxHeight: maxHeight(), alignment: .topLeading)
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty, !localizedPlaceholder.isEmpty {
                        Text(localizedPlaceholder)
                            .font(editorFont)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: binding())
                        .font(editorFont)
                        .scrollContentBackground(.hidden)
                        .applyIf(skeletonTextArea.modifiers?.foregroundColor != nil && Color(hex: skeletonTextArea.modifiers?.foregroundColor ?? "") != nil) { v in
                            v.foregroundColor(Color(hex: skeletonTextArea.modifiers?.foregroundColor ?? "")!)
                        }
                }
            }
    }

'''+t[y:]
x=t.index('        if text.isEmpty, let key = skeletonTextArea.sourceKeypath');y=t.index('        guard let resolver',x)
t=t[:x]+'''        if let context = userInfoValue, let key = skeletonTextArea.sourceKeypath,
           !key.hasPrefix("cell://") {
            text = skeletonEditableStringValue(context[key]) ?? ""
            return
        }
        if text.isEmpty, skeletonTextArea.sourceKeypath == nil {
            text = skeletonTextArea.text ?? ""
        }

'''+t[y:];s=s[:a]+t+s[b:]
p.write_text(s)
# Expose the existing viewmodel dependency without changing the production default.
p=Path('Binding/Binding/FullLibraryView.swift');s=p.read_text();s=s.replace('''        onComponentDragStateChange: ((ComponentPaletteItem?) -> Void)? = nil
    ) {''','''        onComponentDragStateChange: ((ComponentPaletteItem?) -> Void)? = nil,
        bootstrapRuntime: @escaping (Bool) async -> BindingAuthenticatedRuntimeAttempt.Outcome = {
            await BindingRuntimeBootstrap.requestAuthenticatedRuntime(retryAfterFailure: $0)
        }
    ) {''',1);s=s.replace('''                fallbackTemplates: templates
            )''','''                fallbackTemplates: templates,
                bootstrapRuntime: bootstrapRuntime
            )''',1);p.write_text(s)
