# China Defense Forum — iOS client

A native SwiftUI client for the **China Defense Forum** at
`https://www.china-defense.com/smf/` (Simple Machines Forum 2.1.8).

The forum has no API and every page — including the board index — is behind a login,
so the app authenticates with a real forum account and reads the server-rendered
pages. Logins, sessions and cookies stay between the app and the forum.

## What it does

- **Unread tab** — `index.php?action=unread;all;start=0`, paginated. Shows every
  unread topic, with sticky/locked markers and reply counts.
- **One tab per top-level board** — discovered at runtime from the board index, in
  forum order. On iPhone the system tab bar handles overflow with "More"; on iPad the
  top tab strip pages through the boards and the sidebar toggle lists them all.
- **Child boards** appear as chips at the top of their parent board and open inside
  the same tab.
- **Per-post replies** — the quote-bubble on any post opens the reply editor with
  SMF's own `[quote author=…]` block prefilled, so you answer that specific message.
- **Photo viewer** — tap any picture to open it full-screen; swipe left/right
  through every picture in that post, with a counter and page dots.
- **YouTube embeds** — video posts show an inline playable player (with an
  "Open on YouTube" fallback when the owner disables embedding).
- **Posting** — reply to any topic, or start a new one from a board's compose button.
  The editor mirrors the forum's BBCode toolbar (bold, italic, underline,
  strikethrough, quote, code, bullet/numbered lists, link, image, YouTube, size, colour,
  alignment, spoiler, table, super/subscript, font face, smileys) and has a
  server-rendered **Preview** before posting.
- **File attachments** — the paperclip in the editor attaches files to a reply or new
  topic (multiple files, 25 MB each); they upload with the post as SMF attachments.
  Attachments are listed in the composer and Preview shows their names.
- **Likes** — every post shows a heart and its like count; tap to like or unlike.
  The forum can forbid liking for a membergroup; in that case the count is still
  shown and the heart is disabled.
- **Quoted posts** — quotes render as their own card with a rounded border and a
  coloured left bar, instead of blending into the reply text.
- **Notifications** — the bell in the list toolbar shows the unread SMF alert count
  and opens a native list of quotes, mentions and likes. Tapping a notification
  marks it read and opens its post inside the app. You can mark one notification
  read from its checkmark, or mark every notification read from the toolbar.
- **Live unread** — the Unread tab refreshes every minute while the app is open and
  when the app returns to the foreground.
- **Reorderable board tabs** — the ↑↓ button in the list toolbar (or Settings →
  Arrange Board Tabs) opens a list where boards move up/down. "Unread" stays pinned
  first; the order is saved and restored on launch, with a reset to forum order.
- On iPad the content shows a large board (or "Unread") title, and topic pages keep a
  readable ~820 pt column instead of stretching across the screen.
- **Topic view** — posts rendered natively (bold, italics, quotes, code, lists,
  links, inline images), avatars, post numbers, pagination via "Load More Posts".
- Threads open where you left off: **first unread post** for unread topics
  (`?topic=N.new`, scrolled to SMF's "new" marker), or the **last post** for topics you
  have already read. A bottom **page bar** (first / previous / "Page N of M" menu /
  next / last) jumps anywhere in the thread; Load Earlier/Later remain for incremental
  reading.
- Attachments hosted by the forum (including member-only ones) are fetched with the
  session cookies and shown inline; a single picture spans the post card, two or three
  sit side by side.
- **Appearance** — Settings → Display lets you force Light or Dark, or follow the
  system setting. The same section has a **Post text size** stepper (80–150% with a
  live preview) that scales post bodies and code blocks in threads.
- Sign in once: the SMF session cookie is reused on later launches. If it expires,
  the app silently re-authenticates with the saved Keychain credentials.
- In-app browser with the forum session's cookies injected, for links, profiles and
  the original website.
- Board list cached on disk so the tab bar appears instantly at launch.

## Verified against the live forum

Tested end to end with a real account in October 2026: sign-in through the app's own
form scrape, 3 categories / 15 top-level boards, unread list (both the "today" and
absolute date formats), topics with 20 posts per page and pagination, Chinese-language
bodies, quotes, code blocks and images.

## Requirements

- Xcode 27 or later (the project uses the Xcode 27 project format)
- iOS / iPadOS 18.0+
- A China Defense Forum account

## Build

Open `ChinaDefense.xcodeproj`, choose the `ChinaDefense` scheme and run on an
iPhone or iPad simulator or device. No third-party packages.

```sh
xcodebuild -project ChinaDefense.xcodeproj -scheme ChinaDefense \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

## Demo mode

Debug builds accept a `-demo` launch argument which seeds the app with fixture forum
pages, parsed by the real parsers. It exists so the UI can be exercised without forum
credentials (Edit Scheme › Run › Arguments). Release builds contain none of it.

## Tests

```sh
xcodebuild test -project ChinaDefense.xcodeproj -scheme ChinaDefense \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

The test suite covers the HTML parser, the SMF page parsers (board index, unread
list, board topic list, topic, pagination inference, dates) and the login form
scrape. Fixtures mirror SMF 2.1.8's stock `Themes/default` markup.

## How it works

| Layer | File | Notes |
| --- | --- | --- |
| Tolerant HTML DOM | `Core/HTMLDocument.swift` | Dependency-free parser with entity decoding and auto-closing of `p`/`li`/`td` |
| SMF page parsing | `Core/SMFParser.swift` | Board index, topic lists, topics, pagination, dates |
| Post rendering | `Core/PostRenderer.swift` | HTML → `AttributedString`, images collected separately |
| Networking | `Core/SMFClient.swift` | Scraped login (hidden session fields forwarded), cookie jar, error mapping |
| State | `Core/Session.swift`, `Core/ViewModels.swift` | Signed-in state, board tabs, paginated lists |
| UI | `UI/` | Login, dynamic tabs, topic lists, topic detail, settings |

Login flow: fetch `?action=login`, read the `#frmLogin` form, forward every hidden
field (SMF adds per-session tokens), post `user` / `passwrd` / `cookielength=-1`,
then verify by reading `smf_member_id` from the resulting page.

## Limitations

- **Unofficial.** Not affiliated with the forum or its operators. Respect the
  forum's rules and rate limits.
- Posting is supported (replies, new topics and file attachments); editing existing
  posts, polls, search and private messages still use the web view.
- Parsing depends on SMF 2.1.x's stock theme markup. A theme change could require
  selector updates.
- The app is non-functional without an account because the forum does not allow
  guest browsing.
- Photos/attachments are fetched with the session cookies, so member-only images
  load while signed in.
