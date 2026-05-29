#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_DIR="$SCRIPT_DIR/claude"
TARGET_DIR="$HOME/.claude/skills/log-session"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "오류: $SOURCE_DIR 가 없습니다. 리포 루트에서 실행하세요." >&2
  exit 1
fi

echo "log-session 스킬 설치"
echo "  source: $SOURCE_DIR"
echo "  target: $TARGET_DIR"
echo ""

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

mkdir -p "$TARGET_DIR/scripts"

copy_with_prompt "$SOURCE_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"

for script in "$SOURCE_DIR/scripts/"*.sh; do
  [ -f "$script" ] || continue
  copy_with_prompt "$script" "$TARGET_DIR/scripts/$(basename "$script")"
done

chmod +x "$TARGET_DIR/scripts/"*.sh 2>/dev/null || true

echo ""
echo "✓ 설치 완료"
echo ""
echo "사용 방법:"
echo "  Claude Code에서 /log-session 호출"
