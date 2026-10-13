import Foundation
import UIKit

struct PDFDocumentService {

    func createPDF(
        title: String,
        topic: String
    ) throws -> URL {

        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: 612,
            height: 792
        )

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageBounds
            )

        let safeTitle =
            sanitizedFileName(
                title.isEmpty
                ? "Northstar Document"
                : title
            )

        let documentsURL =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!

        let northstarFolder =
            documentsURL.appendingPathComponent(
                "Northstar Documents"
            )

        try FileManager.default.createDirectory(
            at: northstarFolder,
            withIntermediateDirectories: true
        )

        let fileURL =
            northstarFolder.appendingPathComponent(
                "\(safeTitle).pdf"
            )

        try renderer.writePDF(
            to: fileURL
        ) { context in

            context.beginPage()

            let margin: CGFloat = 54

            let contentWidth =
                pageBounds.width - (margin * 2)

            let titleAttributes:
                [NSAttributedString.Key: Any] = [

                .font:
                    UIFont.systemFont(
                        ofSize: 28,
                        weight: .semibold
                    ),

                .foregroundColor:
                    UIColor(
                        red: 0.08,
                        green: 0.12,
                        blue: 0.25,
                        alpha: 1
                    )
            ]

            let paragraphStyle =
                NSMutableParagraphStyle()

            paragraphStyle.lineSpacing = 6

            let bodyAttributes:
                [NSAttributedString.Key: Any] = [

                .font:
                    UIFont.systemFont(
                        ofSize: 16
                    ),

                .foregroundColor:
                    UIColor.darkGray,

                .paragraphStyle:
                    paragraphStyle
            ]

            let footerAttributes:
                [NSAttributedString.Key: Any] = [

                .font:
                    UIFont.systemFont(
                        ofSize: 10
                    ),

                .foregroundColor:
                    UIColor.gray
            ]

            let titleRect = CGRect(
                x: margin,
                y: margin,
                width: contentWidth,
                height: 80
            )

            title.draw(
                in: titleRect,
                withAttributes: titleAttributes
            )

            let lineY =
                titleRect.maxY + 8

            UIColor(
                red: 0.74,
                green: 0.61,
                blue: 0.30,
                alpha: 1
            )
            .setFill()

            UIBezierPath(
                roundedRect: CGRect(
                    x: margin,
                    y: lineY,
                    width: 70,
                    height: 3
                ),
                cornerRadius: 1.5
            )
            .fill()

            let bodyRect = CGRect(
                x: margin,
                y: lineY + 40,
                width: contentWidth,
                height: pageBounds.height
                    - lineY
                    - 120
            )

            topic.draw(
                in: bodyRect,
                withAttributes: bodyAttributes
            )

            let footerRect = CGRect(
                x: margin,
                y: pageBounds.height - 45,
                width: contentWidth,
                height: 20
            )

            "Northstar Labs | One clear destination. An intelligent path forward."
                .draw(
                    in: footerRect,
                    withAttributes: footerAttributes
                )
        }

        return fileURL
    }

    private func sanitizedFileName(
        _ value: String
    ) -> String {

        let forbiddenCharacters =
            CharacterSet(
                charactersIn:
                    "/\\?%*|\"<>:"
            )

        let cleaned =
            value
                .components(
                    separatedBy:
                        forbiddenCharacters
                )
                .joined(
                    separator: "-"
                )
                .trimmingCharacters(
                    in:
                    .whitespacesAndNewlines
                )

        return cleaned.isEmpty
            ? "Northstar Document"
            : cleaned
    }
}
