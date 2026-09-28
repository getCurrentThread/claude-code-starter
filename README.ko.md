# claude-code-starter

Claude Code 전역 설정을 붙여넣기 한 번으로 맞춥니다. 중간에 아무것도 묻지 않습니다.

English: [README.md](README.md)

---

## 쓰는 법

Claude Code에 이걸 붙여넣으세요.

```
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/prompts/bootstrap.md
를 읽고 그 절차를 정확히 따라 내 Claude Code 전역 설정을 구성해줘.
```

Claude가 `settings.json`을 백업하고, 아래 설정을 병합하고, 상태줄을 설치한 뒤 바뀐 내용을
알려줍니다. 그사이 아무것도 묻지 않습니다.

> **실행 전에 [`prompts/bootstrap.md`](prompts/bootstrap.md)를 한 번 읽어보세요.** 짧고,
> `bypassPermissions`를 켭니다. URL의 `main`을 태그로 바꾸면 검토한 버전에 고정할 수 있습니다.

## 넣는 설정

| 키 | 값 |
|---|---|
| `permissions.defaultMode` | `bypassPermissions` — 권한 확인 없음 |
| `skipDangerousModePermissionPrompt` | `true` — bypass 모드 시작 확인창 없음 |
| `model` | `opus` |
| `effortLevel` / `ultracode` | `xhigh` / `true` |
| `modelSettings` | `claude-opus-5-5`, `claude-sonnet-5-5`에 `xhigh` — 최상위 `effortLevel`은 Opus 5.5부터 적용되지 않음 |
| `autoCompactEnabled` / `autoCompactWindow` | `true` / `400000` — 400K 토큰에서 자동 압축 |
| `autoUpdatesChannel` | `latest` |
| `remoteControlAtStartup`, `agentPushNotifEnabled`, `inputNeededNotifEnabled` | `true` |
| `attribution` | 빈 값 — 커밋·PR에 Claude 서명 없음 |

여기에 [CC-statusline](https://github.com/AwesomeJun/CC-statusline)을 `m` 크기로 설치합니다.
이미 `statusLine`이 있으면 그대로 둡니다.

표에 없는 키는 그대로 남고, 파싱되지 않는 `settings.json`은 건드리지 않습니다.

> `bypassPermissions` 모드는 `.git`, `.claude` 같은 보호 경로에 대한 쓰기를 포함해 권한 확인을
> 건너뜁니다. Claude Code가 피해를 줄 수 없는 컨테이너나 VM 같은 격리 환경에서만 쓰세요.
> — [Claude Code 문서](https://code.claude.com/docs/en/permissions)

## 되돌리기

매번 먼저 `settings.json.bak-<타임스탬프>`로 백업하고, 마지막 보고에 복원 명령을 그대로
출력합니다. 직접 하려면:

```powershell
Copy-Item "$env:USERPROFILE\.claude\settings.json.bak-<타임스탬프>" "$env:USERPROFILE\.claude\settings.json" -Force
```

```bash
cp ~/.claude/settings.json.bak-<타임스탬프> ~/.claude/settings.json
```

## v0.1.0에서 올라오는 경우

RTK는 더 이상 설치하지 않습니다. 이미 설치된 RTK는 그대로 둡니다. 지우려면 `settings.json`의
`hooks`에서 RTK의 `PreToolUse` 항목을, 전역 `CLAUDE.md`에서 `@RTK.md` 줄을 삭제하세요.

## 라이선스

MIT. [LICENSE](LICENSE)와 [NOTICE.md](NOTICE.md)를 보세요.
