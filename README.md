# The review board

How we review every plan and every diff at Go Dispatch: a small board of AI reviewers, each with one lens, plus a second AI model, chaired by the main Claude Code session. It's packaged as one Claude Code skill.

```
skills/review-board/
  SKILL.md          the process: cast, loop, Codex, mechanics, merging
  observer.md       Skye, the innovation observer
  codex-review.sh   the launcher for the second model (OpenAI Codex)
  personas/         one charter per reviewer seat; README.md says which seat to add when
```

## Why it works

- **More than one LLM.** This matters most. Seats running on the same model share the same blind spots, however many you add. A pass by a different model (we run OpenAI's Codex beside the Claude seats) reliably finds *different* bugs. It rarely contradicts the Claude seats; it adds to them. One medium-effort Codex pass on a plan found 7 P1 blockers, every one verified in the code. Treat the second model as a required seat, not an extra. The board still runs if Codex fails, but it never runs on one model by choice.
- **Plans are reviewed before code.** A design gap is cheapest to fix before anything is built.
- **Distinct lenses, not clones.** Elena (architecture) and Rafael (the skeptic) by default, with security, tenancy, pricing and the other specialists added when the change touches their area.
- **Findings are leads, not verdicts.** The chair verifies every finding in the code before acting on it, and overrules a finding that doesn't hold. That keeps false alarms out of the fix list.
- **Simple wins.** A finding that adds a mechanism (a lock, a flag, a guard) is declined unless it closes a hole reachable in production today. A scope-growth tripwire stops a small feature from growing large through review.
- **Small and cheap.** 3–4 seats plus Codex, one layer deep. Bigger boards cost more and find less.

## Skye, the innovation observer

Skye has been one of our best additions. Skye sits on every feature plan board, but doesn't review the plan. Skye asks what would make it better than anyone else's: a USP, a better experience for a passenger, driver or operator, more revenue for us or our customers, or a simpler system. Ideas go into a folder and never block the plan. An idea that's far cheaper to fold in now comes back to the product owner as a one-line `PROMPT:`.

We trialled Skye for two weeks and kept the seat. Over five weeks of plan boards, Skye has written 205 ideas.

**Mei**, our performance engineer, sits as the second observer: notes on hot paths and scale, with no vote on the verdict.

## Set it up

1. **Install Claude Code**, and for the second model the **OpenAI Codex CLI** (`npm install -g @openai/codex`, then `codex login`).
2. **Copy the skill** into your skills folder, either for every project or for one repo, shared through git:
   ```sh
   cp -R skills/review-board ~/.claude/skills/
   # or: cp -R skills/review-board <your-repo>/.claude/skills/
   ```
3. **Read the personas.** They name our own services, invariants and baselines. The lenses carry over as they are; swap in your own names and numbers where your platform differs.
4. **Use it.** In Claude Code, write the plan to a file and say *"run the board on docs/plans/my-plan.md"*, or type `/review-board`. The same for a diff: *"run the board on this branch"*.
