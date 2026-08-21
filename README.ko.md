# claude-code-starter

Claude Code 전역 설정을 붙여넣기 한 번으로 맞춥니다. 프로필을 고르고, 바뀔 내용을 확인하고, 승인하면 끝.

English: [README.md](README.md)

---

## 쓰는 법

Claude Code에 이걸 붙여넣으세요.

```
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/prompts/bootstrap.md
를 읽고 그 절차를 정확히 따라 내 Claude Code 전역 설정을 구성해줘.
```

Claude가 현재 환경을 읽고, 어떤 프로필을 쓸지 묻고, 키 단위로 바뀔 내용을 보여준 뒤, **승인 전까지는
아무것도 쓰지 않습니다.**

> **실행 전에 절차서를 한 번 열어보세요.** URL에 있는 지시를 Claude에게 따르게 하는 방식입니다.
> [`prompts/bootstrap.md`](prompts/bootstrap.md)가 전부이고 길지 않습니다. `main` 대신 `v0.1.0` 같은
> 태그로 바꾸면 검토한 버전에 고정할 수 있습니다.

## 프로필

| | `permissions.defaultMode` | `model` | 누구에게 |
|---|---|---|---|
| **safe** | `default` — 도구를 처음 쓸 때마다 물어봄 | 플랜 기본값(지정 안 함) | 기본값. 모르는 사이에 실행되는 게 없습니다. |
| **balanced** | `acceptEdits` — 작업 디렉터리 안의 파일 편집과 흔한 파일시스템 명령을 자동 승인 | `opus` | 믿는 레포에서 매일 하는 작업. |
| **power** | `bypassPermissions` — 권한 확인 없음 | `opus` | 컨테이너나 VM에서만. |

셋 다 `autoUpdatesChannel: "latest"`, `autoCompactEnabled: true`, 그리고 빈 `attribution` 블록을
넣습니다. 마지막 것은 커밋 메시지와 PR에 Claude 서명이 안 남게 합니다.

`power`를 고르면 확인을 두 번 받고, 공식 문서의 경고를 그대로 보여줍니다.

> `bypassPermissions` 모드는 `.git`, `.claude` 같은 보호 경로에 대한 쓰기를 포함해 권한 확인을
> 건너뜁니다. Claude Code가 피해를 줄 수 없는 컨테이너나 VM 같은 격리 환경에서만 쓰세요.
> — [Claude Code 문서](https://code.claude.com/docs/en/permissions)

## 문서에 없는 키는 따로

남의 dotfiles에서 복사해 오는 설정 중 절반은 공식 settings 레퍼런스에 없습니다. `effortLevel`,
`ultracode`, `remoteControlAtStartup`, `inputNeededNotifEnabled`, `skipDangerousModePermissionPrompt`
같은 것들이요. 동작은 합니다. 다만 Claude Code의 `/config` UI가 쓰는 키라서 버전이 올라가면 바뀔 수
있습니다.

그래서 이 레포는 이것들을 별도 선택 단계로 빼고, 고르기 전에 "문서에 없는 키"라고 먼저 알려주고,
기본은 적용하지 않습니다. 키별 근거와 대가는 [`docs/keys.md`](docs/keys.md)에 정리해 뒀습니다.

## 선택 구성 요소

둘 다 선택 사항이고, 둘 다 각자의 공식 인스톨러가 설치합니다. 이 레포에 복사해 둔 남의 코드는
없습니다.

- **[CC-statusline](https://github.com/AwesomeJun/CC-statusline)** (MIT) — 컨텍스트 사용량, 비용,
  추론 강도를 보여주는 상태줄. `statusLine` 키를 담당합니다.
- **[RTK](https://github.com/rtk-ai/rtk)** (Apache-2.0) — 셸 출력이 컨텍스트에 들어오기 전에 압축하는
  `PreToolUse` 훅. `hooks` 키를 담당합니다. `rtk init -g`는 전역 `CLAUDE.md`에 `@RTK.md` import 줄도
  추가하는데, 절차서가 실행 전에 이 사실을 알려줍니다.

이 둘은 설정 병합보다 **먼저** 실행됩니다. 그래야 그들이 쓴 키가 병합 과정에서 그대로 보존됩니다.

## 하지 않는 일

- 고른 프로필에 없는 키를 지우거나 덮어쓰기
- 변경 내용을 보여주고 승인받기 전에 파일 쓰기
- 프로젝트 단위 `.claude/settings.json` 건드리기
- 파싱 안 되는 `settings.json` 고치기 — 멈추고 알려줍니다
- `theme`, `tui`, 권한 알로우리스트 쓰기 — 이건 `/config`와 `/permissions`가 할 일입니다

매번 `settings.json.bak-<타임스탬프>`로 백업합니다. 되돌리는 건 파일 복사 한 번이고, 절차가 끝날 때
쓰는 OS에 맞는 명령을 그대로 출력해 줍니다.

## 문서

- [`prompts/bootstrap.md`](prompts/bootstrap.md) — Claude가 따르는 절차
- [`docs/keys.md`](docs/keys.md) — 모든 키의 문서화 여부와 출처
- [`docs/merge-rules.md`](docs/merge-rules.md) — 병합 알고리즘과 실제 예시
- [`docs/troubleshooting.md`](docs/troubleshooting.md)

## 지원 플랫폼

Windows(PowerShell)에서 확인했습니다. macOS와 Linux 경로도 절차서에 들어 있고, 실제 설치는 세 OS를
모두 지원하는 업스트림 인스톨러에 맡깁니다.

## 라이선스

MIT. [LICENSE](LICENSE)와 업스트림 고지 [NOTICE.md](NOTICE.md)를 보세요.
