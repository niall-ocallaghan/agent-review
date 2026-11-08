---
name: review-board
description: Run the review board, the team's core quality gate, for a plan or a diff. Covers the persona cast and their distinct lenses, the two observers (Skye for innovation, Mei for performance), the plan→code→diff→converge loop, explicit model pinning (never fork a review seat), and the one sanctioned way to launch Codex (codex-review.sh beside this file; medium effort for plans, never hard-block, capped polling). Trigger when reviewing a plan or diff, when the user says "run the board"/"board review"/"get Elena and Rafael on this", before coding any major task, before merging a PR, when a Codex review is needed or has gone quiet, or when a reviewer seat stalls.
---

# The review board

The team's core quality gate for plans and diffs, in every repo. Run well, it carries whole epics with little need for a human in the loop.

**Terms used here:**
- **Chair**: the main session. It writes the brief, launches the seats, verifies every finding in the code and decides.
- **Seat**: one reviewer sub-agent with one persona's lens (`personas/`).
- **Observer**: a seat that reports notes or ideas but does not vote on the verdict.
- **Builder**: whoever writes the code, often the chair itself.
- **Fold**: applying an accepted finding.
- **P1 / P2 / P3**: P1 means wrong, unsafe or loses data. P2 means a real defect or gap. P3 means minor or polish. **P1 and P2 block the merge**; P3s wait for the cleanup pass.
- **Double-green**: the Claude seats and Codex both return no P1/P2.

Files beside this one: `personas/` (the seat charters; `personas/README.md` says which seat to add when), `observer.md` (Skye's brief) and `codex-review.sh` (the Codex launcher).

## The mantra: brief every seat with it

> Define the problem and the goal. Keep it simple. Keep challenging over-engineered solutions. Always think outside the box and try to approach the problem from a different angle. Analyse the *why* and the problem we are trying to solve, and see is there a better way to achieve the goal. Or perhaps some problems are not worth solving.

Every plan states, above everything else: **problem · goal · simplest thing that gets there · is it worth solving now.**

## The cast

**Size: the one-layer rule.** A board is 3–4 persona seats plus Codex: at most **5** Claude sub-agents (observers included) and at most 6 running at once per session. Seats run on your strongest model. Nothing is spawned from a seat, and there is **no refute/verify panel**: the chair verifies every finding in the code. Say the count before launching ("launching 4 agents: Elena, Rafael, Mei, Skye, plus Codex"). A plain `Agent` call per seat, all in one message, is the board. Don't run it through a workflow script that spawns agents per finding.

*Why:* a "refute panel" of three verifier agents per finding once turned a three-seat board into 38 agents and ~4M tokens in 30 minutes, and another into 61 agents that exhausted an account's session limit mid-review. Four seats with distinct lenses find the bugs, and the chair's own verification catches what they miss.

Spawn seats as parallel `Agent` subagents of type `general-purpose`, because they must be able to read code to verify claims. Each seat reads its persona file and the plan or diff **from files**: hand it the paths, never paste the content. Each returns P1/P2/P3 findings and a verdict: `proceed` / `proceed-with-changes` / `rethink`.

Give every seat a **distinct lens**. Clones waste tokens and converge on the same findings.

- **Elena** (`personas/architect.md`), senior domain architect: data modelling, cardinality, boundary/deptrac discipline, one flow per operation whatever the booking source, lifecycle correctness, "is the seam in the right place".
- **Rafael** (`personas/architect-skeptic.md`), pragmatic staff engineer: hot path, edge cases, phasing and risk, testability, over-engineering vs under-specified gaps, fail-soft posture.
- **Codex**, a model-diverse adversarial pass: OpenAI's Codex CLI, launched with `codex-review.sh`, not a Claude agent. Independent passes by a different model reliably surface *non-overlapping* bugs, so Codex runs **alongside** the Claude seats, never instead of them.

Add personas from `personas/` when the change warrants it, e.g. Casey (security) and Priya (multi-tenancy) for auth work. **A hot zone applies even to a one-line change:** a one-line pricing change still gets Sophia.

### The observers

Observers count within the cap of 5. They never block, and they don't vote on the verdict.

- **Skye, innovation** (`observer.md`), on every **feature** plan board: a blue-skies brief covering a USP, a better experience for a passenger, driver or operator, revenue for us or our customers, or a simpler system. Skye writes ideas to the ideas folder and never changes the plan. A `PROMPT:` line in Skye's reply goes to the product owner. Skye doesn't sit on diff boards, fixes, tests, lint or refactors.
- **Mei, performance** (`personas/performance.md`), on plan and diff boards for any change that runs at volume in production: a request path, a query, a loop over rows, a sweep or a scheduled job. Mei skips docs, tests and pure UI. Mei reports performance notes graded P1/P2/P3, with the estimated cost at today's load and at 10×. A note the chair verifies in the code becomes a finding like any other. If a security or tenancy board needs the room, Mei is the first seat to drop when the change has no hot path.

## The loop

**Per task:**
1. **Plan → board.** For any major task, review the *plan* before writing code. A locked or signed-off decision can still be half-wrong, and design gaps are cheapest to catch here.
2. **Code.**
3. **Implementation → board**: a code review of the diff.
4. **Fix every P1 and P2**, then re-review to convergence (double-green). A re-review of a fold is 1–2 seats, not the whole board.
   - **A fold list sent to a builder pastes each reviewer's exact proposed text**, not a summary of it. A builder handed summaries ends up writing the folds itself, and each one then needs a second read.
   - **A live proof can kill a fold's premise.** When it does, delete the path you have decided is dead before the merge, not after.
5. **Next task**, same process.

**Per epic:** every task runs the loop. When all tasks are clear of P1/P2, do a **cleanup pass** for P3s and minor issues. Work autonomously, and pause for a human only when genuinely blocked: a decision that is theirs to make, or a load-bearing ambiguity the code cannot resolve.

Review at **natural break points**, meaning a coherent, independently reviewable unit, not one giant end-of-work batch.

## Findings are leads, not verdicts

The main session is often more capable than a reviewer's backing model.

- **Verify every load-bearing finding in the code before acting.**
- Where reviewers disagree on something load-bearing, verify it yourself rather than averaging two guesses.
- **Overrule a claim that doesn't hold**, and record the reason in the fix brief or the ticket.
- Accept correctness, security and stability findings after verification. Weigh polish and gold-plating against delivery momentum, and **say** when you decline one instead of silently dropping it.
- **A correction is a new claim, and it is yours.** Verifying a finding does not verify the inference you draw from it. When a true finding overturns something you wrote, state what you now conclude as its own claim and check that at source too. For example, before explaining how a caller reaches a line, read which method the line is in. The cheapest check is to write the claim as a test and run it. A correction looks already-checked, so it gets less scrutiny than the claim it replaces. Once, a true Codex finding led to a false explanation that three sessions then relayed.
- **Agreement between seats is not corroboration.** Seats read the same tree and the same plan, so their agreement is often one source read several times. Verify a load-bearing claim in the file whether the board split on it or not. Treat unanimity on a fact nobody had to dig for as a reason to check. Three seats and the chair once agreed on a CORS need that one stale fallback line had created. The commonest cause is the chair's own belief, restated in the plan.
- **Two agents reporting the same number differently is a signal.** State each basis before reconciling. Never round to each other, average, or adopt the more official-looking source. A three-in-800 gap in an API operation count (five HTTP methods counted vs eight) led to a real defect. A number retrieved is not a number verified.

**Simplicity outranks completeness.** A finding that **adds** a mechanism (a lock, a cap, a marker, a token, a guard, a layer, a flag, a sweeper) is **declined by default**. Accept it only when it closes a hole reachable in production *today*. A finding that **removes** one is accepted eagerly, even late in a PR. The board optimises for completeness; the chair optimises for the simplest system that meets the goal.

## Model pinning

**Always pass `model` explicitly on every `Agent` call.** A seat with no `model` inherits the session model, so "the reviewers are on X" silently changes whenever the session model changes.

**Never make a review seat a `fork`.** `subagent_type: "fork"` always inherits the parent model and ignores the override.

**Keep the chair at least as capable as the board.** Findings are leads the chair must verify and sometimes overrule. A weaker chair adjudicating a stronger reviewer can neither safely accept nor reject a finding.

## Codex: the one launch path

Raw `codex exec` is retired for board reviews. In background shells it showed four distinct silent-hang modes (stdin held open by background shells, startup stalls, polling the wrong id, and the echoed prompt mistaken for a verdict) that cost hours of watching nothing happen.

```sh
<this skill's dir>/codex-review.sh <prompt-file> <out-file> [timeout=480] [effort]
```

The wrapper closes stdin and kills a process that hasn't booted within 45s (**exit 65**). It hard-caps wall clock (**exit 66**), and treats a suspiciously small output as a failure (**exit 67**). It exits 0 only when real review content landed. Hangs are impossible by construction; failures are loud and fast.

**Rules:**
1. **Codex is never the sole reviewer on the critical path.** Launch it in the same message as at least one Claude seat. Whoever returns first starts the fold.
2. **Any nonzero wrapper exit = no Codex this round.** Retry at most once, then ship on the Claude verdicts and reconcile Codex after the merge if it lands.
3. **Right-size effort.** Pass `medium` for mechanical-diff sanity passes *and for plan-sized reviews*. The default `xhigh` has run out the clock and returned no Codex review at all, where a `medium` retry landed comfortably and still found 7 code-verified P1 blockers. A completed medium beats a timed-out xhigh. Run xhigh only if you deliberately raise the timeout past its latency.
4. **Never hard-block on Codex.** Cap polling at its real latency (~5–6 min) with early exit, never a blind 20-minute loop. Idling for a second opinion is the wrong trade: Codex rarely contradicts the Claude seats, it usually *extends* them.
5. **Stop a run by its own task or pid, never by pattern.** `pkill -f "codex exec"` matches every Codex review on the machine, so one session's stop kills the others' runs in flight. They end with exit 65/66 or a signal and an empty out-file, which reads like a failed round. Stop the wrapper's own background task (`TaskStop`) or the pid from its launch. A round that died at the moment of someone else's stop is a rerun, not a verdict.
6. **A Codex prompt for a worktree whose `node_modules` is symlinked to the main checkout's forbids Vite and `npm ci`**: "no Vite server, `npm run dev`, `build`, `preview` or `npm ci`; read the code, run vitest, eslint or tsc only". Codex reproduces findings on its own, and one run's `createServer({configFile: false})` emptied the main checkout's `.vite/deps` under the live console, which had to be restarted. `npm ci` there would empty the main checkout's whole install, because it deletes the entries in the link's target.

### Run it from a git repo, and never pipe it

1. **`codex exec` refuses to run outside a trusted directory** ("Not inside a trusted directory and --skip-git-repo-check was not specified"). Run the wrapper with a git repo as cwd (the repo under review is the obvious choice), and pass absolute paths for the prompt and out files.
2. **Never pipe the wrapper through `tail` or `head`.** `$?` then belongs to the pipe's last command, so a failed Codex looks like exit 0. Redirect to a log file instead, and read the out-file to confirm real content landed.

Together these produce the worst case, a "completed, exit 0" notification for a run that never started. Check the out-file's size and first lines before believing any Codex result.

### The launcher-exit trap

If you background the wrapper (`nohup … &` inside a `run_in_background` shell), the **harness completion notification fires for the launcher shell, not for Codex**. You get "exit code 0" within seconds while Codex is still running, and that exit 0 means nothing. Either:

- run the wrapper in the foreground of a backgrounded Bash call, so the harness tracks the wrapper itself and its real exit code, or
- treat the notification as meaningless and poll `<out-file>` on a capped budget, confirming liveness with `pgrep -fl "codex exec"`.

Don't read Codex's raw session JSONL under `~/.codex/sessions` to check progress. Poll the wrapper's out-file (`ls -l`), then read it once it stops growing. `date` works in Bash for elapsed-time budgeting.

## Mechanics checklist

1. **Ground the plan in real code first**, using Explore agents or reading it yourself. A plan built on an unverified handover note is where the worst findings come from.
2. **Write the plan or diff to a file.** For a diff, freeze it **by the branch ref, never `HEAD`**: `git diff <base>...<branch> > <scratch>/<ticket>-diff.patch`. Give the seats a worktree at that same ref (`git worktree add --detach <dir> <branch>`). `HEAD` is wherever the checkout happens to be: a board once froze from `HEAD` while the checkout sat on the previous ticket's branch, and both seats reviewed the wrong diff. Tell each seat the commit, and have it confirm `git log -1` names the ticket before it reviews.
3. **Spawn every reviewer in ONE message** so they run in parallel, including the Codex launch.
4. **Tell each seat the exact repo path** to verify against. In a multi-worktree checkout this is essential: naming the wrong directory sends a reviewer to a branch that will mislead it. If you will keep editing that tree while seats read, give them a frozen snapshot instead (`git worktree add --detach <scratch>/<name> <sha>`, removed afterwards) and name that path.
5. **Seats that run things.** Mutation testing, where a seat breaks the code to prove a test catches it, is exactly what seats should keep doing. The brief says where and how:
   - **Only on the seat's own detached copy, one per seat**, named in that seat's brief. Never in the builder's live worktree, where a mutation can ship in the next commit or a restore can overwrite the builder's edit. Two seats mutating one shared copy restore each other's mutations mid-run and report results neither can trust.
   - **Chain every step with `&&`, never a top-level `;`.** With `;`, the rest runs wherever the shell happens to be when the `cd` fails. Save first, and put a restore that must run even when the proof fails in a brace group: `cd <copy> && /bin/cp <path> <saved> && { <mutate> && <run>; /bin/cp <saved> <path> && cmp <saved> <path>; }`. Restore by copying the saved file back, never with `git checkout`.
   - **Prove a regression test red against the base's file, never against a stash.** Once the fix is committed on the branch, a stash leaves it in place, and the "old rule" run is really the new rule. Write the base's version in place (`git show <base>:<path> > <path>`), grep that the fix's line is absent, run the test, then restore.
   - **Give each snapshot its own dependency folder, never a symlink to the builder's.** A detached worktree has no `vendor/`. Linking the builder's in looks harmless, but an autoloader that resolves `__DIR__` through the link (Composer's does) loads the *builder's* source, so the seat tests the wrong code. Copy it instead. On macOS, `/bin/cp -cR <builder>/vendor <snapshot>/vendor` is an instant APFS clone (name `/bin/cp`, because Homebrew's GNU `cp` has no `-c`).
   - **Run only an explicit `tests/Unit/...` path, never a bare `phpunit`**, and say so in the brief whenever it lets a seat run tests. With no path, PHPUnit runs the whole suite, functional tests included. A seat's mutation script once lost its path argument and ran the full suite from its snapshot while a full test run was going. MySQL refused the snapshot, which had no credentials, but it still shared Redis and the CPU with the real run.
6. **Tell each seat what has already shipped**, so it doesn't re-report work that a stale ticket description implies is missing.
7. **Claude seats return via the normal completion notification. Don't poll or tail their transcripts.** A stalled seat recovers from ONE resume nudge (`SendMessage`): nudge once, never twice. A seat that dies mid-pass on a transient API error recovers the same way. Resume it with "finish and deliver your verdict" rather than relaunching from scratch: it keeps its read context and converges in a fraction of the original pass.
8. **Record the round in the ticket**: verdicts, the findings you accepted, and every finding you **declined, with the reason**.
9. **Stale prose is a finding.** Brief the diff seats to look for docs and comments that still state the rule this diff changed: a docblock, a test comment, a README, another repo's pinned value. Each one is a P2. **A closed list ("scheduled from A, B, C and D") is a contract, not a description**, because a reader auditing it stops there. When a diff renames or retires something, grep the whole docs tree for it with no output limit before declaring nothing else needs to change.
10. **Reuse before writing.** A diff that re-implements a method, service, helper, hook or component that exists elsewhere is a P1-class lead, above all a copy made so a layering rule isn't crossed. The fix is to move it to the one home both callers may depend on, with its layer wiring. Two copies stay only as an approved exception, with the reason in the PR body. Brief the diff seats to look for it.
11. **Runaway loops.** A diff that adds or changes an autonomous loop (a sweep, a watcher, a scheduled job, a consumer that retries) is checked for runaways. A row the loop can't act on is changed once, by a plain write that doesn't go through the failing code. The loop alerts once, where a person looks, and logs one counted line per run, never one per row. The lead to look for is an ERROR or WARNING inside a per-row loop body.
12. **Repo standing lines.** Each repo adds the checks that have escaped a board once, and the diff seats are always briefed with them. Ours:
    - **Console (React) diffs: the styling line.** Any `sx=`, `<Typography`, `helperText`, inline `style={{…}}` or bare (outlined) MUI `TextField` in a `.jsx` diff is a finding. The console styles by className and one stylesheet only. One feature shipped all of these past its diff board and the chair, and they were found on the screen.
    - **The console's backend floor.** A console change that needs a backend change it cannot degrade without moves the console's `compat.json` `minCommit` to that backend sha **in the same PR**. One merged without it, past its board and the chair, and a second PR had to move the floor.
    - **The backend's console floor, the other direction.** A backend diff that an older console cannot survive moves the backend's `supportsConsole.minCommit` to the console commit that adapts, **in the same PR**, and that console commit **merges first**. The usual case is a backend layout node naming a console component the console doesn't have yet, which an older console draws as "Not Supported". So when a backend plan names a new node, split it: the backend without the node, then the console against it, then a small backend PR that names the node and moves the floor.

## Merging: freeze, verify, prove

**The builder's side.** Cut one branch off a freshly fetched `origin/main`. Once review starts, the branch only gains commits: never rebase or force-push, and send each new head to the chair. **A head that moves after approval goes back with its delta before the merge**, even when the change is one the chair asked for, because approval names the exact head that merges. **A test that drives a real command points at a closed port** (`--base-url http://127.0.0.1:9` or the equivalent), never a dev default. A refusal test written before its code once ran for real against a dev stack and started simulated drivers.

**Before the merge (the chair):**
1. **Freeze from origin**, never from a seat's figure: `git fetch origin <branch>`, then `git diff origin/main...origin/<branch>` (three dots) into your scratch dir. Record the head sha, the merge base, ahead/behind, and files/+/−.
2. **Hash the frozen patch**, with index lines stripped (`grep -v '^index ' <patch> | md5`) so a rebase that moves blob ids without moving content keeps the hash. A seat's figure must equal yours. Never copy a seat's hash.
3. **Read every line.**
4. **Read the test run yourself; don't take a report.** Check that every exit code is 0, the totals add up, and the run is newer than the head's commit. A retried-green run passes only if every first-run failure is named and filed as a flake, and none of them tests the code the PR changes. A test of the changed code that fails in parallel and passes serially is a race until shown otherwise.
5. **Merge on the head sha, not the tick.** `gh pr checks` can show a pass for the pre-fold commit while the run on the pushed fold is still going. Find the run for the pushed sha (`gh run list --branch <b> --json headSha,conclusion,databaseId`), assert `headSha == pushed && conclusion == success`, and merge with `--match-head-commit <sha>`. A clean `mergeable` only means no textual conflict: when two open PRs touch the same files, trial-merge onto a throwaway branch and run the suite first.
6. **The check must gate the merge.** In one multi-line shell call a newline acts as `;`, so a failed check on one line does not stop `gh pr merge` on the next. Gate with one `&&` chain that ends in the merge, or with a script run in a child shell (`bash gate.sh`), whose own `set -e` holds. A `set -e` typed into the call itself is no gate: Claude Code's Bash tool runs the call in a top-level shell that ignores errexit, so `set -e; false; echo x` prints `x`.
7. **Wait for CI without draining the API.** Every session shares one GitHub budget of 5,000 requests an hour. A bare `gh run watch` polls every 3 s and `gh pr checks --watch` every 10 s. Two of those running emptied the budget twice in one morning and failed every session's `gh` calls until the hour reset. Use `--interval 90`. `gh api rate_limit` costs nothing.
8. **Run `gh pr merge` from a neutral directory with `--repo`** (`cd ~ && gh pr merge <n> --squash --repo <org>/<repo> --match-head-commit <sha>`), never inside another agent's checkout. Its post-merge tidy switches that checkout to `main` and deletes the branch it was on.

**After the merge (verify on origin, never trust the report):**
9. **The squash's patch hash equals the freeze.** If main moved between freeze and merge, neither hash proves anything. The proof is `squash^{tree}` == `git merge-tree --write-tree <main-at-merge> <frozen-head>`, with an empty diff.
10. **A merge call that errors may have merged.** A `gh pr merge` once answered 504 Gateway Timeout with the squash already on `origin/main`. Before retrying, fetch `origin/main` and read the PR's state. A retry with `--match-head-commit` is safe, since GitHub refuses to merge a merged PR.
11. **In zsh, brace a variable before a colon:** `git show ${H}:src/…`. In a bare `$H:src/…`, zsh reads `:s` as a history modifier and the command gets a mangled argument.

## Keep one copy of each charter

The persona files in `personas/` are the only copy. A charter pasted into another prompt template drifts from this one. If you change a seat's remit, change it there.

## Scope-growth tripwire

A feature sized small at triage must not turn into a large one *through the board* without its owner seeing it happen. Record the size (S / M / L) in the plan before building. Then **stop building** the moment any of these is true:

- the estimated diff or effort crosses a size bucket (S → M, M → L) because of board findings;
- a reviewer finding would add a **mechanism the approved plan did not contain**, such as a lock, a seam, a sweeper, a backfill or a new command;
- the diff board needs a **third round**.

When it trips, comment **"Scope grew"** on the ticket and hand it to the owner. Give the original scope, what grew and which findings drove it, the options (ship the minimal version / a simpler approach / accept the residual risk and downgrade the P1s / drop the feature) and your recommendation. Then move to other work, and resume only on the owner's call.

Findings stay **leads**: a P1 for a residual race window that is not reachable in production *today* is a P3 by default. Record the downgrade and the reason instead of building for it. The default cap on the diff board is **two rounds**. **"Drop the feature"** is always one of the options.

*Case study:* the ruling was one column, one unique index and one 409 response. It shipped as 25 files over four diff rounds. The growth was replay correctness for a deployment shape the customer didn't have, plus three escalating race-window guards on one operator command. Each step was cheap in isolation, and nobody was asked whether the whole was still wanted.
