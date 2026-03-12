# AGENTS.md — Loothing Addon

Agent and collaborator guidelines for the Loothing loot council addon.

## Repository Layout

```
Loothing/               ← this repo (addon code)
  Core/                 ← Constants, Init, Utils, Diagnostics
  Comm/                 ← Protocol, MessageHandler, Handlers/, AckTracker
  Data/                 ← PlayerCache, History, MLDB
  Modules/              ← AutoPass, AutoAward, VersionCheck, Sync, …
  UI/                   ← CouncilTable, RollFrame, HistoryPanel, …
  Debug/Tests/          ← Regression tests (CommunicationTests, StressTests, …)
  Loothing.toc
```

The sibling `Loolib/` directory is a separate git repository — its commits are independent.

---

## Standard Operating Procedure: Code Review + Release

Follow this procedure for every version bump.

### 1. Code Review

Before bumping the version or writing a changelog entry, review every changed file:

| File | What to verify |
|------|---------------|
| `Comm/Protocol.lua` | Return signatures match docblocks; all error paths return the right number of values |
| `Comm/MessageHandler.lua` | TempTable acquired and released in all exit paths of `FlushBatch`; `seenIDs` sweep runs; `Encode` return value captured correctly |
| `Comm/Handlers/Core.lua` | `validateHandler` called before any field access; `SCHEMAS` entries match what `MessageHandler` broadcasts; BATCH size check present |
| `Core/Utils.lua` | `ValidateSchema` handles nil data gracefully (callers must nil-check before calling) |
| `UI/CouncilTable/Rows.lua` | Guard flags (`_clickHooked`, `_voteHooked`) set before `SetScript`; closures read dynamic fields, not captured per-refresh locals |
| `UI/CouncilTable.lua` | `ThrottledRefresh` assigned in `Init` as a closure, not a method; no residual `pendingRefresh`/`lastRefreshTime` state |
| `Loolib/Core/FunctionUtil.lua` | `ThrottleWithTrailing` trailing call fires after remaining cooldown, not a full new interval |

**Checklist per file:**
- [ ] All `@return` docblocks match actual return statements (number of values, nil consistency)
- [ ] No bare `return nil` where a multi-value return is declared
- [ ] No new globals introduced (run `/lt taint scan` in-game after deploy)
- [ ] Guard-flag pattern: `if not frame._hooked then ... frame._hooked = true end` — reset function must NOT clear the flag
- [ ] `TempTable:Release` called in every exit path, never before `Send()` completes

### 2. Version Bump

- `Loothing/Core/Constants.lua` — bump `Loothing.VERSION`
- `CHANGELOG.md` (workspace root) — add new `## [X.Y.Z] - YYYY-MM-DD` section

### 3. CHANGELOG Entry Structure

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
#### Feature Name (`File/Path.lua`)
- Bullet per behavior change

### Fixed
#### Bug Name (`File/Path.lua`)
- Bullet per fix

### Performance
#### Description (`File/Path.lua`)
- Bullet

### Documentation
- Inline bullets for doc-only changes
```

### 4. Commit Sequence

Commit Loothing and Loolib separately (they are different git repos).

**Loothing commits** (in `/mnt/Dongus/Loothing-Addon-Development/Loothing`):

```
fix(security): <description>     ← security hardening
fix(perf): <description>         ← performance fixes
feat(security): <description>    ← new security features
feat(perf): <description>        ← new performance utilities used here
refactor: <description>          ← code cleanup
docs: <description>              ← doc-only changes
chore: bump version to X.Y.Z     ← version + changelog commit
```

**Loolib commits** (in `/mnt/Dongus/Loothing-Addon-Development/Loolib`):

```
feat(loolib): <description>      ← new utilities or APIs
fix(loolib): <description>       ← bug fixes
```

Use `git -C /path/to/repo` to avoid CWD confusion between the two repos.

### 5. Push

```bash
git -C /mnt/Dongus/Loothing-Addon-Development/Loothing push
git -C /mnt/Dongus/Loothing-Addon-Development/Loolib push
```

**Note:** The `CHANGELOG.md` lives at the workspace root (outside both repos) and is not committed to either repo's history — it is maintained as a workspace document.

### 6. Build Release

```bash
cd /mnt/Dongus/Loothing-Addon-Development
bash package.sh --preset loothing
```

Output: `loothing_X.Y.Z.zip` in the workspace root.

### 7. Post-Release Verification

Run these in-game after deploying the new build:

```lua
-- Check for TempTable leaks after a voting session
/run Loolib.TempTable:PrintLeaks()

-- Run taint scan
/lt taint scan

-- Run communication tests
/lt test comm
```

Manual checks:
- Send a BATCH with >20 inner messages from a test client → verify rejection (Debug log)
- Send a v3-format message to a v4 client → verify it processes normally (no dedup drop)
- Open council table with 25+ candidates, trigger rapid vote updates → verify correct candidate selected after sort

---

## Protocol Versioning Rules

- `PROTOCOL_VERSION` lives in `Core/Constants.lua`
- Bump the version only when the wire format changes in a breaking way
- Backward compat target: v(N-1) senders must work with vN receivers
- Document the compat story in `Protocol.lua`'s header block

## Security Model

- Every incoming handler must call `validateHandler(name, data, schema)` before accessing any field
- Handlers that receive no data payload keep a bare nil check via `validateHandler(name, data)` (no schema arg)
- ML-only commands must additionally check `isMasterLooter(sender)` or `isGroupLeaderOrAssistant(sender)`
- Never trust `sender` for authorization without a Blizzard-verified group role check

## Performance Rules

- No anonymous closures in `UpdateRow` or `CreateCandidateRow` hot paths
- Use `Loolib.TempTable:Acquire()` / `Release()` for any table that lives < 500 ms
- Use `Loolib.FunctionUtil.ThrottleWithTrailing` for refresh functions that need both leading responsiveness and trailing completeness
