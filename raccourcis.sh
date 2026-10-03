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
