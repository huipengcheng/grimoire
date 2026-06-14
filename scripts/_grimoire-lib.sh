# Shared helpers for grimoire-install / grimoire-doctor. Sourced, not executable.
# Defines: ROOT, LOCAL_DIR, REGISTRY_FILE, LOCAL_CONFIG,
# STOW_ARTIFACT_DIR, KINDS, C_* (ANSI colors), TARGET_NAMES, and the helpers below.

_GRIMOIRE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$_GRIMOIRE_LIB_DIR/.." && pwd)"
LOCAL_DIR="$ROOT/local"
REGISTRY_FILE="$ROOT/registry.toml"
LOCAL_CONFIG="$LOCAL_DIR/config.toml"
STOW_ARTIFACT_DIR="$ROOT/.grimoire-stow"

KINDS=(skills agents commands)

if [[ -t 1 ]]; then
  C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
  C_RED=$'\e[31m'; C_CYAN=$'\e[36m'; C_RESET=$'\e[0m'
else
  C_BOLD=""; C_DIM=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_RESET=""
fi

die() { printf '%s\n' "$*" >&2; exit 1; }

expand_path() {
  local p=$1
  case "$p" in
    "~"|"~/"*) p="$HOME${p#"~"}" ;;
  esac
  printf '%s' "$p"
}

target_path() {
  local root=$1 rel=$2
  case "$rel" in
    "~"|"~/"*|/*) expand_path "$rel" ;;
    *) printf '%s/%s' "$root" "$rel" ;;
  esac
}

normalize_path() {
  local path=$1 old_ifs part out=""
  local -a parts=() normalized=()
  old_ifs=$IFS
  IFS='/'
  read -r -a parts <<< "$path"
  IFS=$old_ifs
  for part in "${parts[@]+"${parts[@]}"}"; do
    case "$part" in
      ""|".") continue ;;
      "..")
        if [[ ${#normalized[@]} -gt 0 ]]; then
          unset "normalized[$((${#normalized[@]} - 1))]"
        fi
        ;;
      *) normalized+=("$part") ;;
    esac
  done
  for part in "${normalized[@]+"${normalized[@]}"}"; do
    out+="/$part"
  done
  [[ -z "$out" ]] && out="/"
  printf '%s' "$out"
}

link_target_path() {
  local link=$1 target base
  target=$(readlink "$link" 2>/dev/null || true)
  [[ -z "$target" ]] && return 0
  case "$target" in
    /*) normalize_path "$target" ;;
    *)
      base=$(cd -- "$(dirname -- "$link")" && pwd) || return 0
      normalize_path "$base/$target"
      ;;
  esac
}

_var_safe() { printf '%s' "${1//[^A-Za-z0-9_]/_}"; }

# ── TOML loader ────────────────────────────────────────────────────────────
# Minimal parser; supports the shape used by registry.toml and config.toml:
#   - `[section]` headers
#   - `key = "value"` string assignments
#   - `key = [ "s1", "s2", ... ]` string arrays (inline or multi-line)

declare -a TARGET_NAMES=()

load_targets_toml() {
  local file=$1 line key val cur="" safe
  TARGET_NAMES=()
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*$ ]]; then
      cur="${BASH_REMATCH[1]}"
      TARGET_NAMES+=("$cur")
      continue
    fi
    [[ -z "$cur" ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      safe=$(_var_safe "$cur")
      printf -v "TARGET_${safe}_${key}" '%s' "$val"
    fi
  done < "$file"
}

target_field() {
  local var="TARGET_$(_var_safe "$1")_$2"
  printf '%s' "${!var-}"
}

target_exists() {
  local n=$1 t
  for t in "${TARGET_NAMES[@]+"${TARGET_NAMES[@]}"}"; do
    [[ "$t" == "$n" ]] && return 0
  done
  return 1
}

array_index() {
  local needle=$1 item i=0
  shift
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      printf '%s' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

load_string_array() {
  local file=$1 key=$2
  [[ -f "$file" ]] || return 0
  awk -v k="$key" '
    function strip_comment(s,   i, in_str, c) {
      in_str = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\"") in_str = !in_str
        else if (c == "#" && !in_str) return substr(s, 1, i - 1)
      }
      return s
    }
    BEGIN { in_arr = 0 }
    {
      line = $0
      if (!in_arr) {
        re = "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*\\["
        if (match(line, re)) {
          in_arr = 1
          line = substr(line, RSTART + RLENGTH)
        } else next
      }
      done = 0
      if (index(line, "]") > 0) {
        sub("\\].*", "", line)
        in_arr = 0
        done = 1
      }
      line = strip_comment(line)
      while (match(line, /"[^"]*"/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
      }
      if (done) exit
    }
  ' "$file"
}

# ── Disabled list ────────────────────────────────────────────────────────────
# Items are turned off by fully-qualified name "<origin>/<kind>/<name>", where
# <origin> is the install origin label: self | local. Read from
# local/config.toml's `disabled` array.

declare -a DISABLED=()

load_disabled() {
  local d
  DISABLED=()
  [[ -f "$LOCAL_CONFIG" ]] || return 0
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    DISABLED+=("$d")
  done < <(load_string_array "$LOCAL_CONFIG" disabled)
}

is_disabled() {
  local fqn=$1 d
  for d in "${DISABLED[@]+"${DISABLED[@]}"}"; do
    [[ "$d" == "$fqn" ]] && return 0
  done
  return 1
}

# ── Discovery ──────────────────────────────────────────────────────────────
# Print "name<TAB>path" lines for items of $kind under $root. Skill source
# directories may be nested for repo organization, but installed skill names are
# the leaf directory name because supported assistants expect skills/<name>/.
discover() {
  local kind=$1 root=$2 f dir p rel
  [[ -d "$root" ]] || return 0
  if [[ "$kind" == "skills" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      dir=$(dirname "$f")
      rel=$(basename "$dir")
      [[ -z "$rel" || "$dir" == "$root" ]] && continue  # SKILL.md at root: ignore
      printf '%s\t%s\n' "$rel" "$dir"
    done < <(find "$root" -type f -name SKILL.md 2>/dev/null | LC_ALL=C sort)
    return 0
  fi
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    printf '%s\t%s\n' "$(basename "$p")" "$p"
  done < <(find "$root" -mindepth 1 -maxdepth 1 \
           ! -name '.*' ! -name '.gitkeep' 2>/dev/null | LC_ALL=C sort)
}

# ── Resolution ───────────────────────────────────────────────────────────────
# The item sources for a kind form one precedence stack. Defining it once here is
# the single source of truth for "local wins over self". Stack order, least
# specific first:
#   self    <repo>/<kind>
#   local   local/<kind>

# item_layers <kind> — print "origin<TAB>dir", least specific first.
item_layers() {
  local kind=$1
  printf 'self\t%s\n'  "$ROOT/$kind"
  printf 'local\t%s\n' "$LOCAL_DIR/$kind"
}

# resolve_items <kind> [notify] — print effective items as
# "name<TAB>path<TAB>origin", sorted by name. Later layers override earlier ones
# by name; an item whose "<origin>/<kind>/<name>" is in DISABLED is dropped at
# its layer. Dies on a duplicate name within one layer (an ambiguous install).
# notify=1 reports skips and overrides on stderr (used once for the plan preview).
resolve_items() {
  local kind=$1 notify=${2-0}
  local -a names=() paths=() origins=()
  local origin dir name path fqn idx i
  while IFS=$'\t' read -r origin dir; do
    [[ -z "$origin" ]] && continue
    while IFS=$'\t' read -r name path; do
      [[ -z "$name" ]] && continue
      fqn="$origin/$kind/$name"
      if is_disabled "$fqn"; then
        [[ "$notify" == 1 ]] &&
          printf '  %sskip (disabled): %s%s\n' "$C_DIM" "$fqn" "$C_RESET" >&2
        continue
      fi
      if idx=$(array_index "$name" "${names[@]+"${names[@]}"}"); then
        [[ "${origins[$idx]}" == "$origin" ]] &&
          die "duplicate $origin item name: $kind/$name"
        [[ "$notify" == 1 ]] &&
          printf '  %s!%s %s/%s: %s overridden by %s\n' \
            "$C_YELLOW" "$C_RESET" "$kind" "$name" "${origins[$idx]}" "$origin" >&2
        paths[$idx]=$path
        origins[$idx]=$origin
      else
        names+=("$name")
        paths+=("$path")
        origins+=("$origin")
      fi
    done < <(discover "$kind" "$dir")
  done < <(item_layers "$kind")
  for ((i = 0; i < ${#names[@]}; i++)); do
    printf '%s\t%s\t%s\n' "${names[$i]}" "${paths[$i]}" "${origins[$i]}"
  done | LC_ALL=C sort -t $'\t' -k1,1
}
