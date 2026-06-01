import SwiftUI

/// Profile & stats sheet: surfaces the persisted gamification + onboarding data, lets the
/// user switch the learning language, and restart onboarding.
public struct ProfileView: View {
    private let store: AppStore
    private let currentLanguage: TargetLanguage
    private let onSwitchLanguage: (TargetLanguage) -> Void
    private let onRestartOnboarding: () -> Void
    private let onClose: () -> Void

    public init(
        store: AppStore,
        currentLanguage: TargetLanguage,
        onSwitchLanguage: @escaping (TargetLanguage) -> Void,
        onRestartOnboarding: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.currentLanguage = currentLanguage
        self.onSwitchLanguage = onSwitchLanguage
        self.onRestartOnboarding = onRestartOnboarding
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    heroStats
                    statsSection
                    if let profile = store.userProfile() {
                        profileSection(profile)
                    }
                    languageSwitcher
                    restartButton
                }
                .padding(20)
            }
        }
        .background(OnboardingTheme.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Text("Profil")
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: Hero

    private var heroStats: some View {
        HStack(spacing: 12) {
            heroPill(icon: "flame.fill", value: "\(store.streak)", label: "Seri", tint: OnboardingTheme.coral)
            heroPill(icon: "star.circle.fill", value: "\(store.xp)", label: "XP", tint: OnboardingTheme.teal)
            heroPill(icon: "heart.fill", value: "\(store.availableHearts())", label: "Can", tint: OnboardingTheme.coral)
        }
    }

    private func heroPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(OnboardingTheme.ink)
            Text(label).font(.caption).foregroundStyle(OnboardingTheme.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
    }

    // MARK: Stats

    private var statsSection: some View {
        section(title: "İstatistikler") {
            infoRow(icon: "checkmark.seal.fill", label: "Tamamlanan durak", value: "\(store.completedStopCount)")
            infoRow(icon: "star.fill", label: "Toplam yıldız", value: "\(store.totalStars)")
        }
    }

    // MARK: Profile

    private func profileSection(_ profile: UserProfile) -> some View {
        section(title: "Profilin") {
            if let target = profile.targetLanguage {
                infoRow(icon: "globe", label: "Öğrenilen dil", value: "\(target.flag) \(target.title)")
            }
            if let native = profile.nativeLanguage {
                infoRow(icon: "character.bubble", label: "Ana dil", value: "\(native.flag) \(native.title)")
            }
            if let age = profile.ageRange {
                infoRow(icon: "person.fill", label: "Yaş", value: age.title)
            }
            if let goal = profile.dailyGoal {
                infoRow(icon: "clock.fill", label: "Günlük hedef", value: goal.title)
            }
            if !profile.learningPurposes.isEmpty {
                infoRow(icon: "target", label: "Amaç", value: "\(profile.learningPurposes.count) sebep")
            }
            if !profile.learningStyles.isEmpty {
                infoRow(icon: "sparkles", label: "Öğrenme stili", value: "\(profile.learningStyles.count) seçim")
            }
        }
    }

    // MARK: Language switcher

    private var languageSwitcher: some View {
        section(title: "Dil değiştir") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TargetLanguage.allCases) { language in
                    Button { onSwitchLanguage(language) } label: {
                        HStack(spacing: 8) {
                            Text(language.flag).font(.title3)
                            Text(language.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(language == currentLanguage ? .white : OnboardingTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(language == currentLanguage ? OnboardingTheme.teal : OnboardingTheme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(language == currentLanguage ? OnboardingTheme.ink : OnboardingTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var restartButton: some View {
        Button(action: onRestartOnboarding) {
            Text("Onboarding'i tekrar gör")
                .font(.headline.bold())
                .foregroundStyle(OnboardingTheme.coral)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OnboardingTheme.coral.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: Building blocks

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
            VStack(spacing: 8) { content() }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.teal)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.7))
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
    }
}
