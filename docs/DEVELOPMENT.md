# Development Guidelines

## Pre-Commit Hooks

Ein Pre-Commit Hook ist aktiv, der **automatisch** vor jedem Commit läuft:

### Was der Hook prüft:
1. ✅ **Code-Formatting** (`dart format`)
2. ✅ **Static Analysis** (`flutter analyze --fatal-infos`)
3. ✅ **Tests** (`flutter test`)

### Hook überspringen (Notfall):
```bash
# Tests überspringen
NO_TEST=1 git commit -m "message"

# ODER gesamten Hook überspringen (NICHT empfohlen!)
git commit --no-verify -m "message"
```

## Bug-Prevention-System

### Aktivierte Linting-Rules:
- `avoid_dynamic_calls` - Verhindert Type-Safety-Bugs
- `curly_braces_in_flow_control_structures` - Verhindert Logic-Bugs
- `close_sinks` - Verhindert Memory-Leaks
- `use_build_context_synchronously` - Verhindert Async-Bugs
- `only_throw_errors` - Besseres Error-Handling
- Und 10+ weitere (siehe `analysis_options.yaml`)

### Vor jedem Push:
```bash
# 1. Format + Analyze + Test
flutter test

# 2. Build APK (simuliert CI/CD)
flutter build apk --debug
```

## Kritische Bugs verhindert:
✅ Null-Pointer-Crashes (force unwrap `!`)
✅ Array-Out-of-Bounds (reduce auf leere Liste)
✅ Type-Cast-Failures (unsafe `as`)
✅ Division durch 0
✅ Memory Leaks (nicht disposed Controller)
✅ Race Conditions (async ohne error handling)

## Coverage-Ziel:
- Minimum: 70% Code-Coverage
- Aktuell: Run `flutter test --coverage` to check

**🎯 Ziel: KEINE Bugs mehr in Production!**
