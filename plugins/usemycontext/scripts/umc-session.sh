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
# are untouched. A marker whose values are not a plain project id and @handle is
# REFUSED WHOLE, and reads the same as no marker at all - see the shared
# validator below. Dependency-free POSIX sh (dd + grep + sed + tr + cut), no jq.

emit_empty() { printf '{}\n'; exit 0; }

# --- BEGIN shared .umc marker validator (USE-583) ---------------------------
# This block is BYTE-IDENTICAL in all three shell plugin trees:
#   antigravity-plugin/usemycontext/scripts/umc-session.sh
#   claude-code-plugin/usemycontext/scripts/umc-session.sh
#   cursor-plugin/plugins/usemycontext/scripts/umc-session.sh
# and it enforces the SAME rules as its JS twin, validatedMarker() in
# opencode-plugin/index.js. The trees ship as separate public repositories and
# cannot import a shared file, so test/plugin-marker-validation-use583 pins the
# rules on both sides, drives ONE corpus through both, and fails the moment
# either spelling drifts.
#
# Why it exists: a ".umc" marker is attacker-controlled the moment you clone
# somebody else's repository, and our own docs suggest committing one. Its
# values used to be read with no validation and interpolated verbatim into the
# text the model reads, which let a marker carry instructions of its own.
#
# THE RULE, in the order it is applied. Both spellings do exactly this:
#   1. read at most 4096 bytes of a REGULAR, NON-SYMLINK file at <dir>/.umc
#   2. refuse the whole file if any of those bytes is NUL
#   3. drop a UTF-8 BOM (0xEF 0xBB 0xBF), which is what a Windows editor writes
#      ahead of the first key
#   4. split on newlines; trim ASCII whitespace only; skip blank and "#" lines;
#      split each line on its FIRST "="; first occurrence of a key wins
#   5. projectId must match ^[A-Za-z0-9_-]{1,32}$
#      handle    must match ^@[A-Za-z0-9-]{1,40}$
#   6. on ANY miss refuse the WHOLE mapping
# Nothing is half-read, and no value is ever sanitised into something that
# still speaks.
#
# The C locale is DELIBERATE and is part of the rule, not a tidy-up. Under a
# UTF-8 locale [[:space:]] also matches NBSP and tr rejects an invalid byte
# sequence on stderr, so the SAME marker mapped or did not map depending on the
# host's locale - and whether it agreed with the JS twin flipped with it. The JS
# twin trims the C-locale set explicitly for the same reason, rather than using
# String.prototype.trim, which strips NBSP and U+FEFF too.
LC_ALL=C
export LC_ALL

umc_marker_project_id=""
umc_marker_handle=""

# Steps 1 and 3. The 4096 bound is what turns a 944MB marker, a FIFO, or a
# symlink to /dev/stdin into a non-event instead of a hang. A short read only
# ever loses trailing bytes, so it fails CLOSED.
umc_marker_read_bounded() {
  dd if="$1" bs=4096 count=1 2>/dev/null | tr -d '\357\273\277' 2>/dev/null
}

# Step 4 for one key. $2 is only ever one of the two literals below, never
# anything read off disk.
umc_marker_value() {
  umc_marker_read_bounded "$1" \
    | grep -E "^[[:space:]]*$2[[:space:]]*=" 2>/dev/null \
    | head -n1 \
    | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//' 2>/dev/null
}

# Sets umc_marker_project_id / umc_marker_handle from "$1"/.umc, or leaves both
# empty, which every caller reads as "this folder is not mapped".
umc_marker_load() {
  umc_marker_project_id=""
  umc_marker_handle=""
  [ -n "$1" ] || return 0
  umc_file="$1/.umc"
  # -h FIRST: a symlink is refused outright, even one pointing at a perfectly
  # ordinary file. Plain -f FOLLOWS the link, so a committed
  # ".umc -> /dev/stdin" (git stores it as mode 120000, so it ships in a clone)
  # would otherwise pass the test below and then hang.
  [ -h "$umc_file" ] && return 0
  # -f is false for a FIFO, a device, a socket and a directory.
  [ -f "$umc_file" ] || return 0
  # Step 2. A NUL cannot survive command substitution, so it is checked on the
  # bytes themselves rather than on the parsed value.
  umc_raw=$(umc_marker_read_bounded "$umc_file" | wc -c | tr -d ' ')
  umc_txt=$(umc_marker_read_bounded "$umc_file" | tr -d '\000' 2>/dev/null | wc -c | tr -d ' ')
  [ "$umc_raw" = "$umc_txt" ] || return 0
  umc_pid=$(umc_marker_value "$umc_file" projectId)
  umc_hnd=$(umc_marker_value "$umc_file" handle)
  [ -n "$umc_pid" ] || [ -n "$umc_hnd" ] || return 0
  # Steps 5 and 6. Refuse the WHOLE mapping on any miss: a marker carrying one
  # good value and one hostile one is a hostile marker.
  if [ -n "$umc_pid" ]; then
    printf '%s\n' "$umc_pid" | grep -Eq '^[A-Za-z0-9_-]{1,32}$' || return 0
  fi
  if [ -n "$umc_hnd" ]; then
    printf '%s\n' "$umc_hnd" | grep -Eq '^@[A-Za-z0-9-]{1,40}$' || return 0
  fi
  umc_marker_project_id="$umc_pid"
  umc_marker_handle="$umc_hnd"
}
# --- END shared .umc marker validator (USE-583) -----------------------------

# --- BEGIN shared JSON string emit (USE-583) --------------------------------
# BYTE-IDENTICAL in the two shell plugin trees whose host reads JSON back:
#   antigravity-plugin/usemycontext/scripts/umc-session.sh
#   cursor-plugin/plugins/usemycontext/scripts/umc-session.sh
# (the Claude Code hook writes plain stdout, so it has no use for this.)
#
# The old escaper covered backslash, double quote and newline only, so a TAB or
# any other C0 control byte in the message emitted INVALID JSON and the hook
# died silently on the first model call in that folder, every time. Controls are
# DELETED rather than escaped: not one of them belongs in a one-line reminder,
# and the marker validator above already refuses any value that could carry
# one. The length bound is the second belt - the message is our own prose plus
# at most 32 + 40 validated characters, so the cut can only ever be reached by a
# bug of ours. It runs BEFORE the escaping so it can never sever a "\\" pair
# and hand the host invalid JSON in the act of bounding it.
umc_json_string() {
  printf '%s' "$1" \
    | tr -d '\000-\037\177' \
    | cut -c1-3900 \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
# --- END shared JSON string emit (USE-583) ----------------------------------

umc_marker_load "${CURSOR_PROJECT_DIR:-.}"

[ -z "$umc_marker_project_id" ] && [ -z "$umc_marker_handle" ] && emit_empty

label="$umc_marker_project_id"
[ -n "$umc_marker_handle" ] && label="$umc_marker_handle${umc_marker_project_id:+ ($umc_marker_project_id)}"

message="UseMyContext: this folder is mapped to your \"$label\" context."
if [ -n "$umc_marker_project_id" ]; then
  message="$message On every UseMyContext MCP tool call (profile, list_files, search_files, get_file, ask_docs, query_table, suggest_update), pass the argument projectId=\"$umc_marker_project_id\" so this session reads the mapped project. This applies when your UseMyContext connection is account-wide; a single-project connection is already scoped and ignores the argument."
fi

printf '{"additional_context":"%s"}\n' "$(umc_json_string "$message")"
