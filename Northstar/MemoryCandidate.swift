import Foundation

struct MemoryCandidate: Identifiable, Equatable {

    let id = UUID()
    let content: String
    let suggestedSubject: String
    let reason: String
}

