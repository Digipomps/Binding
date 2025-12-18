import SwiftUI
import CellBase
import CellApple

struct SkeletonView: View {
    let element: SkeletonElement

    var body: some View {
        render(element)
    }

    private func render(_ element: SkeletonElement) -> AnyView {
        switch element {
        case .Text(let text):
            return AnyView(Text(text.text ?? "").frame(maxWidth: .infinity, alignment: .leading))
        case .Image(let image):
            let img: Image = image.name.map { Image($0) } ?? Image(systemName: "photo")
            return AnyView(
                img
                    .if(image.resizable) { $0.resizable() }
                    .if(image.scaledToFit) { $0.scaledToFit() }
                    .padding(CGFloat(image.padding ?? 0))
            )
        case .Spacer(let spacer):
            return AnyView(Spacer().frame(width: spacer.width.map { CGFloat($0) }))
        case .HStack(let h):
            return AnyView(
                HStack(alignment: .center, spacing: 8) {
                    ForEach(h.elements, id: \.id) { el in
                        render(el)
                    }
                }
            )
        case .VStack(let v):
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(v.elements, id: \.id) { el in
                        render(el)
                    }
                }
            )
        case .List(let l):
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(l.elements.enumerated()), id: \.offset) { _, val in
                        Text("\(describe(val))")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                }
            )
        case .Reference(let ref):
            return AnyView(
                CellReferenceView(skeletonReference: skeletonCellReference, userInfoValue: userInfoValue)
                    .if(skeletonCellReference.scaledToFit) { view in
                        view.scaledToFit()
                    }
                
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary, lineWidth: 1)
                    .overlay(Text("Reference: \(ref.keypath)").padding(6))
            )
        case .Object(_):
            return AnyView(Text("Object"))
        case .Button(let btn):
            return AnyView(Button(btn.label) {
                Task { _ = await btn.execute() }
            })
        }
    }

    private func describe(_ value: ValueType) -> String {
        (try? value.jsonString()) ?? "null"
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
