#!/usr/bin/env bash
set -euo pipefail

# Keep this installer self-contained so it also works when piped into Bash.
if [[ $# -gt 1 || ${1:-} == --help || ${1:-} == -h ]]; then
  printf 'Usage: bash install.sh [shell-profile]\n'
  exit 0
fi

if [[ $# -eq 1 ]]; then
  shell_rc=$1
else
  case "${SHELL##*/}" in
    zsh) shell_rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      if [[ -f "$HOME/.bash_profile" ]]; then
        shell_rc="$HOME/.bash_profile"
      else
        shell_rc="$HOME/.bashrc"
      fi
      ;;
    *)
      printf 'Shell non pris en charge. Indiquez un profil Bash ou Zsh : bash install.sh chemin/du/profil\n' >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$(dirname "$shell_rc")"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
original="$work/original"
if [[ -f "$shell_rc" ]]; then
  cp -p "$shell_rc" "$original"
else
  : > "$original"
fi

# Replace only a complete managed block, preserving all surrounding content.
# Reject malformed/duplicate markers before modifying the user's profile.
awk '
  $0 == "# >>> codex-aliases >>>" {
    if (inside || seen++) exit 1
    inside = 1
    next
  }
  $0 == "# <<< codex-aliases <<<" {
    if (!inside) exit 1
    inside = 0
    next
  }
  !inside { print }
  END { if (inside) exit 1 }
' "$original" > "$work/outside" || {
  printf 'Invalid codex-aliases markers in %s; profile left unchanged.\n' "$shell_rc" >&2
  exit 1
}

if grep -Eq '(^|[;[:space:]])(alias[[:space:]]+)?(cxa|cxs|cxl)[[:space:]]*(=|\(\))|function[[:space:]]+(cxa|cxs|cxl)([[:space:]]|$)' "$work/outside"; then
  printf 'A shortcut already exists outside the managed block in %s.\n' "$shell_rc" >&2
  exit 1
fi

cat > "$work/block" <<'ALIASES'
# >>> codex-aliases >>>
# Codex shortcuts — Bash / Zsh
# Remove legacy aliases before defining functions (also when reloading a profile).
unalias cxa cxs cxl 2>/dev/null || :

_codex_aliases_run() {
  local model="$1"
  shift
  case "${1:-}" in
    --low|--medium|--high|--xhigh)
      local effort="${1#--}"
      shift
      case "${1:-}" in
        --low|--medium|--high|--xhigh)
          printf 'Choose only one reasoning level.\n' >&2
          return 2
          ;;
      esac
      codex --model "$model" -c "model_reasoning_effort=\"$effort\"" "$@"
      ;;
    *) codex --model "$model" "$@" ;;
  esac
}

cxa() { _codex_aliases_run "${CODEX_MODEL_ASTRA:-gpt-6-astra}" "$@"; }
cxs() { _codex_aliases_run "${CODEX_MODEL_SOL:-gpt-6.1-sol}" "$@"; }
cxl() { _codex_aliases_run "${CODEX_MODEL_LUNA:-gpt-6-luna}" "$@"; }
# <<< codex-aliases <<<
ALIASES

awk -v block="$work/block" '
  function emit( line) {
    while ((getline line < block) > 0) print line
    close(block)
  }
  $0 == "# >>> codex-aliases >>>" { emit(); inside = 1; seen = 1; next }
  $0 == "# <<< codex-aliases <<<" { inside = 0; next }
  !inside { print }
  END { if (!seen) { print ""; emit() } }
' "$original" > "$work/result"

if cmp -s "$original" "$work/result"; then
  printf 'Shortcuts already up to date in %s.\n' "$shell_rc"
  exit 0
fi
if [[ -f "$shell_rc" ]]; then
  backup=$(mktemp "${shell_rc}.codex-aliases-backup.XXXXXX")
  cp -p "$shell_rc" "$backup"
  printf 'Backup: %s\n' "$backup"
fi
cat "$work/result" > "$shell_rc"

printf 'Alias installés dans %s.\nOuvrez un nouveau terminal ou exécutez :\n  source %q\n' "$shell_rc" "$shell_rc"
printf 'cxa → Astra | cxs → Sol | cxl → Luna\n'
