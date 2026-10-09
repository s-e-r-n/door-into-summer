| date | issue | section | PR | severity |
| ---- | ----- | ------- | -- | -------- |
| 2026-10-09 | While the backend keeps running, a new image generation of a session replaces the previous one in the chat. Every image of a session should stay in the chat, and every message in the order it was sent, until the backend stops. | Card | - | medium |
| 2026-10-09 | Using an image as a reference does not address the session that generated it: the reviewer has to type `@<session>` as well. Using an image as a reference should address that session on its own. | Use | - | medium |
| 2026-10-09 | The chat labels the reviewer's messages with the word `reviewer`. It should show the reviewer's name, taken from the configuration of the machine. | Card | - | low |
| 2026-10-09 | The whole window can be dragged from anywhere in it, unlike a native macOS window, which moves only by its title bar. | - | - | medium |
