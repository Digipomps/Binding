import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
final class SkeletonEditorFloatingPanelsController {
#if os(macOS)
    private enum PanelSide {
        case left
        case center
        case right
    }

    private var componentsPanel: NSPanel?
    private var elementsPanel: NSPanel?
    private var modifiersPanel: NSPanel?
#endif

    func setEditing(
        _ isEditing: Bool,
        editorState: EditorState,
        componentsPanelRootView: AnyView? = nil
    ) {
#if os(macOS)
        if isEditing {
            showPanels(editorState: editorState, componentsPanelRootView: componentsPanelRootView)
        } else {
            hidePanels()
        }
#endif
    }

    func closePanels() {
#if os(macOS)
        componentsPanel?.close()
        elementsPanel?.close()
        modifiersPanel?.close()
        componentsPanel = nil
        elementsPanel = nil
        modifiersPanel = nil
#endif
    }

#if os(macOS)
    private func showPanels(editorState: EditorState, componentsPanelRootView: AnyView?) {
        if let componentsPanelRootView {
            let components = ensureComponentsPanel(rootView: componentsPanelRootView)
            components.orderFrontRegardless()
        }
        let elements = ensureElementsPanel(editorState: editorState)
        let modifiers = ensureModifiersPanel(editorState: editorState)
        elements.orderFrontRegardless()
        modifiers.orderFrontRegardless()
    }

    private func hidePanels() {
        componentsPanel?.orderOut(nil)
        elementsPanel?.orderOut(nil)
        modifiersPanel?.orderOut(nil)
    }

    private func ensureComponentsPanel(rootView: AnyView) -> NSPanel {
        if let componentsPanel {
            updatePanel(componentsPanel, rootView: rootView)
            return componentsPanel
        }
        let panel = makePanel(
            title: "Components",
            autosaveName: "SkeletonEditor.ComponentsPanel",
            size: NSSize(width: 360, height: 300),
            rootView: rootView,
            preferredSide: .center
        )
        componentsPanel = panel
        return panel
    }

    private func ensureElementsPanel(editorState: EditorState) -> NSPanel {
        if let elementsPanel {
            return elementsPanel
        }
        let panel = makePanel(
            title: "Elements",
            autosaveName: "SkeletonEditor.ElementsPanel",
            size: NSSize(width: 340, height: 520),
            rootView: AnyView(SkeletonTreePanel(editorState: editorState)),
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
            rootView: AnyView(SkeletonModifierInspectorPanel(editorState: editorState)),
            preferredSide: .right
        )
        modifiersPanel = panel
        return panel
    }

    private func makePanel(
        title: String,
        autosaveName: String,
        size: NSSize,
        rootView: AnyView,
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

    private func updatePanel(_ panel: NSPanel, rootView: AnyView) {
        if let hostingController = panel.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = rootView
        } else {
            panel.contentViewController = NSHostingController(rootView: rootView)
        }
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
        case .center:
            proposedX = anchorFrame.midX - (panelWidth / 2)
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
