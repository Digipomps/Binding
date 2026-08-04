import SwiftUI

enum HavenBrandPalette {
    static let accent = Color(red: 83 / 255, green: 74 / 255, blue: 183 / 255)
    static let accentDark = Color(red: 112 / 255, green: 102 / 255, blue: 213 / 255)
    static let strong = Color(red: 67 / 255, green: 60 / 255, blue: 152 / 255)
    static let cream = Color(red: 255 / 255, green: 248 / 255, blue: 238 / 255)
    static let canvas = Color(red: 244 / 255, green: 239 / 255, blue: 230 / 255)
    static let darkCanvas = Color(red: 24 / 255, green: 19 / 255, blue: 35 / 255)
}

struct HavenArcMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: point(x: 0.179_687_5, y: 0.371_093_75, in: rect))
        path.addCurve(
            to: point(x: 0.820_312_5, y: 0.371_093_75, in: rect),
            control1: point(x: 0.309_570_312_5, y: 0.146_484_375, in: rect),
            control2: point(x: 0.690_429_687_5, y: 0.146_484_375, in: rect)
        )

        path.move(to: point(x: 0.179_687_5, y: 0.628_906_25, in: rect))
        path.addCurve(
            to: point(x: 0.820_312_5, y: 0.628_906_25, in: rect),
            control1: point(x: 0.309_570_312_5, y: 0.853_515_625, in: rect),
            control2: point(x: 0.690_429_687_5, y: 0.853_515_625, in: rect)
        )

        return path
    }

    private func point(x: CGFloat, y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * x),
            y: rect.minY + (rect.height * y)
        )
    }
}

struct HavenArcMark: View {
    var color: Color = HavenBrandPalette.strong

    var body: some View {
        GeometryReader { proxy in
            HavenArcMarkShape()
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: max(2, min(proxy.size.width, proxy.size.height) * 0.066_406_25),
                        lineCap: .butt,
                        lineJoin: .round
                    )
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
