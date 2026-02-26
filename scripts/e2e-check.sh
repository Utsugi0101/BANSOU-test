#!/usr/bin/env bash
set -euo pipefail

# Half-auto E2E checker for BANSOU-test
# Usage:
#   BANSOU_GATE_API_TOKEN=... scripts/e2e-check.sh
# Optional:
#   BANSOU_GATE_URL=https://... (default: from workflow/issuer)
#   BANSOU_SUB=Utsugi0101 (default: git config github.user || git config user.name)
#   BANSOU_REQUIRED_QUIZ_ID=core-pr

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is required" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is required" >&2
  exit 1
fi

WORKFLOW_FILE=".github/workflows/bansou-verify.yml"
if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "[ERROR] Missing workflow file: $WORKFLOW_FILE" >&2
  exit 1
fi

HEAD_SHA="$(git rev-parse HEAD)"
BRANCH="$(git branch --show-current)"
REPO_URL="$(git config --get remote.origin.url || true)"
REPO_SLUG=""
if [[ "$REPO_URL" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
  REPO_SLUG="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi
if [[ -z "$REPO_SLUG" ]]; then
  REPO_SLUG="${BANSOU_REPO:-}" 
fi
if [[ -z "$REPO_SLUG" ]]; then
  echo "[ERROR] Could not determine repo slug from remote.origin.url" >&2
  exit 1
fi

SUB_DEFAULT="$(git config --get github.user || git config --get user.name || true)"
BANSOU_SUB="${BANSOU_SUB:-$SUB_DEFAULT}"
BANSOU_REQUIRED_QUIZ_ID="${BANSOU_REQUIRED_QUIZ_ID:-core-pr}"

# Pull changed files in PR-like range: merge-base(origin/main, HEAD)..HEAD
BASE_REF="origin/main"
if git show-ref --verify --quiet refs/remotes/origin/HEAD; then
  BASE_REF="$(git symbolic-ref --short refs/remotes/origin/HEAD)"
fi
MERGE_BASE="$(git merge-base HEAD "$BASE_REF" 2>/dev/null || true)"
if [[ -z "$MERGE_BASE" ]]; then
  MERGE_BASE="$(git rev-parse HEAD~1 2>/dev/null || true)"
fi
if [[ -z "$MERGE_BASE" ]]; then
  echo "[ERROR] Could not determine merge base" >&2
  exit 1
fi

CHANGED_FILES=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  CHANGED_FILES+=("$line")
done < <(git diff --name-only "$MERGE_BASE..HEAD")

# Apply same essential-file rule as gate side (approx)
ESSENTIAL_FILES=()
for f in "${CHANGED_FILES[@]:-}"; do
  nf="${f#./}"
  if [[ "$nf" == .bansou/* ]]; then
    continue
  fi
  if [[ "$nf" == .github/* ]]; then
    continue
  fi
  if [[ "$nf" == scripts/* ]]; then
    continue
  fi
  if [[ "$nf" =~ \.(md|markdown|json|yml|yaml|toml|ini|cfg|lock)$ ]]; then
    continue
  fi
  ESSENTIAL_FILES+=("$nf")
done

# Resolve gate URL (env first, fallback to known value)
BANSOU_GATE_URL="${BANSOU_GATE_URL:-https://bansou-server.soraki0101.workers.dev}"
BANSOU_GATE_API_TOKEN="${BANSOU_GATE_API_TOKEN:-}"

echo "== BANSOU E2E Check =="
echo "repo:          $REPO_SLUG"
echo "branch:        $BRANCH"
echo "head:          $HEAD_SHA"
echo "base_ref:      $BASE_REF"
echo "merge_base:    $MERGE_BASE"
echo "sub:           ${BANSOU_SUB:-<empty>}"
echo "quiz_id:       $BANSOU_REQUIRED_QUIZ_ID"
echo "gate_url:      $BANSOU_GATE_URL"
echo "changed_files: ${#CHANGED_FILES[@]}"
echo "essential:     ${#ESSENTIAL_FILES[@]}"

if [[ ! -s "$WORKFLOW_FILE" ]]; then
  echo "[ERROR] Workflow file empty" >&2
  exit 1
fi

if ! grep -q "gate_url:" "$WORKFLOW_FILE"; then
  echo "[WARN] Workflow does not appear to use server ledger mode (gate_url missing)."
fi

if [[ -z "$BANSOU_SUB" ]]; then
  echo "[WARN] BANSOU_SUB is empty. Set BANSOU_SUB=your_github_login for accurate check."
fi

if [[ -z "$BANSOU_GATE_API_TOKEN" ]]; then
  echo "[ACTION] Set gate token and rerun:"
  echo "  BANSOU_GATE_API_TOKEN=<token> scripts/e2e-check.sh"
  exit 2
fi

# Common shell mistake:
#   ... BANSOU_GATE_API_TOKEN='xxx'BANSOU_SUB='yyy' npm run ...
# (missing space before next env var)
if [[ "$BANSOU_GATE_API_TOKEN" == *"BANSOU_SUB="* ]] || [[ "$BANSOU_GATE_API_TOKEN" == *" "* ]]; then
  echo "[ERROR] BANSOU_GATE_API_TOKEN looks malformed (possibly missing a space between env vars)." >&2
  echo "[ACTION] Run with spaces between env vars, e.g.:" >&2
  echo "  BANSOU_GATE_API_TOKEN=<token> BANSOU_SUB=<login> npm run e2e:check" >&2
  exit 2
fi

health_file="/tmp/bansou_gate_health_$$.json"
health_code="$(curl -sS -o "$health_file" -w "%{http_code}" "$BANSOU_GATE_URL/gate/health" || true)"
if [[ "$health_code" == "200" ]]; then
  if grep -q '"ok":false' "$health_file"; then
    echo "[WARN] /gate/health reports not-ready:"
    cat "$health_file"
    echo
  fi
else
  echo "[WARN] /gate/health unavailable (status=$health_code). Deployment may be old."
fi

if [[ ${#ESSENTIAL_FILES[@]} -eq 0 ]]; then
  echo "[OK] No essential files changed. Gate should pass without quiz proofs."
  exit 0
fi

# Build JSON array safely
json_files="["
for i in "${!ESSENTIAL_FILES[@]}"; do
  f="${ESSENTIAL_FILES[$i]}"
  esc_f="${f//\\/\\\\}"
  esc_f="${esc_f//\"/\\\"}"
  if [[ $i -gt 0 ]]; then json_files+=","; fi
  json_files+="\"$esc_f\""
done
json_files+="]"

payload="{\"repo\":\"$REPO_SLUG\",\"commit\":\"$HEAD_SHA\",\"sub\":\"$BANSOU_SUB\",\"required_quiz_id\":\"$BANSOU_REQUIRED_QUIZ_ID\",\"changed_files\":$json_files}"

response_file="/tmp/bansou_gate_eval_$$.json"
status_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X POST "$BANSOU_GATE_URL/gate/evaluate" \
  -H "Authorization: Bearer $BANSOU_GATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload")"

echo "http_status:    $status_code"
echo "response:"
cat "$response_file"
echo

if [[ "$status_code" != "200" ]]; then
  echo "[FAIL] gate/evaluate returned non-200."
  echo "[ACTION] Check BANSOU_GATE_URL, token, and server deployment."
  exit 3
fi

if grep -q '"ok":true' "$response_file"; then
  echo "[OK] Server ledger gate is satisfied for current HEAD."
  exit 0
fi

echo "[FAIL] Missing proofs remain for current HEAD."
echo "[ACTION] In VSCode (BANSOU-test):"
echo "  1) get diff files"
echo "  2) generate quiz"
echo "  3) submit answers (pass)"
echo "  4) rerun this script"
exit 4
