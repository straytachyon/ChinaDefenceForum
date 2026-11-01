import SwiftUI
import UniformTypeIdentifiers

/// New topic / reply composer with SMF's BBCode formatting tools, server-rendered
/// preview and post submission.
struct ComposeView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let mode: PostComposer.Mode
    var onPosted: (PostOutcome) -> Void

    @State private var model: PostComposer
    @State private var editor = BBCodeEditorController()
    @State private var showPreview = false

    @State private var showLinkDialog = false
    @State private var linkURL = ""
    @State private var linkText = ""

    @State private var showImageDialog = false
    @State private var imageURL = ""

    @State private var showYouTubeDialog = false
    @State private var youtubeURL = ""

    @State private var attachments: [AttachmentUpload] = []
    @State private var showFileImporter = false

    init(mode: PostComposer.Mode, onPosted: @escaping (PostOutcome) -> Void = { _ in }) {
        self.mode = mode
        self.onPosted = onPosted
        _model = State(initialValue: PostComposer(mode: mode))
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.form == nil {
                    ProgressView("Opening editor…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage, model.form == nil {
                    ContentUnavailableView {
                        Label("Couldn’t Open Editor", systemImage: "square.and.pencil")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await model.load(session: session) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    composeForm
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                formattingToolbar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            Task { await post() }
                        }
                        .disabled(!canPost)
                        .fontWeight(.semibold)
                    }
                }
            }
            .task { await model.load(session: session) }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    addFiles(urls)
                case .failure(let error):
                    model.errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showPreview) {
                if let preview = model.preview {
                    PreviewSheet(
                        subject: preview.subject,
                        content: preview.content,
                        attachmentNames: attachments.map(\.fileName)
                    )
                }
            }
            .alert("Insert Link", isPresented: $showLinkDialog) {
                TextField("https://…", text: $linkURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Link text (optional)", text: $linkText)
                Button("Cancel", role: .cancel) {}
                Button("Insert") { insertLink() }
            } message: {
                Text("Enter the address to link to.")
            }
            .alert("Insert YouTube Video", isPresented: $showYouTubeDialog) {
                TextField("https://youtube.com/watch?v=…", text: $youtubeURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Insert") { insertYouTube() }
            } message: {
                Text("Paste a YouTube link or an 11-character video ID.")
            }
            .alert("Insert Image", isPresented: $showImageDialog) {
                TextField("https://…", text: $imageURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Insert") { insertImage() }
            } message: {
                Text("Paste the image URL.")
            }
        }
    }

    // MARK: - Form

    private var composeForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let board = model.boardName {
                    Label(board, systemImage: "bubble.left.and.bubble.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                TextField("Subject", text: Binding(
                    get: { model.subject },
                    set: { model.subject = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.headline)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                BBCodeEditor(
                    text: Binding(
                        get: { model.message },
                        set: { model.message = $0 }
                    ),
                    controller: editor,
                    placeholder: ""
                )
                .frame(minHeight: 230, maxHeight: 420)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(alignment: .topLeading) {
                    if model.message.isEmpty {
                        Text("Write your post…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 20)
                            .padding(.leading, 15)
                            .allowsHitTesting(false)
                    }
                }

                if !attachments.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(attachments) { file in
                            HStack(spacing: 10) {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(AppTheme.accent)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.fileName)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    attachments.removeAll { $0.id == file.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(file.fileName)")
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                }

                HStack {
                    Text("\(model.message.count) characters")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Button {
                        Task {
                            await model.requestPreview(session: session)
                            if model.preview != nil { showPreview = true }
                        }
                    } label: {
                        Label("Preview", systemImage: "eye")
                            .font(.caption.weight(.medium))
                    }
                    .disabled(model.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSubmitting)
                }

                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Formatting toolbar

    private var formattingToolbar: some View {
        FlowLayout(spacing: 4) {
                formatButton("bold", "Bold") { editor.wrap("[b]", "[/b]", "bold text") }
                formatButton("italic", "Italic") { editor.wrap("[i]", "[/i]", "italic text") }
                formatButton("underline", "Underline") { editor.wrap("[u]", "[/u]", "underlined text") }
                formatButton("strikethrough", "Strikethrough") { editor.wrap("[s]", "[/s]", "struck text") }

                formatButton("text.quote", "Quote") { editor.wrap("[quote]", "[/quote]", "Quote") }
                formatButton("chevron.left.forwardslash.chevron.right", "Code") { editor.wrap("[code]", "[/code]", "code") }
                formatButton("list.bullet", "Bullet list") {
                    editor.insert("[list]\n[li]item[/li]\n[/list]")
                }
                formatButton("list.number", "Numbered list") {
                    editor.insert("[list type=decimal]\n[li]item[/li]\n[/list]")
                }

                formatButton("link", "Insert link") { showLinkDialog = true }
                formatButton("photo", "Insert image") { showImageDialog = true }
                formatButton("play.rectangle", "Insert YouTube video") { showYouTubeDialog = true }
                formatButton("paperclip", "Attach file") { showFileImporter = true }

                Menu {
                    ForEach(["8pt", "10pt", "12pt", "14pt", "18pt", "24pt"], id: \.self) { size in
                        Button(size) { editor.wrap("[size=\(size)]", "[/size]", "text") }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Font size")

                Menu {
                    ForEach(["red", "blue", "green", "orange", "purple", "gray"], id: \.self) { color in
                        Button(color.capitalized) { editor.wrap("[color=\(color)]", "[/color]", "text") }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Font colour")

                Menu {
                    Button("Left") { editor.wrap("[left]", "[/left]", "text") }
                    Button("Center") { editor.wrap("[center]", "[/center]", "text") }
                    Button("Right") { editor.wrap("[right]", "[/right]", "text") }
                } label: {
                    Image(systemName: "text.alignleft")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Alignment")

                formatButton("eye.slash", "Spoiler") { editor.wrap("[spoiler]", "[/spoiler]", "Spoiler") }
                formatButton("tablecells", "Table") {
                    editor.insert("[table]\n[tr]\n[td]cell[/td]\n[/tr]\n[/table]")
                }
                formatButton("textformat.superscript", "Superscript") { editor.wrap("[sup]", "[/sup]", "text") }
                formatButton("textformat.subscript", "Subscript") { editor.wrap("[sub]", "[/sub]", "text") }

                Menu {
                    ForEach(["Arial", "Times New Roman", "Courier New", "Verdana"], id: \.self) { face in
                        Button(face) { editor.wrap("[font=\(face)]", "[/font]", "text") }
                    }
                } label: {
                    Image(systemName: "textformat")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Font face")

                Menu {
                    ForEach([":)", ":-)", ";)", ":D", ":P", ":(", ":o", "::)", ":laugh:"], id: \.self) { smiley in
                        Button(smiley) { editor.insert(smiley) }
                    }
                } label: {
                    Image(systemName: "face.smiling")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Smileys")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func formatButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    private func insertLink() {
        let url = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        editor.insert("[url=\(url)]\(text.isEmpty ? url : text)[/url]")
        linkURL = ""
        linkText = ""
    }

    private func insertYouTube() {
        let input = youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        var videoID: String?
        if let url = URL(string: input) {
            videoID = PostRenderer.youTubeID(from: url)
        }
        if videoID == nil, input.count == 11,
           input.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            videoID = input
        }
        guard let videoID else { return }

        editor.insert("[youtube]\(videoID)[/youtube]")
        youtubeURL = ""
    }

    private func insertImage() {
        let url = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        editor.insert("[img]\(url)[/img]")
        imageURL = ""
    }

    private var canPost: Bool {
        guard model.form != nil, !model.isSubmitting else { return false }
        let hasBody = !model.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
        let hasSubject = !model.isNewTopic || !model.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasBody && hasSubject
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            guard data.count <= 25 * 1024 * 1024 else {
                model.errorMessage = "\(url.lastPathComponent) is too large (maximum 25 MB)."
                continue
            }
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            attachments.append(AttachmentUpload(fileName: url.lastPathComponent, mimeType: mime, data: data))
        }
    }

    private func post() async {
        guard let outcome = await model.submit(session: session, attachments: attachments) else { return }
        onPosted(outcome)
        dismiss()
    }
}

private struct PreviewSheet: View {
    let subject: String
    let content: PostContent
    var attachmentNames: [String] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !subject.isEmpty {
                        Text(subject)
                            .font(.headline)
                    }
                    ForEach(Array(content.blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .text(let text):
                            Text(text.scaledForPostText(settings.postTextScale))
                                .textSelection(.enabled)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        case .code(let code):
                            CodeBlockView(code: code)
                        case .image(let url):
                            InlinePostImage(url: url)
                        case .video(let id):
                            YouTubeEmbedView(videoID: id)
                                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    if !content.images.isEmpty {
                        PostImageGrid(urls: content.images)
                    }

                    if !attachmentNames.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Attachments")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                            ForEach(attachmentNames, id: \.self) { name in
                                Label(name, systemImage: "doc.fill")
                                    .font(.caption)
                            }
                            Text("Files are uploaded when you tap Post.")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
