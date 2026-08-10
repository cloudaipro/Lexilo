import SwiftUI

enum LexiloTheme {
    static let paper = Color(red: 0.984, green: 0.969, blue: 0.950)
    static let paperDeep = Color(red: 0.946, green: 0.922, blue: 0.886)
    static let ink = Color(red: 0.075, green: 0.118, blue: 0.188)
    static let sage = Color(red: 0.356, green: 0.514, blue: 0.455)
    static let sageLight = Color(red: 0.855, green: 0.902, blue: 0.870)
    static let brass = Color(red: 0.647, green: 0.469, blue: 0.246)
    static let muted = Color(red: 0.390, green: 0.400, blue: 0.405)
    static let danger = Color(red: 0.624, green: 0.278, blue: 0.239)
}

extension Font {
    static func lexiloDisplay(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct PaperBackground: View {
    var body: some View {
        LexiloTheme.paper
            .overlay {
                Canvas { context, size in
                    for index in 0..<75 {
                        let x = CGFloat((index * 47) % 101) / 101 * size.width
                        let y = CGFloat((index * 83) % 107) / 107 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(LexiloTheme.brass.opacity(0.045)))
                    }
                }
            }
            .ignoresSafeArea()
    }
}

struct PressableScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

