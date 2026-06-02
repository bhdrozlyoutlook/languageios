import Foundation

public enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case targetLanguage
    case nativeLanguage
    case ageRange
    case learningPurpose
    case currentLevel
    case learningStyle
    case dailyGoal
    case reminderTime
    case planSummary
    case auth

    public var id: Int { rawValue }
    public var isLast: Bool { self == Self.allCases.last }
}

public struct ReminderTime: Equatable, Hashable, Codable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    public var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static let defaultReminder = ReminderTime(hour: 19, minute: 0)
}

public enum TargetLanguage: String, CaseIterable, Identifiable, Codable {
    case englishUK
    case englishUS
    case turkish
    case german
    case spanish
    case french

    public var id: String { rawValue }

    public var title: String {
        let value: String.LocalizationValue = switch self {
        case .englishUK: "İngilizce (İngiliz)"
        case .englishUS: "İngilizce (Amerikan)"
        case .turkish: "Türkçe"
        case .german: "Almanca"
        case .spanish: "İspanyolca"
        case .french: "Fransızca"
        }
        return String(localized: value)
    }

    public var subtitle: String {
        let value: String.LocalizationValue = switch self {
        case .englishUK: "Birleşik Krallık aksanı (BBC, Oxford)"
        case .englishUS: "ABD aksanı (Hollywood, Netflix)"
        case .turkish: "Türkiye"
        case .german: "Almanya"
        case .spanish: "İspanya"
        case .french: "Fransa"
        }
        return String(localized: value)
    }

    public var flag: String {
        switch self {
        case .englishUK: "🇬🇧"
        case .englishUS: "🇺🇸"
        case .turkish: "🇹🇷"
        case .german: "🇩🇪"
        case .spanish: "🇪🇸"
        case .french: "🇫🇷"
        }
    }

    public var countryCode: String {
        switch self {
        case .englishUK: "GB"
        case .englishUS: "US"
        case .turkish: "TR"
        case .german: "DE"
        case .spanish: "ES"
        case .french: "FR"
        }
    }

    public static func from(localeIdentifier code: String) -> TargetLanguage? {
        let normalized = code.lowercased().replacingOccurrences(of: "_", with: "-")
        switch normalized {
        case "tr", "tr-tr": return .turkish
        case "de", "de-de", "de-at", "de-ch": return .german
        case "es", "es-es", "es-mx", "es-419": return .spanish
        case "fr", "fr-fr", "fr-ca": return .french
        case "en-us", "en-ca": return .englishUS
        case "en-gb", "en-au", "en-nz", "en-ie": return .englishUK
        case "en": return .englishUS
        default: return nil
        }
    }

    public static func detectFromDeviceLocale() -> TargetLanguage? {
        guard let preferred = Locale.preferredLanguages.first else { return nil }
        if let exact = from(localeIdentifier: preferred) {
            return exact
        }
        let langOnly = String(preferred.split(separator: "-").first ?? Substring(preferred))
        return from(localeIdentifier: langOnly)
    }
}

public enum CurrentLevel: String, CaseIterable, Identifiable, Hashable, Codable {
    case beginner
    case basicVocabulary
    case listening
    case reading
    case speaking
    case writing
    case advancedGrammar

    public var id: String { rawValue }

    public var title: String {
        let value: String.LocalizationValue = switch self {
        case .beginner: "Yeni başlıyorum"
        case .basicVocabulary: "Temel kelimeleri biliyorum"
        case .listening: "Sesli içerikleri anlıyorum"
        case .reading: "Yazılı metinleri okuyabiliyorum"
        case .speaking: "Günlük konularda konuşabiliyorum"
        case .writing: "Yazılı ifadeler oluşturabiliyorum"
        case .advancedGrammar: "İleri gramer ve nüansa hakimim"
        }
        return String(localized: value)
    }

    public var subtitle: String {
        let value: String.LocalizationValue = switch self {
        case .beginner:
            "A1 • Harfler, sayılar ve ilk kelimeler"
        case .basicVocabulary:
            "A2 • Selamlaşma, alışveriş ve günlük kelimeler"
        case .listening:
            "B1+ • Podcast, dizi, film ve konuşmalar"
        case .reading:
            "B1+ • Kitap, makale ve uzun mesajlar"
        case .speaking:
            "B1-B2 • Sohbet, karşılıklı konuşma, görüş"
        case .writing:
            "B1+ • E-posta, kompozisyon, mesajlaşma"
        case .advancedGrammar:
            "C1-C2 • Karmaşık yapı, nüans ve ileri ifade"
        }
        return String(localized: value)
    }
}

public enum AgeRange: String, CaseIterable, Identifiable, Codable {
    case preschool
    case primary
    case teen
    case youngAdult
    case adult
    case midAdult
    case mature

    public var id: String { rawValue }

    public var title: String {
        let value: String.LocalizationValue = switch self {
        case .preschool: "Okul öncesi (3-5 yaş)"
        case .primary: "İlkokul (6-10 yaş)"
        case .teen: "13-17"
        case .youngAdult: "18-24"
        case .adult: "25-34"
        case .midAdult: "35-49"
        case .mature: "50+"
        }
        return String(localized: value)
    }

    public var subtitle: String {
        let value: String.LocalizationValue = switch self {
        case .preschool: "Şarkı, hikaye ve görsellerle eğlenceli tanışma"
        case .primary: "Okul derslerine destek, oyun temelli aktiviteler"
        case .teen: "Okul, sınav ve sosyal medya odaklı içerik"
        case .youngAdult: "Üniversite, iş başlangıcı ve yurtdışı için"
        case .adult: "Kariyer, seyahat ve günlük hayat odaklı"
        case .midAdult: "Profesyonel iletişim, aile ve seyahat"
        case .mature: "Rahat tempo, kültür ve seyahat odaklı"
        }
        return String(localized: value)
    }

    public var relevantLevels: [CurrentLevel] {
        switch self {
        case .preschool:
            [.beginner, .listening, .speaking]
        case .primary:
            [.beginner, .basicVocabulary, .listening, .speaking, .reading, .writing]
        case .teen, .youngAdult, .adult, .midAdult, .mature:
            CurrentLevel.allCases
        }
    }
}

public enum LearningPurpose: String, CaseIterable, Identifiable, Codable {
    case travel
    case work
    case education
    case family
    case media
    case personalGrowth

    public var id: String { rawValue }

    public var title: String {
        let value: String.LocalizationValue = switch self {
        case .travel: "Seyahat"
        case .work: "İş ve kariyer"
        case .education: "Eğitim ve sınav"
        case .family: "Aile ve sosyal hayat"
        case .media: "Film, dizi, müzik"
        case .personalGrowth: "Kişisel gelişim"
        }
        return String(localized: value)
    }

    public var subtitle: String {
        let value: String.LocalizationValue = switch self {
        case .travel:
            "Yurt dışı tatil ve gezilerde rahat iletişim"
        case .work:
            "İş hayatı, iş başvuruları, profesyonel iletişim"
        case .education:
            "Okul, akademik çalışma, dil sınavları (TOEFL, IELTS)"
        case .family:
            "Sevdiklerimle ve arkadaşlarımla iletişim"
        case .media:
            "Altyazısız film/dizi izle, şarkı sözlerini anla"
        case .personalGrowth:
            "Hobi, kültür, beyin egzersizi"
        }
        return String(localized: value)
    }
}

public enum LearningStyle: String, CaseIterable, Identifiable, Codable {
    case cameraObjects
    case musicLyrics
    case speakingPractice
    case dailyLessons
    case aiExplanations

    public var id: String { rawValue }

    public var title: String {
        let value: String.LocalizationValue = switch self {
        case .cameraObjects: "Kamera ile objeler"
        case .musicLyrics: "Müzik ve şarkı sözleri"
        case .speakingPractice: "Konuşma pratiği"
        case .dailyLessons: "Kısa günlük dersler"
        case .aiExplanations: "AI açıklamalar"
        }
        return String(localized: value)
    }

    public var subtitle: String {
        let value: String.LocalizationValue = switch self {
        case .cameraObjects:
            "Gördüğün objeleri kamerayla etiketle, kelime hazineni gerçek dünyadan büyüt"
        case .musicLyrics:
            "Sevdiğin şarkıların sözlerinden kelime ve günlük kalıpları öğren"
        case .speakingPractice:
            "Native telaffuz dinle, kendi sesini kaydet, akıcılığını geliştir"
        case .dailyLessons:
            "Her gün 5-10 dakikalık kısa derslerle düzenli ritim oluştur"
        case .aiExplanations:
            "Cümlelerini AI'a analiz ettir, hatalarını anında ve açık şekilde öğren"
        }
        return String(localized: value)
    }
}

public enum DailyGoal: Int, CaseIterable, Identifiable, Codable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30

    public var id: Int { rawValue }
    public var title: String { String(localized: "\(rawValue) dakika") }

    /// Target number of completed lessons/practices per day for this goal.
    public var targetActivities: Int {
        switch self {
        case .fiveMinutes: 1
        case .tenMinutes: 2
        case .fifteenMinutes: 3
        case .thirtyMinutes: 4
        }
    }

    public var subtitle: String {
        let value: String.LocalizationValue = switch self {
        case .fiveMinutes:
            "Mikro alışkanlık • Hiç başlamamaktan iyi, ritim kurar"
        case .tenMinutes:
            "İdeal denge • Meşgul günlerde bile sürdürülebilir tempo"
        case .fifteenMinutes:
            "En verimli aralık • Konsantrasyon zirvesi, kalıcı öğrenme"
        case .thirtyMinutes:
            "Hızlı ilerleme • 6 ayda ciddi sıçrama, en kısa yol"
        }
        return String(localized: value)
    }
}

public struct PlanCard: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
}

public struct TypewriterText: Equatable {
    public let fullText: String

    public init(fullText: String) {
        self.fullText = fullText
    }

    public var characterCount: Int {
        fullText.count
    }

    public func visibleText(characterCount: Int) -> String {
        String(fullText.prefix(max(0, min(characterCount, self.characterCount))))
    }
}

public struct OnboardingFlowState: Equatable {
    public var currentStep: OnboardingStep
    public var profile: OnboardingProfile

    public init(
        currentStep: OnboardingStep = .welcome,
        profile: OnboardingProfile = OnboardingProfile()
    ) {
        self.currentStep = currentStep
        self.profile = profile
    }

    public mutating func reset() {
        currentStep = .welcome
        profile = OnboardingProfile()
    }
}

public struct OnboardingProfile: Equatable {
    public var targetLanguage: TargetLanguage?
    public var nativeLanguage: TargetLanguage?
    public var ageRange: AgeRange?
    public var learningPurposes: Set<LearningPurpose>
    public var currentLevels: Set<CurrentLevel>
    public var learningStyles: Set<LearningStyle>
    public var dailyGoal: DailyGoal?
    public var reminderTime: ReminderTime?

    public init(
        targetLanguage: TargetLanguage? = nil,
        nativeLanguage: TargetLanguage? = nil,
        ageRange: AgeRange? = nil,
        learningPurposes: Set<LearningPurpose> = [],
        currentLevels: Set<CurrentLevel> = [],
        learningStyles: Set<LearningStyle> = [],
        dailyGoal: DailyGoal? = nil,
        reminderTime: ReminderTime? = nil
    ) {
        self.targetLanguage = targetLanguage
        self.nativeLanguage = nativeLanguage
        self.ageRange = ageRange
        self.learningPurposes = learningPurposes
        self.currentLevels = currentLevels
        self.learningStyles = learningStyles
        self.dailyGoal = dailyGoal
        self.reminderTime = reminderTime
    }

    public mutating func toggleLearningStyle(_ style: LearningStyle) {
        if learningStyles.contains(style) {
            learningStyles.remove(style)
        } else {
            learningStyles.insert(style)
        }
    }

    public mutating func toggleCurrentLevel(_ level: CurrentLevel) {
        if currentLevels.contains(level) {
            currentLevels.remove(level)
        } else {
            currentLevels.insert(level)
        }
    }

    public mutating func toggleLearningPurpose(_ purpose: LearningPurpose) {
        if learningPurposes.contains(purpose) {
            learningPurposes.remove(purpose)
        } else {
            learningPurposes.insert(purpose)
        }
    }

    public func canContinue(from step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .planSummary, .auth:
            true
        case .targetLanguage:
            targetLanguage != nil
        case .nativeLanguage:
            nativeLanguage != nil
        case .ageRange:
            ageRange != nil
        case .learningPurpose:
            !learningPurposes.isEmpty
        case .currentLevel:
            !currentLevels.isEmpty
        case .learningStyle:
            !learningStyles.isEmpty
        case .dailyGoal:
            dailyGoal != nil
        case .reminderTime:
            reminderTime != nil
        }
    }

    public var planCards: [PlanCard] {
        var cards: [PlanCard] = []

        if learningStyles.contains(.cameraObjects) {
            cards.append(.init(
                id: "camera",
                title: "Gerçek dünyadan kelime yakalama",
                detail: "Kamerayla gördüğün objeleri etiketleyip tekrar listene ekle."
            ))
        }

        if learningStyles.contains(.musicLyrics) {
            cards.append(.init(
                id: "music",
                title: "Şarkı sözleriyle kalıp öğrenme",
                detail: "Dinlediğin müziklerdeki kelimeleri Türkçe ve hedef dil arasında keşfet."
            ))
        }

        if learningStyles.contains(.speakingPractice) {
            cards.append(.init(
                id: "voice",
                title: "Native telaffuz ve sesli tekrar",
                detail: "Doğal sesleri dinleyip kendi konuşmanı pratik et."
            ))
        }

        if learningStyles.contains(.aiExplanations) {
            cards.append(.init(
                id: "ai",
                title: "AI ile hata analizi",
                detail: "Cümlelerini analiz ettir, hatalarını kısa açıklamalarla öğren."
            ))
        }

        if learningStyles.contains(.dailyLessons) || cards.isEmpty {
            cards.append(.init(
                id: "lessons",
                title: "Kısa günlük dersler",
                detail: "Her gün küçük ve tamamlanabilir pratiklerle ritim kur."
            ))
        }

        if let dailyGoal {
            cards.append(.init(
                id: "goal",
                title: "\(dailyGoal.rawValue) dakikalık günlük ritim",
                detail: "Planın günlük hedefini koruyacak şekilde ayarlanır."
            ))
        }

        return cards
    }
}
