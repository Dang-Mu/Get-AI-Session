#!/usr/bin/env bash
# 현재 Codex 세션 메타데이터를 JSON으로 출력한다.
#
# 출력 필드:
#   cwd               현재 작업 디렉토리
#   project_name      디렉토리명 (예: learning-finder)
#   folder_name       Codex projects 디렉토리명 (cwd의 / -> -)
#   codex_home        Codex 홈 디렉토리 (~/.codex 기본값)
#   projects_dir      ~/.codex/projects/{folder_name}
#   downloads_dir     탐지된 다운로드 폴더 (표준 위치 -> 검색 순)
#   sessions_dir      세션 로그 저장 위치 ({downloads_dir}/codex-sessions)
#   session_id        현재 세션 UUID 또는 rollout ID (추정)
#   session_id_short  세션 ID 앞 8자리
#   transcript_path   현재 세션의 jsonl 파일 경로 (추정)

set -euo pipefail

CWD="$(pwd)"
PROJECT_NAME="$(basename "$CWD")"
FOLDER_NAME="$(echo "$CWD" | sed 's|/|-|g')"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PROJECTS_DIR="$CODEX_HOME/projects/$FOLDER_NAME"
CODEX_SESSIONS_DIR="$CODEX_HOME/sessions"

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
#   3) %USERPROFILE% 기반 (Git Bash) - OneDrive 경로 포함
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
SESSIONS_DIR="$DOWNLOADS_DIR/codex-sessions"

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
  "downloads_dir": "$(json_escape "$DOWNLOADS_DIR")",
  "sessions_dir": "$(json_escape "$SESSIONS_DIR")",
  "session_id": "$(json_escape "$SESSION_ID")",
  "session_id_short": "$(json_escape "$SESSION_ID_SHORT")",
  "transcript_path": "$(json_escape "$TRANSCRIPT_PATH")"
}
EOF
