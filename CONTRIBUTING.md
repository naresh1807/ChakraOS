# Contributing to Chakra OS

Chakra OS is early — most of the project is still empty scaffolding (see `docs/roadmap.md`). Before opening a PR for a new feature, check which phase it belongs to and whether that phase's prerequisites are actually done; a lot of later phases (e.g. anything under `ai-agent/`) explicitly depend on earlier ones (`core/`, security substrate) existing first.

## Reporting bugs

Open a GitHub issue with:
- What you expected vs. what happened
- Whether it's the build (`build/scripts/build_iso.sh`) or the running ISO
- For build issues: the tail of the build log
- For ISO/boot issues: how you tested (QEMU, VirtualBox, real hardware) and at what point it failed

## Working on the build script

- `build/scripts/build_iso.sh` is designed to be resumable: `build/rootfs` persists between runs (use `--clean` to force a fresh `debootstrap`), and every custom install step is wrapped in `|| { log "WARNING: ..."; return 0; }` so one failure doesn't corrupt the whole build.
- Before adding a package name to `config/packages/packages.list`, verify it actually exists in the target Debian suite (currently `bookworm`) — a single bad name aborts the whole `apt-get install`.
- Test with a full rebuild before opening a PR, not just `bash -n` syntax checking.

## Style

- Shell: match the existing style in `build_iso.sh` — one function per logical step, called explicitly from `main()`, defensive wrapping around anything network-dependent or best-effort.
- Discover things at build time rather than hardcoding versions/paths where they can legitimately vary (see how theme component names are discovered in `apply_windows11_theme()`).

## License

By contributing, you agree your contribution is licensed under the project's GPL-3.0-or-later license (see `LICENSE`).
