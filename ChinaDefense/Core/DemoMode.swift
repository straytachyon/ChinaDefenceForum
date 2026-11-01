#if DEBUG
import Foundation

/// Launch-argument driven demo data (`-demo`). Debug builds only: it lets the UI be
/// exercised end to end without forum credentials, and because the fixtures are parsed
/// by the real `SMFParser` it also smoke-tests the parsing pipeline in the app.
enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    static func boardIndex() -> BoardIndexResult {
        SMFParser.parseBoardIndex(boardIndexHTML)
    }

    static func topicList(mode: TopicListModel.Mode, start: Int) -> TopicListPage {
        switch mode {
        case .unread:
            return SMFParser.parseTopicList(unreadHTML, start: start)
        case .board:
            return SMFParser.parseTopicList(boardTopicsHTML, start: start)
        }
    }

    static func topic(id: Int, title: String, start: Int?) -> TopicPage {
        var html = topicHTML
        if !title.isEmpty {
            html = html.replacingOccurrences(
                of: "<span id=\"top_subject\">Type 076 launched</span>",
                with: "<span id=\"top_subject\">\(title)</span>"
            )
        }
        return SMFParser.parseTopic(html, topicID: id, start: start ?? 0)
    }

    // MARK: - Fixtures (stock SMF 2.1.8 markup)

    private static let boardIndexHTML = """
    <div id="top_section"><ul id="top_info">
        <li class="welcome">Welcome to <strong>China Defense Forum</strong>.</li>
        <li><a href="?action=unread">Unread Posts <span class="amt">7</span></a></li>
        <li><a href="?action=profile;u=42">observer <span class="amt">2</span></a></li>
    </ul></div>
    <script>var smf_member_id = 42;</script>
    <div id="boardindex_table" class="boardindex_table">
        <div class="cat_bar" id="category_1"><h3 class="catbg">Chinese Military</h3></div>
        <div id="category_1_boards" class="main_container">
            <div id="board_10" class="up_contain board_row">
                <div class="board_icon"><a href="?board=10.0" class="board_on"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=10.0" id="b10">PLA News</a>
                    <div class="board_description">Daily news, procurement and exercises of the People&#039;s Liberation Army.</div>
                </div>
                <div class="board_stats"><p>Topics: 1,204<br>Posts: 8,931</p></div>
                <div id="board_10_children" class="children"><a href="?board=11.0">Navy</a><a href="?board=12.0">Air Force</a></div>
            </div>
            <div id="board_13" class="up_contain board_row">
                <div class="board_icon"><a href="?board=13.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=13.0" id="b13">Naval Programs</a>
                    <div class="board_description">Carriers, destroyers, submarines and coast guard.</div>
                </div>
                <div class="board_stats"><p>Topics: 88<br>Posts: 1,022</p></div>
            </div>
            <div id="board_14" class="up_contain board_row">
                <div class="board_icon"><a href="?board=14.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=14.0" id="b14">Air Power</a>
                    <div class="board_description">Combat aircraft, drones and air defence.</div>
                </div>
                <div class="board_stats"><p>Topics: 342<br>Posts: 5,110</p></div>
            </div>
            <div id="board_15" class="up_contain board_row">
                <div class="board_icon"><a href="?board=15.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=15.0" id="b15">Strategic Forces</a>
                    <div class="board_description">Missiles, space and nuclear policy.</div>
                </div>
                <div class="board_stats"><p>Topics: 210<br>Posts: 3,208</p></div>
            </div>
        </div>
        <div class="cat_bar" id="category_2"><h3 class="catbg">Community</h3></div>
        <div id="category_2_boards" class="main_container">
            <div id="board_20" class="up_contain board_row">
                <div class="board_icon"><a href="?board=20.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=20.0" id="b20">General Discussion</a>
                    <div class="board_description">Introductions and off-topic conversation.</div>
                </div>
                <div class="board_stats"><p>Topics: 4<br>Posts: 9</p></div>
            </div>
            <div id="board_21" class="up_contain board_row">
                <div class="board_icon"><a href="?board=21.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=21.0" id="b21">Site Feedback</a>
                    <div class="board_description">Questions about the forum itself.</div>
                </div>
                <div class="board_stats"><p>Topics: 12<br>Posts: 41</p></div>
            </div>
            <div id="board_22" class="up_contain board_row">
                <div class="board_icon"><a href="?board=22.0" class="board_off"></a></div>
                <div class="info">
                    <a class="subject mobile_subject" href="?board=22.0" id="b22">History</a>
                    <div class="board_description">Military history and archives.</div>
                </div>
                <div class="board_stats"><p>Topics: 67<br>Posts: 802</p></div>
            </div>
        </div>
    </div>
    """

    private static let unreadHTML = """
    <div id="unread">
        <div id="display_head" class="information"><h2 class="display_title">Unread Posts</h2></div>
        <div class="pagesection"><div class="pagelinks floatleft">
            <span class="current_page">1</span>
            <a class="navPages" href="?action=unread;all;start=20">2</a>
        </div></div>
        <div id="topic_container">
            <div class="windowbg">
                <div class="board_icon"></div>
                <div class="info">
                    <div class="icons floatright"><span class="main_icons lock"></span></div>
                    <div class="recent_title">
                        <a href="?topic=900.msg1200#new" class="new_posts">new</a>
                        <span class="preview"><span id="msg_1200">
                            <a href="?topic=900.0" class="subject" id="subject_1200">J-20 programme update — new unit spotted</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=12">observer</a></p>
                </div>
                <div class="board_stats centertext"><p>3 replies<br>45 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=7">tester</a> on <a href="?topic=900.0">Today at 09:15:00 AM</a></p></div>
            </div>
            <div class="windowbg2">
                <div class="board_icon"></div>
                <div class="info">
                    <div class="icons floatright"><span class="main_icons sticky"></span></div>
                    <div class="recent_title">
                        <span class="preview"><span id="msg_1201">
                            <a href="?topic=901.0" class="subject" id="subject_1201">Forum rules — please read before posting</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=1">admin</a></p>
                </div>
                <div class="board_stats centertext"><p>12 replies<br>900 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=5">mod</a> on <a href="?topic=901.0">October 30, 2026, 10:05:00 PM</a></p></div>
            </div>
            <div class="windowbg">
                <div class="board_icon"></div>
                <div class="info">
                    <div class="recent_title">
                        <a href="?topic=902.msg1210#new" class="new_posts">new</a>
                        <span class="preview"><span id="msg_1210">
                            <a href="?topic=902.0" class="subject" id="subject_1210">Type 076 amphibious assault ship launched</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=9">shipwatcher</a></p>
                </div>
                <div class="board_stats centertext"><p>41 replies<br>2,310 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=9">shipwatcher</a> on <a href="?topic=902.0">Yesterday at 06:40:00 PM</a></p></div>
            </div>
            <div class="windowbg2">
                <div class="board_icon"></div>
                <div class="info">
                    <div class="recent_title">
                        <a href="?topic=903.msg1220#new" class="new_posts">new</a>
                        <span class="preview"><span id="msg_1220">
                            <a href="?topic=903.0" class="subject" id="subject_1220">J-35 carrier trials — photographs</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=15">planespotter</a></p>
                </div>
                <div class="board_stats centertext"><p>8 replies<br>512 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=15">planespotter</a> on <a href="?topic=903.0">Yesterday at 02:11:00 PM</a></p></div>
            </div>
            <div class="windowbg">
                <div class="board_icon"></div>
                <div class="info">
                    <div class="recent_title">
                        <a href="?topic=904.msg1230#new" class="new_posts">new</a>
                        <span class="preview"><span id="msg_1230">
                            <a href="?topic=904.0" class="subject" id="subject_1230">DF-27 range estimates</a>
                        </span></span>
                    </div>
                    <p class="floatleft">Started by <a href="?action=profile;u=21">analyst</a></p>
                </div>
                <div class="board_stats centertext"><p>2 replies<br>97 views</p></div>
                <div class="lastpost"><p>Last post by <a href="?action=profile;u=21">analyst</a> on <a href="?topic=904.0">Yesterday at 09:02:00 AM</a></p></div>
            </div>
        </div>
        <div class="pagelinks"><a class="navPages" href="?action=unread;all;start=20">&raquo;</a></div>
    </div>
    """

    private static let boardTopicsHTML = """
    <div id="display_head" class="information">
        <h2 class="display_title">PLA News</h2>
        <p>Daily news, procurement and exercises of the People&#039;s Liberation Army.</p>
    </div>
    <div id="topic_container">
        <div class="windowbg">
            <div class="board_icon"></div>
            <div class="info">
                <div class="icons floatright"><span class="main_icons sticky"></span></div>
                <div class="message_index_title">
                    <span class="preview"><span id="msg_1100">
                        <a href="?topic=700.0" class="subject" id="subject_1100">Pinned: PLA daily digest</a>
                    </span></span>
                </div>
                <p class="floatleft">Started by <a href="?action=profile;u=1">admin</a></p>
            </div>
            <div class="board_stats centertext"><p>Replies: 120<br>Views: 4,512</p></div>
            <div class="lastpost"><p><a href="?topic=700.0">Today at 07:00:00 AM</a> by <a href="?action=profile;u=3">reporter</a></p></div>
        </div>
        <div class="windowbg2">
            <div class="board_icon"></div>
            <div class="info">
                <div class="message_index_title">
                    <a href="?topic=701.msg1101#new" class="new_posts">new</a>
                    <span class="preview"><span id="msg_1101">
                        <a href="?topic=701.0" class="subject" id="subject_1101">Type 076 launched</a>
                    </span></span>
                </div>
                <p class="floatleft">Started by <a href="?action=profile;u=9">shipwatcher</a></p>
            </div>
            <div class="board_stats centertext"><p>Replies: 4<br>Views: 88</p></div>
            <div class="lastpost"><p><a href="?topic=701.0">Yesterday at 06:40:00 PM</a> by <a href="?action=profile;u=9">shipwatcher</a></p></div>
        </div>
        <div class="windowbg">
            <div class="board_icon"></div>
            <div class="info">
                <div class="message_index_title">
                    <span class="preview"><span id="msg_1102">
                        <a href="?topic=702.0" class="subject" id="subject_1102">Annual exercise announcements</a>
                    </span></span>
                </div>
                <p class="floatleft">Started by <a href="?action=profile;u=3">reporter</a></p>
            </div>
            <div class="board_stats centertext"><p>Replies: 17<br>Views: 640</p></div>
            <div class="lastpost"><p><a href="?topic=702.0">October 29, 2026, 11:20:00 AM</a> by <a href="?action=profile;u=5">mod</a></p></div>
        </div>
        <div class="windowbg2">
            <div class="board_icon"></div>
            <div class="info">
                <div class="icons floatright"><span class="main_icons lock"></span></div>
                <div class="message_index_title">
                    <span class="preview"><span id="msg_1103">
                        <a href="?topic=703.0" class="subject" id="subject_1103">Budget figures 2026 (locked)</a>
                    </span></span>
                </div>
                <p class="floatleft">Started by <a href="?action=profile;u=21">analyst</a></p>
            </div>
            <div class="board_stats centertext"><p>Replies: 33<br>Views: 1,204</p></div>
            <div class="lastpost"><p><a href="?topic=703.0">October 28, 2026, 08:12:00 PM</a> by <a href="?action=profile;u=21">analyst</a></p></div>
        </div>
    </div>
    """

    private static let topicHTML = """
    <div id="display_head" class="information">
        <h2 class="display_title"><span id="top_subject">Type 076 launched</span></h2>
        <p>Started by shipwatcher, Yesterday at 06:40:00 PM</p>
        <p class="navigate_section"><a href="?board=10.0">PLA News</a></p>
    </div>
    <div class="pagesection"><div class="pagelinks floatleft">
        <span class="current_page">1</span>
        <a class="navPages" href="?topic=701.15">2</a>
    </div></div>
    <div class="post_wrapper">
        <div class="poster"><h4><a href="?action=profile;u=9">shipwatcher</a></h4></div>
        <div class="postarea">
            <div class="keyinfo">
                <div id="subject_1101" class="subject_title">Type 076 launched</div>
                <div class="postinfo"><a href="?topic=701.msg1101#msg1101" rel="nofollow" class="smalltext">Yesterday at 06:40:00 PM</a></div>
            </div>
            <div class="post"><div class="inner" data-msgid="1101" id="msg_1101">
                <iframe width="560" height="315" src="https://www.youtube.com/embed/4iZ75mbX6mY" frameborder="0" allowfullscreen></iframe>
                <div class="quoteheader">Quote from: observer on Yesterday at 06:30:00 PM</div>
                <blockquote class="bbc_standard_quote">A new <strong>amphibious</strong> ship with a drone deck.</blockquote>
                <br>Satellite imagery today confirms the hull is fitting out at Hudong-Zhonghua. The flight deck appears wider than the Type 075, consistent with the reported UAV mission.
                <br><br>More discussion <a href="?topic=702.0" class="bbc_link">in the programmes thread</a>.
                <br>
                <div class="codeheader">Code:</div>
                <div class="bbc_code">hull = 076&#10;deck = UAV</div>
            </div></div>
        </div>
    </div>
    <div class="post_wrapper">
        <div class="poster"><h4><a href="?action=profile;u=7">tester</a></h4></div>
        <div class="postarea">
            <div class="keyinfo">
                <div id="subject_1102" class="subject_title">Re: Type 076 launched</div>
                <div class="postinfo"><a href="?topic=701.msg1102#msg1102" rel="nofollow" class="smalltext">Yesterday at 11:10:00 PM</a></div>
                <span class="page_number floatright">#2</span>
            </div>
            <div class="post"><div class="inner" data-msgid="1102" id="msg_1102">
                <p>Thanks for sharing. It will be interesting to see whether the air wing is <em>only</em> unmanned.</p>
                <ul><li>GJ-11</li><li>WZ-8</li><li>Z-20 possibly</li></ul>
            </div></div>
        </div>
    </div>
    <div class="post_wrapper">
        <div class="poster"><h4><a href="?action=profile;u=3">reporter</a></h4></div>
        <div class="postarea">
            <div class="keyinfo">
                <div id="subject_1103" class="subject_title">Re: Type 076 launched</div>
                <div class="postinfo"><a href="?topic=701.msg1103#msg1103" rel="nofollow" class="smalltext">Today at 04:05:00 AM</a></div>
                <span class="page_number floatright">#3</span>
            </div>
            <div class="post"><div class="inner" data-msgid="1103" id="msg_1103">
                <p>Official coverage is expected next week.</p>
            </div></div>
        </div>
    </div>
    """
}
#endif
