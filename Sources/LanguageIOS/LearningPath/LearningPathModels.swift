import Foundation

/// Layered artwork descriptor for a single learning stop.
///
/// `baseImageName` is the "landmass" shown while the stop is locked or active.
/// `layerImageNames` are detail layers that reveal one-by-one (animated) once the
/// stop is completed — this is what produces the "katmanlar tek tek açılır" effect.
///
/// Asset naming convention (drop real PNGs into an asset catalog with these names
/// and `StopArtworkView` will pick them up automatically — see the design doc):
///   base:   "<languageRaw>_<slug>_base"     e.g. "englishUS_california_base"
///   layers: "<languageRaw>_<slug>_l1" … "_lN"
public struct StopArtwork: Equatable, Hashable {
    public let baseImageName: String
    public let layerImageNames: [String]

    public init(baseImageName: String, layerImageNames: [String]) {
        self.baseImageName = baseImageName
        self.layerImageNames = layerImageNames
    }

    public var layerCount: Int { layerImageNames.count }
}

/// A single destination on the learning map (a US state, a city, …).
public struct LearningStop: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let artwork: StopArtwork

    public init(id: String, title: String, subtitle: String, artwork: StopArtwork) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork
    }
}

/// The ordered, language-themed path the user travels through.
public struct LearningJourney: Equatable {
    public let language: TargetLanguage
    public let title: String
    public let tagline: String
    public let stops: [LearningStop]

    public init(language: TargetLanguage, title: String, tagline: String, stops: [LearningStop]) {
        self.language = language
        self.title = title
        self.tagline = tagline
        self.stops = stops
    }

    public var stopCount: Int { stops.count }
}

// MARK: - Catalog

public extension LearningJourney {
    /// Returns the themed journey for a learning language. Every `TargetLanguage`
    /// resolves to a non-empty journey.
    static func journey(for language: TargetLanguage) -> LearningJourney {
        switch language {
        case .englishUS:
            return make(
                language,
                title: "Amerika yolculuğun",
                tagline: "50 eyalette batıdan doğuya İngilizce",
                // Coast-to-coast: Pacific → Mountain → Plains → Midwest → South → Northeast.
                places: [
                    ("california", "California"),
                    ("oregon", "Oregon"),
                    ("washington", "Washington"),
                    ("nevada", "Nevada"),
                    ("arizona", "Arizona"),
                    ("hawaii", "Hawaii"),
                    ("alaska", "Alaska"),
                    ("utah", "Utah"),
                    ("idaho", "Idaho"),
                    ("montana", "Montana"),
                    ("wyoming", "Wyoming"),
                    ("colorado", "Colorado"),
                    ("newmexico", "New Mexico"),
                    ("northdakota", "North Dakota"),
                    ("southdakota", "South Dakota"),
                    ("nebraska", "Nebraska"),
                    ("kansas", "Kansas"),
                    ("oklahoma", "Oklahoma"),
                    ("texas", "Texas"),
                    ("minnesota", "Minnesota"),
                    ("iowa", "Iowa"),
                    ("missouri", "Missouri"),
                    ("wisconsin", "Wisconsin"),
                    ("illinois", "Illinois"),
                    ("michigan", "Michigan"),
                    ("indiana", "Indiana"),
                    ("ohio", "Ohio"),
                    ("arkansas", "Arkansas"),
                    ("louisiana", "Louisiana"),
                    ("mississippi", "Mississippi"),
                    ("alabama", "Alabama"),
                    ("tennessee", "Tennessee"),
                    ("kentucky", "Kentucky"),
                    ("georgia", "Georgia"),
                    ("florida", "Florida"),
                    ("southcarolina", "South Carolina"),
                    ("northcarolina", "North Carolina"),
                    ("virginia", "Virginia"),
                    ("westvirginia", "West Virginia"),
                    ("maryland", "Maryland"),
                    ("delaware", "Delaware"),
                    ("pennsylvania", "Pennsylvania"),
                    ("newjersey", "New Jersey"),
                    ("newyork", "New York"),
                    ("connecticut", "Connecticut"),
                    ("rhodeisland", "Rhode Island"),
                    ("massachusetts", "Massachusetts"),
                    ("vermont", "Vermont"),
                    ("newhampshire", "New Hampshire"),
                    ("maine", "Maine")
                ]
            )
        case .englishUK:
            return make(
                language,
                title: "İngiltere yolculuğun",
                tagline: "Şehir şehir İngiliz İngilizcesi",
                places: [
                    ("london", "Londra"),
                    ("oxford", "Oxford"),
                    ("manchester", "Manchester"),
                    ("liverpool", "Liverpool"),
                    ("edinburgh", "Edinburgh"),
                    ("bristol", "Bristol"),
                    ("cambridge", "Cambridge")
                ]
            )
        case .german:
            return make(
                language,
                title: "Almanya yolculuğun",
                tagline: "Şehir şehir Almanca öğren",
                places: [
                    ("muenchen", "Münih"),
                    ("koeln", "Köln"),
                    ("berlin", "Berlin"),
                    ("hamburg", "Hamburg"),
                    ("frankfurt", "Frankfurt"),
                    ("stuttgart", "Stuttgart"),
                    ("dresden", "Dresden")
                ]
            )
        case .spanish:
            return make(
                language,
                title: "İspanya yolculuğun",
                tagline: "Şehir şehir İspanyolca öğren",
                places: [
                    ("madrid", "Madrid"),
                    ("barcelona", "Barcelona"),
                    ("sevilla", "Sevilla"),
                    ("valencia", "Valencia"),
                    ("bilbao", "Bilbao"),
                    ("granada", "Granada"),
                    ("malaga", "Málaga")
                ]
            )
        case .french:
            return make(
                language,
                title: "Fransa yolculuğun",
                tagline: "Şehir şehir Fransızca öğren",
                places: [
                    ("paris", "Paris"),
                    ("lyon", "Lyon"),
                    ("marseille", "Marsilya"),
                    ("bordeaux", "Bordeaux"),
                    ("nice", "Nice"),
                    ("toulouse", "Toulouse"),
                    ("strasbourg", "Strazburg")
                ]
            )
        case .turkish:
            return make(
                language,
                title: "Türkiye yolculuğun",
                tagline: "Şehir şehir Türkçe öğren",
                places: [
                    ("istanbul", "İstanbul"),
                    ("ankara", "Ankara"),
                    ("izmir", "İzmir"),
                    ("antalya", "Antalya"),
                    ("bursa", "Bursa"),
                    ("trabzon", "Trabzon"),
                    ("konya", "Konya")
                ]
            )
        }
    }

    /// Shared unit themes layered on top of each destination, in order.
    static var unitThemes: [String] {
        [
            String(localized: "İlk kelimeler"),
            String(localized: "Selamlaşma"),
            String(localized: "Günlük diyaloglar"),
            String(localized: "Alışveriş ve sayılar"),
            String(localized: "Seyahat ve yön sorma"),
            String(localized: "İş ve kariyer"),
            String(localized: "Akıcı konuşma")
        ]
    }

    private static func make(
        _ language: TargetLanguage,
        title: String,
        tagline: String,
        places: [(slug: String, title: String)]
    ) -> LearningJourney {
        let stops = places.enumerated().map { index, place -> LearningStop in
            // 2…4 detail layers, cycling, so reveals vary stop to stop.
            let layerCount = 2 + (index % 3)
            let base = "\(language.rawValue)_\(place.slug)_base"
            let layers = (1...layerCount).map { "\(language.rawValue)_\(place.slug)_l\($0)" }
            return LearningStop(
                id: "\(language.rawValue)_\(place.slug)",
                title: place.title,
                subtitle: unitThemes[index % unitThemes.count],
                artwork: StopArtwork(baseImageName: base, layerImageNames: layers)
            )
        }
        return LearningJourney(language: language, title: title, tagline: tagline, stops: stops)
    }
}

// MARK: - Progress

/// Status of one stop relative to the user's progress.
public enum StopStatus: Equatable {
    case completed
    case active
    case locked
}

/// Per-language progress: how many stops the user has completed.
/// Stop `i` is `.completed` when `i < completedCount`, `.active` when it is the very
/// next one (`i == completedCount`), and `.locked` otherwise.
public struct LearningProgress: Equatable, Codable {
    public var completedCount: Int

    public init(completedCount: Int = 0) {
        self.completedCount = max(0, completedCount)
    }

    public func status(forIndex index: Int) -> StopStatus {
        if index < completedCount { return .completed }
        if index == completedCount { return .active }
        return .locked
    }

    /// Marks the current active stop complete, clamped to the total number of stops.
    public mutating func completeCurrentStop(total: Int) {
        completedCount = min(completedCount + 1, max(total, 0))
    }

    public func isFinished(total: Int) -> Bool {
        completedCount >= total && total > 0
    }
}
