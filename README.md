# Get-AI-Session

Claude Code 세션의 작업을 L1~L4 레벨로 분류하고 프로젝트별 MD 파일로 저장하는 사용자 호출 스킬.

## 설치

```bash
git clone git@github.com:Dang-Mu/Get-AI-Session.git
cd Get-AI-Session
./install.sh
```

`~/.claude/skills/log-session/` 에 SKILL.md와 헬퍼 스크립트가 복사됩니다. 기존 파일이 있으면 덮어쓰기 전에 한 번씩 묻습니다.

## 사용

Claude Code에서 다음 명령을 실행하면 현재 세션을 분석하여 MD 파일로 저장합니다.

```
/log-session
```

저장 위치는 다음과 같습니다:

```
~/.claude/projects/{프로젝트폴더}/sessions/{YYYY-MM-DD}-{세션ID앞8자리}.md
```

## 폴더 구조

```
.
├── README.md
├── install.sh                       설치 스크립트 (대화형 덮어쓰기)
└── claude/                          ~/.claude/skills/log-session/ 로 복사되는 내용
    ├── SKILL.md                     스킬 정의 (Claude가 따라가는 절차)
    └── scripts/
        └── get-session-info.sh      현재 세션 메타데이터를 JSON으로 출력
```

## 레벨 기준

| 레벨 | 기준 | 예시 |
|------|------|------|
| L1 | 단순 지시 (삭제, 이름 변경, 1줄 수정) | "강하늘 탭 없애요" |
| L2 | 명확한 작업 (단일 파일 편집) | "성장포인트 어미 변환" |
| L3 | 분석 + 편집 (패턴 파악, 크로스파일, 디버깅) | "12개 파일 정중체 변환" |
| L4 | 설계 / 아키텍처 (시스템 결정, 스킬 생성) | "세션 로깅 스킬 설계" |

## get-session-info.sh 출력 예시

```json
{
  "cwd": "/Users/ull/Desktop/ella-dev/learning-finder",
  "project_name": "learning-finder",
  "folder_name": "-Users-ull-Desktop-ella-dev-learning-finder",
  "projects_dir": "/Users/ull/.claude/projects/-Users-ull-Desktop-ella-dev-learning-finder",
  "sessions_dir": "/Users/ull/.claude/projects/-Users-ull-Desktop-ella-dev-learning-finder/sessions",
  "session_id": "f3562c82-85e7-40e2-a1c1-b6956b9daf21",
  "session_id_short": "f3562c82",
  "transcript_path": "/Users/ull/.claude/projects/.../f3562c82-...jsonl"
}
```

세션 ID는 `CLAUDE_SESSION_ID` 환경변수 → 없으면 현재 프로젝트 폴더의 가장 최근 `*.jsonl` 파일명 순으로 추출합니다.
