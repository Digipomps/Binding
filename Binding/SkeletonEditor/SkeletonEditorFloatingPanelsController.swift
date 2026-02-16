import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
final class SkeletonEditorFloatingPanelsController {
#if os(macOS)
    private enum PanelSide {
        case left
        case right
    }

    private var elementsPanel: NSPanel?
    private var modifiersPanel: NSPanel?
#endif

    func setEditing(_ isEditing: Bool, editorState: EditorState) {
#if os(macOS)
        if isEditing {
            showPanels(editorState: editorState)
        } else {
            hidePanels()
        }
#endif
    }

    func closePanels() {
#if os(macOS)
        elementsPanel?.close()
        modifiersPanel?.close()
        elementsPanel = nil
        modifiersPanel = nil
#endif
    }

#if os(macOS)
    private func showPanels(editorState: EditorState) {
        let elements = ensureElementsPanel(editorState: editorState)
        let modifiers = ensureModifiersPanel(editorState: editorState)
        elements.orderFrontRegardless()
        modifiers.orderFrontRegardless()
    }

    private func hidePanels() {
        elementsPanel?.orderOut(nil)
        modifiersPanel?.orderOut(nil)
    }

    private func ensureElementsPanel(editorState: EditorState) -> NSPanel {
        if let elementsPanel {
            return elementsPanel
        }
        let panel = makePanel(
            title: "Elements",
            autosaveName: "SkeletonEditor.ElementsPanel",
            size: NSSize(width: 340, height: 520),
            rootView: SkeletonTreePanel(editorState: editorState),
            preferredSide: .left
        )
        elementsPanel = panel
        return panel
    }

    private func ensureModifiersPanel(editorState: EditorState) -> NSPanel {
        if let modifiersPanel {
            return modifiersPanel
        }
        let panel = makePanel(
            title: "Modifiers",
            autosaveName: "SkeletonEditor.ModifiersPanel",
            size: NSSize(width: 380, height: 560),
            rootView: SkeletonModifierInspectorPanel(editorState: editorState),
            preferredSide: .right
        )
        modifiersPanel = panel
        return panel
    }

    private func makePanel<Content: View>(
        title: String,
        autosaveName: String,
        size: NSSize,
        rootView: Content,
        preferredSide: PanelSide
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.setFrameAutosaveName(autosaveName)

        if !panel.setFrameUsingName(autosaveName) {
            positionPanel(panel, preferredSide: preferredSide)
        }
        return panel
    }

    private func positionPanel(_ panel: NSPanel, preferredSide: PanelSide) {
        guard let anchorWindow = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let anchorFrame = anchorWindow.frame
        let visibleFrame = anchorWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchorFrame

        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let proposedY = anchorFrame.maxY - panelHeight - 72
        let y = clamped(proposedY, min: visibleFrame.minY + 20, max: visibleFrame.maxY - panelHeight - 20)

        let proposedX: CGFloat
        switch preferredSide {
        case .left:
            proposedX = anchorFrame.minX - panelWidth - 14
        case .right:
            proposedX = anchorFrame.maxX + 14
        }
        let x = clamped(proposedX, min: visibleFrame.minX + 20, max: visibleFrame.maxX - panelWidth - 20)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(maxValue, Swift.max(minValue, value))
    }
#endif
}
