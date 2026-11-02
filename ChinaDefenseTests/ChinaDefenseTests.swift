import Foundation
import Testing
@testable import ChinaDefense

// MARK: - Fixtures
//
// Markup mirrors SMF 2.1.8's stock Themes/default templates (BoardIndex, MessageIndex,
// Recent and Display). Keeping the fixtures close to the real templates is what makes
// these tests meaningful: the selectors in SMFParser follow this structure.

enum Fixtures {
    static let boardIndex = """
    <!DOCTYPE html>
    <html><head><title>China Defense Forum</title></head>
    <body class="action_home">
    <script>
        var smf_member_id = 42;
        var smf_session_id = "abc";
    </script>
    <div id="top_section">
        <ul id="top_info">
            <li class="welcome">Welcome to <strong>China Defense Forum</strong>.</li>
            <li><a href="https://www.china-defense.com/smf/index.php?action=profile;u=42">Observer
                <span class="amt">2</span></a></li>
        </ul>
    </div>
    <div id="boardindex_table" class="boardindex_table">
        <div class="cat_bar" id="category_1">
            <h3 class="catbg">Chinese Military</h3>
        </div>
        <div id="category_1_boards" class="main_container">
            <div id="board_10" class="up_contain board_row">
                <div class="board_icon"><a href="?board=10.0" class="board_on"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="https://www.china-defense.com/smf/index.php?board=10.0" id="b10">PLA News</a>
                    <div class="board_description">Daily news about the People&#039;s Liberation Army.</div>
                </div>
                <div class="board_stats"><p>Topics: 1,204<br>Posts: 8,931</p></div>
                <div class="lastpost"><p><a href="?topic=50.0">Today at 08:12:00 AM</a> by <a href="?action=profile;u=7">tester</a></p></div>
                <div id="board_10_children" class="children">
                    <a href="?board=11.0">Navy</a>
                    <a href="?board=12.0">Air Force</a>
                </div>
            </div>
            <div id="board_13" class="up_contain board_row">
                <div class="board_icon"><a href="?board=13.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="https://www.china-defense.com/smf/index.php?board=13.0" id="b13">Naval Programs</a>
                    <div class="board_description">Carriers, destroyers and submarines.</div>
                </div>
                <div class="board_stats"><p>Topics: 88<br>Posts: 1,022</p></div>
                <div class="lastpost"><p>Never</p></div>
            </div>
        </div>
        <div class="cat_bar" id="category_2">
            <h3 class="catbg">Community</h3>
        </div>
        <div id="category_2_boards" class="main_container">
            <div id="board_20" class="up_contain board_row">
                <div class="board_icon"><a href="?board=20.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="https://www.china-defense.com/smf/index.php?board=20.0" id="b20">General Discussion</a>
                    <div class="board_description">Off topic and introductions.</div>
                </div>
                <div class="board_stats"><p>Topics: 4<br>Posts: 9</p></div>
                <div class="lastpost"><p><a href="?topic=60.0">Yesterday at 11:02:00 PM</a></p></div>
            </div>
        </div>
    </div>
    <div class="mark_read">
        <a href="https://www.china-defense.com/smf/index.php?action=markasread;sa=all;token=abc123">Mark all read</a>
    </div>
    </body></html>
    """

    static let unread = """
    <!DOCTYPE html>
    <html><head><title>Show unread posts</title></head>
    <body>
    <script>var smf_member_id = 42;</script>
    <div id="unread">
        <div id="display_head" class="information">
            <h2 class="display_title">Unread Posts</h2>
        </div>
        <div class="pagesection">
            <div class="pagelinks floatleft">
                <span class="current_page">1</span>
                <a class="navPages" href="?action=unread;all;start=20">2</a>
                <a class="navPages" href="?action=unread;all;start=40">3</a>
            </div>
        </div>
        <div id="topic_container">
            <div class="windowbg">
                <div class="board_icon"><img src="?action=dlattach;topic=900.0;attach=1"></div>
                <div class="info">
                    <div class="icons floatright"><span class="main_icons lock"></span></div>
                    <div class="recent_title">
                        <a href="?topic=900.msg1200#new" id="newicon1200" class="new_posts">new</a>
                        <span class="preview" title="Latest reply"><span id="msg_1200">
                            <a href="https://www.china-defense.com/smf/index.php?topic=900.0" class="subject" id="subject_1200">J-20 programme update</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=12">observer</a></p>
                </div>
                <div class="board_stats centertext"><p>3 replies<br>45 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=7">tester</a> on <a href="?topic=900.msg1205;topicseen#msg1205">Today at 09:15:00 AM</a></p></div>
            </div>
            <div class="windowbg2">
                <div class="board_icon"><img src="?action=dlattach;topic=901.0;attach=2"></div>
                <div class="info">
                    <div class="icons floatright"><span class="main_icons sticky"></span></div>
                    <div class="recent_title">
                        <span class="preview"><span id="msg_1201">
                            <a href="https://www.china-defense.com/smf/index.php?topic=901.0" class="subject" id="subject_1201">Forum rules — read first</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=1">admin</a></p>
                    <span id="pages1201" class="topic_pages">1 2 3</span>
                </div>
                <div class="board_stats centertext"><p>12 replies<br>900 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=5">mod</a> on <a href="?topic=901.0">October 30, 2026, 10:05:00 PM</a></p></div>
            </div>
        </div>
        <div class="pagelinks"><a class="navPages" href="?action=unread;all;start=20">&raquo;</a></div>
    </div>
    </body></html>
    """

    static let boardTopics = """
    <!DOCTYPE html>
    <html><head><title>PLA News</title></head>
    <body>
    <div id="display_head" class="information">
        <h2 class="display_title">PLA News</h2>
        <p>Daily news about the People&#039;s Liberation Army.</p>
    </div>
    <div class="pagesection">
        <div class="pagelinks floatleft">
            <span class="current_page">2</span>
            <a class="navPages" href="?board=10.40">3</a>
            <a class="navPages" href="?board=10.0">1</a>
        </div>
    </div>
    <div id="topic_container">
        <div class="windowbg">
            <div class="board_icon"><img src="?action=dlattach;topic=700.0;attach=3"></div>
            <div class="info">
                <div class="icons floatright"><span class="main_icons sticky"></span></div>
                <div class="message_index_title">
                    <span class="preview"><span id="msg_1100">
                        <a href="https://www.china-defense.com/smf/index.php?topic=700.0" class="subject" id="subject_1100">Pinned: PLA daily digest</a>
                    </span></span>
                </div>
                <p class="floatleft">Started by <a href="?action=profile;u=1">admin</a></p>
            </div>
            <div class="board_stats centertext"><p>Replies: 120<br>Views: 4,512</p></div>
            <div class="lastpost"><p><a href="?topic=700.0">Today at 07:00:00 AM</a> by <a href="?action=profile;u=3">reporter</a></p></div>
        </div>
        <div class="windowbg2">
            <div class="board_icon"><img src="?action=dlattach;topic=701.0;attach=4"></div>
            <div class="info">
                <div class="message_index_title">
                    <a href="?topic=701.msg1101#new" id="newicon1101" class="new_posts">new</a>
                    <span class="preview"><span id="msg_1101">
                        <a href="https://www.china-defense.com/smf/index.php?topic=701.0" class="subject" id="subject_1101">Type 076 launched</a>
                    </span></span>
                </div>
                <p class="floatleft">Started by <a href="?action=profile;u=9">shipwatcher</a></p>
            </div>
            <div class="board_stats centertext"><p>Replies: 4<br>Views: 88</p></div>
            <div class="lastpost"><p><a href="?topic=701.0">Yesterday at 06:40:00 PM</a> by <a href="?action=profile;u=9">shipwatcher</a></p></div>
        </div>
    </div>
    </body></html>
    """

    static let topic = """
    <!DOCTYPE html>
    <html><head><title>Type 076 launched</title></head>
    <body>
    <script>var smf_member_id = 42;</script>
    <div id="display_head" class="information">
        <h2 class="display_title"><span id="top_subject">Type 076 launched</span></h2>
        <p>Started by shipwatcher, Today at 06:40:00 PM</p>
        <p class="navigate_section"><a href="?board=10.0">PLA News</a></p>
    </div>
    <div class="pagesection">
        <div class="pagelinks floatleft">
            <span class="current_page">1</span>
            <a class="navPages" href="?topic=701.15">2</a>
        </div>
    </div>
    <div class="post_wrapper">
        <div class="poster">
            <h4><a href="?action=profile;u=9">shipwatcher</a></h4>
            <img class="avatar" src="https://www.china-defense.com/smf/avatars/avatar_9.png">
        </div>
        <div class="postarea">
            <div class="keyinfo">
                <div id="subject_1101" class="subject_title"><a href="?topic=701.msg1101#msg1101">Type 076 launched</a></div>
                <div class="postinfo">
                    <a href="?topic=701.msg1101#msg1101" rel="nofollow" class="smalltext">Today at 06:40:00 PM</a>
                </div>
            </div>
            <div class="post">
                <div class="inner" data-msgid="1101" id="msg_1101">
                    <div class="quoteheader">Quote from: observer on Today at 06:30:00 PM</div>
                    <blockquote class="bbc_standard_quote">A new <strong>amphibious</strong> ship.</blockquote>
                    <br>More pictures <a href="?topic=701.0" class="bbc_link">in this thread</a>.
                    <br><img src="https://www.china-defense.com/smf/attachments/photo1.jpg" alt="" class="bbc_img">
                    <img src="https://www.china-defense.com/smf/Smileys/default/smiley.gif" alt=":)">
                    <div class="codeheader">Code:</div>
                    <div class="bbc_code">hull = 076</div>
                </div>
            </div>
        </div>
    </div>
    <div class="post_wrapper">
        <div class="poster">
            <h4><a href="?action=profile;u=7">tester</a></h4>
        </div>
        <div class="postarea">
            <div class="keyinfo">
                <div id="subject_1102" class="subject_title">Re: Type 076 launched</div>
                <div class="postinfo">
                    <a href="?topic=701.msg1102#msg1102" rel="nofollow" class="smalltext">Yesterday at 11:10:00 PM</a>
                </div>
                <span class="page_number floatright">#2</span>
            </div>
            <div class="post">
                <div class="inner" data-msgid="1102" id="msg_1102">
                    <p>Thanks for sharing.</p>
                </div>
            </div>
        </div>
    </div>
    </body></html>
    """

    static let loginPage = """
    <!DOCTYPE html>
    <html><head><title>Log in</title></head>
    <body>
    <form class="login" action="https://www.china-defense.com/smf/index.php?action=login2" name="frmLogin" id="frmLogin" method="post">
        <input type="text" id="loginuser" name="user" value="">
        <input type="password" id="loginpass" name="passwrd" value="">
        <input type="submit" value="Log in" class="button">
        <input type="hidden" name="session_token_a" value="0123456789abcdef0123456789abcdef">
        <input type="hidden" name="session_token_b" value="fedcba9876543210fedcba9876543210">
    </form>
    </body></html>
    """
}

// MARK: - Board index

struct BoardIndexParsingTests {
    @Test func parsesCategoriesAndTopLevelBoards() {
        let result = SMFParser.parseBoardIndex(Fixtures.boardIndex)

        #expect(result.categories.count == 2)
        #expect(result.categories[0].name == "Chinese Military")
        #expect(result.categories[0].boards.map(\.name) == ["PLA News", "Naval Programs"])
        #expect(result.categories[1].boards.count == 1)
        #expect(result.boards.count == 3)
    }

    @Test func readsBoardDescriptionsAndCounts() {
        let result = SMFParser.parseBoardIndex(Fixtures.boardIndex)
        let pla = result.boards.first { $0.id == 10 }

        #expect(pla?.summary == "Daily news about the People's Liberation Army.")
        #expect(pla?.topicCount == 1204)
        #expect(pla?.postCount == 8931)
    }

    @Test func collectsChildBoardsWithoutPromotingThem() {
        let result = SMFParser.parseBoardIndex(Fixtures.boardIndex)
        let pla = result.boards.first { $0.id == 10 }

        #expect(pla?.childBoards.map(\.id) == [11, 12])
        #expect(result.boards.contains { $0.id == 11 } == false)
    }

    @Test func findsMarkAllReadLinkAndMember() {
        let result = SMFParser.parseBoardIndex(Fixtures.boardIndex)
        #expect(result.markAllReadURL?.absoluteString.contains("action=markasread") == true)

        let member = SMFParser.parseMember(in: Fixtures.boardIndex)
        #expect(member.id == 42)
        #expect(member.name == "Observer")
    }

    @Test func detectsGuestSession() {
        let member = SMFParser.parseMember(in: Fixtures.loginPage)
        #expect(member.id == 0)
    }
}

// MARK: - Unread / topic lists

struct TopicListParsingTests {
    @Test func parsesUnreadRows() {
        let page = SMFParser.parseTopicList(Fixtures.unread, start: 0)

        #expect(page.topics.count == 2)
        #expect(page.topics[0].id == 900)
        #expect(page.topics[0].title == "J-20 programme update")
        #expect(page.topics[0].author == "observer")
        #expect(page.topics[0].replies == 3)
        #expect(page.topics[0].views == 45)
        #expect(page.topics[0].isUnread == true)
        #expect(page.topics[0].isLocked == true)
        #expect(page.topics[0].lastPostText == "Today at 09:15 AM")
        #expect(page.topics[0].firstUnreadMessageID == 1200)
        #expect(page.topics[0].lastMessageID == 1205)
    }

    @Test func recognisesStickyAndPageCount() {
        let page = SMFParser.parseTopicList(Fixtures.unread, start: 0)
        let sticky = page.topics[1]

        #expect(sticky.id == 901)
        #expect(sticky.isSticky == true)
        #expect(sticky.isUnread == false)
        #expect(sticky.pageCount == 3)
    }

    @Test func computesPaginationFromUnreadLinks() {
        let page = SMFParser.parseTopicList(Fixtures.unread, start: 0)

        #expect(page.currentStart == 0)
        #expect(page.perPage == 20)
        #expect(page.maxStart == 40)
        #expect(page.nextStart == 20)
        #expect(page.hasNextPage == true)
    }

    @Test func parsesBoardHeaderAndBoardPagination() {
        let page = SMFParser.parseTopicList(Fixtures.boardTopics, start: 20)

        #expect(page.boardName == "PLA News")
        #expect(page.boardSummary == "Daily news about the People's Liberation Army.")
        #expect(page.topics.count == 2)
        #expect(page.currentStart == 20)
        #expect(page.maxStart == 40)
        #expect(page.nextStart == 40)
    }

    @Test func readsCountsFromBothSMFWordingStyles() {
        let unread = SMFParser.parseTopicList(Fixtures.unread, start: 0)
        let board = SMFParser.parseTopicList(Fixtures.boardTopics, start: 0)

        #expect(unread.topics[0].replies == 3)
        #expect(unread.topics[0].views == 45)
        #expect(board.topics[0].replies == 120)
        #expect(board.topics[0].views == 4512)
    }
}

// MARK: - Topic

struct TopicParsingTests {
    @Test func parsesTopicAndPosts() {
        let page = SMFParser.parseTopic(Fixtures.topic, topicID: 701, start: 0)

        #expect(page.title == "Type 076 launched")
        #expect(page.boardName == "PLA News")
        #expect(page.boardID == 10)
        #expect(page.posts.count == 2)
        #expect(page.posts[0].id == 1101)
        #expect(page.posts[0].author == "shipwatcher")
        #expect(page.posts[0].authorID == 9)
        #expect(page.posts[0].postNumber == nil)
        #expect(page.posts[1].postNumber == 2)
        #expect(page.posts[0].avatarURL?.lastPathComponent == "avatar_9.png")
    }

    @Test func computesTopicPagination() {
        let page = SMFParser.parseTopic(Fixtures.topic, topicID: 701, start: 0)

        #expect(page.perPage == 15)
        #expect(page.maxStart == 15)
        #expect(page.nextStart == 15)
        #expect(page.hasNextPage == true)
    }

    @Test func rendersPostBodiesIntoAttributedText() {
        let page = SMFParser.parseTopic(Fixtures.topic, topicID: 701, start: 0)
        let body = page.posts[0].content
        let text = String(body.text.characters)

        #expect(text.contains("Quote from: observer"))
        #expect(text.contains("A new amphibious ship."))
        #expect(text.contains("More pictures"))
        #expect(text.contains("hull = 076"))
        #expect(text.contains(":)" ) == false)
    }

    @Test func extractsOnlyRealImagesNotSmileys() {
        let page = SMFParser.parseTopic(Fixtures.topic, topicID: 701, start: 0)
        let inlineImages = page.posts[0].content.blocks.compactMap { block -> URL? in
            if case .image(let url) = block { return url }
            return nil
        }

        #expect(inlineImages.count == 1)
        #expect(inlineImages.first?.lastPathComponent == "photo1.jpg")
        // Inline pictures belong in the flow, not in the attachment gallery.
        #expect(page.posts[0].content.images.isEmpty)
    }

    @Test func usesFullSizeImageBehindThumbnailLink() {
        let html = """
        <div class="post"><div class="inner" data-msgid="1" id="msg_1">
        Before <a href="https://example.com/full/photo.jpg"><img src="https://example.com/thumb/photo.jpg;thumb" alt="" class="bbc_img"></a> after.
        </div></div>
        """
        let content = PostRenderer.render(html: html)
        let images = content.blocks.compactMap { block -> URL? in
            if case .image(let url) = block { return url }
            return nil
        }

        #expect(images.count == 1)
        #expect(images.first?.absoluteString == "https://example.com/full/photo.jpg")
    }

    @Test func keepsInlineImageInReadingOrder() {
        let page = SMFParser.parseTopic(Fixtures.topic, topicID: 701, start: 0)
        let blocks = page.posts[0].content.blocks
        guard let imageIndex = blocks.firstIndex(where: { block in
            if case .image = block { return true }
            return false
        }) else {
            Issue.record("Expected an inline image block")
            return
        }

        #expect(imageIndex > 0)
        if case .text = blocks[imageIndex - 1] {} else {
            Issue.record("Image should keep its position after the text that precedes it")
        }
    }

    @Test func preservesParagraphSpacingAndInlineColour() {
        let content = PostRenderer.render(
            html: "<div>First line<br><br>Second <b><span style=\"color: blue;\">blue bold</span></b></div>"
        )
        let text = String(content.text.characters)

        #expect(text.contains("First line\n\nSecond"))
        let bold = content.text.runs.filter {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        }
        #expect(!bold.isEmpty)
    }

    @Test func rendersQuotesAsBorderedBlocks() {
        let content = PostRenderer.render(html: """
        <blockquote><div class="quoteheader">Quote from: vincent</div><div class="quote">Original quoted text</div></blockquote>
        <p>Reply after the quote.</p>
        """)
        let quoteIndex = content.blocks.firstIndex {
            if case .quote = $0 { return true }
            return false
        }
        #expect(quoteIndex != nil)
        #expect(content.text.characters.contains("Original quoted text"))
    }

    @Test func parsesAlertPopupCountAndList() {
        let popup = """
        <div class="alerts_unread">
            <a class="unread_notify"><span class="alert_text">One</span></a>
            <div class="unread_notify"><span class="alert_text">Two</span></div>
        </div>
        <a href="https://example.com/index.php?action=profile;area=notification;sa=markread;token=abc">Mark all read</a>
        """
        #expect(SMFParser.parseAlertPopupCount(popup) == 2)
        #expect(SMFParser.parseAlertPopupCount("<div class=\"no_unread\">No unread alerts.</div>") == 0)

        let list = """
        <table id="alerts">
            <tr class="windowbg">
                <td class="alert_text">
                    <div><a href="https://example.com/topic=1.msg2">deepseek_test</a> liked your post</div>
                    <time class="alert_inline_time">Today at 11:00</time>
                </td>
                <td class="alert_time"><time>Today at 11:00</time></td>
                <td class="alert_buttons">
                    <a href="https://example.com/index.php?action=profile;u=1;area=showalerts;do=read;aid=31047;token=abc">Mark read</a>
                    <a href="https://example.com/index.php?action=profile;area=showalerts;alert=31047;">View</a>
                </td>
            </tr>
        </table>
        """
        let alerts = SMFParser.parseAlerts(list)
        #expect(alerts.count == 1)
        #expect(alerts[0].text.contains("liked your post"))
        #expect(alerts[0].url?.absoluteString.contains("alert=31047") == true)
        #expect(alerts[0].isUnread)
        #expect(alerts[0].markReadURL?.absoluteString.contains("do=read") == true)
        #expect(SMFParser.parseAlertMarkAllURL(popup)?.absoluteString.contains("sa=markread") == true)
    }

    @Test func buildsMultipartAttachmentBody() {
        let body = SMFClient.multipartBody(
            fields: ["post": "Post", "subject": "Test"],
            files: [AttachmentUpload(fileName: "a.txt", mimeType: "text/plain", data: Data("hello".utf8))],
            boundary: "BOUNDARY"
        )
        let text = String(decoding: body, as: UTF8.self)

        #expect(text.contains("name=\"post\"\r\n\r\nPost"))
        #expect(text.contains("name=\"attachment[]\"; filename=\"a.txt\""))
        #expect(text.contains("Content-Type: text/plain"))
        #expect(text.contains("hello"))
        #expect(text.hasSuffix("--BOUNDARY--\r\n"))
    }

    @Test func marksBoldRuns() {
        let page = SMFParser.parseTopic(Fixtures.topic, topicID: 701, start: 0)
        let attributed = page.posts[0].content.text
        let boldRuns = attributed.runs.filter { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        }
        #expect(boldRuns.isEmpty == false)
    }
}

// MARK: - HTML parser

struct HTMLParserTests {
    @Test func decodesEntities() {
        let node = HTMLParser.parse("<p>A &amp; B &lt;tag&gt; &#8212; &#x1F600;</p>")
        #expect(node.textContent == "A & B <tag> — 😀")
    }

    @Test func autoClosesParagraphsAndListItems() {
        let document = HTMLParser.parse("<div><p>one<p>two<li>a<li>b</div>")
        let paragraphs = document.allTags("p")
        let items = document.allTags("li")

        #expect(paragraphs.count == 2)
        #expect(paragraphs.map(\.textContent) == ["one", "two"])
        #expect(items.count == 2)
    }

    @Test func ignoresScriptAndStyleContent() {
        let document = HTMLParser.parse("<div><script>var x = '<p>no</p>';</script><style>.a{}</style>Visible</div>")
        #expect(document.textContent == "Visible")
    }

    @Test func findsElementsByClassAndId() {
        let document = HTMLParser.parse("<div id=\"main\"><span class=\"a b\">x</span><span class=\"b\">y</span></div>")
        #expect(document.element(id: "main")?.allClasses("b").count == 2)
        #expect(document.firstClass("a")?.textContent == "x")
    }
}

// MARK: - Dates

struct SMFDateTests {
    @Test func parsesAbsoluteTimestamps() {
        let date = SMFDate.parse("October 30, 2026, 09:12:04 PM")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = date.map { calendar.dateComponents([.year, .month, .day, .hour], from: $0) }

        #expect(parts?.year == 2026)
        #expect(parts?.month == 10)
        #expect(parts?.day == 30)
        #expect(parts?.hour == 21)
    }

    @Test func parsesTodayTimestamps() {
        #expect(SMFDate.parse("Today at 09:15:00 AM") != nil)
        #expect(SMFDate.parse("not a date") == nil)
    }
}

// MARK: - Login form

struct LoginFormTests {
    @Test func ignoresBannedTextEmbeddedInEveryPageScript() {
        // SMF puts this string in a JS variable on every page, success or failure.
        let html = """
        <script>var banned_text = 'Sorry Guest, you are banned from using this forum!';</script>
        <div id="frmLogin"><input name="user"></div>
        """
        #expect(SMFClient.loginErrorMessage(in: HTMLParser.parse(html)) == nil)
    }

    @Test func surfacesTheRealLoginErrorBox() {
        let html = "<div class=\"errorbox\">That username does not exist.</div>"
        #expect(SMFClient.loginErrorMessage(in: HTMLParser.parse(html)) == "That username does not exist.")
    }

    @Test func findsEveryHiddenFieldOnTheLoginForm() {
        let document = HTMLParser.parse(Fixtures.loginPage)
        let form = document.all(where: { $0.tag == "form" }).first { $0.attr("id") == "frmLogin" }

        let names = form?.allTags("input").compactMap { $0.attr("name") } ?? []
        #expect(names.contains("user"))
        #expect(names.contains("session_token_a"))
        #expect(names.contains("session_token_b"))
        #expect(form?.attr("action") == "https://www.china-defense.com/smf/index.php?action=login2")
    }
}




