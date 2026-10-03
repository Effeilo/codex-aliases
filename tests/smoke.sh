#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

profile="$scratch/profile with spaces"
printf '# existing configuration\n' > "$profile"
bash "$root/install.sh" "$profile"
cp "$profile" "$scratch/expected"
bash "$root/install.sh" "$profile"
cmp "$profile" "$scratch/expected"
grep -qx '# existing configuration' "$profile"
sed -n '/^# >>> codex-aliases >>>$/,/^# <<< codex-aliases <<<$/{ /codex-aliases >>>/d; /codex-aliases <<</d; p; }' "$profile" > "$scratch/installed"
cp "$root/raccourcis.sh" "$scratch/source"
cmp "$scratch/installed" "$scratch/source"

# Exercise the same stdin execution used by curl ... | bash, outside the repo.
(
  cd "$scratch"
  curl -fsSL "file://$root/install.sh" | bash -s -- "$scratch/piped profile"
)
sed -n '/^# >>> codex-aliases >>>$/,/^# <<< codex-aliases <<<$/{ /codex-aliases >>>/d; /codex-aliases <<</d; p; }' "$scratch/piped profile" > "$scratch/piped aliases"
cmp "$scratch/piped aliases" "$scratch/source"

printf "alias cxs='something-else'\n" > "$scratch/conflict"
if bash "$root/install.sh" "$scratch/conflict"; then
  printf 'FAIL: conflicting alias accepted\n' >&2
  exit 1
fi

SHELL=/bin/zsh ZDOTDIR="$scratch/zsh config" bash "$root/install.sh"
test -f "$scratch/zsh config/.zshrc"
if SHELL=/bin/fish bash "$root/install.sh"; then
  printf 'FAIL: unsupported shell accepted\n' >&2
  exit 1
fi

for shell in bash zsh; do
  command -v "$shell" >/dev/null || continue
  "$shell" -f -c '
    if [ -n "${BASH_VERSION:-}" ]; then shopt -s expand_aliases; fi
    codex() { printf "<%s>\n" "$@"; }
    source "$1"
    eval '\''cxa "a prompt with spaces"'\''
    eval '\''cxs resume --last'\''
    eval '\''cxl exec "hello world"'\''
    export CODEX_MODEL_SOL=custom-model
    eval '\''cxs "custom prompt"'\''
  ' test "$profile" > "$scratch/actual"
  cat > "$scratch/wanted" <<'EXPECTED'
<--model>
<gpt-6-astra>
<a prompt with spaces>
<--model>
<gpt-6.1-sol>
<resume>
<--last>
<--model>
<gpt-6-luna>
<exec>
<hello world>
<--model>
<custom-model>
<custom prompt>
EXPECTED
  diff -u "$scratch/wanted" "$scratch/actual"
  printf 'OK: %s argument forwarding and model overrides\n' "$shell"
done
printf 'OK: installation, idempotence, profile preservation and conflicts\n'

# Upgrade a legacy block without moving surrounding settings.
cat > "$scratch/legacy" <<'LEGACY'
# before
# >>> codex-aliases >>>
alias cxa='old-command'
# <<< codex-aliases <<<
# after
LEGACY
bash "$root/install.sh" "$scratch/legacy"
test "$(head -n 1 "$scratch/legacy")" = '# before'
test "$(tail -n 1 "$scratch/legacy")" = '# after'
if grep -q old-command "$scratch/legacy"; then exit 1; fi
printf '# >>> codex-aliases >>>\nkeep me\n' > "$scratch/broken"
cp "$scratch/broken" "$scratch/broken-original"
if bash "$root/install.sh" "$scratch/broken"; then exit 1; fi
cmp "$scratch/broken" "$scratch/broken-original"

for shell in bash zsh; do
  command -v "$shell" >/dev/null || continue
  "$shell" -f -s -- "$root/raccourcis.sh" <<'CHECK'
set -eu
if [ -n "${BASH_VERSION:-}" ]; then shopt -s expand_aliases; fi
alias cxa='old-command'
source "$1"
source "$1"
codex() { printf '<%s>\n' "$@"; }
for level in low medium high xhigh; do
  actual=$(cxa "--$level" 'a prompt with spaces')
  expected=$(printf '<%s>\n' --model gpt-6-astra -c "model_reasoning_effort=\"$level\"" 'a prompt with spaces')
  test "$actual" = "$expected"
done
test "$(cxs --high resume --last)" = "$(printf '<%s>\n' --model gpt-6.1-sol -c 'model_reasoning_effort="high"' resume --last)"
test "$(cxl --low exec 'hello world')" = "$(printf '<%s>\n' --model gpt-6-luna -c 'model_reasoning_effort="low"' exec 'hello world')"
test "$(cxa -- --high)" = "$(printf '<%s>\n' --model gpt-6-astra -- --high)"
if cxa --high --low; then exit 1; fi
codex() { return 42; }
if cxa --high; then exit 1; else test "$?" -eq 42; fi
CHECK
  printf 'OK: %s reasoning flags, legacy reload, literal arguments and exit status\n' "$shell"
done
