# SSOP review-window

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| Review page | HTTP server at 127.0.0.1:8765 | WebPage rendered by WebView | `WebPage.load` finishing or throwing, in `ReviewPage.open` | `ReviewPage.Availability` : `connecting`, `unanswered`, `shown` | The line "does not answer" shown over a page that loaded |
| Review address | Constant of the app | `ReviewPage` | Compile time, `URL(string:)` of a literal checked once | `URL` | A load without an address |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `door_into_summer_window` | content view | `content: () -> View` | `Scene` | `Sources/NativeWindow/door_into_summer.swift` (copy) |
| `ReviewPage` | `WebPage`, review address | `address: URL` | `availability`, `page`, `open() async` | `Sources/DoorIntoSummer/ReviewPage.swift` |
| `ReviewPageView` | `ReviewPage` | none | `View` | `Sources/DoorIntoSummer/ReviewPageView.swift` |
| `DoorIntoSummerApp` | `door_into_summer_window`, `ReviewPageView` | none | `App` | `Sources/DoorIntoSummer/DoorIntoSummerApp.swift` |
| `Door into Summer.app` path | `DoorIntoSummer` product | none | printed path | `scripts/make_app.sh` |

Edges : `ReviewPageView` needs `ReviewPage`. `DoorIntoSummerApp` needs `door_into_summer_window` and `ReviewPageView`. `make_app.sh` needs the `DoorIntoSummer` product. `WebPage` and the review address are boundary data.

Sort :

1. `door_into_summer_window`, `ReviewPage`
2. `ReviewPageView`
3. `DoorIntoSummerApp`
4. `make_app.sh`

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| `NativeWindow` | The window chrome, synced from the template | `door_into_summer_window { content }` is a `Scene` |
| `ReviewPage` | Where the review page lives and what happens while it does not answer | `ReviewPage(address:)`, `open()` runs until the page is shown or the task is cancelled, `availability` and `page` are read only |
| `ReviewPageView` | How the compartment shows the page or the one line | Nothing, it takes no parameter |
| `make_app.sh` | How the binary becomes a bundle | It prints the path of the built app on stdout |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| Availability of the review page | `ReviewPage` | `ReviewPageView` | `ReviewPage.open` |
| The loaded page | `ReviewPage`, through its `WebPage` | `ReviewPageView` | `ReviewPage.open` |
| The `ReviewPage` instance | `ReviewPageView`, `@State` | `ReviewPageView` | `ReviewPageView` |

## Amendments
- The template renamed its product `window` and its public type `window` before the copy, so the copy is `Sources/NativeWindow/window.swift` and the app calls `window { }` instead of `door_into_summer_window { }`.
