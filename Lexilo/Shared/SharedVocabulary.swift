import Foundation

struct SeedWord: Identifiable, Sendable {
    let id: String
    let word: String
    let partOfSpeech: String
    let ipa: String
    let definition: String
    let example: String
    let rank: Int

    init(_ word: String, _ partOfSpeech: String, _ ipa: String, _ definition: String, _ example: String, rank: Int) {
        self.id = word
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.definition = definition
        self.example = example
        self.rank = rank
    }
}

enum StarterVocabulary {
    static let words: [SeedWord] = [
        .init("elusive", "adjective", "/ɪˈluːsɪv/", "Difficult to find, catch, or achieve.", "The answer remained elusive despite hours of research.", rank: 1),
        .init("lucid", "adjective", "/ˈluːsɪd/", "Expressed clearly; easy to understand.", "Her lucid explanation made the concept feel simple.", rank: 2),
        .init("pragmatic", "adjective", "/præɡˈmætɪk/", "Dealing with problems in a practical way.", "They took a pragmatic approach to the deadline.", rank: 3),
        .init("resilient", "adjective", "/rɪˈzɪliənt/", "Able to recover quickly from difficulty.", "The small community proved remarkably resilient.", rank: 4),
        .init("nuance", "noun", "/ˈnuːɑːns/", "A subtle distinction in meaning or expression.", "The translation preserves every nuance of the poem.", rank: 5),
        .init("concise", "adjective", "/kənˈsaɪs/", "Giving much information in few words.", "Keep the summary concise and specific.", rank: 6),
        .init("scrutinize", "verb", "/ˈskruːtənaɪz/", "To examine something very carefully.", "Researchers scrutinized the results for errors.", rank: 7),
        .init("coherent", "adjective", "/koʊˈhɪrənt/", "Logical, consistent, and easy to follow.", "The evidence formed a coherent account.", rank: 8),
        .init("ambiguous", "adjective", "/æmˈbɪɡjuəs/", "Open to more than one interpretation.", "The ending is deliberately ambiguous.", rank: 9),
        .init("meticulous", "adjective", "/məˈtɪkjələs/", "Showing great attention to detail.", "She kept meticulous notes throughout the study.", rank: 10),
        .init("candid", "adjective", "/ˈkændɪd/", "Truthful and straightforward.", "We had a candid conversation about the risks.", rank: 11),
        .init("diligent", "adjective", "/ˈdɪlɪdʒənt/", "Careful and persistent in one’s work.", "His diligent practice produced steady progress.", rank: 12),
        .init("tangible", "adjective", "/ˈtændʒəbəl/", "Clear and definite; able to be perceived.", "The new routine brought tangible benefits.", rank: 13),
        .init("foster", "verb", "/ˈfɒstər/", "To encourage the development of something.", "Good questions foster deeper understanding.", rank: 14),
        .init("intricate", "adjective", "/ˈɪntrɪkət/", "Very detailed or complicated.", "The watch contains an intricate mechanism.", rank: 15),
        .init("sporadic", "adjective", "/spəˈrædɪk/", "Occurring irregularly or only in a few places.", "Sporadic practice made retention difficult.", rank: 16),
        .init("versatile", "adjective", "/ˈvɜːrsətəl/", "Able to adapt to many different functions.", "It is a versatile tool for language learners.", rank: 17),
        .init("infer", "verb", "/ɪnˈfɜːr/", "To reach a conclusion from evidence.", "Readers can infer her mood from the final line.", rank: 18)
    ]
}

