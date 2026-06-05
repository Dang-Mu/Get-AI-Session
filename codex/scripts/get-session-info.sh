#!/usr/bin/env bash
# 현재 Codex 세션 메타데이터를 JSON으로 출력한다.
#
# 출력 필드:
#   cwd               현재 작업 디렉토리
#   project_name      디렉토리명 (예: learning-finder)
#   folder_name       Codex projects 디렉토리명 (cwd의 / -> -)
#   codex_home        Codex 홈 디렉토리 (~/.codex 기본값)
#   projects_dir      ~/.codex/projects/{folder_name}
#   sessions_dir      세션 로그 저장 위치 (~/.codex/projects/{folder_name}/sessions)
#   session_id        현재 세션 UUID 또는 rollout ID (추정)
#   session_id_short  세션 ID 앞 8자리
#   transcript_path   현재 세션의 jsonl 파일 경로 (추정)

set -euo pipefail

CWD="$(pwd)"
PROJECT_NAME="$(basename "$CWD")"
FOLDER_NAME="$(echo "$CWD" | sed 's|/|-|g')"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PROJECTS_DIR="$CODEX_HOME/projects/$FOLDER_NAME"
SESSIONS_DIR="$PROJECTS_DIR/sessions"
CODEX_SESSIONS_DIR="$CODEX_HOME/sessions"

SESSION_ID="${CODEX_SESSION_ID:-}"
TRANSCRIPT_PATH=""

if [ -n "$SESSION_ID" ] && [ -d "$CODEX_SESSIONS_DIR" ]; then
  TRANSCRIPT_PATH="$(find "$CODEX_SESSIONS_DIR" -type f -name "*$SESSION_ID.jsonl" -print 2>/dev/null | head -1 || true)"
fi

if [ -z "$TRANSCRIPT_PATH" ] && [ -d "$CODEX_SESSIONS_DIR" ]; then
  TRANSCRIPT_PATH="$(find "$CODEX_SESSIONS_DIR" -type f -name "*.jsonl" -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1 || true)"
fi

if [ -z "$SESSION_ID" ] && [ -n "$TRANSCRIPT_PATH" ]; then
  BASE_NAME="$(basename "$TRANSCRIPT_PATH" .jsonl)"
  SESSION_ID="$(printf '%s' "$BASE_NAME" | sed -E 's/^rollout-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-//')"
fi

SESSION_ID_SHORT="${SESSION_ID:0:8}"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cat <<EOF
{
  "cwd": "$(json_escape "$CWD")",
  "project_name": "$(json_escape "$PROJECT_NAME")",
  "folder_name": "$(json_escape "$FOLDER_NAME")",
  "codex_home": "$(json_escape "$CODEX_HOME")",
  "projects_dir": "$(json_escape "$PROJECTS_DIR")",
  "sessions_dir": "$(json_escape "$SESSIONS_DIR")",
  "session_id": "$(json_escape "$SESSION_ID")",
  "session_id_short": "$(json_escape "$SESSION_ID_SHORT")",
  "transcript_path": "$(json_escape "$TRANSCRIPT_PATH")"
}
EOF
