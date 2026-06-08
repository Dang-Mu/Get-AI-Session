#!/usr/bin/env bash
# 현재 Claude Code 세션 메타데이터를 JSON으로 출력한다.
#
# 출력 필드:
#   cwd               현재 작업 디렉토리
#   project_name      디렉토리명 (예: learning-finder)
#   folder_name       Claude projects 디렉토리명 (cwd의 / → -)
#   projects_dir      ~/.claude/projects/{folder_name}
#   downloads_dir     탐지된 다운로드 폴더 (표준 위치 → 검색 순)
#   sessions_dir      세션 로그 저장 위치 ({downloads_dir}/claude-sessions)
#   session_id        현재 세션 UUID (최근 수정된 jsonl 기준)
#   session_id_short  세션 ID 앞 8자리
#   transcript_path   현재 세션의 jsonl 파일 경로

set -euo pipefail

CWD="$(pwd)"
PROJECT_NAME="$(basename "$CWD")"
FOLDER_NAME="$(echo "$CWD" | sed 's|/|-|g')"
PROJECTS_DIR="$HOME/.claude/projects/$FOLDER_NAME"

# 윈도우 경로(C:\Users\foo)를 POSIX 경로(/c/Users/foo)로 변환한다.
# Git Bash의 cygpath를 우선 쓰고, 없으면 sed로 대체한다.
win_to_posix() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || true
  else
    printf '%s' "$p" | sed -e 's|\\|/|g' -e 's|^\([A-Za-z]\):|/\L\1|'
  fi
}

# 다운로드 폴더를 탐지한다. 시도 순서:
#   1) 표준 위치 (macOS / Linux / Git Bash 기본 HOME)
#   2) 윈도우 레지스트리 (위치 변경 / OneDrive 리디렉션까지 정확)
#   3) %USERPROFILE% 기반 (Git Bash) — OneDrive 경로 포함
#   4) xdg (Linux 데스크톱)
#   5) 홈 하위 검색
#   6) 모두 실패하면 ~/Downloads 로 폴백
detect_downloads_dir() {
  local d x found

  # 1) 표준 위치
  for d in "$HOME/Downloads" "$HOME/다운로드"; do
    [ -d "$d" ] && { printf '%s' "$d"; return; }
  done

  # 2) 윈도우 레지스트리 (Downloads known folder GUID)
  local reg_bin raw winpath posix pat
  reg_bin="$(command -v reg.exe 2>/dev/null || command -v reg 2>/dev/null || true)"
  if [ -n "$reg_bin" ]; then
    raw="$("$reg_bin" query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' //v '{374DE290-123F-4565-9164-39C4925E467B}' 2>/dev/null | tr -d '\r' || true)"
    winpath="$(printf '%s\n' "$raw" | sed -n 's/.*REG_[A-Z_]*[[:space:]][[:space:]]*//p' | tail -1)"
    if [ -n "$winpath" ]; then
      pat='%USERPROFILE%'
      winpath="${winpath/$pat/${USERPROFILE:-}}"
      posix="$(win_to_posix "$winpath")"
      [ -n "$posix" ] && [ -d "$posix" ] && { printf '%s' "$posix"; return; }
    fi
  fi

  # 3) %USERPROFILE% 기반 (OneDrive 리디렉션 포함)
  if [ -n "${USERPROFILE:-}" ]; then
    local up
    up="$(win_to_posix "$USERPROFILE")"
    if [ -n "$up" ]; then
      for d in "$up/Downloads" "$up/OneDrive/Downloads" "$up/다운로드"; do
        [ -d "$d" ] && { printf '%s' "$d"; return; }
      done
    fi
  fi

  # 4) xdg
  if command -v xdg-user-dir >/dev/null 2>&1; then
    x="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
    [ -n "$x" ] && [ -d "$x" ] && { printf '%s' "$x"; return; }
  fi

  # 5) 홈 하위 검색
  found="$(find "$HOME" -maxdepth 3 -type d \( -iname 'downloads' -o -iname '다운로드' \) -print 2>/dev/null | head -1 || true)"
  [ -n "$found" ] && { printf '%s' "$found"; return; }

  # 6) 폴백
  printf '%s' "$HOME/Downloads"
}

DOWNLOADS_DIR="$(detect_downloads_dir)"
SESSIONS_DIR="$DOWNLOADS_DIR/claude-sessions"

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
  "downloads_dir": "$DOWNLOADS_DIR",
  "sessions_dir": "$SESSIONS_DIR",
  "session_id": "$SESSION_ID",
  "session_id_short": "$SESSION_ID_SHORT",
  "transcript_path": "$TRANSCRIPT_PATH"
}
EOF
