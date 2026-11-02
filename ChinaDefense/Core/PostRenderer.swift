import SwiftUI

/// Converts the HTML of a forum post into a theme-aware `AttributedString`.
///
/// SMF renders BBCode into a predictable set of tags. This renderer walks that markup
/// and produces native text attributes instead of embedding a web view, which keeps
/// posts fast, selectable and dark-mode friendly. Images are collected separately so the
/// UI can lay them out in a grid.
enum PostRenderer {
    static func render(html: String, baseURL: URL = AppConfig.baseURL) -> PostContent {
        let document = HTMLParser.parse(html)
        var builder = Builder(baseURL: baseURL)
        builder.walk(childrenOf: document)
        return builder.finish()
    }

    static func isImageURL(_ url: URL) -> Bool {
        let full = url.absoluteString.lowercased()
        if full.contains(";image") { return true }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"].contains(ext)
    }

    /// Extracts the video id from an embed/watch/short URL.
    static func youTubeID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        guard host.contains("youtube.com") || host.contains("youtu.be") else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }

        if host.contains("youtu.be"), let id = components.first, id.count >= 6 {
            return id
        }
        if let index = components.firstIndex(of: "embed"), index + 1 < components.count {
            return components[index + 1]
        }
        if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value, value.count >= 6 {
            return value
        }
        return nil
    }

    // MARK: - Style

    struct PostFontSizeAttribute: AttributedStringKey {
        typealias Value = Double
        static let name = "postFontSize"
    }

    struct QuoteDepthAttribute: AttributedStringKey {
        typealias Value = Int
        static let name = "quoteDepth"
    }

    private struct Style {
        var bold = false
        var italic = false
        var code = false
        var quoteDepth = 0
        var listDepth = 0
        var isHeader = false
        var isSmall = false
        var link: URL?
        var color: Color?
    }

    // MARK: - Builder

    private struct Builder {
        let baseURL: URL
        var result = AttributedString()
        var blocks: [PostBlock] = []
        var images: [URL] = []
        var pendingBreaks = 0
        var style = Style()

        mutating func walk(childrenOf node: HTMLNode) {
            for child in node.children { walk(child) }
        }

        mutating func walk(_ node: HTMLNode) {
            if node.isText {
                appendText(node.text)
                return
            }

            if node.tag == "div", node.hasClass("attachments") {
                collectAttachments(node)
                return
            }

            switch node.tag {
            case "script", "style", "noscript", "head", "input", "button", "select",
                 "textarea", "svg", "form", "label", "nav":
                return

            case "br":
                ensureBreak()

            case "p", "div", "section", "article", "header", "footer", "aside",
                 "table", "tr", "ul", "ol", "dl", "fieldset":
                blockElement(node)

            case "h1", "h2", "h3", "h4", "h5", "h6":
                header(node)

            case "blockquote":
                let saved = style
                style.quoteDepth += 1
                style.italic = true
                ensureBreak()
                walk(childrenOf: node)
                ensureBreak()
                style = saved

            case "li":
                listItem(node)

            case "pre":
                appendCodeBlock(node.rawText)

            case "hr":
                ensureBreak()
                append(text: "———", style: style)
                ensureBreak()

            case "img":
                appendInlineImage(node)

            case "iframe", "embed", "video", "audio":
                if let src = node.attr("src"), let url = AppConfig.resolve(src, relativeTo: baseURL) {
                    if let id = PostRenderer.youTubeID(from: url) {
                        appendVideoBlock(id)
                    } else {
                        ensureBreak()
                        var linkStyle = style
                        linkStyle.link = url
                        append(text: url.absoluteString, style: linkStyle)
                        ensureBreak()
                    }
                }

            case "a":
                link(node)

            case "span":
                span(node)

            case "strong", "b":
                with(node, bold: true)

            case "em", "i", "cite":
                with(node, italic: true)

            case "u":
                var container = attributes(for: style)
                container.underlineStyle = .single
                append(childrenOf: node, container: container)

            case "s", "strike", "del":
                var container = attributes(for: style)
                container.strikethroughStyle = .single
                append(childrenOf: node, container: container)

            case "code", "tt":
                let saved = style
                style.code = true
                walk(childrenOf: node)
                style = saved

            case "sup", "sub":
                walk(childrenOf: node)

            case "td", "th":
                walk(childrenOf: node)
                append(text: " ", style: style)

            default:
                walk(childrenOf: node)
            }
        }

        // MARK: Elements

        private mutating func blockElement(_ node: HTMLNode) {
            // SMF renders [code] blocks as div.bbc_code.
            if node.hasClass("bbc_code") || node.hasClass("code") {
                appendCodeBlock(node.rawText)
                return
            }

            // SMF puts the "Quote from: …" caption in a div.quoteheader.
            if node.hasClass("quoteheader") {
                ensureBreak()
                var caption = style
                caption.isSmall = true
                caption.bold = true
                append(text: node.textContent, style: caption)
                ensureBreak()
                return
            }
            if node.hasClass("codeheader") {
                ensureBreak()
                var caption = style
                caption.isSmall = true
                caption.bold = true
                append(text: node.textContent, style: caption)
                ensureBreak()
                return
            }
            // The small "Quote" / "Code" toggle links.
            if node.hasClass("quoteexpand") || node.hasClass("code_operation") {
                return
            }

            ensureBreak()
            walk(childrenOf: node)
            ensureBreak()
        }

        private mutating func header(_ node: HTMLNode) {
            let saved = style
            style.bold = true
            style.isHeader = true
            ensureBreak()
            walk(childrenOf: node)
            ensureBreak()
            style = saved
        }

        private mutating func listItem(_ node: HTMLNode) {
            ensureBreak()
            append(text: "•  ", style: style)
            let saved = style
            style.listDepth += 1
            walk(childrenOf: node)
            style = saved
            ensureBreak()
        }

        private mutating func link(_ node: HTMLNode) {
            guard let href = node.attr("href"), let url = AppConfig.resolve(href, relativeTo: baseURL) else {
                walk(childrenOf: node)
                return
            }

            // SMF wraps pictures in a link to the full-size file, with the <img>
            // pointing at a thumbnail. Show the full-size picture in place.
            if PostRenderer.isImageURL(url), let image = node.allTags("img").first {
                appendInlineImage(image, preferredURL: url)
                return
            }

            let saved = style
            style.link = url
            walk(childrenOf: node)
            style = saved
        }

        private mutating func with(_ node: HTMLNode, bold: Bool = false, italic: Bool = false) {
            let saved = style
            if bold { style.bold = true }
            if italic { style.italic = true }
            walk(childrenOf: node)
            style = saved
        }

        private mutating func collectAttachments(_ node: HTMLNode) {
            var foundFullSize = false
            for anchor in node.all(where: { $0.tag == "a" && ($0.href?.contains("dlattach") ?? false) }) {
                guard let href = anchor.href, href.contains(";image"),
                      let url = AppConfig.resolve(href, relativeTo: baseURL) else { continue }
                if !images.contains(url) { images.append(url) }
                foundFullSize = true
            }
            if !foundFullSize {
                for image in node.allTags("img") where (image.src ?? "").contains("dlattach") {
                    collectImage(image)
                }
            }
        }

        private mutating func span(_ node: HTMLNode) {
            let saved = style
            if let raw = node.attr("style"), let color = Self.inlineColor(raw) {
                style.color = color
            }
            walk(childrenOf: node)
            style = saved
        }

        private static func inlineColor(_ style: String) -> Color? {
            guard let range = style.range(of: "color\\s*:", options: .regularExpression) else { return nil }
            let rest = style[range.upperBound...]
            let value = rest.split(separator: ";").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return color(named: value)
        }

        private static func color(named value: String) -> Color? {
            let name = value.lowercased()
            if name.hasPrefix("#") {
                let hex = String(name.dropFirst())
                guard hex.count == 6, let number = Int(hex, radix: 16) else { return nil }
                return Color(
                    red: Double((number >> 16) & 0xFF) / 255,
                    green: Double((number >> 8) & 0xFF) / 255,
                    blue: Double(number & 0xFF) / 255
                )
            }
            switch name {
            case "blue": return .blue
            case "red": return .red
            case "green": return .green
            case "orange": return .orange
            case "purple": return .purple
            case "gray", "grey": return .gray
            case "brown": return .brown
            case "cyan": return .cyan
            case "magenta": return .pink
            case "yellow": return .yellow
            case "black": return .black
            case "white": return .white
            default: return nil
            }
        }

        private mutating func appendInlineImage(_ node: HTMLNode, preferredURL: URL? = nil) {
            guard let src = node.attr("src"),
                  var url = preferredURL ?? AppConfig.resolve(src, relativeTo: baseURL),
                  url.scheme == "https" || url.scheme == "http" else { return }

            let path = url.path.lowercased()
            if path.contains("/smileys/") || path.contains("/post/") { return }
            if path.contains("/themes/") || path.contains("/images/icons/") { return }
            if node.hasClass("smiley") { return }

            // Attachment thumbnails carry a ;thumb suffix; the full file is ;image.
            if url.absoluteString.contains(";thumb") {
                url = URL(string: url.absoluteString.replacingOccurrences(of: ";thumb", with: ";image")) ?? url
            }

            flushTextBlock()
            pendingBreaks = 0
            let block = PostBlock.image(url)
            if !blocks.contains(block) { blocks.append(block) }
        }

        private mutating func appendVideoBlock(_ id: String) {
            flushTextBlock()
            pendingBreaks = 0
            let block = PostBlock.video(id)
            if !blocks.contains(block) { blocks.append(block) }
        }

        private mutating func collectImage(_ node: HTMLNode) {
            guard var resolved = node.attr("src").flatMap({ AppConfig.resolve($0, relativeTo: baseURL) }) else { return }
            // Attachment thumbnails are requested with ";thumb"; the plain ";image" URL is the original.
            if resolved.absoluteString.contains("dlattach"), resolved.absoluteString.hasSuffix(";thumb") {
                resolved = URL(string: String(resolved.absoluteString.dropLast(";thumb".count))) ?? resolved
            }
            let url = resolved
            guard url.scheme == "https" || url.scheme == "http" else { return }

            // Smileys, theme chrome and post icons are noise in a native reader.
            let path = url.path.lowercased()
            if path.contains("/smileys/") || path.contains("/post/") { return }
            if path.contains("/themes/") || path.contains("/images/icons/") { return }
            if node.hasClass("smiley") { return }
            if !images.contains(url) { images.append(url) }
        }

        // MARK: Text

        private mutating func flushTextBlock() {
            guard !result.characters.isEmpty else { return }

            var buffer = AttributedString()
            var bufferIsQuote = false
            var started = false

            for run in result.runs {
                let isQuote = (run[QuoteDepthAttribute.self] ?? 0) > 0
                let piece = AttributedString(result[run.range])

                if !started {
                    buffer = piece
                    bufferIsQuote = isQuote
                    started = true
                } else if isQuote == bufferIsQuote {
                    buffer += piece
                } else {
                    blocks.append(bufferIsQuote ? .quote(buffer) : .text(buffer))
                    buffer = piece
                    bufferIsQuote = isQuote
                }
            }

            if !buffer.characters.isEmpty {
                blocks.append(bufferIsQuote ? .quote(buffer) : .text(buffer))
            }
            result = AttributedString()
        }

        private mutating func appendCodeBlock(_ raw: String) {
            flushTextBlock()
            pendingBreaks = 0
            let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return }
            blocks.append(.code(code))
        }

        private mutating func appendText(_ raw: String) {
            guard !raw.isEmpty else { return }
            let text = style.code ? raw : collapseWhitespace(raw)
            append(text: text, style: style)
        }

        private mutating func append(childrenOf node: HTMLNode, container: AttributeContainer) {
            for child in node.children { append(child, container: container) }
        }

        private mutating func append(_ node: HTMLNode, container: AttributeContainer) {
            if node.isText {
                append(text: collapseWhitespace(node.text), container: container)
                return
            }
            switch node.tag {
            case "br":
                ensureBreak()
            case "img":
                appendInlineImage(node)
            default:
                for child in node.children { append(child, container: container) }
            }
        }

        private mutating func append(text: String, style: Style) {
            append(text: text, container: attributes(for: style))
        }

        private mutating func append(text raw: String, container: AttributeContainer) {
            guard !raw.isEmpty else { return }
            var text = raw
            // No leading whitespace at the very start of a post.
            if result.characters.isEmpty {
                while let first = text.first, first.isWhitespace { text.removeFirst() }
            }
            // Collapse the whitespace that block boundaries introduce.
            if result.characters.last == " " {
                while let first = text.first, first == " " { text.removeFirst() }
            }
            guard !text.isEmpty else { return }
            flushBreaks()
            var piece = AttributedString(text)
            piece.setAttributes(container)
            result += piece
        }

        // MARK: Breaks

        private mutating func ensureBreak() {
            pendingBreaks = min(pendingBreaks + 1, 2)
        }

        private mutating func flushBreaks() {
            guard pendingBreaks > 0 else { return }
            if !result.characters.isEmpty {
                var piece = AttributedString(String(repeating: "\n", count: pendingBreaks))
                piece.setAttributes(attributes(for: style))
                result += piece
            }
            pendingBreaks = 0
        }

        // MARK: Attributes

        private func attributes(for style: Style) -> AttributeContainer {
            var container = AttributeContainer()
            var size: CGFloat = style.isSmall ? 13 : 16
            if style.isHeader { size = 18 }

            var font = Font.system(size: size, design: style.code ? .monospaced : .default)
            if style.bold { font = font.weight(.semibold) }
            if style.italic { font = font.italic() }
            container.font = font

            if let color = style.color {
                container.foregroundColor = color
            } else {
                container.foregroundColor = style.quoteDepth > 0 ? Color.primary.opacity(0.72) : Color.primary
            }

            container[PostFontSizeAttribute.self] = Double(size)
            container[QuoteDepthAttribute.self] = style.quoteDepth

            if let link = style.link {
                container.link = link
                container.underlineStyle = .single
            }

            var intent = InlinePresentationIntent()
            if style.bold { intent.insert(.stronglyEmphasized) }
            if style.italic { intent.insert(.emphasized) }
            if style.code { intent.insert(.code) }
            if !intent.isEmpty { container.inlinePresentationIntent = intent }

            return container
        }

        private func collapseWhitespace(_ string: String) -> String {
            let hadLeading = string.first?.isWhitespace ?? false
            let hadTrailing = string.last?.isWhitespace ?? false
            let core = string
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
            if core.isEmpty { return hadLeading || hadTrailing ? " " : "" }
            return (hadLeading ? " " : "") + core + (hadTrailing ? " " : "")
        }

        // MARK: Finish

        mutating func finish() -> PostContent {
            flushTextBlock()

            // Flattened text keeps search and the existing tests working.
            var combined = AttributedString()
            for block in blocks {
                switch block {
                case .text(let text), .quote(let text):
                    combined += text
                case .code(let code):
                    if !combined.characters.isEmpty {
                        combined += AttributedString("\n")
                    }
                    combined += AttributedString(code)
                case .image, .video:
                    // Media lives in blocks; the flattened text skips it.
                    break
                }
            }

            return PostContent(text: combined, blocks: blocks, images: images)
        }
    }
}


extension AttributedString {
    /// Re-applies the user's post-text scale while keeping bold/italic/code.
    func scaledForPostText(_ scale: Double) -> AttributedString {
        guard scale != 1 else { return self }
        var copy = self
        for run in copy.runs {
            guard let size = run[PostRenderer.PostFontSizeAttribute.self] else { continue }
            var font = Font.system(size: size * scale)
            let intent = run.inlinePresentationIntent ?? []
            if intent.contains(.stronglyEmphasized) { font = font.weight(.semibold) }
            if intent.contains(.emphasized) { font = font.italic() }
            if intent.contains(.code) { font = .system(size: size * scale, design: .monospaced) }
            copy[run.range].font = font
        }
        return copy
    }
}
