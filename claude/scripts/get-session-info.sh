#!/usr/bin/env bash
# 현재 Claude Code 세션 메타데이터를 JSON으로 출력한다.
#
# 출력 필드:
#   cwd               현재 작업 디렉토리
#   project_name      디렉토리명 (예: learning-finder)
#   folder_name       Claude projects 디렉토리명 (cwd의 / → -)
#   projects_dir      ~/.claude/projects/{folder_name}
#   sessions_dir      세션 로그 저장 위치 (~/.claude/projects/{folder_name}/sessions)
#   session_id        현재 세션 UUID (최근 수정된 jsonl 기준)
#   session_id_short  세션 ID 앞 8자리
#   transcript_path   현재 세션의 jsonl 파일 경로

set -euo pipefail

CWD="$(pwd)"
PROJECT_NAME="$(basename "$CWD")"
FOLDER_NAME="$(echo "$CWD" | sed 's|/|-|g')"
PROJECTS_DIR="$HOME/.claude/projects/$FOLDER_NAME"
SESSIONS_DIR="$PROJECTS_DIR/sessions"

SESSION_ID=""
TRANSCRIPT_PATH=""

if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
  SESSION_ID="$CLAUDE_SESSION_ID"
  TRANSCRIPT_PATH="$PROJECTS_DIR/$SESSION_ID.jsonl"
elif [ -d "$PROJECTS_DIR" ]; then
  LATEST_JSONL="$(ls -t "$PROJECTS_DIR"/*.jsonl 2>/dev/null | head -1 || true)"
  if [ -n "$LATEST_JSONL" ]; then
    SESSION_ID="$(basename "$LATEST_JSONL" .jsonl)"
    TRANSCRIPT_PATH="$LATEST_JSONL"
  fi
fi

SESSION_ID_SHORT="${SESSION_ID:0:8}"

cat <<EOF
{
  "cwd": "$CWD",
  "project_name": "$PROJECT_NAME",
  "folder_name": "$FOLDER_NAME",
  "projects_dir": "$PROJECTS_DIR",
  "sessions_dir": "$SESSIONS_DIR",
  "session_id": "$SESSION_ID",
  "session_id_short": "$SESSION_ID_SHORT",
  "transcript_path": "$TRANSCRIPT_PATH"
}
EOF
