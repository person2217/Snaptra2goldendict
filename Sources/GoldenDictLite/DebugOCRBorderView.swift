import SwiftUI

struct DebugOCRBorderView: View {
    let wordBoxes: [CGRect]

    static func convert(_ box: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: box.minX * size.width,
               y: (1 - box.minY - box.height) * size.height,
               width: box.width * size.width,
               height: box.height * size.height)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().stroke(Color.red, lineWidth: 3)
                ForEach(Array(wordBoxes.enumerated()), id: \.offset) { _, box in
                    let rect = Self.convert(box, in: geometry.size)
                    Rectangle()
                        .stroke(Color.green, lineWidth: 1.5)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}
