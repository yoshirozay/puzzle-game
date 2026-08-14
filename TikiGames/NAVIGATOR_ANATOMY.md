# Navigator — Code anatomy

Player-facing name: **Navigator**. Engine/id: **`navigator`**.

| File | ~LOC | Role |
|------|------|------|
| `NavigatorView.swift` | 1181 | Hub, peek clock, board, coach, won/run-over |
| `NavigatorBackgroundView.swift` | 663 | Ocean night scenery |
| `NavigatorGame.swift` | 478 | Pure run / passage engine |
| `NavigatorLevel.swift` | 116 | 60-passage campaign generator |

## Product

Memory-flash voyage: **peek** the star chart → clouds → **tap** every star from memory. **3 mistakes** end the **run** (back to Passage 1). **60 passages** in 5 board-size bands; beating P60 **loops** with 15% faster peeks. Wallet: per-passage `levelScore` via `recordRun`; chart ranks **totalPassages**.

## Hierarchy

```
ContentView (.navigator)
└── NavigatorView
    ├── NavigatorGame
    ├── NavigatorBackgroundView(phase)
    ├── run-start hub (START RUN)
    ├── board + peek clock
    ├── passage-won / run-over panels
    └── Coach / READY TO SAIL / HowTo
```

## Engine blocks

| Block | Role |
|-------|------|
| Phase | idle / peek(n) / input / passageWon / runOver |
| startNewRun / advanceAfterWin / backOutOfRun | Run lifecycle + loop |
| newLevel + NavRandom pattern | Attempt-salted stars, no 2×2 clumps |
| tap | star score 25+streak; fail at mistakes 0 |
| seedTutorialBoard | P1 attempt 99, mistakes 99, no meta |
| payload/restore | Meta always; mid-passage same roll |

## Scoring

```
star: +25 + min(streak-1,5)*5
clear: +30 + 10*targets
perfect (no wrong, no re-peek): +50
```

## Timeline

Enter → restore or hub → START RUN / coach P1 → WATCH THE SKY → peek → input → passage won (NEXT) or run over (life) → loop forever.

---
*iOS oracle for Android twin.*
