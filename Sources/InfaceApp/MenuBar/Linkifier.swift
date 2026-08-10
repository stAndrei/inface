import Foundation
import InfaceCore
import SwiftUI

enum Linkifier {
    static func attributedString(
        from text: String,
        baseColor: Color = InfaceTheme.textPrimary,
        linkColor: Color = InfaceTheme.accent
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: nsRange)

        let meetingLinks = MeetingLinkDetector.shared
        for match in matches {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: text),
                  let start = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let end = AttributedString.Index(stringRange.upperBound, within: attributed)
            else { continue }

            let range = start..<end
            // ChatZone https links open in the browser by default — use deep link target.
            attributed[range].link = meetingLinks.launchURL(for: url)
            attributed[range].foregroundColor = linkColor
            attributed[range].underlineStyle = .single
        }

        return attributed
    }
}
