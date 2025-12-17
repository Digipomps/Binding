import SwiftUI

struct SkeletonView: View {
    let element: SkeletonElement

    var body: some View {
        render(element)
    }

    @ViewBuilder
    private func render(_ element: SkeletonElement) -> some View {
        switch element {
        case .Text(let text):
            Text(text.text ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
        case .Image(let image):
            Group {
                if let name = image.name { Image(name) } else { Image(systemName: "photo") }
            }
            .resizableIfNeeded(image.resizable)
            .scaledToFitIfNeeded(image.scaledToFit)
            .padding(image.padding ?? 0)
        case .Spacer(let spacer):
            Spacer().frame(width: spacer.width)
        case .HStack(let h):
            HStack(alignment: .center, spacing: 8) {
                ForEach(h.elements, id: \.id) { render($0) }
            }
        case .VStack(let v):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(v.elements, id: \.id) { render($0) }
            }
        case .List(let l):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(l.elements.enumerated()), id: \.offset) { _, val in
                    Text("\(describe(val))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                }
            }
        case .Reference(let ref):
            // Placeholder for nested cell reference rendering
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary, lineWidth: 1)
                .overlay(Text("Reference: \(ref.keypath)").padding(6))
        case .Object(_):
            Text("Object")
        case .Button(let btn):
            Button(btn.label) {
                Task { _ = await btn.execute() }
            }
        }
    }

    private func describe(_ value: ValueType) -> String {
        (try? value.jsonString()) ?? "null"
    }
}

private extension View {
    @ViewBuilder
    func resizableIfNeeded(_ needed: Bool) -> some View {
        if needed { self.resizable() } else { self }
    }
    @ViewBuilder
    func scaledToFitIfNeeded(_ needed: Bool) -> some View {
        if needed { self.scaledToFit() } else { self }
    }
}
