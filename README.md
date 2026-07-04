# UseMyContext plugin marketplace for Cursor

Your context follows you into your editor. This repository is a Cursor plugin marketplace that distributes
the **UseMyContext** plugin: sign in once and Cursor reads your UseMyContext profile, lists and opens your
files, and answers from your documents, all read-only and audited. Map a folder to one of your projects and
every session in that folder reads the right context.

## Install

Once this plugin is listed in Cursor's marketplace, add it from
[cursor.com/marketplace](https://cursor.com/marketplace) (the "Add to Cursor" button) or with `/add-plugin`
in the editor, then open Cursor Settings, go to Tools and MCP Servers, find `usemycontext`, and click
Connect to complete the browser sign-in. Full plugin docs, including how folder-to-profile mapping works,
are in [`plugins/usemycontext/README.md`](./plugins/usemycontext/README.md).

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

## The boundary

This plugin scopes your CONTEXT per folder, that is, which UseMyContext profile the AI reads. It does not
change your Cursor account, your Cursor plan, your billing, or which model runs.

## For maintainers: publishing and submission

This directory is the full contents of the public marketplace repository. Cursor plugins are distributed as
Git repositories and every plugin is manually reviewed by the Cursor team before it is listed. To publish:

1. Copy the contents of this directory to the root of a public Git repository (for example
   `usemycontext/cursor-plugin`), so `.cursor-plugin/marketplace.json` sits at the repo root and
   `plugins/usemycontext/` is the plugin directory.
2. Validate the format before you commit:

   ```
   node scripts/validate.mjs
   ```

   Fix every reported error. This checks the manifests parse, the plugin name is lowercase kebab-case, the
   marketplace entry maps to a real folder, referenced paths (logo, hooks, mcp) resolve, and skill and rule
   files carry their required frontmatter.
3. Push to the default branch, then submit the repository link to the Cursor team (via Slack or
   `kniparko@anysphere.com`) for review and listing.

Bump `version` in `plugins/usemycontext/.cursor-plugin/plugin.json` on every release. Nothing here deploys a
worker or a Pages site; the plugin only needs this public repository to exist. The live UseMyContext service
it connects to is at [usemycontext.ai](https://usemycontext.ai).
