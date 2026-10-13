import SwiftUI
import PDFKit

struct PDFPreviewView: UIViewRepresentable {

    let pdfURL: URL

    func makeUIView(
        context: Context
    ) -> PDFView {

        let pdfView = PDFView()

        pdfView.autoScales = true

        pdfView.displayMode =
            .singlePageContinuous

        pdfView.displayDirection =
            .vertical

        pdfView.document =
            PDFDocument(
                url: pdfURL
            )

        return pdfView
    }

    func updateUIView(
        _ pdfView: PDFView,
        context: Context
    ) {

        if pdfView.document?
            .documentURL != pdfURL {

            pdfView.document =
                PDFDocument(
                    url: pdfURL
                )
        }
    }
}
