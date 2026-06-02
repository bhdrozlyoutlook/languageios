import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct OnboardingView: View {
    @State private var flow = OnboardingFlowState(
        profile: OnboardingProfile(nativeLanguage: TargetLanguage.detectFromDeviceLocale())
    )
    @State private var authMessage: String?
    @Environment(\.appEnvironment) private var env

    private let onFinish: (OnboardingProfile) -> Void

    /// `onFinish` is called with the completed profile when the user finishes the auth
    /// step. Defaults to a no-op so previews and tests can use `OnboardingView()`.
    public init(onFinish: @escaping (OnboardingProfile) -> Void = { _ in }) {
        self.onFinish = onFinish
    }

    private var canGoBack: Bool {
        flow.currentStep.rawValue > 0
    }

    public var body: some View {
        VStack(spacing: 0) {
            if flow.currentStep != .auth {
                HStack(spacing: 12) {
                    headerCircleButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "Önceki adıma dön",
                        isEnabled: canGoBack,
                        action: goBack
                    )

                    OnboardingProgressView(
                        currentIndex: flow.currentStep.rawValue,
                        totalCount: OnboardingStep.allCases.count
                    )

                    headerCircleButton(
                        systemImage: "arrow.counterclockwise",
                        accessibilityLabel: "Onboarding'i başa al",
                        isEnabled: true,
                        action: resetFlow
                    )
                }
                .padding(.bottom, 20)
            }

            currentContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if flow.currentStep != .auth {
                OnboardingPrimaryButton(
                    title: flow.currentStep == .planSummary ? "Planımı kaydet" : "Devam et",
                    isEnabled: flow.profile.canContinue(from: flow.currentStep),
                    action: advance
                )
                .frame(height: 56)
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(OnboardingTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: flow.currentStep)
        .onAppear { env.analytics.track(OnboardingFunnel.stepViewed(flow.currentStep)) }
        .onChange(of: flow.currentStep) { _, newStep in
            env.analytics.track(OnboardingFunnel.stepViewed(newStep))
        }
    }

    private func headerCircleButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? OnboardingTheme.ink : OnboardingTheme.ink.opacity(0.25))
                .frame(width: 36, height: 36)
                .background(OnboardingTheme.paper)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            isEnabled ? OnboardingTheme.ink.opacity(0.55) : OnboardingTheme.cardBorder,
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(isEnabled ? 0.08 : 0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var currentContent: some View {
        switch flow.currentStep {
        case .welcome:
            WelcomeStepView()
        case .targetLanguage:
            LanguageSelectionStepView(
                title: "Hangi dili öğrenmek istiyorsun?",
                options: TargetLanguage.allCases,
                selected: flow.profile.targetLanguage,
                animatesSelection: false
            ) { flow.profile.targetLanguage = $0 }
        case .nativeLanguage:
            LanguageSelectionStepView(
                title: "Ana dilin ne?",
                options: TargetLanguage.allCases,
                selected: flow.profile.nativeLanguage,
                animatesSelection: false
            ) { flow.profile.nativeLanguage = $0 }
        case .ageRange:
            SingleSelectionStepView(
                title: "Yaş aralığın hangisi?",
                options: AgeRange.allCases,
                selected: flow.profile.ageRange,
                titleProvider: \.title,
                subtitleProvider: \.subtitle
            ) { flow.profile.ageRange = $0 }
        case .learningPurpose:
            LearningPurposeStepView(profile: $flow.profile)
        case .currentLevel:
            LevelMultiSelectStepView(profile: $flow.profile)
        case .learningStyle:
            LearningStyleStepView(profile: $flow.profile)
        case .dailyGoal:
            SingleSelectionStepView(
                title: "Günde ne kadar çalışmak istersin?",
                options: DailyGoal.allCases,
                selected: flow.profile.dailyGoal,
                titleProvider: \.title,
                subtitleProvider: \.subtitle
            ) { flow.profile.dailyGoal = $0 }
        case .reminderTime:
            ReminderTimeStepView(profile: $flow.profile)
        case .planSummary:
            PersonalPlanSummaryView(profile: flow.profile)
        case .auth:
            AuthChoiceView(message: $authMessage) { provider in
                env.analytics.track(OnboardingFunnel.authChosen(provider: provider))
                onFinish(flow.profile)
            }
        }
    }

    private func advance() {
        guard flow.profile.canContinue(from: flow.currentStep),
              let nextStep = OnboardingStep(rawValue: flow.currentStep.rawValue + 1)
        else { return }

        if flow.currentStep == .planSummary, let reminder = flow.profile.reminderTime {
            NotificationManager.scheduleDailyReminder(
                at: reminder,
                body: notificationBody(for: flow.profile)
            )
        }

        env.analytics.track(OnboardingFunnel.stepAnswered(flow.currentStep, value: answerValue(for: flow.currentStep)))
        env.performance.measure("OnboardingAdvance") {
            flow.currentStep = nextStep
        }
    }

    /// A short, analytics-friendly summary of the answer given on a step.
    private func answerValue(for step: OnboardingStep) -> String {
        let profile = flow.profile
        switch step {
        case .targetLanguage: return profile.targetLanguage?.rawValue ?? ""
        case .nativeLanguage: return profile.nativeLanguage?.rawValue ?? ""
        case .ageRange: return profile.ageRange?.rawValue ?? ""
        case .learningPurpose: return String(profile.learningPurposes.count)
        case .currentLevel: return String(profile.currentLevels.count)
        case .learningStyle: return String(profile.learningStyles.count)
        case .dailyGoal: return profile.dailyGoal.map { String($0.rawValue) } ?? ""
        case .reminderTime: return profile.reminderTime?.formatted ?? ""
        case .welcome, .planSummary, .auth: return ""
        }
    }

    private func notificationBody(for profile: OnboardingProfile) -> String {
        let goal = profile.dailyGoal?.rawValue ?? 15
        let lang = profile.targetLanguage?.title ?? "dil"
        return "\(goal) dakikalık \(lang) dersin seni bekliyor."
    }

    private func goBack() {
        guard let previousStep = OnboardingStep(rawValue: flow.currentStep.rawValue - 1) else { return }
        authMessage = nil
        flow.currentStep = previousStep
    }

    private func resetFlow() {
        env.analytics.track(OnboardingFunnel.flowReset())
        authMessage = nil
        flow = OnboardingFlowState(
            profile: OnboardingProfile(nativeLanguage: TargetLanguage.detectFromDeviceLocale())
        )
    }
}

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 26) {
            LearningHeroIllustration()
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            VStack(spacing: 12) {
                Text("Dil öğrenmeyi hayatına taşı")
                    .font(.system(size: 40, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Gördüğün objelerden, dinlediğin şarkılardan ve konuşma pratiğinden sana özel dersler oluştur.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                WelcomeBadge(title: "Kamera", subtitle: "obje etiketi")
                WelcomeBadge(title: "AI", subtitle: "analiz")
                WelcomeBadge(title: "Müzik", subtitle: "lyrics")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LearningHeroIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(OnboardingTheme.coral.opacity(0.35))
                .frame(width: 250, height: 74)
                .rotationEffect(.degrees(-5))
                .offset(y: 82)

            VStack(spacing: -6) {
                BookLayer(width: 230, height: 46, color: OnboardingTheme.paper)
                BookLayer(width: 250, height: 48, color: OnboardingTheme.teal)
                BookLayer(width: 220, height: 44, color: OnboardingTheme.paper)
            }
            .rotationEffect(.degrees(-3))

            FloatingIcon(systemName: "camera.viewfinder", size: 56)
                .offset(x: -118, y: -46)

            FloatingIcon(systemName: "music.note.list", size: 54)
                .offset(x: 116, y: -54)

            FloatingIcon(systemName: "sparkles", size: 46)
                .offset(x: 112, y: 78)

            Image(systemName: "iphone")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(OnboardingTheme.ink)
                .offset(x: -76, y: 80)
        }
        .frame(height: 300)
        .accessibilityHidden(true)
    }
}

private struct BookLayer: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(OnboardingTheme.ink, lineWidth: 4)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(OnboardingTheme.ink)
                    .frame(width: width * 0.86, height: 4)
                    .offset(y: -9)
            }
    }
}

private struct FloatingIcon: View {
    let systemName: String
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(OnboardingTheme.paper)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(OnboardingTheme.ink, lineWidth: 4)
            }
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundStyle(OnboardingTheme.teal)
            }
    }
}

private struct WelcomeBadge: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(OnboardingTheme.ink)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LanguageSelectionStepView: View {
    let title: LocalizedStringKey
    let options: [TargetLanguage]
    let selected: TargetLanguage?
    var animatesSelection: Bool = true
    let select: (TargetLanguage) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        OnboardingOptionCard(
                            title: option.title,
                            subtitle: option.subtitle,
                            leadingText: option.flag,
                            leadingCountryCode: option.countryCode,
                            isSelected: selected == option,
                            animatesSelection: animatesSelection
                        ) {
                            select(option)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LevelMultiSelectStepView: View {
    @Binding var profile: OnboardingProfile

    private var availableLevels: [CurrentLevel] {
        profile.ageRange?.relevantLevels ?? CurrentLevel.allCases
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Şu an seviyen nasıl?")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sana uyan tüm alanları seçebilirsin.")
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.66))
                    .padding(.bottom, 2)

                VStack(spacing: 12) {
                    ForEach(availableLevels) { level in
                        OnboardingOptionCard(
                            title: level.title,
                            subtitle: level.subtitle,
                            isSelected: profile.currentLevels.contains(level),
                            animatesSelection: false
                        ) {
                            profile.toggleCurrentLevel(level)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SingleSelectionStepView<Option>: View where Option: Identifiable & Equatable {
    let title: LocalizedStringKey
    let options: [Option]
    let selected: Option?
    let titleProvider: KeyPath<Option, String>
    var subtitleProvider: KeyPath<Option, String>? = nil
    let select: (Option) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        OnboardingOptionCard(
                            title: option[keyPath: titleProvider],
                            subtitle: subtitleProvider.map { option[keyPath: $0] },
                            isSelected: selected == option,
                            animatesSelection: false
                        ) {
                            select(option)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LearningPurposeStepView: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Öğrenme amacın ne?")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sana uyan tüm sebepleri seçebilirsin.")
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.66))
                    .padding(.bottom, 2)

                VStack(spacing: 12) {
                    ForEach(LearningPurpose.allCases) { purpose in
                        OnboardingOptionCard(
                            title: purpose.title,
                            subtitle: purpose.subtitle,
                            isSelected: profile.learningPurposes.contains(purpose),
                            animatesSelection: false
                        ) {
                            profile.toggleLearningPurpose(purpose)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReminderTimeStepView: View {
    @Binding var profile: OnboardingProfile
    @State private var isTimePickerPresented = false
    @State private var draftReminderDate = Date()

    private var selectedTime: ReminderTime {
        profile.reminderTime ?? .defaultReminder
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ders hatırlatması ne zaman gelsin?")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Her gün bu saatte sana kısa bir push hatırlatma göndereceğiz.")
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.66))
                    .padding(.bottom, 4)

                Button {
                    draftReminderDate = date(from: selectedTime)
                    isTimePickerPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Text(selectedTime.formatted)
                            .font(.system(size: 88, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(OnboardingTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(OnboardingTheme.ink.opacity(0.38))
                    }
                    .frame(maxWidth: .infinity, minHeight: 178, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hatırlatma saati")
                .accessibilityValue(selectedTime.formatted)
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(
            ReminderPickerPresenter(
                isPresented: $isTimePickerPresented,
                selection: $draftReminderDate,
                onCancel: { isTimePickerPresented = false },
                onSave: saveDraftReminderTime
            )
        )
        .onAppear {
            if profile.reminderTime == nil {
                profile.reminderTime = .defaultReminder
            }
        }
    }

    private func date(from time: ReminderTime) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = time.hour
        components.minute = time.minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func reminderTime(from date: Date) -> ReminderTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ReminderTime(
            hour: components.hour ?? selectedTime.hour,
            minute: components.minute ?? selectedTime.minute
        )
    }

    private func saveDraftReminderTime() {
        profile.reminderTime = reminderTime(from: draftReminderDate)
        requestNotificationPermissionIfNeeded()
        isTimePickerPresented = false
    }

    private func requestNotificationPermissionIfNeeded() {
        Task { await NotificationManager.requestAuthorization() }
    }
}

private struct ReminderPickerPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selection: Date
    let onCancel: () -> Void
    let onSave: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $isPresented) {
            ReminderTimePickerSheet(
                selection: $selection,
                onCancel: onCancel,
                onSave: onSave
            )
            .presentationBackground(.clear)
        }
        #else
        content.sheet(isPresented: $isPresented) {
            ReminderTimePickerSheet(
                selection: $selection,
                onCancel: onCancel,
                onSave: onSave
            )
        }
        #endif
    }
}

private struct ReminderTimePickerSheet: View {
    @Binding var selection: Date
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var appeared = false

    private var formattedSelection: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selection)
        return ReminderTime(
            hour: components.hour ?? ReminderTime.defaultReminder.hour,
            minute: components.minute ?? ReminderTime.defaultReminder.minute
        )
        .formatted
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appeared ? 0.32 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss(then: onCancel) }

            card
                .padding(.horizontal, 14)
                .padding(.bottom, 5)
                .offset(y: appeared ? 0 : 48)
                .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Vazgeç") { dismiss(then: onCancel) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.7))

                Spacer()

                VStack(spacing: 2) {
                    Text("Saat seç")
                        .font(.headline)
                        .foregroundStyle(OnboardingTheme.ink)

                    Text(formattedSelection)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(OnboardingTheme.teal)
                }

                Spacer()

                Button("Kaydet") { dismiss(then: onSave) }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(OnboardingTheme.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            timePicker
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(OnboardingTheme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(OnboardingTheme.cardBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 22, x: 0, y: 10)
    }

    private func dismiss(then action: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: action)
    }

    @ViewBuilder
    private var timePicker: some View {
        #if os(iOS)
        DatePicker(
            "Hatırlatma saati",
            selection: $selection,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(height: 130)
        .clipped()
        .environment(\.locale, Locale(identifier: "tr_TR"))
        #else
        DatePicker(
            "Hatırlatma saati",
            selection: $selection,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        #endif
    }
}

private struct LearningStyleStepView: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("En çok nasıl öğrenmek istersin?")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Birden fazla seçim yapabilirsin.")
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.66))
                    .padding(.bottom, 2)

                VStack(spacing: 12) {
                    ForEach(LearningStyle.allCases) { style in
                        OnboardingOptionCard(
                            title: style.title,
                            subtitle: style.subtitle,
                            isSelected: profile.learningStyles.contains(style),
                            animatesSelection: false
                        ) {
                            profile.toggleLearningStyle(style)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PersonalPlanSummaryView: View {
    let profile: OnboardingProfile
    @State private var revealedCount = 0
    @State private var revealedChipCount = 0
    @State private var heroFinished = false

    private var heroPhrases: [String] {
        [
            String(localized: "Profilini inceliyorum..."),
            String(localized: "En verimli yolu hesaplıyorum..."),
            String(localized: "Plan hazırlanıyor..."),
            String(localized: "Planın hazır 🎉")
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader
                if heroFinished {
                    profileChipsList
                    plansSection
                }
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { triggerAnimations() }
    }

    private var heroHeader: some View {
        SequentialTypewriterText(
            phrases: heroPhrases,
            typingSpeed: 0.01,
            holdDuration: 0.08,
            settleOnLast: true,
            onComplete: {
                withAnimation(.easeOut(duration: 0.24)) {
                    heroFinished = true
                }
            }
        )
        .font(.system(size: 30, weight: .black, design: .serif))
        .foregroundStyle(OnboardingTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var profileChipsList: some View {
        let chips = profileChips()
        return VStack(spacing: 10) {
            ForEach(chips.indices, id: \.self) { idx in
                profileChip(chips[idx])
                    .opacity(revealedChipCount > idx ? 1 : 0)
                    .offset(y: revealedChipCount > idx ? 0 : 14)
            }
        }
    }

    private func profileChip(_ chip: Chip) -> some View {
        HStack(spacing: 10) {
            Image(systemName: chip.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.teal)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(chip.label)
                    .font(.caption2)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.55))
                Text(chip.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1)
        )
    }

    private struct Chip { let icon: String; let label: String; let value: String }

    private func profileChips() -> [Chip] {
        var result: [Chip] = []
        if let lang = profile.targetLanguage {
            result.append(.init(icon: "globe", label: String(localized: "Hedef dil"), value: "\(lang.flag) \(lang.title)"))
        }
        if let age = profile.ageRange {
            result.append(.init(icon: "person.fill", label: String(localized: "Yaş"), value: age.title))
        }
        if let goal = profile.dailyGoal {
            result.append(.init(icon: "clock.fill", label: String(localized: "Günlük hedef"), value: goal.title))
        }
        if !profile.learningPurposes.isEmpty {
            let count = profile.learningPurposes.count
            result.append(.init(icon: "target", label: String(localized: "Amaç"), value: String(localized: "\(count) sebep")))
        }
        return result
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eğitim Planınız")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
                .padding(.top, 4)

            VStack(spacing: 12) {
                ForEach(Array(profile.planCards.enumerated()), id: \.element.id) { idx, card in
                    PlanCardRow(
                        card: card,
                        icon: planIcon(for: card.id),
                        commentary: aiCommentary(for: card.id),
                        startTyping: revealedCount > idx
                    )
                    .opacity(revealedCount > idx ? 1 : 0)
                    .offset(y: revealedCount > idx ? 0 : 16)
                }
            }
        }
    }

    private func planIcon(for id: String) -> String {
        switch id {
        case "camera": "camera.fill"
        case "music": "music.note"
        case "voice": "mic.fill"
        case "ai": "sparkles"
        case "lessons": "book.fill"
        case "goal": "target"
        default: "checkmark.seal.fill"
        }
    }

    private func aiCommentary(for id: String) -> String {
        let goalMin = profile.dailyGoal?.rawValue ?? 15
        switch id {
        case "camera":
            return String(localized: "Günde 5-7 obje etiketleyerek 1 ay sonra ~150 yeni kelime ekleyebilirsin. Görsel hafızan en güçlü öğrenme yolun.")
        case "music":
            return String(localized: "Haftada 2-3 sevdiğin şarkıyı birlikte inceleyelim. Her şarkıdan ortalama 8-10 günlük ifade çıkar.")
        case "voice":
            return String(localized: "Günlük \(goalMin) dakikanın 3-5'i sesli pratik. Telaffuzun ve dinleme kasın ay sonu belirgin gelişir.")
        case "ai":
            return String(localized: "Yazdığın her cümle AI analiziyle anında geri dönüş alır. Tekrar eden hataların kişisel bir öğrenme listesi olur.")
        case "lessons":
            return String(localized: "\(goalMin) dakikalık konsantre seanslarla 3 ay sonra temel sohbet, 6 ay sonra rahat ifade seviyesine ulaşırsın.")
        case "goal":
            return String(localized: "Tutarlı \(goalMin) dakika = haftada ~\(goalMin * 7) dk = ay sonu ciddi mesafe. Küçük adımlar büyük fark yaratır.")
        default:
            return String(localized: "Bu seçim, planının önemli bir parçası.")
        }
    }

    private func triggerAnimations() {
        revealedCount = 0
        revealedChipCount = 0
        heroFinished = false
        Task { @MainActor in
            while !heroFinished {
                try? await Task.sleep(for: .milliseconds(80))
            }
            let chips = profileChips()
            for i in 0..<chips.count {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    revealedChipCount = i + 1
                }
                try? await Task.sleep(for: .milliseconds(40))
            }
            try? await Task.sleep(for: .milliseconds(40))
            for i in 0..<profile.planCards.count {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    revealedCount = i + 1
                }
                try? await Task.sleep(for: .milliseconds(55))
            }
        }
    }
}

private struct PlanCardRow: View {
    let card: PlanCard
    let icon: String
    let commentary: String
    let startTyping: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.teal.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.teal)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(OnboardingTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                OneShotTypewriterText(
                    text: commentary,
                    charDelay: 0.003,
                    start: startTyping
                )
                .font(.caption)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

private struct SequentialTypewriterText: View {
    let phrases: [String]
    var typingSpeed: Double = 0.05
    var holdDuration: Double = 0.6
    var settleOnLast: Bool = true
    var onComplete: () -> Void = {}

    @State private var phraseIndex = 0
    @State private var visibleCount = 0
    @State private var task: Task<Void, Never>?

    private var currentPhrase: String {
        guard !phrases.isEmpty else { return "" }
        return phrases[min(phraseIndex, phrases.count - 1)]
    }

    var body: some View {
        let prefix = String(currentPhrase.prefix(visibleCount))
        Text(prefix)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .onAppear { start() }
            .onDisappear { task?.cancel() }
    }

    private func start() {
        task?.cancel()
        task = Task { @MainActor in
            guard !phrases.isEmpty else { return }
            for (idx, phrase) in phrases.enumerated() {
                phraseIndex = idx
                visibleCount = 0
                for c in 1...phrase.count {
                    visibleCount = c
                    try? await Task.sleep(for: .milliseconds(Int(typingSpeed * 1000)))
                }
                let isLast = idx == phrases.count - 1
                if isLast && settleOnLast {
                    onComplete()
                    return
                }
                try? await Task.sleep(for: .milliseconds(Int(holdDuration * 1000)))
                for c in stride(from: phrase.count - 1, through: 0, by: -1) {
                    visibleCount = c
                    try? await Task.sleep(for: .milliseconds(Int((typingSpeed * 1000) / 2)))
                }
            }
            onComplete()
        }
    }
}

private struct OneShotTypewriterText: View {
    let text: String
    var charDelay: Double = 0.02
    var start: Bool

    @State private var visibleCount = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        Text(String(text.prefix(visibleCount)))
            .onChange(of: start) { _, newValue in
                if newValue { run() }
            }
            .onAppear {
                if start { run() }
            }
            .onDisappear {
                task?.cancel()
            }
    }

    private func run() {
        task?.cancel()
        visibleCount = 0
        task = Task { @MainActor in
            for c in 1...text.count {
                visibleCount = c
                try? await Task.sleep(for: .milliseconds(Int(charDelay * 1000)))
            }
        }
    }
}

private struct AuthChoiceView: View {
    @Binding var message: String?
    let onContinue: (String) -> Void
    @Environment(\.appEnvironment) private var env

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            TypewriterTitleView(texts: [String(localized: "Dinleyerek öğren"), String(localized: "Yabancı arkadaşlar edin")])

            Text("İlerlemen, etiketlerin ve öğrenme geçmişin hesabında saklanır.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.68))
                .padding(.horizontal, 18)

            Spacer()

            VStack(spacing: 14) {
                #if canImport(AuthenticationServices)
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                #else
                AuthProviderButton(
                    logo: .apple,
                    title: "Apple ile devam et",
                    style: .primary
                ) { onContinue("apple") }
                #endif

                AuthProviderButton(
                    logo: .google,
                    title: "Google ile devam et",
                    style: .secondary
                ) { onContinue("google") }

                AuthProviderButton(
                    logo: .symbol("envelope.fill"),
                    title: "E-posta ile devam et",
                    style: .secondary
                ) { onContinue("email") }

                AuthProviderButton(
                    logo: .symbol("person.crop.circle.fill"),
                    title: "Zaten hesabım var",
                    style: .secondary
                ) { onContinue("existing") }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OnboardingTheme.ink.opacity(0.62))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if canImport(AuthenticationServices)
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            message = String(localized: "Apple ile giriş tamamlanamadı.")
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        try? env.settingsRepository.setAccount(
            Account(appleUserId: credential.user, displayName: name.isEmpty ? nil : name)
        )
        onContinue("apple")
    }
    #endif
}

private struct TypewriterTitleView: View {
    let texts: [String]
    @State private var phraseIndex = 0
    @State private var visibleCharacterCount = 0
    @State private var isDeleting = false
    @State private var holdTicks = 0
    @State private var showCursor = true

    private let tick = Timer.publish(every: 0.075, on: .main, in: .common).autoconnect()
    private let cursorTick = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    private var currentPhrase: String {
        guard !texts.isEmpty else { return "" }
        return texts[phraseIndex % texts.count]
    }

    private var typewriter: TypewriterText {
        TypewriterText(fullText: currentPhrase)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(typewriter.visibleText(characterCount: visibleCharacterCount))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(OnboardingTheme.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Circle()
                .fill(OnboardingTheme.ink)
                .frame(width: 26, height: 26)
                .opacity(showCursor ? 1 : 0.18)
                .offset(y: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentPhrase)
        .onAppear {
            phraseIndex = 0
            visibleCharacterCount = 0
            isDeleting = false
            holdTicks = 0
            showCursor = true
        }
        .onReceive(tick) { _ in
            advanceAnimation()
        }
        .onReceive(cursorTick) { _ in
            showCursor.toggle()
        }
    }

    private func advanceAnimation() {
        guard texts.count > 0 else { return }
        let total = typewriter.characterCount

        if isDeleting {
            if visibleCharacterCount > 0 {
                visibleCharacterCount -= 1
            } else {
                isDeleting = false
                phraseIndex = (phraseIndex + 1) % texts.count
            }
            return
        }

        if visibleCharacterCount < total {
            visibleCharacterCount += 1
            return
        }

        if texts.count == 1 { return }

        if holdTicks < 18 {
            holdTicks += 1
        } else {
            holdTicks = 0
            isDeleting = true
        }
    }
}

#Preview {
    OnboardingView()
}
