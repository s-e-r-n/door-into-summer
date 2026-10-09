| date | issue | section | PR | severity |
| ---- | ----- | ------- | -- | -------- |
| 2026-10-09 | While the backend keeps running, a new image generation of a session replaces the previous one in the chat. Every image of a session should stay in the chat, and every message in the order it was sent, until the backend stops. Solution track, chosen by the reviewer: the backend keeps every attempt and every message of each session in memory while it runs, and serves them on `/cards` and `/events`; the app only shows them. The history survives the app being quit and reopened, and ends when the backend stops or the session is closed. | Card | - | medium |
| 2026-10-09 | Using an image as a reference does not address the session that generated it: the reviewer has to type `@<session>` as well. Using an image as a reference should address that session on its own. | Use | - | medium |
| 2026-10-09 | The chat labels the reviewer's messages with the word `reviewer`. It should show the reviewer's name, taken from the configuration of the machine. | Card | - | low |
| 2026-10-09 | The whole window can be dragged from anywhere in it, unlike a native macOS window, which moves only by its title bar. | - | - | medium |
| 2026-10-09 | Validating an earlier image of a session files the session's latest image instead. The reviewer validated generations 1 and 2 of a session, and the gallery and the store received generations 2 and 3. The backend knows only the latest attempt of a session, so it files that one. Solution track: the one of the row on images replaced, which gives the backend the job of every attempt. | Use | - | critical |
| 2026-10-09 | Shift+Enter does nothing in the chat bar. It should start a new line. | Use | - | low |
| 2026-10-09 | Sending a message with Enter shows it several times in the chat before it settles on a single entry labelled `reviewer`. | Use | - | medium |
| 2026-10-09 | Cmd+B does nothing until `details` has been clicked once on a post. | Card | - | low |
| 2026-10-09 | Cmd+B should open the metadata of the generated image on screen, never that of the original shown beside it. | Card | - | low |
| 2026-10-09 | The `/` menu of the chat lists no command: no skill carries `door-into-summer: command` in its frontmatter yet. The reviewer writes and connects these skills. | Use | - | low |
| 2026-10-09 | The chat bar does not wrap its text. It should wrap, and grow up to three lines high. | - | - | medium |
| 2026-10-09 | The chat bar is frosted, but it does not look like the Liquid Glass of macOS 26. | - | - | low |
