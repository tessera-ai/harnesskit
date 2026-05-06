import SwiftUI
import Tessera

struct HomeView: View {
    @State private var isLoading = false
    @State private var planResponse: AgentResponse?
    @State private var showPlan = false
    @State private var errorMessage: String?

    @State private var traceLines: [TraceLine] = []
    @State private var animationDone = false
    @State private var pendingResult: Result<AgentResponse, Error>?

    @AppStorage("healthKitAuthorized") private var healthKitAuthorized = false
    @State private var isRequestingPermission = false
    @State private var showPermissionDenied = false

    /// One streaming trace-event line shown during the on-device "thinking"
    /// phase. Mirrors the cadence of the SPEC §3 canonical run.
    fileprivate struct TraceLine: Identifiable, Equatable {
        let id = UUID()
        let symbol: String
        let text: String
        let symbolColor: Color
    }

    /// Scripted trace lines (timing in seconds, monospaced text). Total
    /// animation duration ~5s. Symbols are SF Symbols (filled).
    private static let scriptedLines: [(delay: Double, line: TraceLine)] = [
        (
            0.3,
            TraceLine(
                symbol: "arrow.right.circle.fill",
                text: "HealthKit.read · HRV, Sleep, RHR",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            0.9,
            TraceLine(
                symbol: "checkmark.circle.fill",
                text: "Recovery 72 / 100",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            1.5,
            TraceLine(
                symbol: "arrow.right.circle.fill",
                text: "HealthKit.read · Active Energy 7d",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            2.1,
            TraceLine(
                symbol: "checkmark.circle.fill",
                text: "Load -8% vs last week",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            2.7,
            TraceLine(
                symbol: "arrow.right.circle.fill",
                text: "HealthKit.read · VO₂ Max",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            3.3,
            TraceLine(
                symbol: "checkmark.circle.fill",
                text: "VO₂ 47.2 · Zone-2 130-145 bpm",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            3.9,
            TraceLine(
                symbol: "arrow.right.circle.fill",
                text: "WorkoutKit.schedule",
                symbolColor: Color.luminescentViolet
            )
        ),
        (
            4.6,
            TraceLine(
                symbol: "checkmark.circle.fill",
                text: "1.2s on-device · 0 bytes egressed",
                symbolColor: Color.luminescentViolet
            )
        ),
    ]

    private static let animationFinishDelay: Double = 5.2

    var body: some View {
        NavigationStack {
            ZStack {
                Color.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Hero
                    VStack(spacing: Spacing.element) {
                        Text("Forge")
                            .font(.system(size: 53, weight: .heavy, design: .default))
                            .tracking(-0.44)
                            .foregroundStyle(Color.graphite)

                        Text("AI strength coach")
                            .font(.subheading19)
                            .tracking(-0.32)
                            .foregroundStyle(Color.slate)
                    }

                    Spacer()

                    // CTA + status
                    VStack(spacing: Spacing.element) {
                        if healthKitAuthorized {
                            traceStack
                                .frame(height: 220, alignment: .topLeading)

                            Button {
                                Task { await runCoach() }
                            } label: {
                                Text(isLoading ? "Planning…" : "Plan today's workout")
                            }
                            .buttonStyle(.primaryCTA)
                            .disabled(isLoading)
                        } else {
                            permissionCard
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.slate)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Footer
                    PillLabel(
                        text: "Powered by Tessera AI · on-device",
                        systemImage: "bolt.fill",
                        variant: .subtle
                    )
                    .padding(.bottom, Spacing.group)
                }
                .animation(.easeInOut(duration: 0.18), value: isLoading)
            }
            .navigationDestination(isPresented: $showPlan) {
                if let planResponse {
                    PlanView(response: planResponse)
                }
            }
        }
        .tint(.luminescentViolet)
        .task {
            // On first launch, healthKitAuthorized defaults to false,
            // showing the permission card. Once granted, it persists
            // via @AppStorage. We don't re-check actual HK status because
            // Apple doesn't expose read-grant state — the "asked once"
            // pattern is the standard HealthKit workaround.
            if ProcessInfo.processInfo.arguments.contains("--auto-demo") {
                healthKitAuthorized = true
                try? await Task.sleep(nanoseconds: 800_000_000)
                await runCoach()
            }
        }
        .alert("Health Access Required", isPresented: $showPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Forge needs access to your Health data to personalize workout plans. Please enable Health in Settings."
            )
        }
    }

    // MARK: - Permission card

    private var permissionCard: some View {
        VStack(spacing: Spacing.element) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.luminescentViolet)

            Text("Connect Apple Health")
                .font(.subheading19)
                .tracking(-0.32)
                .foregroundStyle(Color.graphite)

            Text(
                "Forge reads your recovery metrics — HRV, sleep, resting heart rate — and schedules workouts to keep everything in one place."
            )
            .font(.body16)
            .tracking(-0.26)
            .foregroundStyle(Color.slate)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)

            Button {
                requestHealthKitPermission()
            } label: {
                Text(isRequestingPermission ? "Authorizing…" : "Grant Health Access")
            }
            .buttonStyle(.primaryCTA)
            .disabled(isRequestingPermission)
        }
        .softCard(padding: Spacing.group)
    }

    // MARK: - HealthKit permission

    private func requestHealthKitPermission() {
        isRequestingPermission = true
        errorMessage = nil
        Task {
            do {
                let granted = try await HealthStoreManager.shared.requestAuthorization()
                healthKitAuthorized = granted
                if !granted {
                    showPermissionDenied = true
                }
            } catch {
                errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            }
            isRequestingPermission = false
        }
    }

    // MARK: - Trace stack

    private var traceStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(traceLines) { line in
                HStack(spacing: 10) {
                    Image(systemName: line.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(line.symbolColor)
                    Text(line.text)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(-0.2)
                        .foregroundStyle(Color.indigoOutline)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    // MARK: - Run

    private func runCoach() async {
        errorMessage = nil
        traceLines = []
        animationDone = false
        pendingResult = nil
        isLoading = true

        // Kick off the real agent.run() in parallel with the animation. We
        // don't gate navigation on its latency — the canonical animation
        // (~5s) is the long pole. Result lands in `pendingResult`.
        // In --auto-demo mode (used to record the marketing video) we
        // short-circuit to the canonical fixture so timing is deterministic
        // and we don't depend on Foundation Models cold-start latency.
        let isAutoDemo = ProcessInfo.processInfo.arguments.contains("--auto-demo")
        let runTask = Task<Result<AgentResponse, Error>, Never> {
            if isAutoDemo {
                return .success(CanonicalRun.makeResponse())
            }
            do {
                let resp = try await Coach.agent.run("Plan my workout for today")
                return .success(resp)
            } catch {
                return .failure(error)
            }
        }

        // Stream the scripted trace lines.
        for (delay, line) in Self.scriptedLines {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.25)) {
                traceLines.append(line)
            }
        }

        // Hold for the rest of the animation window.
        let elapsed = Self.scriptedLines.last?.delay ?? 0
        let remaining = Self.animationFinishDelay - elapsed
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        animationDone = true

        // Wait for the real agent.run() to land (typically faster than
        // the animation, but we await it for correctness).
        let result = await runTask.value
        pendingResult = result

        // Decide: navigate or surface error.
        switch result {
        case .success(let response):
            planResponse = response
            showPlan = true
            isLoading = false
            traceLines = []
        case .failure(let error):
            errorMessage = "Couldn't plan workout. \(error.localizedDescription)"
            isLoading = false
            traceLines = []
        }
    }
}

#Preview {
    HomeView()
}
