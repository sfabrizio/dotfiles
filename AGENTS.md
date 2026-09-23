# AGENTS.md — working notes for coding agents on this repo

Read this before touching anything. It contains the traps that cost real
debugging rounds. Keep it updated when you learn something new.

## What this repo is

Personal dotfiles (zsh + omz, byobu/tmux + tmux-powerline, vim, git) with a
hardened installer and CI. **Branch: `develop`** — the only maintained branch
(`master` is a stale 2018 line; install one-liners point at develop).

## Layout map

| Path | Role |
| --- | --- |
| `install.sh`, `install-pi.sh`, `install-windows.sh` | installers (idempotent, DRY_RUN, bash-guarded); windows one installs Windows Terminal (winget) + WT profile fragment |
| `scripts/install-lib.sh` | shared installer helpers (run/write_config/backup_configs/summary) |
| `scripts/deps-versions.sh` | SINGLE SOURCE OF TRUTH for every pinned dependency (tmux-powerline sha, zoxide, nvm, nerd font, shunit2) + upstream URLs + OS package lists; the weekly CI PR edits ONLY this file |
| `scripts/deps-lib.sh` | dep library: network probes (timeout-guarded, empty = unknown), compare helpers (deps_is_newer/deps_sha_matches), installed-version probes (nvm-aware npm resolution), install/update functions shared by installers + deps-apply |
| `scripts/deps-check.sh` | pins vs upstream (CI, exit 10 = updates) / `--local` (drift + floating deps + OS pkgs) / `--os` / `--machine` TSV (KIND\tname\tA\tB\tC\tstatus) |
| `scripts/deps-apply.sh` | shows WHAT will be updated, asks [y/N] (tty-guarded; DOTFILES_DEPS_TTY=0 forces no-tty for tests), applies drift/behind deps; OS upgrades behind a second confirmation (sudo) |
| `scripts/deps-bump-pr.sh` | CI-only: deps report → sed bumps in deps-versions.sh → commit `[MOD] deps: bump N pin(s)` on `deps/weekly-bump` → single recycled PR (gh) |
| `scripts/auto-update.sh` | omz-style background update (13d epoch, modes, --force); after a pull runs deps-apply (`DOTFILES_DEPS_APPLY=0` off) |
| `scripts/lazy-nvm.zsh` | lazy nvm loader (sourced by zshrc; first node-family command pays the load) |
| `scripts/lazy-autoenv.zsh` | lazy autoenv loader (first `cd` or first node-family command; keeps .env nvm switches off the startup path) |
| `scripts/startup-check.sh` | zsh startup benchmark + zprof — the perf gate for every new plugin/tool |
| `scripts/doctor.sh` | interactive health check (tiered ok/warn/FAIL); pin checks read deps-versions.sh, never hardcode |
| `scripts/smoke-test.sh` | post-install verification (CI runs it after the installer) |
| `scripts/nerd-font-download.sh` | patched font installer (default Hack + tag from deps-versions.sh) |
| `scripts/semver.sh`, `scripts/get_os_name.sh` | small libs (sourced, not executed) |
| `segments/` | tmux-powerline user segments (libraries: they define run_segment) |
| `tmux-bar-sam-theme.sh` | the bar theme + segment lists |
| `byobu.tmux.conf` | byobu user hook — installer wires `~/.byobu/.tmux.conf` to source this so byobu launches with the dotfiles powerline bar (byobu's tmuxrc sources the user hook last) |
| `assets/demo.tape` + `demo.gif` | README live demo: vhs-rendered scripted session; re-render from repo root with `vhs assets/demo.tape` (see trap 34 for the tooling pins/gotchas) |
| `bin/` | thin exec shims on PATH (re-commit, multi-git, dotfiles-update, dotfiles-doctor, dotfiles-deps) |
| `test.sh` | self-contained suite: bash -n sweep, shunit2 units, installer dry-run |
| `.github/workflows/` | test.yml + install-{linux,macos,windows}.yml → reusable ci-install.yml + deps-check.yml (weekly Mon 06:00 UTC pin-bump PR) |

## The traps (read twice)

### tmux / status bar
1. Clicks on **user ranges always fire `MouseDown1Status`** regardless of bar
   side (server-client.c maps STYLE_RANGE_USER → STATUS). Bare left/right
   areas fire `MouseDown1StatusLeft/Right`; gaps + right-block segments fire
   `MouseDown1StatusDefault`.
2. **`\;` does not sequence inside if-shell branches** on tmux 3.5a (single-
   quoted branch strings keep it literal → silently broken installs). One
   command per branch, or a single `run-shell` with shell-level `;`.
3. Detect the tmux version with **`tmux -V`**, never
   `tmux display -p '#{version}'` (that needs a running server).
4. Segments are **libraries**: define `run_segment()`, no top-level code.
   Empty output + return 1 = the framework drops the segment (its contract).
   Tests must `source` the script then call `run_segment`.
5. The framework wraps segment content as `#[fg=<theme_fg>,bg=<theme_bg>]`
   (fg first). In-content `#[...]` markup may override, but remember the
   prefix order when writing assertions.

### shell / shunit2 2.1.6
6. shunit2 evals assert conditions **unquoted** → literal consecutive spaces
   in grep patterns collapse. Use `[[:space:]]*` classes, never literal
   multi-spaces.
7. shunit2 defines its own `fail()` (name collision) and **exits the shell
   when sourced** → run suites in a subshell. It is fetched on demand to
   /tmp (two mirrors in test.sh).
8. Interactive **zsh exports `ZSH`** (omz) — installers inherit it and the
   omz installer errors "The $ZSH folder already exists". Use `env -u ZSH`.
   zsh's printf also lacks `\u` — do byte/glyph work under bash.
9. `PATH=... cmd` prefix assignments break command lookup in tests (even the
   interpreter) — use absolute interpreter paths.

### glyph / font
10. The Write tool **drops PUA glyphs** (Nerd Font chars). Write an ASCII
    placeholder, then insert the bytes with perl/printf
    (e.g. `perl -pi -e 's/PLACEHOLDER/\xef\x85\xb9/'`).
11. Hack Nerd Font has **no U+F8FF** (Apple logo, Apple-fonts-only) — the
    os-icon segment uses the NF apple glyph U+F179 instead. Byobu's logo
    table uses `color BACK FORE` argument order — ubuntu = white "u" on
    colour202.

### installer / CI
12. **tmux-powerline is pinned** to fca0d61: newer upstream restructured and
    silently ignores ~/.tmux-powerlinerc + user themes/segments (bar renders
    with the default theme — easy to miss). Proven TWICE: c9e142f (2026-09,
    98-file framework rewrite) renders left/right fine but silently drops
    the close segment's `range=user|closepane` markup — install CI caught it
    AFTER the weekly PR merged it. The dep is on `DEPS_HOLD` (deps-versions.sh):
    reported as "held", never bumped, so the Monday cron cannot re-break the
    bar. Removing the hold = porting tmux-bar-sam-theme.sh + segments/ to the
    new framework first.
13. **Everything in the installers is guarded** (dir/file/capability checks);
    re-runs must be clean; failures are collected into a summary and exit 1.
    Never add an unguarded step. Local override files (`~/*.local`) are
    created once and never overwritten.
14. zoxide's official installer queries the **github API** — rate-limited on
    CI/shared IPs. Install via direct release download (see install_zoxide).
    The same trap applies to any tool whose installer "queries the latest
    release".
15. **CI yaml**: an unquoted colon inside a step name invalidates the whole
    workflow file (no runs at all — only a "Check failure" on the commit).
    `if: failure()` at STEP level is false after continue-on-error steps —
    reporting steps use `if: always()`.
16. Failure observability: install jobs upload artifacts; the report job
    downloads them and posts a digest as a **commit comment** (ubuntu runner
    — proven channel) + pushes to the `ci-logs/report` branch (readable via
    raw.githubusercontent / git fetch — **api.github.com is rate-limited
    60/h unauth; raw and git are not**).
17. npm installers that fetch many packages print EBADENGINE noise (turbo-git
    declares node 7) — warnings, not failures.

### zsh / startup perf
18. **nvm is lazy-loaded** (scripts/lazy-nvm.zsh): node/npm/npx/yarn/pnpm are
    wrapper functions until the first call; npm-global bins not in the
    wrapper list (tgit, diff-so-fancy, ...) go through
    `command_not_found_handler` (absolute-path exec → cannot recurse;
    `_lazy_nvm_load` stays defined on purpose — the handler depends on it).
    doctor.sh / smoke-test.sh source nvm.sh themselves before node checks —
    keep doing that in any new node-related check.
19. **Startup perf gate**: run `bash scripts/startup-check.sh` (before +
    after) for every new plugin/segment/tool and log the medians in the
    perf log below. doctor.sh fails above 800ms (`DOTFILES_STARTUP_MAX_MS`
    overrides). Baseline insight: nvm eager-load was ~350ms — the single
    biggest startup cost; guard against regressions, not against ms.
20. **autoenv is lazy too** (scripts/lazy-autoenv.zsh): the first `cd` (or
    first node-family command, via the `_AUTOENV_LAZY_PENDING` marker that
    lazy-nvm checks) sources activate.sh — whose source-time `cd "${PWD}"`
    self-activation IS the eager start-dir activation. The two loaders
    coordinate through that marker; keep the contract if you touch either.
    zprof caveat: autoenv_cd calls autoenv_init — nested attribution made
    the cost look like ~34ms when it was ~16ms. Also: `~/.env` (the nvm
    auto-switch helper) must stay an ABSOLUTE symlink to ~/dotfiles/env —
    a relative one dangled for 2 years silently disabling the feature.
32. **Lazy-nvm recursion contract** (scripts/lazy-nvm.zsh): every wrapper
    unsets ITSELF before dispatching, and a re-source never redefines the
    wrappers once `_NVM_LAZY_LOADED` is set. Proven macOS crash: `omz
    reload` / `source ~/.zshrc` after a first node-family command overwrote
    the REAL nvm function with a fresh wrapper → the wrapper re-dispatched
    into itself → infinite recursion (zsh has no FUNCNEST by default →
    stack death). Regression tests:
    test_lazy_nvm_reload_preserves_real_nvm +
    test_lazy_nvm_stale_wrapper_never_recurses (FUNCNEST-capped so a
    regression fails fast instead of hanging). `unset -f` on the load path
    must keep `2>/dev/null` (zsh errors on already-gone names — the guard
    path fires per unknown command via the not-found handler).
33. **The official nvm installer APPENDS its eager-load snippet to
    ~/.zshrc** — placed after the entrypoint it silently defeats lazy-nvm
    (~1.4s of nvm_auto on every start; mrsatan 2026-09-23: 1661ms → 130ms
    after deleting lines 3-5). doctor.sh flags `nvm.sh|NVM_DIR` inside
    ~/.zshrc with a fix hint; the dotfiles entrypoint itself never mentions
    nvm.sh. Same session, sibling trap: **byobu must be wired** —
    `~/.byobu/.tmux.conf` sources ~/dotfiles/byobu.tmux.conf (installer
    write_config; byobu's tmuxrc sources the user hook LAST) or byobu
    sessions launch with byobu's own bar until a manual reload. And
    **write_config never writes THROUGH a symlink**: a symlink into the
    clone counts as wired (mrsatan's manual ~/.byobu/.tmux.conf), a foreign
    symlink is replaced (bak'd first) — printf > would follow the link and
    clobber the target (nearly the repo file itself).
34. **README demo rendering (assets/demo.tape)** — the whole pipeline has
    teeth, learned render-by-render: (a) **pin vhs v0.9.0** — v0.12.0's
    in-process encoder exits 0, prints "Creating …gif" and produces NO
    file (silent; strace shows zero ffmpeg execs; v0.9.0 execs system
    ffmpeg and works). (b) **vhs spawns the shell with NO_RCS** ($- contains
    `f`): ~/.zshrc never loads, so the tape must `source ~/.zshrc` itself —
    otherwise the GIF shows vhs's violet PS1, no lazy wrappers (node
    resolves via the inherited nvm PATH = the lazy demo lies) and no fzf
    widget. (c) v0.12 dropped `Click` and `Set WindowBarColor`. (d)
    **never run bare `byobu` inside a tape** — it attaches the LIVE server
    session and leaks the user's screen into the render (caught on frame
    review); isolate with `tmux -L demo new -s demo`. (e) fzf Ctrl-R's
    Enter only ACCEPTS the entry into the command line — a second Enter
    executes it, else the next typed section concatenates onto the line.
    (f) `time` on a self-unsetting wrapper garbles its stats line (first
    call) — demo the load with plain `nvm --version` + a timed second
    call. (g) first render downloads ~150MB chromium into ~/.cache/rod;
    PUA glyphs in the tape need the perl byte-insert trick (trap 10).
21. **CI runners are not mrsatan**: GitHub-hosted runners ship system
    node/npm and can set npm prefix env — smoke checks must not assume
    npm globals land under `$NVM_DIR/versions/node/*/bin` (test mechanisms
    with synthetic fixtures, not installed-tool locations). Also
    `nvm install --lts` + `nvm alias default lts` can dangle when the
    remote alias-metadata fetch flakes (container-repro'd: empty
    `alias/lts/` dir → `default -> lts (-> N/A)` → no node on PATH, masked
    on CI by system node) — anchor default to `$(nvm current)` after the
    install activates it. Docker E2E gotchas: mount is root-owned →
    `git config --global --add safe.directory '<src>/.git'` (exact gitdir)
    before cloning; install.sh `cd "$HOME"`s — cd back before smoke.
20. **Windows Terminal profiles are wired as fragments**, not settings.json:
    `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\fragment.json`
    (WT >= 1.6 scans that dir; user settings.json is never touched; file is
    created once via `write_file_once` — re-runs skip). `command -v wt` and
    `command -v winget` work under git-bash (MSYS matches `.exe` on PATH).
    `$LOCALAPPDATA` is a Windows-style path (`C:\...`) — MSYS handles mixed
    separators, but guard it: it is NOT set outside Windows, and doctor.sh
    runs with `set -u`. doctor/smoke windows blocks must stay OS-guarded —
    the doctor fixture tests run on linux.
21. **Windows fonts are per-user installs** (no admin): copy to
    `%LOCALAPPDATA%\Microsoft\Windows\Fonts` + a value under
    `HKCU\...\CurrentVersion\Fonts` via `reg add` (git-bash calls `reg.exe`
    fine; `cygpath -w` converts the path for the registry value). The
    nerd-font script uses a single-file Regular TTF download there instead
    of the zip (unzip is not shipped by every Git for Windows). doctor's
    tmux-bar section is `!= windows`-guarded: tmux lives on the server.
22. **reg.exe flags get mangled by git-bash** ("Invalid syntax"): MSYS path
    conversion rewrites `/v /t /d /f` as POSIX paths when spawning native
    binaries — every `reg` call needs `MSYS_NO_PATHCONV=1
    MSYS2_ARG_CONV_EXCL='*'` (both, Git-for-Windows / MSYS2). Font
    idempotency must check file AND registry (a file without registration
    is a partial install — the script self-heals it). Same class of trap:
    a blanket `npm install -g` re-resolves the whole dep tree on re-runs —
    gate installs on `npm ls -g` misses.

### deps tooling (weekly check + local apply)
23. **npm resolution order**: the dotfiles install their globals through the
    nvm npm, so probes/updates must resolve `deps_npm_bin` = nvm-current
    FIRST, PATH npm second (system npm "sees" no globals → false "missing").
    CI runners have no nvm → PATH fallback covers them (trap 21 pairing).
24. **Test env hygiene**: the host's `NVM_DIR` leaks into every subprocess —
    fixture runners (dc_run/da_run/doctor stub tests) must set
    `NVM_DIR="$fixture/.nvm-absent"` or the stub npm is bypassed by the real
    nvm npm and assertions flip with whatever the host has installed.
25. **deps-apply prompts read `/dev/tty`** (background-safe, like omz), so
    `</dev/null` does NOT disable them — a suite run from an interactive
    terminal would BLOCK. Tests force the no-tty path with
    `DOTFILES_DEPS_TTY=0`; mode `auto` or `--yes` bypass prompts entirely.
26. **Machine-line discipline**: deps-check TSV rows are 6 fields
    (KIND\tname\tA\tB\tC\tstatus); empty fields must become "-" BEFORE
    printing or the human table columns shift visually (an empty field
    renders as blank, not as a placeholder). Test assertions must include
    the placeholder columns — `.*` spans are safer than exact columns.
27. **Pin display is raw**: latest upstream tags are shown/bumped as returned
    (nvm `v0.40.x` keeps the v, zoxide strips it because ZOXIDE_VERSION has
    none) — comparisons are v-tolerant (`checkIsLowerVerion`), but the bump
    script must format per-dep (see `deps-bump-pr.sh` case) or the pin URL
    breaks (nvm's install URL requires the `v` prefix).
28. **deps-apply applies drift, not "outdated"**: a pin behind upstream is a
    repo-level action (merge the weekly PR); only installed-vs-pin drift and
    floating "behind/missing" rows are applied locally. Conflating the two
    makes machines chase pins that were never merged.
29. **Pins are versions, not artifacts**: one pin serves every OS — the
    per-OS release selection happens at apply time inside the install
    function (zoxide target triples via uname, nerd-font zip vs Windows TTF).
    Never add per-OS pins unless a dep truly needs different versions per OS.
    But a version existing as a tag/release does NOT mean its artifacts
    exist for every OS — `deps_artifacts_exist` HEAD-verifies the zoxide
    target triples + nerd-font zip/TTF BEFORE `deps-bump-pr.sh` offers the
    bump (an incomplete upstream release is skipped, noted in the PR body,
    pin kept). Apply-time failures remain the last-resort guard (run()
    records the 404; the install CI matrix re-proves it per OS on push).
    Proven catch, day one: nerd-fonts v3.3+ FLATTENED
    patched-fonts/<font>/Regular/ away — the gate blocked the v3.5.1 bump
    until the windows TTF URL learned both layouts (nerd-font-download.sh
    tries Regular/ first, then flat; the gate accepts either).
30. **Tests on the weekly PR must be pin-agnostic**: the deps PR edits
    deps-versions.sh, and test.yml runs ON that PR — any assertion with a
    literal pin value (`v0.40.3`, `fca0d61`) fails against the PR's own
    output. Tests read current pins at runtime (`dep_pin` in test.sh) and
    fixtures carry a `v9.9.9` sentinel tag so "outdated" holds regardless.
31. **CI-generated commits/PRs use the repo's turbo commit convention**
    (`[ADD]`/`[MOD]`/`[FIX]`/`[DEL]` prefix) — never conventional-commit
    `chore:`/`feat:` style. `deps-bump-pr.sh` builds
    `[MOD] deps: bump N pin(s) (weekly check)` dynamically; the dry-run
    prints the message and the tests assert the `[MOD]` shape so a
    convention regression fails CI.
    Windows scope is limited on purpose: `deps-check` (DEPS_IS_WINDOWS) only
    checks the font + npm globals there — the windows installer ships
    Windows Terminal + font only (tmux is server-side, no nvm/fzf/autoenv);
    probing them would report "missing" and offer installs Windows must not
    get. The weekly PR itself is OS-agnostic (repo-level text).

### adding a new dependency (the checklist — read before touching deps)

The mental model in one line: **a pin is a version, not an artifact**.
`deps-versions.sh` says WHAT version every OS should have; the per-OS install
function in `deps-lib.sh` decides WHICH file to download for the machine it
runs on; the CI gate proves the artifacts exist for all OSes BEFORE a bump PR
is offered. Keep those three responsibilities separate.

Flow of the whole system (who calls what):

```
deps-check.yml (Mon cron, ubuntu)
  └─ deps-check.sh --machine            pins vs upstream, exit 10 = updates
      └─ deps-bump-pr.sh <report>       HEAD-verifies artifacts, sed-bumps
                                        deps-versions.sh, one recycled PR
merge PR → 13d auto-update pulls → auto-update.sh
  └─ deps-apply.sh                      deps-check --local --machine → plan →
      [y/N via /dev/tty]                applies drift/behind via deps-lib fns
                                        (OS pkgs = separate sudo confirmation)
doctor.sh / dotfiles-deps               same probes, network-free + report-only
```

To add a dependency, first classify it:

| Kind | Where it registers | What you must write |
| --- | --- | --- |
| **Pinned git repo** (sha or tag) | `deps-versions.sh`: `<NAME>_PIN`/`_VERSION` + `_REPO_URL` (with a `DOTFILES_*` env override for test fixtures) | `check_t1` block in deps-check.sh (probe via `deps_latest_git_sha`/`deps_latest_git_tag`, compare via `deps_sha_matches`/`deps_is_newer`, local drift probe, `t1_row`); `describe_line` + `apply_line` cases in deps-apply.sh; install fn in deps-lib.sh if the installer needs one |
| **GitHub release binary/font** | same as pinned git, but the version comes from `deps_latest_github_release` | everything above **plus** its artifact URLs in `deps_artifacts_exist` (per-OS targets) — this is MANDATORY, the gate refuses to bump a release it cannot verify |
| **npm global (floating)** | add the package name to `NPM_PACKAGES` in deps-versions.sh | nothing else — check_t2 and deps-apply iterate the array automatically |
| **Floating git clone** (fzf-style) | `_REPO_URL` in deps-versions.sh | entry in check_t2's pair loop + `deps_install_<name>` clone-or-pull fn |
| **OS package** (apt/brew) | NEVER pinned: add to `OS_PKGS_UBUNTU`/`OS_PKGS_PI`/`OS_PKGS_BREW` | nothing else — check_os filters `apt list --upgradable` / `brew outdated` by these lists; doctor reports, deps-apply offers the upgrade |
| **Windows-only** | usually nothing: DEPS_IS_WINDOWS limits checks to font + npm globals | a new dep only shows up on windows if the windows installer actually installs it — otherwise skip it |

Pin-format rules (trap 27): store the version EXACTLY as the install URL
needs it (nvm requires the `v` prefix in its tag URL, zoxide's pin has none)
and add a `case` arm in deps-bump-pr.sh so the bumped value keeps that
format. Comparisons are v-tolerant; URLs are not.

Status vocabulary (keep the meanings — deps-apply dispatches on them):
`ok` / `outdated` (pin behind upstream → repo action, merge the PR) /
`drift` (machine ≠ pin → apply locally) / `behind` `missing` (floating) /
`upgradable` (OS) / `unknown` (probe failed — tolerated, never fatal).
deps-apply only ever acts on drift/behind/missing; never let it chase pins
that were not merged yet (trap 28).

Testing a new dep (all offline — trap 21):
- git deps: `file://` bare-repo fixture in `dc_setup` + `DOTFILES_*_REPO_URL`
  override in `dc_run`;
- release deps: the `bump_curl_stub` (404s only `$DEPS_CURL_FAIL` — put the
  failure INSIDE a URL substring or the stub 200s everything);
- npm deps: stub npm on PATH and point `NVM_DIR` at
  `"$fixture/.nvm-absent"` or the host's real nvm npm wins (trap 24);
- assert on full 6-field machine lines (trap 26) and add the dep to
  `dc_setup` fixtures so `test_deps_check_*` keeps covering it.

Finally: update the dep's row here in the layout map, the README's
dependency lists, and — if the dep changed install behavior — rerun the full
verification workflow below.

### verification workflow (do this after any change)
- `bash test.sh` — syntax sweep + shunit2 units + installer dry-run.
- `bash scripts/smoke-test.sh` — full local wiring check.
- `bash scripts/doctor.sh` — live machine health (26+ checks).
- `bash scripts/deps-check.sh --local` — dependency drift on this machine
  (network probes are timeout-guarded; `unknown` = upstream unreachable).
- E2E in a throwaway container:
  `docker run --rm -v ~/dotfiles:/dotfiles-src:ro ubuntu:24.04 bash -c
  '...clone + bash install.sh + bash scripts/smoke-test.sh...'`
- CI: 4 badges (Tests / Install Linux / macOS / Windows) run the installer
  FOR REAL on every push. macOS failures: read the failure digest commit
  comment (posted by the report job from ubuntu). Weekly: deps-check.yml
  opens/updates a `deps/weekly-bump` PR (Mondays 06:00 UTC).

## Planned plugin phases (TODO — scouted from unixorn/awesome-zsh-plugins)

Every phase: `bash scripts/startup-check.sh` before + after; log medians in
the perf log below. Phases land one at a time.

- [ ] **Phase 2 — completions**: guarded shallow clones of
  `zsh-users/zsh-completions` + `zsh-users/zsh-autosuggestions` into
  `~/.oh-my-zsh/custom/plugins/` (installer, skip-if-exists); guarded plugins
  array in zshrc (append only when the dir exists — a failed clone must not
  break the shell). Verified in omz source: omz adds ALL `$plugins` to fpath
  BEFORE running compinit — that's why the plugins-array integration works
  for zsh-completions.
- [ ] **Phase 3 — colors**: `marlonrichert/zcolors` is NOT an omz plugin —
  generate-then-source: installer runs `zsh zcolors > ~/.zcolors.zsh`
  (3/4-bit LS_COLORS values only). Source the generated theme BEFORE
  `zsh-users/zsh-syntax-highlighting`; syntax-highlighting must be sourced
  MANUALLY last (not via the plugins array — omz sources plugins before we
  can layer the zcolors theme in between).
- [ ] **Phase 4 — carapace**: completions for ~1000 modern CLIs; single Go
  binary → pinned direct release download (trap 14 pattern, like
  install_zoxide), wired guarded in tools.zsh: `source <(carapace _carapace)`.
- [ ] **Phase 5 — zsh-bench shim**: `bin/dotfiles-bench` (thin exec shim,
  clone romkatv/zsh-bench if missing) — measures real interactive latency
  (input lag, first prompt), beyond exit-time benchmarks.

## Startup perf log (scripts/startup-check.sh — median of 5, mrsatan)

| date | change | median |
| --- | --- | --- |
| 2026-09-11 | eager nvm baseline | 516ms (min 509 / max 549) |
| 2026-09-11 | phase 1: lazy nvm | 153ms (min 143 / max 175) — −70% |
| 2026-09-11 | ZSH_DISABLE_COMPFIX=true (macOS ask) | 146ms on zsh 5.8.1 — no-op here: zsh's compinit -u still evals compaudit internally (xtrace-proved); zsh 5.9 (macOS) skips the audit on -u, big win on the Mac |
| 2026-09-11 | lazy autoenv + ~/.env symlink fix | ~145ms here (real autoenv cost was ~16ms — zprof nested attribution said 34ms); the real win: project-dir .env nvm switches deferred to first cd/node — eager autoenv would have re-pulled the nvm load into startup in project dirs |
| 2026-09-23 | eager-load regression found: the nvm installer's snippet had been appended to ~/.zshrc (~1.4s nvm_auto every start); deleted + doctor now flags it; lazy-nvm recursion fix (self-unset wrappers, omz-reload safe) | 130ms (min 119 / max 138) |

## Conventions

- **Commits follow the Turbo Commit convention (strict — test.sh lints the
  HEAD commit; merge commits exempt):** `[TAG] title <=50 chars`, a BLANK
  line, then `- ` bullets <=72 chars each (bullets may reuse tags). Tags:
  `[ADD]` `[FIX]` `[MOD]` `[DEL]` `[REF]` `[BRK]`. Without the blank line
  git folds everything into a giant subject — that is the classic mistake.
- Per-host overrides live in $HOME, never committed: ~/.gitconfig.local,
  ~/.zshrc.local, ~/.bash.local, ~/.alias.local, ~/.vimrc.local,
  ~/.tmux.local, ~/.tmux-powerline.local (extra bar segments).
- New personal commands = a thin exec shim in `bin/` (never symlinks — they
  break on Windows clones; never .sh-suffixed).
- Version minimums live in doctor.sh (node 18, nvm 0.39, tmux 3.3, git 2.28,
  bash 3.2, zsh 5.0) — bump them there, with a `fix:` hint.
- The bar: `os-icon 235 255 - - - both_disable separator_disable` renders
  self-contained (own spacing, own wedge); other segments use the framework
  separator normally.
