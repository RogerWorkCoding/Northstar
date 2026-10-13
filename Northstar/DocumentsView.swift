import SwiftUI

struct DocumentsView: View {

    @State private var pdfFiles: [URL] = []
    @State private var selectedPDF: SelectedPDF?

    var body: some View {

        ZStack {

            Color(
                red: 0.08,
                green: 0.12,
                blue: 0.25
            )
            .ignoresSafeArea()

            if pdfFiles.isEmpty {

                VStack(spacing: 20) {

                    Image(systemName: "doc.text")
                        .font(
                            .system(
                                size: 60,
                                weight: .light
                            )
                        )
                        .foregroundStyle(.white)

                    Text("Northstar Documents")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text(
                        "No saved documents found."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .white.opacity(0.65)
                    )
                }
                .padding()

            } else {

                List {

                    ForEach(
                        pdfFiles,
                        id: \.self
                    ) { file in

                        Button {

                            selectedPDF =
                                SelectedPDF(
                                    url: file
                                )

                        } label: {

                            HStack(spacing: 14) {

                                Image(
                                    systemName:
                                        "doc.text.fill"
                                )
                                .font(.title2)
                                .foregroundStyle(.blue)

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {

                                    Text(
                                        file
                                            .deletingPathExtension()
                                            .lastPathComponent
                                    )
                                    .font(.body)

                                    Text(
                                        "PDF Document"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }

                                Spacer()

                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                            .padding(
                                .vertical,
                                8
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(
                        perform:
                            deleteDocuments
                    )
                }
                .scrollContentBackground(
                    .hidden
                )
                .background(
                    Color.clear
                )
            }
        }
        .navigationTitle(
            "Documents"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .onAppear {

            loadDocuments()
        }
        .sheet(
            item: $selectedPDF
        ) { selectedPDF in

            PDFPreviewScreen(
                pdfURL:
                    selectedPDF.url
            )
        }
    }

    private func loadDocuments() {

        let documentsURL =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!

        let northstarFolder =
            documentsURL
                .appendingPathComponent(
                    "Northstar Documents"
                )

        do {

            pdfFiles =
                try FileManager.default
                    .contentsOfDirectory(
                        at: northstarFolder,
                        includingPropertiesForKeys: [
                            .contentModificationDateKey
                        ],
                        options: [
                            .skipsHiddenFiles
                        ]
                    )
                    .filter {
                        $0.pathExtension
                            .lowercased()
                        == "pdf"
                    }
                    .sorted {

                        modificationDate(
                            for: $0
                        )
                        >
                        modificationDate(
                            for: $1
                        )
                    }

        } catch {

            pdfFiles = []

            print(
                "Failed to load PDFs:",
                error.localizedDescription
            )
        }
    }

    private func deleteDocuments(
        at offsets: IndexSet
    ) {

        for index in offsets {

            let file =
                pdfFiles[index]

            do {

                try FileManager.default
                    .removeItem(
                        at: file
                    )

            } catch {

                print(
                    "Delete failed:",
                    error.localizedDescription
                )
            }
        }

        loadDocuments()
    }

    private func modificationDate(
        for url: URL
    ) -> Date {

        let values =
            try? url.resourceValues(
                forKeys: [
                    .contentModificationDateKey
                ]
            )

        return values?
            .contentModificationDate
            ?? .distantPast
    }
}

private struct SelectedPDF:
    Identifiable {

    let url: URL

    var id: String {

        url.path
    }
}

private struct PDFPreviewScreen:
    View {

    @Environment(\.dismiss)
    private var dismiss

    let pdfURL: URL

    var body: some View {

        NavigationStack {

            PDFPreviewView(
                pdfURL: pdfURL
            )
            .navigationTitle(
                pdfURL
                    .lastPathComponent
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button("Done") {

                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    ShareLink(
                        item: pdfURL
                    ) {

                        Image(
                            systemName:
                                "square.and.arrow.up"
                        )
                    }
                }
            }
        }
    }
}

#Preview {

    NavigationStack {

        DocumentsView()
    }
}
