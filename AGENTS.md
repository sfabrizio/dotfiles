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
| `scripts/auto-update.sh` | omz-style background update (13d epoch, modes, --force) |
| `scripts/lazy-nvm.zsh` | lazy nvm loader (sourced by zshrc; first node-family command pays the load) |
| `scripts/startup-check.sh` | zsh startup benchmark + zprof — the perf gate for every new plugin/tool |
| `scripts/doctor.sh` | interactive health check (tiered ok/warn/FAIL) |
| `scripts/smoke-test.sh` | post-install verification (CI runs it after the installer) |
| `scripts/nerd-font-download.sh` | patched font installer (default: Hack) |
| `scripts/semver.sh`, `scripts/get_os_name.sh` | small libs (sourced, not executed) |
| `segments/` | tmux-powerline user segments (libraries: they define run_segment) |
| `tmux-bar-sam-theme.sh` | the bar theme + segment lists |
| `bin/` | thin exec shims on PATH (re-commit, multi-git, dotfiles-update, dotfiles-doctor) |
| `test.sh` | self-contained suite: bash -n sweep, shunit2 units, installer dry-run |
| `.github/workflows/` | test.yml + install-{linux,macos,windows}.yml → reusable ci-install.yml |

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
    with the default theme — easy to miss).
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
20. **Windows Terminal profiles are wired as fragments**, not settings.json:
    `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\fragment.json`
    (WT >= 1.6 scans that dir; user settings.json is never touched; file is
    created once via `write_file_once` — re-runs skip). `command -v wt` and
    `command -v winget` work under git-bash (MSYS matches `.exe` on PATH).
    `$LOCALAPPDATA` is a Windows-style path (`C:\...`) — MSYS handles mixed
    separators, but guard it: it is NOT set outside Windows, and doctor.sh
    runs with `set -u`. doctor/smoke windows blocks must stay OS-guarded —
    the doctor fixture tests run on linux.

### verification workflow (do this after any change)
- `bash test.sh` — syntax sweep + shunit2 units + installer dry-run.
- `bash scripts/smoke-test.sh` — full local wiring check.
- `bash scripts/doctor.sh` — live machine health (26+ checks).
- E2E in a throwaway container:
  `docker run --rm -v ~/dotfiles:/dotfiles-src:ro ubuntu:24.04 bash -c
  '...clone + bash install.sh + bash scripts/smoke-test.sh...'`
- CI: 4 badges (Tests / Install Linux / macOS / Windows) run the installer
  FOR REAL on every push. macOS failures: read the failure digest commit
  comment (posted by the report job from ubuntu).

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

## Conventions

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
