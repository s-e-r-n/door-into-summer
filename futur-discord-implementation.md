# Future Discord implementation

Not to build now: a solution to a future problem.

Problem: when the human works remote, through Remote Control from the iPhone, Door into Summer is a macOS window, so the images cannot be seen nor answered.

Idea, the human's words, 2026-10-25:

> On pourrait trouver une solution à ça, un serveur discord gratuit par exemple. La logique serait :
>
> SI l'user est en remote => les sessions DiS postent sur discord. Même fonctionnement que DiS, mais on leverage l'infra discord. à ne pas faire maintenant, c'est une solution à un problème futur.

Requirements, the human's words, 2026-10-25:

> Le serveur : privé, que moi.
>
> Il faut quand même penser à la scalabilité : l'idéal à terme serait de pouvoir lancer une gen depuis le serveur en mode midjourney.
>
> workflow : discord => hypnos => session de gen d'image => discord.

## Findings from the Discord documentation

1. An image session posts its image into the private server: Execute Webhook, `POST /webhooks/{webhook.id}/{webhook.token}`, the image as `files[0]` in a `multipart/form-data` body, `thread_id` to post into the thread of that session, `wait=true` to get back the message id: https://docs.discord.com/developers/resources/webhook#execute-webhook
2. The human's reply to that image reaches that session: a bot on the Gateway receives the Message Create event, whose `referenced_message` or thread `channel_id` names the image message, which maps to the session given to `hy-session.sh send`: https://docs.discord.com/developers/events/gateway-events#message-create and https://docs.discord.com/developers/resources/message#message-reference-structure
3. A message the human writes in Discord reaches the running Hypnos session: Claude Code channels, the plugin `discord@claude-plugins-official` started with `claude --channels plugin:discord@claude-plugins-official`, which pushes each Discord message into the open session and replies through the same bot, in research preview: https://code.claude.com/docs/en/channels
4. A slash command in the server launches an image generation: a guild `CHAT_INPUT` command registered with `POST /applications/{application.id}/guilds/{guild.id}/commands`, a `STRING` option for the prompt and an `ATTACHMENT` option for a reference photo, received through the Gateway `INTERACTION_CREATE` event so no public URL is needed, acknowledged within 3 seconds with `DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE`, the result posted as a followup while the 15 minute token lives: https://docs.discord.com/developers/interactions/application-commands#making-a-guild-command and https://docs.discord.com/developers/interactions/receiving-and-responding#responding-to-an-interaction
5. The server stays private to the human alone: the application's Public Bot setting unchecked so only its owner can add the bot, guild commands that exist in that one server only, `default_member_permissions` set to `"0"` so only an administrator runs them, and the channel sender allowlist paired to the human's account: https://docs.discord.com/developers/topics/oauth2#bot-authorization-flow and https://docs.discord.com/developers/interactions/application-commands#permissions and https://code.claude.com/docs/en/channels#security

### Limits

- Attachment size: 20 MiB per file by default for all users, higher with Nitro or a server Boost tier: https://docs.discord.com/developers/reference#uploading-files
- Rate limits: 50 requests per second per bot, per-route buckets read from the `X-RateLimit-*` headers, a temporary IP ban after 10,000 invalid requests in 10 minutes, interaction endpoints outside the global limit: https://docs.discord.com/developers/topics/rate-limits#global-rate-limit
- Privileged intents: `MESSAGE_CONTENT` is privileged and switched on in the Developer Portal, without it `content` and `attachments` arrive empty except in DMs, mentions and the bot's own messages, and approval is required only for verified apps, which apps in 100 or more servers must be: https://docs.discord.com/developers/events/gateway#privileged-intents
- What is free: channels need no setting for Pro and Max users without an organization, and the 20 MiB upload limit is the default for all users without Nitro: https://code.claude.com/docs/en/channels#enterprise-controls and https://docs.discord.com/developers/reference#uploading-files

### Open points

- No official page says whether one bot token can serve both the Claude Code Discord channel and the bot that routes replies and slash commands, or whether two applications are needed.
- No official page says whether a session driven by Remote Control can also run with `--channels`, nor whether the Discord channel can post an image back.
- Keeping the server itself invite-only with the human as its only member, and the price of a Discord application, are not covered by the developer documentation.
