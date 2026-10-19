import SwiftUI
import UIKit
import CoreText

// 🗒 Notes for my counselor: the person picks entries, Northstar writes neutral notes in their own words
// (what happened, how they described feeling, questions to discuss), they read and change them, then share
// a PDF. The PDF is made in a temporary folder only: nothing is kept or sent unless they share it.

struct CounselorNotesView: View {
    @State private var store = JournalStore.shared
    @State private var picked: Set<UUID> = []
    @State private var notes = ""
    @State private var working = false
    @State private var problem: String?
    @State private var crisisReply: String?
    @State private var pdf: URL?
    @Environment(\.dismiss) private var dismiss

    private let engine = NorthstarEngineClient()

    var body: some View {
        Form {
            if notes.isEmpty && crisisReply == nil {
                Section {
                    ForEach(store.entries) { item in
                        Button {
                            if picked.contains(item.id) { picked.remove(item.id) } else { picked.insert(item.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: picked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(picked.contains(item.id) ? NorthstarChatStyle.linkBlue : NorthstarChatStyle.label)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.headline)
                                    Text(item.created, format: .dateTime.month(.abbreviated).day().year())
                                        .font(.subheadline)
                                        .foregroundStyle(NorthstarChatStyle.label)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityAddTraits(picked.contains(item.id) ? [.isButton, .isSelected] : .isButton)
                    }
                } header: {
                    Text("Pick the entries to include")
                } footer: {
                    Text("Only the entries you pick are sent to Northstar, just to write these notes. They aren't kept.")
                }

                Section {
                    Button {
                        Task { await makeNotes() }
                    } label: {
                        HStack {
                            if working { ProgressView() }
                            Text(working ? "Writing notes\u{2026}" : "Write my notes")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(picked.isEmpty || working)
                    if let problem {
                        Text(problem).foregroundStyle(NorthstarChatStyle.warning)
                    }
                }
            } else if let crisisReply {
                Section {
                    Text(NorthstarReplyView.formatted(crisisReply))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 320)
                        .font(.system(size: 17))
                } header: {
                    Text("Your notes. Change anything you like.")
                } footer: {
                    Text("Northstar isn't a counselor. These notes are only your own words, put in order.")
                }
                Section {
                    if let pdf {
                        ShareLink(item: pdf) {
                            Label("Share the PDF", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    } else {
                        Button {
                            pdf = Self.makePDF(notes)
                            if pdf == nil { problem = "The PDF couldn't be made. Please try again." }
                        } label: {
                            Label("Make a PDF to share", systemImage: "doc.richtext")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    Button("Start over") {
                        notes = ""
                        pdf = nil
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .navigationTitle("Notes for my counselor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
        .onChange(of: notes) { pdf = nil }      // edited after the PDF: make it again
        .onDisappear { if let pdf { try? FileManager.default.removeItem(at: pdf) } }
    }

    private func makeNotes() async {
        working = true
        problem = nil
        let chosen = store.entries.filter { picked.contains($0.id) }.reversed()   // oldest first
        let body = chosen.map { item in
            let date = item.created.formatted(.dateTime.month(.wide).day().year())
            return "Entry: \(item.title) (\(date))\n\(item.text)"
        }.joined(separator: "\n\n---\n\n")
        let ask = "Please write my notes for my counselor from these journal entries of mine.\n\n" + body
        let reply = await engine.getReply(for: [MessageModel(role: .user, content: ask)],
                                          settings: EngineSettings.current, source: "counselor")
        working = false
        if reply.insight?.crisis == true {
            crisisReply = reply.text
        } else if reply.failed || reply.text.isEmpty {
            problem = "The notes couldn't be written right now. Please try again."
        } else {
            notes = reply.text
        }
    }

    /// A simple, multi-page PDF of their notes, in a temporary folder.
    static func makePDF(_ text: String) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 60
        let heading = "Notes for my counselor\n"
        let date = Date.now.formatted(.dateTime.month(.wide).day().year()) + "\n\n"
        let full = NSMutableAttributedString(string: heading, attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: UIColor.black,
        ])
        full.append(NSAttributedString(string: date, attributes: [
            .font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.darkGray,
        ]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.paragraphSpacing = 8
        let plain = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "## ", with: "")
        full.append(NSAttributedString(string: plain, attributes: [
            .font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.black, .paragraphStyle: style,
        ]))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Notes for my counselor.pdf")
        try? FileManager.default.removeItem(at: url)
        let setter = CTFramesetterCreateWithAttributedString(full)
        let box = page.insetBy(dx: margin, dy: margin)
        do {
            try UIGraphicsPDFRenderer(bounds: page).writePDF(to: url) { context in
                var start = 0
                while start < full.length {
                    context.beginPage()
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.textMatrix = .identity
                    cg.translateBy(x: 0, y: page.height)
                    cg.scaleBy(x: 1, y: -1)
                    let path = CGPath(rect: CGRect(x: box.minX, y: margin, width: box.width, height: box.height), transform: nil)
                    let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
                    CTFrameDraw(frame, cg)
                    cg.restoreGState()
                    let shown = CTFrameGetVisibleStringRange(frame).length
                    if shown == 0 { break }
                    start += shown
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
