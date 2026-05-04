import SwiftUI
import Tessera

struct PlanView: View {
    let response: AgentResponse

    @State private var showToast = false
    @State private var toastTask: Task<Void, Never>?

    private struct Exercise: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
    }

    /// Canonical workout plan from SPEC §3.
    private let exercises: [Exercise] = [
        .init(name: "Back Squat",            detail: "4 × 5 @ 85%"),
        .init(name: "Romanian Deadlift",     detail: "3 × 8 @ 70%"),
        .init(name: "Bulgarian Split Squat", detail: "3 × 10 each leg"),
        .init(name: "Cooldown",              detail: "5 min Zone 2")
    ]

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
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.element) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's plan")
                    .heading27Style()
                Spacer()
                PillLabel(text: "Recovery 72", systemImage: "heart.fill", variant: .filled)
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
            ForEach(exercises) { ex in
                exerciseRow(ex)
            }
        }
    }

    private func exerciseRow(_ ex: Exercise) -> some View {
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
            PillLabel(text: "0 bytes left your device",
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
        .shadow(color: Color(red: 97/255, green: 110/255, blue: 124/255).opacity(0.114),
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
}
