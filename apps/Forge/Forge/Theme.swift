import SwiftUI

// MARK: - Stocketa color tokens

extension Color {
    /// #e0dde2 — soft warm-neutral background
    static let canvas = Color(red: 0xe0 / 255.0, green: 0xdd / 255.0, blue: 0xe2 / 255.0)

    /// #f0f0f0 — subtle surface tint
    static let ash = Color(red: 0xf0 / 255.0, green: 0xf0 / 255.0, blue: 0xf0 / 255.0)

    /// #000000 — primary text
    static let graphite = Color.black

    /// #9aa1b2 — secondary text
    static let slate = Color(red: 0x9a / 255.0, green: 0xa1 / 255.0, blue: 0xb2 / 255.0)

    /// #995bb9 — primary accent (CTA fill, headings, icons)
    static let luminescentViolet = Color(red: 0x99 / 255.0, green: 0x5b / 255.0, blue: 0xb9 / 255.0)

    /// #3a4766 — ghost button outline
    static let indigoOutline = Color(red: 0x3a / 255.0, green: 0x47 / 255.0, blue: 0x66 / 255.0)

    /// rgba(83,116,152,0.07) — soft card translucent fill
    static let softCardFill = Color(red: 83 / 255.0, green: 116 / 255.0, blue: 152 / 255.0).opacity(0.07)
}

// MARK: - Typography helpers

extension Font {
    /// Body 16, system, regular weight (apply tracking -0.26 at usage site).
    static let body16: Font = .system(size: 16, weight: .regular, design: .default)

    /// Subheading 19, weight 600 (apply tracking -0.32 at usage site).
    static let subheading19: Font = .system(size: 19, weight: .semibold, design: .default)

    /// Heading 27, weight 500 (apply tracking -0.44 at usage site).
    static let heading27: Font = .system(size: 27, weight: .medium, design: .default)

    /// Display, weight 800 — used sparingly.
    static let display: Font = .system(size: 53, weight: .heavy, design: .default)
}

extension Text {
    func body16Style() -> some View {
        self.font(.body16).tracking(-0.26).foregroundStyle(Color.graphite)
    }

    func subheading19Style() -> some View {
        self.font(.subheading19).tracking(-0.32).foregroundStyle(Color.graphite)
    }

    func heading27Style() -> some View {
        self.font(.heading27).tracking(-0.44).foregroundStyle(Color.graphite)
    }
}

// MARK: - Radii / spacing

enum Radius {
    static let card: CGFloat = 18
    static let pill: CGFloat = 100
    static let `default`: CGFloat = 22
}

enum Spacing {
    static let base: CGFloat = 8
    static let element: CGFloat = 16
    static let group: CGFloat = 32
    static let section: CGFloat = 40
}

// MARK: - Soft card modifier

struct SoftCardModifier: ViewModifier {
    var padding: CGFloat = Spacing.element

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.softCardFill)
            )
            // Layered Stocketa shadow:
            //   inset highlight (top, white 39%) – approximated via overlay stroke
            //   outer drop:  0 4px 15px rgba(97,110,124,0.114)
            //   tight drop:  0 1px 1px rgba(34,50,94,0.08)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.39), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .shadow(
                color: Color(red: 97 / 255, green: 110 / 255, blue: 124 / 255).opacity(0.114),
                radius: 15, x: 0, y: 4
            )
            .shadow(
                color: Color(red: 34 / 255, green: 50 / 255, blue: 94 / 255).opacity(0.08),
                radius: 1, x: 0, y: 1)
    }
}

extension View {
    func softCard(padding: CGFloat = Spacing.element) -> some View {
        modifier(SoftCardModifier(padding: padding))
    }
}

// MARK: - Pill primitives

enum PillVariant {
    case outline
    case filled
    case subtle
}

struct PillLabel: View {
    let text: String
    var systemImage: String? = nil
    var variant: PillVariant = .subtle

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .medium))
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(foreground)
        .background(
            Capsule().fill(background)
        )
        .overlay(
            Capsule().stroke(borderColor, lineWidth: borderWidth)
        )
    }

    private var foreground: Color {
        switch variant {
        case .outline: return .indigoOutline
        case .filled: return .white
        case .subtle: return .graphite
        }
    }

    private var background: Color {
        switch variant {
        case .outline: return .clear
        case .filled: return .luminescentViolet
        case .subtle: return .ash
        }
    }

    private var borderColor: Color {
        switch variant {
        case .outline: return .indigoOutline
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        variant == .outline ? 1 : 0
    }
}

// MARK: - Primary CTA

struct PrimaryCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.32)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 28)
            .background(
                Capsule().fill(Color.luminescentViolet)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryCTAStyle {
    static var primaryCTA: PrimaryCTAStyle { PrimaryCTAStyle() }
}

// MARK: - Thinking on-device pill

struct ThinkingPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.luminescentViolet)
            Text("Thinking on-device")
                .font(.system(size: 14, weight: .medium))
                .tracking(-0.22)
                .foregroundStyle(Color.graphite)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.softCardFill))
        .overlay(Capsule().stroke(Color.white.opacity(0.39), lineWidth: 1).blendMode(.overlay))
    }
}
