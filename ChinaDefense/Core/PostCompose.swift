import Foundation
import Observation

struct AttachmentUpload: Identifiable, Sendable {
    let id = UUID()
    let fileName: String
    let mimeType: String
    let data: Data
}

enum PostOutcome: Sendable {
    case preview(subject: String, content: PostContent, form: PostFormInfo)
    case posted(topicID: Int?, messageID: Int?)
}

/// Drives the new-topic / reply composer: form tokens, draft text, SMF preview
/// and the final submission.
@MainActor
@Observable
final class PostComposer {
    enum Mode {
        case newTopic(BoardTarget)
        case reply(ForumTopic, quoteMessageID: Int?)
    }

    struct Preview {
        var subject: String
        var content: PostContent
    }

    let mode: Mode
    private(set) var form: PostFormInfo?
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var preview: Preview?

    var subject = ""
    var message = ""
    var errorMessage: String?

    private let client = SMFClient.shared

    init(mode: Mode) {
        self.mode = mode
    }

    var isNewTopic: Bool {
        if case .newTopic = mode { return true }
        return false
    }

    var navigationTitle: String {
        isNewTopic ? "New Topic" : "Reply"
    }

    var topicTitle: String {
        if case .reply(let topic, _) = mode { return topic.title }
        return ""
    }

    var boardName: String? {
        if case .newTopic(let board) = mode { return board.name }
        return nil
    }

    var canSubmit: Bool {
        form != nil
            && !isSubmitting
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!isNewTopic || !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func load(session: Session) async {
        guard form == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded: PostFormInfo
            switch mode {
            case .newTopic(let board):
                loaded = try await client.fetchPostForm(boardID: board.id)
            case .reply(let topic, let quoteMessageID):
                loaded = try await client.fetchPostForm(topicID: topic.id, quoteMessageID: quoteMessageID)
            }

            form = loaded
            if subject.isEmpty {
                subject = loaded.subject
            }
            if message.isEmpty {
                message = loaded.message
            }
            errorMessage = nil
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestPreview(session: Session) async {
        guard let form, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch try await client.submitPost(form: form, subject: subject, message: message, preview: true) {
            case .preview(let previewSubject, let content, let refreshedForm):
                preview = Preview(subject: previewSubject, content: content)
                self.form = refreshedForm
            case .posted:
                break
            }
            errorMessage = nil
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit(session: Session, attachments: [AttachmentUpload] = []) async -> PostOutcome? {
        let hasBody = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
        let hasSubject = !isNewTopic || !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard let form, hasBody, hasSubject, !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let outcome = try await client.submitPost(
                form: form,
                subject: subject,
                message: message,
                preview: false,
                attachments: attachments
            )
            errorMessage = nil
            return outcome
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }
}
