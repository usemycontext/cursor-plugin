# UseMyContext for Cursor

Your personal context layer for AI, served to Cursor over MCP. Sign in once and Cursor can read your
UseMyContext profile, list and open your files, and answer from your documents, all read-only against your
files and audited. It is proactive by design: when a question touches you personally, Cursor is guided to
check your profile and documents before saying it does not know about you - you should not have to name
UseMyContext by hand.

Map a folder to one of your projects, and every Cursor session in that folder reads the right context: a
work repo reads your work profile, a side project reads your personal one.

## Install

Once this plugin is listed in Cursor's marketplace, add it from
[cursor.com/marketplace](https://cursor.com/marketplace) (the "Add to Cursor" button) or with `/add-plugin`
in the editor. Then open Cursor Settings, go to Tools and MCP Servers, find `usemycontext`, click Connect,
and complete the browser sign-in (OAuth, no token stored in any file). Do not have an account yet? Create
one at [usemycontext.ai](https://usemycontext.ai) first.

**Try it in 30 seconds - no signup.** Sign in as `demo@usemycontext.ai` with code `424242` (fixed - no
email access needed). A shared, read-only demo account with a full profile, files, and a shared context.
Docs: [usemycontext.ai/docs](https://usemycontext.ai/docs)

## What you get

- The UseMyContext MCP server at `https://mcp.usemycontext.ai/mcp` (Streamable HTTP, OAuth 2.1), with the
  full tool surface: `profile`, `list_profiles`, `info`, `account`, `list_files`, `search_files`, `get_file`,
  `search`, `fetch` (thin aliases of `search_files`/`get_file` for ChatGPT deep-research compatibility),
  `ask_docs`, `query_table`, `suggest_update`, `shared_context`.
- A `/umc` skill to check, set, or change which UseMyContext profile a folder reads.
- An always-on rule plus a sessionStart hook that read a folder's `.umc` marker so a new session is
  already pointed at the right project.

One tool, `suggest_update`, can write: it files a pending suggestion that you review and approve in the
web app. Nothing the AI does ever edits your profile or your files directly, and every access leaves a
record in your audit trail. When a conversation is wrapping up having surfaced something new and durable
about you, Cursor is guided to offer that save before the context is lost - so the loop closes at both
ends: your context is read at the start of a session, and what the session taught is offered back at the
end.

## Folder to profile mapping

Each UseMyContext project has its own context and its own `@handle`. To bind a folder to a project, drop a
`.umc` file in the repo root:

```
projectId=p2
handle=@work
```

`projectId` (like `p2`) is what scopes the reads. `handle` is an optional readable label. Find both in the
UseMyContext web app on the project's page. The `/umc` skill can create or update this file for you.

With no `.umc`, the folder reads your account's active profile.

### How it takes effect

Two supported ways, both work today:

1. **Account-wide sign-in plus the `.umc` marker (the default).** You sign in once with an account-wide
   grant. In a mapped folder, tool calls carry `projectId` from `.umc`, and the server verifies it is one
   of your own projects before scoping the read. The bundled rule, `/umc` skill, and sessionStart hook
   apply this for you.
2. **Single-project sign-in.** Connect with a single-project grant using the Connect chooser in the web
   app. Every tool is then scoped to that one project automatically, no marker needed. To vary the project
   per folder this way, add the MCP server at project scope and authenticate each repo to its project.

## Disconnecting and revoking

- In Cursor, open Cursor Settings, go to Tools and MCP Servers, and disconnect `usemycontext`.
- Or revoke from the UseMyContext web app: the Connect page lists every AI connected right now, each with
  its own Disconnect button, plus a "Disconnect all".

Revoking is enforced on the server: the token dies immediately, everywhere. Nothing needs cleaning up
locally.

## What it can and cannot do

- Reads: your profile and the files you uploaded to UseMyContext, scoped to the connected or mapped
  project.
- Writes: nothing to your files. The one write tool, `suggest_update`, files a pending suggestion that
  you review and approve in the web app.
- Every access leaves a record in your audit trail.
- You can revoke access at any time, from Cursor Settings or from the web app's Connect page.
- It does not change your Cursor account, your Cursor plan, your billing, or which model runs.

## Links

- Docs: [usemycontext.ai/docs](https://usemycontext.ai/docs)
- Web app: [usemycontext.ai](https://usemycontext.ai)
- MCP endpoint: `https://mcp.usemycontext.ai/mcp`
