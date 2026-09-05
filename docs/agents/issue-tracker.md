# Issue tracker: Linear

Issues for this repo live in Linear. Use the **Linear MCP server** for every operation; there is no first-party CLI. Tool names below are bare (`save_issue`, `get_issue`, …); the real names carry the server's prefix. If the tools are deferred, load them in **one** `ToolSearch` call.

## Team and project

**Team: `Engineering` (key `ENG`).** **Project: `beam-sharp design map`**, exact string, no dash: a wrong project name returns an empty list and raises no error.

## Canonicality is split

Linear owns **state**: status, assignee, blocking, priority, labels, the frontier. The repo owns **content**: a map ticket's question, answer and cross-references live in `wayfinder/issues/NN-<slug>.md`, and the Linear description carries the gist plus a link to that file. Research and prototypes are repo-only. `CLAUDE.md` says why.

## Conventions

- **Create**: `save_issue` with `title`, `team: "Engineering"`, `project: "beam-sharp design map"`. `description` is Markdown with literal newlines.
- **Update**: `save_issue` with `id` set to the identifier (`ENG-123`). Prefer `patch` (anchor + insert/replace) over rewriting a long description; each anchor must match exactly once.
- **Read**: `get_issue` with `id`; add `includeRelations: true` for `blockedBy`/`blocks`. Comments come from `list_comments`.
- **List**: `list_issues` with `project: "beam-sharp design map"`, `limit: 250`, and `fields` such as `["id","title","status","statusType","priority","labels","parentId","updatedAt"]`.
- **Labels**: `labels` replaces the whole set; use `addLabels` / `removeLabels` for a change. Existing vocabulary: `ready-for-agent`, `ready-for-human`, `needs-info`, `quick-fix`, `apparatus`, `debt`, `deferred`, `Bug`, `Improvement`, `Feature`, and the `wayfinder:*` set below.
- **Close**: `save_issue` with `state: "Done"` (type `completed`) or `"Canceled"`. Write the explanation into the description or a comment first.

### Identifiers

Issues are `ENG-NNN`. **There is no formula from a ticket number to an issue id.** `ENG-(166+NN)` held for tickets 00–32 and has broken since; query Linear for the id every time.

### States are typed

`Triage`, `Backlog`, `Todo`, `In Progress`, `In Review`, `Done`, `Canceled`, `Duplicate`. Write logic against `statusType`, show names to humans. **`In Review` means waiting on David's verdict**, not on a session: skip it when picking work.

## Diffs as a triage surface

**No.** Linear diffs are not a request surface for this repo.

## Wayfinding operations

Used by `/wayfinder`. **`/frontier` is the ranked front end** to these for this repo: it runs the repo-side script, pulls state as below, ranks by claim, blocking, priority, label and the repo's own rules, and claims the pick. Prefer it over a raw frontier query.

- **Map**: [ENG-165](https://linear.app/davewil/issue/ENG-165), labelled `wayfinder:map`. Destination, Notes and *Decisions so far* live there; the last was rebuilt on 2026-09-05 from the tickets' decisions entries, one line each, after the repo copy of the map was deleted. Append one line there on each resolution. "Was X decided" is answered by `grep -l X wayfinder/issues/*.md` and the hit's `## Decisions entry` section.
- **Child ticket**: a native sub-issue, `save_issue` with `parentId: "ENG-165"` and the project set. A **map ticket** is titled `NN — <question>` and has a file `wayfinder/issues/NN-<slug>.md` holding the question; the Linear description holds the gist and the file link. A **defect or feature** is a Linear-only issue in the same project with no ticket number and no file. Labels: `wayfinder:<type>` for `research`, `prototype`, `grilling`, `task`.
- **Blocking**: native relations. `save_issue` with `blockedBy: ["ENG-12"]` (append-only; `removeBlockedBy` to drop). Read with `get_issue` and `includeRelations: true`. Never a `Blocked by:` line in prose.
- **Frontier query**: `list_issues` with the project and the fields above; drop `completed`/`canceled`, drop `In Review`, drop anything assigned and `In Progress` in both trackers unless you are resuming it; then `get_issue` with relations on the survivors and drop any with an open blocker. Then rank per `/frontier`.
- **Claim**: `save_issue` with `state: "In Progress"` and `assignee: "me"`, **and** for a map ticket `Status: claimed` in its repo file. Both, before any work; one tracker alone is a stale label.
- **Resolve**: write the answer in the repo file, with a `## Decisions entry` section holding a ```` ```decisions-entry ```` block, and commit. Then `save_issue` to `Done` and paste the gist into the description. Then append one line to ENG-165's *Decisions so far* with `save_issue`'s `patch` (`insert_after` the last entry). Three writes, in that order.

## When a skill says "publish to the issue tracker"

`save_issue` with the team and project above.

## When a skill says "fetch the relevant ticket"

`get_issue` with the identifier, then the repo file its description links to. The file is the content; the issue is the state.
