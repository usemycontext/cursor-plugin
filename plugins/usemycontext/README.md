# UseMyContext for Cursor

One context, every AI app: your UseMyContext context, served to Cursor over MCP. Sign in once and Cursor can read your
UseMyContext profile, list and open your files, and answer from your documents, all read-only against your
files and audited. It is proactive by design: when a question touches you personally, Cursor is guided to
check your profile and documents before saying it does not know about you - you should not have to name
UseMyContext by hand.

Map a folder to one of your projects, and every Cursor session in that folder reads the right context: a
work repo reads your work profile, a side project reads your personal one.

## Install

This plugin is not in Cursor's marketplace yet. Until it is, use the **Add to Cursor** button on the
Connect page at [usemycontext.ai](https://usemycontext.ai), or add `https://mcp.usemycontext.ai/mcp` to
`~/.cursor/mcp.json`. Then open Cursor Settings, go to Tools and MCP Servers, find `usemycontext`, click Connect,
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
  already pointed at the right project. The hook refuses to run any script that resolves inside
  `CURSOR_PROJECT_DIR`, so a repository you opened cannot substitute its own, and it refuses outright if
  Cursor does not tell it where the workspace is. If the mapping line does not appear in a session, the
  always-on rule still carries it, and the `/umc` skill reports the mapping on request.

One tool, `suggest_update`, can write. Your answers to the first setup questions save straight to your
profile; everything else waits for your approval in the web app. Nothing the AI does ever touches your
files, and every access leaves a record in your audit trail. When a conversation is wrapping up having surfaced something new and durable
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

A `projectId` may only be letters, digits, `_` and `-`, up to 32 characters, and a `handle` only `@`
followed by letters, digits and `-`, up to 40. Anything else and the whole marker is ignored, so a
repository you did not write cannot use one to talk to your assistant.

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
- Writes: nothing to your files. The one write tool, `suggest_update`, saves your answers to the first
  setup questions straight to your profile; everything else waits for your approval in the web app.
- Every access leaves a record in your audit trail.
- You can revoke access at any time, from Cursor Settings or from the web app's Connect page.
- It does not change your Cursor account, your Cursor plan, your billing, or which model runs.

## Links

- Docs: [usemycontext.ai/docs](https://usemycontext.ai/docs)
- Web app: [usemycontext.ai](https://usemycontext.ai)
- MCP endpoint: `https://mcp.usemycontext.ai/mcp`
