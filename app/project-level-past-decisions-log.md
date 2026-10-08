# Past decisions

Append only. One row per decision. A row is never edited or deleted, a reversal is a new row.

A row exists when a problem was raised and a decision closed it. Nothing else gets a row.
Problem and decision are one line each. An error code, a trace id or a ticket number goes in Ref, never the error itself.

| Date | Problem | Decision | Ref |
| ---- | ------- | -------- | --- |
| 2026-10-08 | The window template could be a Swift package dependency or a copy | Its single module file is copied into Sources/NativeWindow, verbatim, with no dependency on the template repository | macos_26_tahoe_native_ui_templates main 090290c |
| 2026-10-08 | The copied file names its type `window` in snake case, against Swift conventions | The copy stays verbatim so a later sync is a plain diff, the app's own code follows Swift conventions | Sources/NativeWindow/window.swift |
| 2026-10-08 | SwiftUI's WebView or WKWebView for the review page | SwiftUI WebView with WebPage, whose load throws when the server does not answer, so no WKWebView is needed | WebPage.NavigationError.failedProvisionalNavigation |
| 2026-10-08 | App Transport Security could block plain http to 127.0.0.1 | Info.plist sets NSAllowsLocalNetworking | scripts/make_app.sh |
