import SwiftUI

// 📄 Documents (star menu): PDFs made in Northstar, newest first.
// Uses the app's Day/Night colors, so the title and cards are always readable.
// Names are calm ("Letter to Mom"), never the private first line of the text.

struct DocumentsView: View {

    @State private var pdfFiles: [URL] = []
    @State private var selectedPDF: SelectedPDF?

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()

            if pdfFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(NorthstarChatStyle.label)
                    Text("No documents yet")
                        .font(.headline)
                        .foregroundStyle(NorthstarChatStyle.text)
                    Text("Documents you make with Northstar show up here.")
                        .font(.subheadline)
                        .foregroundStyle(NorthstarChatStyle.soft)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                List {
                    ForEach(pdfFiles, id: \.self) { file in
                        row(file)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onDelete(perform: deleteDocuments)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadDocuments() }
        .sheet(item: $selectedPDF) { selected in
            PDFPreviewScreen(pdfURL: selected.url, title: displayName(for: selected.url))
        }
    }

    private func row(_ file: URL) -> some View {
        let name = displayName(for: file)
        let when = Self.dateText(modificationDate(for: file))
        return Button {
            selectedPDF = SelectedPDF(url: file)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: name.hasPrefix("Letter to") ? "envelope" : "doc.text")
                    .font(.title3)
                    .foregroundStyle(NorthstarChatStyle.text)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(NorthstarChatStyle.cardStrong)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.text)
                        .lineLimit(1)
                    Text(when)
                        .font(.caption)
                        .foregroundStyle(NorthstarChatStyle.label)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(NorthstarChatStyle.label)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NorthstarChatStyle.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NorthstarChatStyle.stroke, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(when)")
    }

    /// Older files were named after their first line; show the calm name instead.
    /// Keeps a " 2" copy number so two letters to Mom stay tell-apart-able.
    private func displayName(for url: URL) -> String {
        let fileName = url.deletingPathExtension().lastPathComponent
        var base = fileName
        var suffix = ""
        if let match = fileName.range(of: #" \d+$"#, options: .regularExpression) {
            base = String(fileName[..<match.lowerBound])
            suffix = String(fileName[match])
        }
        return DocumentNaming.calmName(for: base) + suffix
    }

    private static func dateText(_ date: Date) -> String {
        guard date != .distantPast else { return "PDF" }
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today, \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday, \(time)" }
        let sameYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        let day = sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(day), \(time)"
    }

    private func loadDocuments() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let northstarFolder = documentsURL.appendingPathComponent("Northstar Documents")
        do {
            pdfFiles = try FileManager.default
                .contentsOfDirectory(
                    at: northstarFolder,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                .filter { $0.pathExtension.lowercased() == "pdf" }
                .sorted { modificationDate(for: $0) > modificationDate(for: $1) }
        } catch {
            pdfFiles = []
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            do {
                try FileManager.default.removeItem(at: pdfFiles[index])
            } catch {
                print("Delete failed:", error.localizedDescription)
            }
        }
        loadDocuments()
    }

    private func modificationDate(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }
}

private struct SelectedPDF: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct PDFPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    let pdfURL: URL
    let title: String

    var body: some View {
        NavigationStack {
            PDFPreviewView(pdfURL: pdfURL)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: pdfURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share \(title)")
                    }
                }
        }
    }
}

#Preview {
    NavigationStack { DocumentsView() }
}
