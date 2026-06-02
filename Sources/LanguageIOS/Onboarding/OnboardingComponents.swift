import SwiftUI
#if canImport(FlagKit)
import FlagKit
#endif

enum OnboardingTheme {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let ink = Color(red: 0.05, green: 0.05, blue: 0.04)
    static let teal = Color(red: 0.50, green: 0.72, blue: 0.72)
    static let coral = Color(red: 1.0, green: 0.48, blue: 0.42)
    static let paper = Color.white
    static let disabled = Color(red: 0.84, green: 0.82, blue: 0.77)
    static let cardBorder = Color(red: 0.82, green: 0.79, blue: 0.72)
}

struct OnboardingProgressView: View {
    let currentIndex: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? OnboardingTheme.ink : OnboardingTheme.ink.opacity(0.14))
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentIndex + 1) of \(totalCount)")
    }
}

struct OnboardingOptionCard: View {
    let title: String
    let subtitle: String?
    let leadingText: String?
    let leadingCountryCode: String?
    let isSelected: Bool
    let animatesSelection: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        leadingText: String? = nil,
        leadingCountryCode: String? = nil,
        isSelected: Bool,
        animatesSelection: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingText = leadingText
        self.leadingCountryCode = leadingCountryCode
        self.isSelected = isSelected
        self.animatesSelection = animatesSelection
        self.action = action
    }

    private var hasFlag: Bool {
        leadingCountryCode != nil || leadingText != nil
    }

    private var chipGrows: Bool { isSelected && animatesSelection }
    private var chipWidth: CGFloat { chipGrows ? 62 : 44 }
    private var chipHeight: CGFloat { chipGrows ? 44 : 32 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if hasFlag {
                    leadingFlagChip
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : OnboardingTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(isSelected ? .white.opacity(0.88) : OnboardingTheme.ink.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : OnboardingTheme.cardBorder)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? OnboardingTheme.teal : OnboardingTheme.paper)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? OnboardingTheme.ink : OnboardingTheme.cardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: .black.opacity(isSelected ? 0.18 : 0.06),
                radius: isSelected ? 4 : 8,
                x: 0,
                y: isSelected ? 2 : 3
            )
            .animation(animatesSelection ? .spring(response: 0.35, dampingFraction: 0.78) : nil, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var leadingFlagChip: some View {
        #if canImport(FlagKit)
        if let leadingCountryCode, let flag = Flag(countryCode: leadingCountryCode) {
            Image(uiImage: flag.originalImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: chipWidth, height: chipHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(chipGrows ? 0.55 : 0), lineWidth: 1)
                )
        } else if let leadingText {
            Text(leadingText)
                .font(.system(size: chipGrows ? 40 : 32))
                .frame(width: chipWidth, height: chipHeight)
        }
        #else
        if let leadingText {
            Text(leadingText)
                .font(.system(size: chipGrows ? 40 : 32))
                .frame(width: chipWidth, height: chipHeight)
        }
        #endif
    }

    private var accessibilityLabel: String {
        let suffix = isSelected ? ", seçili" : ""
        if let subtitle {
            return "\(title), \(subtitle)\(suffix)"
        }
        return "\(title)\(suffix)"
    }
}

struct OnboardingPrimaryButton: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? OnboardingTheme.ink : OnboardingTheme.disabled)

                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(isEnabled ? .white : OnboardingTheme.ink.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isEnabled ? OnboardingTheme.ink : OnboardingTheme.cardBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(isEnabled ? 0.18 : 0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

enum AuthProviderLogo {
    case apple
    case google
    case symbol(String)
}

struct AuthProviderButton: View {
    enum Style {
        case primary
        case secondary

        var usesInkBackground: Bool {
            switch self {
            case .primary: true
            case .secondary: false
            }
        }
    }

    let logo: AuthProviderLogo
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                logoView
                    .frame(width: 24, height: 22)

                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(OnboardingTheme.ink, lineWidth: 1)
            }
            .shadow(color: .black.opacity(style.usesInkBackground ? 0.18 : 0.10), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var logoView: some View {
        switch logo {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.title3)
                .foregroundStyle(foreground)
        case .google:
            GoogleGLogo()
                .frame(width: 20, height: 20)
        case .symbol(let name):
            Image(systemName: name)
                .font(.title3)
                .foregroundStyle(foreground)
        }
    }

    private var backgroundColor: Color {
        style.usesInkBackground ? OnboardingTheme.ink : OnboardingTheme.paper
    }

    private var foreground: Color {
        style.usesInkBackground ? .white : OnboardingTheme.ink
    }
}

/// Authentic four-color Google "G" mark, drawn from the official logo path data
/// so it stays crisp at any size without bundling an image asset.
struct GoogleGLogo: View {
    private static let parts: [(path: String, color: Color)] = [
        // Blue
        ("M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z",
         Color(red: 66/255, green: 133/255, blue: 244/255)),
        // Green
        ("M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z",
         Color(red: 52/255, green: 168/255, blue: 83/255)),
        // Yellow
        ("M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z",
         Color(red: 251/255, green: 188/255, blue: 5/255)),
        // Red
        ("M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z",
         Color(red: 234/255, green: 67/255, blue: 53/255))
    ]

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            for part in Self.parts {
                context.fill(SVGPath.path(part.path, viewBox: 48, in: rect), with: .color(part.color))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Minimal SVG path-data parser (supports M/L/H/V/C/S and their relative forms
/// plus Z), scaled from a square viewBox into the target rect.
private enum SVGPath {
    private enum Token { case command(Character); case number(CGFloat) }

    static func path(_ data: String, viewBox: CGFloat, in rect: CGRect) -> Path {
        let tokens = scan(data)
        let scale = min(rect.width, rect.height) / viewBox
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }

        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "

        var index = 0
        func nextNumber() -> CGFloat {
            while index < tokens.count {
                defer { index += 1 }
                if case let .number(value) = tokens[index] { return value }
            }
            return 0
        }
        func nextIsNumber() -> Bool {
            if index < tokens.count, case .number = tokens[index] { return true }
            return false
        }
        func reflectedControl() -> CGPoint {
            guard let lastControl, "CcSs".contains(lastCommand) else { return current }
            return CGPoint(x: 2 * current.x - lastControl.x, y: 2 * current.y - lastControl.y)
        }

        while index < tokens.count {
            guard case let .command(raw) = tokens[index] else { index += 1; continue }
            index += 1

            if raw == "Z" || raw == "z" {
                path.closeSubpath()
                current = subpathStart
                lastControl = nil
                lastCommand = raw
                continue
            }

            var command = raw
            repeat {
                switch command {
                case "M", "m":
                    let x = command == "m" ? current.x + nextNumber() : nextNumber()
                    let y = command == "m" ? current.y + nextNumber() : nextNumber()
                    current = CGPoint(x: x, y: y)
                    subpathStart = current
                    path.move(to: point(x, y))
                    command = command == "m" ? "l" : "L"
                case "L", "l":
                    let x = command == "l" ? current.x + nextNumber() : nextNumber()
                    let y = command == "l" ? current.y + nextNumber() : nextNumber()
                    current = CGPoint(x: x, y: y)
                    path.addLine(to: point(x, y))
                case "H", "h":
                    let x = command == "h" ? current.x + nextNumber() : nextNumber()
                    current.x = x
                    path.addLine(to: point(current.x, current.y))
                case "V", "v":
                    let y = command == "v" ? current.y + nextNumber() : nextNumber()
                    current.y = y
                    path.addLine(to: point(current.x, current.y))
                case "C", "c":
                    let relative = command == "c"
                    let x1 = (relative ? current.x : 0) + nextNumber()
                    let y1 = (relative ? current.y : 0) + nextNumber()
                    let x2 = (relative ? current.x : 0) + nextNumber()
                    let y2 = (relative ? current.y : 0) + nextNumber()
                    let x = (relative ? current.x : 0) + nextNumber()
                    let y = (relative ? current.y : 0) + nextNumber()
                    path.addCurve(to: point(x, y), control1: point(x1, y1), control2: point(x2, y2))
                    lastControl = CGPoint(x: x2, y: y2)
                    current = CGPoint(x: x, y: y)
                case "S", "s":
                    let relative = command == "s"
                    let control1 = reflectedControl()
                    let x2 = (relative ? current.x : 0) + nextNumber()
                    let y2 = (relative ? current.y : 0) + nextNumber()
                    let x = (relative ? current.x : 0) + nextNumber()
                    let y = (relative ? current.y : 0) + nextNumber()
                    path.addCurve(to: point(x, y), control1: point(control1.x, control1.y), control2: point(x2, y2))
                    lastControl = CGPoint(x: x2, y: y2)
                    current = CGPoint(x: x, y: y)
                default:
                    return path
                }
                lastCommand = command
            } while nextIsNumber()
        }

        return path
    }

    private static func scan(_ data: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(data)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" {
                i += 1
                continue
            }
            if c.isLetter {
                tokens.append(.command(c))
                i += 1
                continue
            }
            var j = i
            if chars[j] == "+" || chars[j] == "-" { j += 1 }
            var seenDot = false
            while j < chars.count {
                let d = chars[j]
                if d.isNumber {
                    j += 1
                } else if d == "." {
                    if seenDot { break }
                    seenDot = true
                    j += 1
                } else {
                    break
                }
            }
            if let value = Double(String(chars[i..<j])) {
                tokens.append(.number(CGFloat(value)))
            }
            i = max(j, i + 1)
        }
        return tokens
    }
}
