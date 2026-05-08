import SwiftUI
import Tessera

struct PlanView: View {
    let response: AgentResponse

    @State private var showToast = false
    @State private var toastTask: Task<Void, Never>?

    // MARK: - Parsed from AgentResponse

    private let exercises: [CanonicalRun.Exercise]
    private let signals: HealthSignals

    struct HealthSignals {
        let recovery: String?  // e.g. "Recovery 72"
        let load: String?  // e.g. "Load -8% / 7d"
        let vo2: String?  // e.g. "VO₂ 47.2"

        static let empty = Self(recovery: nil, load: nil, vo2: nil)
    }

    init(response: AgentResponse) {
        self.response = response
        self.exercises = Self.parseExercises(from: response.trace)
        self.signals = Self.parseSignals(from: response.trace)
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.group) {
                    header
                    exerciseList
                    scheduleCTA
                    egressFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, Spacing.element)
                .padding(.bottom, Spacing.section)
            }

            if showToast {
                VStack {
                    Spacer()
                    toastView
                        .padding(.bottom, Spacing.section)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.luminescentViolet)
        .task {
            if ProcessInfo.processInfo.arguments.contains("--auto-demo") {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                showScheduledToast()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.element) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's plan")
                    .heading27Style()
                Spacer()
            }

            HStack(spacing: 8) {
                if let recovery = signals.recovery {
                    PillLabel(text: recovery, systemImage: "heart.fill", variant: .filled)
                }
                if let load = signals.load {
                    PillLabel(text: load, systemImage: "flame.fill", variant: .subtle)
                }
                if let vo2 = signals.vo2 {
                    PillLabel(text: vo2, systemImage: "lungs.fill", variant: .subtle)
                }
            }

            Text(response.text)
                .font(.body16)
                .tracking(-0.26)
                .foregroundStyle(Color.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var exerciseList: some View {
        VStack(spacing: Spacing.base) {
            ForEach(Array(exercises.enumerated()), id: \.offset) { _, ex in
                exerciseRow(ex)
            }
        }
    }

    private func exerciseRow(_ ex: CanonicalRun.Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ex.name)
                    .subheading19Style()
                Text(ex.detail)
                    .font(.body16)
                    .tracking(-0.26)
                    .foregroundStyle(Color.slate)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.slate)
        }
        .softCard(padding: Spacing.element)
    }

    private var scheduleCTA: some View {
        VStack(spacing: Spacing.element) {
            Button {
                showScheduledToast()
            } label: {
                Text("Schedule for 6 PM")
            }
            .buttonStyle(.primaryCTA)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate)
                Text("Today @ 18:00 · 45 min")
                    .font(.system(size: 13))
                    .tracking(-0.2)
                    .foregroundStyle(Color.slate)
            }
        }
    }

    private var egressFooter: some View {
        HStack {
            Spacer()
            PillLabel(
                text: "0 bytes left your device",
                systemImage: "lock.shield.fill",
                variant: .subtle)
            Spacer()
        }
    }

    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.luminescentViolet)
            Text("Scheduled · 45 min")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.26)
                .foregroundStyle(Color.graphite)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Color.softCardFill)
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.39), lineWidth: 1).blendMode(.overlay))
        .shadow(
            color: Color(red: 97 / 255, green: 110 / 255, blue: 124 / 255).opacity(0.114),
            radius: 15, x: 0, y: 4)
    }

    // MARK: - Toast lifecycle

    private func showScheduledToast() {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showToast = true
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    showToast = false
                }
            }
        }
    }

    // MARK: - Trace parsing

    private static func parseExercises(from trace: AgentTrace) -> [CanonicalRun.Exercise] {
        for event in trace.events {
            if case .toolCall(_, let tool, let argsJSON) = event,
                tool == "workoutkit_schedule"
            {
                struct Args: Decodable {
                    let exercises: [CanonicalRun.Exercise]
                }
                if let data = argsJSON.data(using: .utf8),
                    let args = try? JSONDecoder().decode(Args.self, from: data)
                {
                    return args.exercises
                }
            }
        }
        return CanonicalRun.exercises
    }

    private static func parseSignals(from trace: AgentTrace) -> HealthSignals {
        var recovery: String?
        var load: String?
        var vo2: String?

        for event in trace.events {
            guard case .toolResult(_, _, let tool, let resultJSON) = event,
                tool == "healthkit_read"
            else { continue }

            if let data = resultJSON.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {

                if json["hrv"] != nil {
                    recovery = parseRecovery(from: json)
                }
                if json["activeEnergy"] != nil {
                    load = parseLoad(from: json)
                }
                if json["vo2Max"] != nil {
                    vo2 = parseVO2(from: json)
                }
            }
        }

        guard recovery != nil || load != nil || vo2 != nil else {
            return HealthSignals(recovery: "Recovery 72", load: "Load -8% / 7d", vo2: "VO₂ 47.2")
        }
        return HealthSignals(recovery: recovery, load: load, vo2: vo2)
    }

    private static func parseRecovery(from json: [String: Any]) -> String? {
        guard let hrv = json["hrv"] as? Double,
            let sleep = json["sleep"] as? Double,
            let rhr = json["restingHeartRate"] as? Double
        else { return nil }
        let score = Int(
            min(
                max(
                    (hrv / 80) * 33 + (sleep / 8) * 33 + ((70 - rhr) / 30) * 34,
                    0), 100
            ).rounded())
        return "Recovery \(score)"
    }

    private static func parseLoad(from json: [String: Any]) -> String? {
        guard let delta = json["deltaVsPriorPct"] as? Int else { return nil }
        let sign = delta >= 0 ? "+" : ""
        return "Load \(sign)\(delta)% / 7d"
    }

    private static func parseVO2(from json: [String: Any]) -> String? {
        guard let vo2Max = json["vo2Max"] as? Double else { return nil }
        return String(format: "VO\u{2082} %.1f", vo2Max)
    }
}
