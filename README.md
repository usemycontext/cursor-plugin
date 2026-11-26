# UseMyContext plugin marketplace for Cursor

Own your context, for every AI app. Now in your editor. This repository is a Cursor plugin marketplace that distributes
the **UseMyContext** plugin: sign in once and Cursor reads your UseMyContext profile, lists and opens your
files, and answers from your documents, all read-only against your files and audited. One tool,
`suggest_update`, can write. Your answers to the first setup questions save straight to your profile;
everything else waits for your approval in the web app. Nothing the AI does ever touches your files, and
every access leaves a record in your audit trail. Map a folder to one of your projects and every session in that folder reads the right
context. And it does not wait to be asked, at either end of a session: when a question touches you
personally, Cursor is guided to check your profile and documents before saying it does not know about
you, and when a conversation is wrapping up having taught it something durable about you, it is guided
to offer to save that before the context is lost. You should not have to name UseMyContext by hand.

## Install

This plugin is not in Cursor's marketplace yet. Until it is, use the **Add to Cursor** button on the
Connect page at [usemycontext.ai](https://usemycontext.ai), or add `https://mcp.usemycontext.ai/mcp` to
`~/.cursor/mcp.json`. Then open Cursor Settings, go to Tools and MCP Servers, find `usemycontext`, and
click Connect to complete the browser sign-in. Full plugin docs, including how folder-to-profile mapping works,
are in [`plugins/usemycontext/README.md`](./plugins/usemycontext/README.md).

## Try it in 30 seconds

**No signup needed.** At the browser sign-in, use `demo@usemycontext.ai` with code `424242`
(fixed - no email access needed). A shared, read-only demo account with a full profile, files, and a
shared context. Then ask Cursor "what do you know about me?". Docs:
[usemycontext.ai/docs](https://usemycontext.ai/docs)

## Layout

```
.
|-- .cursor-plugin/
|   `-- marketplace.json           # the marketplace catalog (one plugin: usemycontext)
|-- scripts/
|   `-- validate.mjs               # zero-dependency format validator (run before publishing)
`-- plugins/
    `-- usemycontext/              # the plugin
        |-- .cursor-plugin/
        |   `-- plugin.json         # plugin manifest
        |-- mcp.json                # registers the remote UseMyContext MCP server (OAuth)
        |-- rules/usemycontext.mdc  # the always-on folder-mapping rule
        |-- skills/umc/SKILL.md     # the /umc skill (status + folder mapping)
        |-- hooks/hooks.json        # sessionStart hook
        |-- scripts/umc-session.sh  # reads a folder's .umc marker, emits JSON context
        |-- assets/logo.png         # the UseMyContext keyhole mark
        |-- .umc.example            # example folder mapping
        `-- README.md               # plugin documentation
```

## What it can and cannot do

- Reads: your profile and the files you uploaded to UseMyContext, scoped to the connected or mapped
  project.
- Writes: nothing to your files. The one write tool, `suggest_update`, saves your answers to the first
  setup questions straight to your profile; everything else waits for your approval in the web app.
- Every access leaves a record in your audit trail.
- You can revoke access at any time: disconnect `usemycontext` under Cursor Settings, Tools and MCP
  Servers, or revoke from the Connect page in the UseMyContext web app. Revoking is enforced on the
  server: the token dies immediately, everywhere.
- It does not change your Cursor account, your Cursor plan, your billing, or which model runs.

## Publishing

Cursor plugins are distributed as Git repositories and every plugin is manually reviewed by the Cursor
team before it is listed. Before committing a change, validate the format:

```
node scripts/validate.mjs
```

Fix every reported error. This checks the manifests parse, the plugin name is lowercase kebab-case, the
marketplace entry maps to a real folder, referenced paths (logo, hooks, mcp) resolve, and skill and rule
files carry their required frontmatter. Bump `version` in `plugins/usemycontext/.cursor-plugin/plugin.json`
on every release. Nothing here deploys a worker or a Pages site; the plugin only needs this public
repository to exist. The live UseMyContext service it connects to is at
[usemycontext.ai](https://usemycontext.ai).
