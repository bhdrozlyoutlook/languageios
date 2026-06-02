import Foundation

/// Lesson vocabulary. Authored, real content for the first English (US) stops, plus a
/// small per-language starter bank so every other stop is still playable (fallback).
/// All pairs are `target` ↔ Turkish `native`.
enum LessonContent {

    /// Hand-written content keyed by `LearningStop.id`.
    static let authored: [String: [VocabularyItem]] = [
        "englishUS_california": [   // İlk kelimeler
            .init(id: "us_ca_1", target: "hello", native: "merhaba"),
            .init(id: "us_ca_2", target: "yes", native: "evet"),
            .init(id: "us_ca_3", target: "no", native: "hayır"),
            .init(id: "us_ca_4", target: "please", native: "lütfen"),
            .init(id: "us_ca_5", target: "thank you", native: "teşekkürler"),
            .init(id: "us_ca_6", target: "water", native: "su")
        ],
        "englishUS_oregon": [       // Selamlaşma
            .init(id: "us_or_1", target: "good morning", native: "günaydın"),
            .init(id: "us_or_2", target: "good night", native: "iyi geceler"),
            .init(id: "us_or_3", target: "how are you", native: "nasılsın"),
            .init(id: "us_or_4", target: "I'm fine", native: "iyiyim"),
            .init(id: "us_or_5", target: "goodbye", native: "hoşça kal"),
            .init(id: "us_or_6", target: "welcome", native: "hoş geldin")
        ],
        "englishUS_washington": [   // Günlük diyaloglar
            .init(id: "us_wa_1", target: "what", native: "ne"),
            .init(id: "us_wa_2", target: "where", native: "nerede"),
            .init(id: "us_wa_3", target: "who", native: "kim"),
            .init(id: "us_wa_4", target: "today", native: "bugün"),
            .init(id: "us_wa_5", target: "now", native: "şimdi"),
            .init(id: "us_wa_6", target: "here", native: "burada")
        ],
        "englishUS_nevada": [       // Alışveriş ve sayılar
            .init(id: "us_nv_1", target: "one", native: "bir"),
            .init(id: "us_nv_2", target: "two", native: "iki"),
            .init(id: "us_nv_3", target: "three", native: "üç"),
            .init(id: "us_nv_4", target: "money", native: "para"),
            .init(id: "us_nv_5", target: "how much", native: "ne kadar"),
            .init(id: "us_nv_6", target: "expensive", native: "pahalı")
        ],

        // English (UK)
        "englishUK_london": [
            .init(id: "uk_lo_1", target: "hello", native: "merhaba"),
            .init(id: "uk_lo_2", target: "yes", native: "evet"),
            .init(id: "uk_lo_3", target: "no", native: "hayır"),
            .init(id: "uk_lo_4", target: "please", native: "lütfen"),
            .init(id: "uk_lo_5", target: "thank you", native: "teşekkürler"),
            .init(id: "uk_lo_6", target: "water", native: "su")
        ],
        "englishUK_oxford": [
            .init(id: "uk_ox_1", target: "good morning", native: "günaydın"),
            .init(id: "uk_ox_2", target: "good evening", native: "iyi akşamlar"),
            .init(id: "uk_ox_3", target: "how are you", native: "nasılsın"),
            .init(id: "uk_ox_4", target: "I'm well", native: "iyiyim"),
            .init(id: "uk_ox_5", target: "goodbye", native: "hoşça kal"),
            .init(id: "uk_ox_6", target: "cheers", native: "sağ ol")
        ],

        // Almanca
        "german_muenchen": [
            .init(id: "de_mu_1", target: "hallo", native: "merhaba"),
            .init(id: "de_mu_2", target: "ja", native: "evet"),
            .init(id: "de_mu_3", target: "nein", native: "hayır"),
            .init(id: "de_mu_4", target: "bitte", native: "lütfen"),
            .init(id: "de_mu_5", target: "danke", native: "teşekkürler"),
            .init(id: "de_mu_6", target: "Wasser", native: "su")
        ],
        "german_koeln": [
            .init(id: "de_ko_1", target: "guten Morgen", native: "günaydın"),
            .init(id: "de_ko_2", target: "gute Nacht", native: "iyi geceler"),
            .init(id: "de_ko_3", target: "wie geht's", native: "nasılsın"),
            .init(id: "de_ko_4", target: "mir geht's gut", native: "iyiyim"),
            .init(id: "de_ko_5", target: "tschüss", native: "hoşça kal"),
            .init(id: "de_ko_6", target: "willkommen", native: "hoş geldin")
        ],

        // İspanyolca
        "spanish_madrid": [
            .init(id: "es_ma_1", target: "hola", native: "merhaba"),
            .init(id: "es_ma_2", target: "sí", native: "evet"),
            .init(id: "es_ma_3", target: "no", native: "hayır"),
            .init(id: "es_ma_4", target: "por favor", native: "lütfen"),
            .init(id: "es_ma_5", target: "gracias", native: "teşekkürler"),
            .init(id: "es_ma_6", target: "agua", native: "su")
        ],
        "spanish_barcelona": [
            .init(id: "es_ba_1", target: "buenos días", native: "günaydın"),
            .init(id: "es_ba_2", target: "buenas noches", native: "iyi geceler"),
            .init(id: "es_ba_3", target: "cómo estás", native: "nasılsın"),
            .init(id: "es_ba_4", target: "estoy bien", native: "iyiyim"),
            .init(id: "es_ba_5", target: "adiós", native: "hoşça kal"),
            .init(id: "es_ba_6", target: "bienvenido", native: "hoş geldin")
        ],

        // Fransızca
        "french_paris": [
            .init(id: "fr_pa_1", target: "bonjour", native: "merhaba"),
            .init(id: "fr_pa_2", target: "oui", native: "evet"),
            .init(id: "fr_pa_3", target: "non", native: "hayır"),
            .init(id: "fr_pa_4", target: "s'il vous plaît", native: "lütfen"),
            .init(id: "fr_pa_5", target: "merci", native: "teşekkürler"),
            .init(id: "fr_pa_6", target: "eau", native: "su")
        ],
        "french_lyon": [
            .init(id: "fr_ly_1", target: "bonne nuit", native: "iyi geceler"),
            .init(id: "fr_ly_2", target: "comment ça va", native: "nasılsın"),
            .init(id: "fr_ly_3", target: "ça va bien", native: "iyiyim"),
            .init(id: "fr_ly_4", target: "au revoir", native: "hoşça kal"),
            .init(id: "fr_ly_5", target: "bienvenue", native: "hoş geldin"),
            .init(id: "fr_ly_6", target: "salut", native: "selam")
        ],

        // Türkçe (hedef Türkçe, gloss İngilizce)
        "turkish_istanbul": [
            .init(id: "tr_is_1", target: "merhaba", native: "hello"),
            .init(id: "tr_is_2", target: "evet", native: "yes"),
            .init(id: "tr_is_3", target: "hayır", native: "no"),
            .init(id: "tr_is_4", target: "lütfen", native: "please"),
            .init(id: "tr_is_5", target: "teşekkürler", native: "thank you"),
            .init(id: "tr_is_6", target: "su", native: "water")
        ],
        "turkish_ankara": [
            .init(id: "tr_an_1", target: "günaydın", native: "good morning"),
            .init(id: "tr_an_2", target: "iyi geceler", native: "good night"),
            .init(id: "tr_an_3", target: "nasılsın", native: "how are you"),
            .init(id: "tr_an_4", target: "iyiyim", native: "I'm fine"),
            .init(id: "tr_an_5", target: "hoşça kal", native: "goodbye"),
            .init(id: "tr_an_6", target: "hoş geldin", native: "welcome")
        ],

        // English (US) — daha ileri duraklar
        "englishUS_arizona": [   // Seyahat ve yön sorma
            .init(id: "us_az_1", target: "left", native: "sol"),
            .init(id: "us_az_2", target: "right", native: "sağ"),
            .init(id: "us_az_3", target: "straight", native: "düz"),
            .init(id: "us_az_4", target: "near", native: "yakın"),
            .init(id: "us_az_5", target: "far", native: "uzak"),
            .init(id: "us_az_6", target: "map", native: "harita")
        ],
        "englishUS_hawaii": [    // İş ve kariyer
            .init(id: "us_hi_1", target: "work", native: "iş"),
            .init(id: "us_hi_2", target: "job", native: "meslek"),
            .init(id: "us_hi_3", target: "office", native: "ofis"),
            .init(id: "us_hi_4", target: "meeting", native: "toplantı"),
            .init(id: "us_hi_5", target: "email", native: "e-posta"),
            .init(id: "us_hi_6", target: "boss", native: "patron")
        ],
        "englishUS_alaska": [    // Akıcı konuşma
            .init(id: "us_ak_1", target: "maybe", native: "belki"),
            .init(id: "us_ak_2", target: "because", native: "çünkü"),
            .init(id: "us_ak_3", target: "however", native: "ama"),
            .init(id: "us_ak_4", target: "I think", native: "bence"),
            .init(id: "us_ak_5", target: "I agree", native: "katılıyorum"),
            .init(id: "us_ak_6", target: "of course", native: "tabii ki")
        ],

        // Günlük diyaloglar (3. duraklar)
        "german_berlin": [
            .init(id: "de_be_1", target: "was", native: "ne"),
            .init(id: "de_be_2", target: "wo", native: "nerede"),
            .init(id: "de_be_3", target: "wer", native: "kim"),
            .init(id: "de_be_4", target: "heute", native: "bugün"),
            .init(id: "de_be_5", target: "jetzt", native: "şimdi"),
            .init(id: "de_be_6", target: "hier", native: "burada")
        ],
        "spanish_sevilla": [
            .init(id: "es_se_1", target: "qué", native: "ne"),
            .init(id: "es_se_2", target: "dónde", native: "nerede"),
            .init(id: "es_se_3", target: "quién", native: "kim"),
            .init(id: "es_se_4", target: "hoy", native: "bugün"),
            .init(id: "es_se_5", target: "ahora", native: "şimdi"),
            .init(id: "es_se_6", target: "aquí", native: "burada")
        ],
        "french_marseille": [
            .init(id: "fr_ma_1", target: "quoi", native: "ne"),
            .init(id: "fr_ma_2", target: "où", native: "nerede"),
            .init(id: "fr_ma_3", target: "qui", native: "kim"),
            .init(id: "fr_ma_4", target: "aujourd'hui", native: "bugün"),
            .init(id: "fr_ma_5", target: "maintenant", native: "şimdi"),
            .init(id: "fr_ma_6", target: "ici", native: "burada")
        ]
    ]

    /// The vocabulary for a stop: authored if available, otherwise the language starter bank.
    static func items(forStopId stopId: String, language: TargetLanguage) -> [VocabularyItem] {
        if let authored = authored[stopId], authored.count >= 4 {
            return authored
        }
        return starterBank(for: language)
    }

    /// Small, correct fallback set per language (target ↔ Turkish, except `turkish`).
    static func starterBank(for language: TargetLanguage) -> [VocabularyItem] {
        switch language {
        case .englishUS, .englishUK:
            return bank("en", [
                ("hello", "merhaba"), ("thanks", "teşekkürler"), ("water", "su"),
                ("food", "yemek"), ("friend", "arkadaş"), ("day", "gün"),
                ("big", "büyük"), ("small", "küçük")
            ])
        case .german:
            return bank("de", [
                ("hallo", "merhaba"), ("danke", "teşekkürler"), ("Wasser", "su"),
                ("Essen", "yemek"), ("Freund", "arkadaş"), ("Tag", "gün"),
                ("groß", "büyük"), ("klein", "küçük")
            ])
        case .spanish:
            return bank("es", [
                ("hola", "merhaba"), ("gracias", "teşekkürler"), ("agua", "su"),
                ("comida", "yemek"), ("amigo", "arkadaş"), ("día", "gün"),
                ("grande", "büyük"), ("pequeño", "küçük")
            ])
        case .french:
            return bank("fr", [
                ("bonjour", "merhaba"), ("merci", "teşekkürler"), ("eau", "su"),
                ("nourriture", "yemek"), ("ami", "arkadaş"), ("jour", "gün"),
                ("grand", "büyük"), ("petit", "küçük")
            ])
        case .turkish:
            return bank("tr", [
                ("merhaba", "hello"), ("teşekkürler", "thanks"), ("su", "water"),
                ("yemek", "food"), ("arkadaş", "friend"), ("gün", "day"),
                ("büyük", "big"), ("küçük", "small")
            ])
        }
    }

    private static func bank(_ prefix: String, _ pairs: [(String, String)]) -> [VocabularyItem] {
        pairs.enumerated().map { index, pair in
            VocabularyItem(id: "\(prefix)_starter_\(index)", target: pair.0, native: pair.1)
        }
    }
}
