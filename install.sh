#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

confirm_overwrite() {
  read -r -p "  덮어쓸까요? [y/N] " ans </dev/tty
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

copy_with_prompt() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ]; then
    echo "기존 파일 존재: $dst"
    if confirm_overwrite; then
      cp -f "$src" "$dst"
      echo "  ✓ 덮어씀: $dst"
    else
      echo "  - 건너뜀: $dst"
    fi
  else
    cp "$src" "$dst"
    echo "  ✓ 설치: $dst"
  fi
}

select_target() {
  if [ "${1:-}" != "" ]; then
    printf '%s\n' "$1"
    return
  fi

  echo "설치할 log-session 스킬 버전을 선택하세요." >/dev/tty
  echo "  1) claude  -> ~/.claude/skills/log-session" >/dev/tty
  echo "  2) codex   -> ~/.codex/skills/log-session" >/dev/tty
  echo "  3) all     -> 둘 다 설치" >/dev/tty
  echo "" >/dev/tty
  read -r -p "번호로 입력하세요 [1/2/3, 기본: 2(codex)] " choice </dev/tty
  case "${choice:-2}" in
    1) printf '%s\n' "claude" ;;
    2) printf '%s\n' "codex" ;;
    3) printf '%s\n' "all" ;;
    *)
      echo "오류: 1, 2, 3 중 하나의 번호를 입력하세요 (입력값: $choice)" >&2
      exit 1
      ;;
  esac
}

install_skill() {
  local variant="$1"
  local source_dir
  local target_dir

  case "$variant" in
    claude)
      source_dir="$SCRIPT_DIR/claude"
      target_dir="$HOME/.claude/skills/log-session"
      ;;
    codex)
      source_dir="$SCRIPT_DIR/codex"
      target_dir="${CODEX_HOME:-$HOME/.codex}/skills/log-session"
      ;;
    *)
      echo "오류: 알 수 없는 설치 대상입니다: $variant" >&2
      echo "사용법: ./install.sh [claude|codex|all]" >&2
      exit 1
      ;;
  esac

  if [ ! -d "$source_dir" ]; then
    echo "오류: $source_dir 가 없습니다. 리포 루트에서 실행하세요." >&2
    exit 1
  fi

  echo "log-session 스킬 설치 ($variant)"
  echo "  source: $source_dir"
  echo "  target: $target_dir"
  echo ""

  mkdir -p "$target_dir/scripts"
  copy_with_prompt "$source_dir/SKILL.md" "$target_dir/SKILL.md"

  if [ -d "$source_dir/agents" ]; then
    mkdir -p "$target_dir/agents"
    for agent_file in "$source_dir/agents/"*; do
      [ -f "$agent_file" ] || continue
      copy_with_prompt "$agent_file" "$target_dir/agents/$(basename "$agent_file")"
    done
  fi

  for script in "$source_dir/scripts/"*.sh; do
    [ -f "$script" ] || continue
    copy_with_prompt "$script" "$target_dir/scripts/$(basename "$script")"
  done

  chmod +x "$target_dir/scripts/"*.sh 2>/dev/null || true

  echo ""
}

TARGET="$(select_target "${1:-}")"

case "$TARGET" in
  claude|codex)
    install_skill "$TARGET"
    ;;
  all)
    install_skill claude
    install_skill codex
    ;;
  *)
    echo "오류: 알 수 없는 설치 대상입니다: $TARGET" >&2
    echo "사용법: ./install.sh [claude|codex|all]" >&2
    exit 1
    ;;
esac

echo "✓ 설치 완료"
echo ""
echo "사용 방법:"
echo "  Claude Code: /log-session"
echo "  Codex: \$log-session 스킬 호출 또는 'log-session으로 세션 기록 저장' 요청"
