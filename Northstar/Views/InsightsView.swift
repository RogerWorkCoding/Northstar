import SwiftUI
import Supabase

// 📊 Insights (Northstar Labs only): what people use Northstar for, and what they ask for
// that it can't do yet. Anonymous counts only, never anyone's words.
// The screen shows only for the accounts listed as admins on the server.

nonisolated struct InsightsReport: Decodable, Sendable {
    nonisolated struct Item: Decodable, Sendable, Hashable { let name: String; let count: Int }
    nonisolated struct Cost: Decodable, Sendable, Hashable { let day: String; let requests: Int; let dollars: Double }
    let days: Int
    let people: Int
    let peopleToday: Int
    let questions: Int
    let questionsToday: Int
    let features: [Item]
    let topics: [Item]
    let unmet: [Item]
    let failed: Int
    let medianSeconds: Double
    let cost: [Cost]

    enum CodingKeys: String, CodingKey {
        case days, people, questions, features, topics, unmet, failed, cost
        case peopleToday = "people_today"
        case questionsToday = "questions_today"
        case medianSeconds = "median_seconds"
    }
}

enum InsightsService {
    nonisolated private struct Request: Encodable, Sendable { let days: Int }
    nonisolated private struct Response: Decodable, Sendable {
        let allowed: Bool?
        let report: InsightsReport?
    }

    /// The report, or nil when this account isn't an admin (or it couldn't load).
    @MainActor static func load(days: Int) async -> InsightsReport? {
        do {
            let r: Response = try await SupabaseManager.shared.client.functions.invoke(
                "northstar-insights", options: FunctionInvokeOptions(body: Request(days: days)))
            return r.allowed == true ? r.report : nil
        } catch {
            return nil
        }
    }
}

struct InsightsView: View {
    @State var report: InsightsReport
    @State private var days = 7
    @State private var loading = false

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("Period", selection: $days) {
                        Text("Today").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        tile("\(report.people)", "people")
                        tile("\(report.questions)", "questions")
                        tile(String(format: "$%.2f", report.cost.reduce(0) { $0 + $1.dollars }), "cost")
                    }
                    Text("Today: \(report.peopleToday) people · \(report.questionsToday) questions · replies take about \(String(format: "%.1f", report.medianSeconds)) s")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)

                    bars("Can't do that yet", report.unmet, empty: "Nothing yet. When people ask for something Northstar can't do, it shows here.")
                    bars("What they use", report.features.map { .init(name: friendly($0.name), count: $0.count) }, empty: "No questions yet.")
                    bars("Topics", report.topics.map { .init(name: $0.name.capitalized, count: $0.count) }, empty: "No questions yet.")

                    if report.failed > 0 {
                        Label("\(report.failed) replies failed", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(NorthstarChatStyle.warning)
                    }

                    Text("Anonymous counts only. Northstar never shows anyone's words here.")
                        .font(.footnote)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await reload() }
            .overlay { if loading { ProgressView() } }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: days) { Task { await reload() } }
    }

    private func reload() async {
        loading = true
        if let r = await InsightsService.load(days: days) { report = r }
        loading = false
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(NorthstarChatStyle.text)
            Text(label).font(.footnote).foregroundStyle(NorthstarChatStyle.label)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
        .accessibilityElement(children: .combine)
    }

    private func bars(_ title: String, _ items: [InsightsReport.Item], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold)).tracking(2)
                .foregroundStyle(NorthstarChatStyle.label)
            if items.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(NorthstarChatStyle.soft)
            } else {
                let top = max(1, items.map(\.count).max() ?? 1)
                ForEach(items, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name).foregroundStyle(NorthstarChatStyle.text)
                            Spacer()
                            Text("\(item.count)").foregroundStyle(NorthstarChatStyle.soft)
                        }
                        .font(.subheadline)
                        GeometryReader { g in
                            Capsule().fill(NorthstarChatStyle.linkBlue.opacity(0.7))
                                .frame(width: max(4, g.size.width * CGFloat(item.count) / CGFloat(top)))
                        }
                        .frame(height: 6)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
    }

    private func friendly(_ f: String) -> String {
        switch f {
        case "chat": return "Chat"
        case "concierge": return "Concierge"
        case "photo": return "Photos"
        case "web": return "Web search"
        case "places": return "Places"
        case "calendar": return "Calendar & reminders"
        case "video": return "Video"
        case "design": return "Design"
        case "code": return "Code"
        default: return f.hasPrefix("module:") ? "Module: " + f.dropFirst(7).capitalized : f.capitalized
        }
    }
}
