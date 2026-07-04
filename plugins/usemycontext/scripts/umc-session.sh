#!/usr/bin/env sh
# UseMyContext Cursor plugin - sessionStart hook.
#
# Cursor runs sessionStart hooks with a JSON payload on stdin and reads a JSON
# object back on stdout. We return an "additional_context" string that tells the
# session which UseMyContext profile this folder is bound to. Unlike Claude
# Code's plain-stdout SessionStart hook, Cursor requires valid JSON here, so this
# script emits a JSON object (and nothing else) on every path.
#
# The mapping lives in a per-repo ".umc" marker (a tiny key=value file), for
# example:
#   projectId=p2
#   handle=@work
#
# No marker, or an empty one, means this folder uses your account's active
# UseMyContext profile - the hook returns an empty JSON object so unmapped repos
# are untouched. Dependency-free POSIX sh (grep + sed + tr), no jq.

emit_empty() { printf '{}\n'; exit 0; }

project_dir="${CURSOR_PROJECT_DIR:-.}"
marker="$project_dir/.umc"
[ -f "$marker" ] || emit_empty

read_value() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$marker" 2>/dev/null \
    | head -n1 \
    | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//'
}

project_id=$(read_value projectId)
handle=$(read_value handle)

[ -z "$project_id" ] && [ -z "$handle" ] && emit_empty

label="$project_id"
[ -n "$handle" ] && label="$handle${project_id:+ ($project_id)}"

message="UseMyContext: this folder is mapped to your \"$label\" context."
if [ -n "$project_id" ]; then
  message="$message On every UseMyContext MCP tool call (profile, list_files, search_files, get_file, ask_docs, query_table, suggest_update), pass the argument projectId=\"$project_id\" so this session reads the mapped project. This applies when your UseMyContext connection is account-wide; a single-project connection is already scoped and ignores the argument."
fi

# JSON-escape the string value: backslash first, then double-quote, then strip
# any stray newlines so the output is a single valid JSON object.
escaped=$(printf '%s' "$message" \
  | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
  | tr -d '\012\015')

printf '{"additional_context":"%s"}\n' "$escaped"
