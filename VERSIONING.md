# Versioning Guidelines für Plantry

## Semantic Versioning Schema

```
MAJOR.MINOR.PATCH+BUILD
```

### Beispiel
```
0.8.7+12
│ │ │  └─ Build Number (nur für interne Zwecke)
│ │ └──── PATCH: Bugfixes
│ └────── MINOR: Neue Features
└──────── MAJOR: Breaking Changes
```

---

## Regeln für Version Updates

### ⚠️ WICHTIG: Beide Nummern erhöhen!

**Jedes Release, das live geht (Google Play Store), MUSS die sichtbare Version erhöhen!**

Tester sehen nur `MAJOR.MINOR.PATCH` - NICHT die Build Number!

### 1. 🐛 Bugfix-Update (PATCH)
- **Wann**: Fehlerbehebungen ohne neue Features
- **Erhöhe**: PATCH + BUILD
- **Beispiel**: `0.8.7+12` → `0.8.8+13`

```yaml
# pubspec.yaml
version: 0.8.8+13  # ✅ RICHTIG
version: 0.8.7+13  # ❌ FALSCH - Tester sehen kein Update!
```

### 2. ✨ Feature-Update (MINOR)
- **Wann**: Neue Features, aber abwärtskompatibel
- **Erhöhe**: MINOR (PATCH auf 0 zurücksetzen) + BUILD
- **Beispiel**: `0.8.9+15` → `0.9.0+16`

```yaml
# pubspec.yaml
version: 0.9.0+16  # ✅ RICHTIG
```

### 3. 💥 Breaking Changes (MAJOR)
- **Wann**: Inkompatible Änderungen (z.B. neue Datenbank-Version ohne Migration)
- **Erhöhe**: MAJOR (MINOR + PATCH auf 0) + BUILD
- **Beispiel**: `0.9.5+20` → `1.0.0+21`

```yaml
# pubspec.yaml
version: 1.0.0+21  # ✅ RICHTIG
```

---

## Release Workflow

### 🚀 Automatischer Weg (EMPFOHLEN)

Nutze das `update_version.sh` Script:

```bash
# Syntax
./update_version.sh <VERSION> <BUILD>

# Beispiel: Bugfix Release
./update_version.sh 0.8.8 13

# Beispiel: Feature Release
./update_version.sh 0.9.0 14
```

**Das Script aktualisiert automatisch:**
✅ `pubspec.yaml`
✅ `lib/utils/app_version.dart`
✅ `README.md`

**Du musst nur noch:**
1. `CHANGELOG.md` manuell aktualisieren
2. Changes reviewen: `git diff`
3. Testen & committen

---

### ⚙️ Manueller Weg (Fallback)

Falls das Script nicht funktioniert:

#### Vor jedem Release Checklist

- [ ] `pubspec.yaml` Version erhöht
- [ ] `lib/utils/app_version.dart` Version erhöht (MUSS identisch zu pubspec.yaml sein!)
- [ ] `README.md` Version erhöht
- [ ] `CHANGELOG.md` aktualisiert
- [ ] Git commit mit Version Tag
- [ ] Build getestet

#### 1. Version in pubspec.yaml UND app_version.dart aktualisieren

⚠️ **KRITISCH**: Beide Dateien MÜSSEN die gleiche Version haben!

```bash
# 1. Editiere pubspec.yaml
version: 0.8.X+Y  # X = neue PATCH, Y = neue BUILD

# 2. Editiere lib/utils/app_version.dart
static const String version = '0.8.X+Y';  # EXAKT die gleiche Version!

# 3. Editiere README.md
**Version:** 0.8.X  # Nur Semantic Version, OHNE +BUILD
```

**Warum alle drei Dateien?**
- `pubspec.yaml` → Wird von Flutter Build System verwendet
- `app_version.dart` → Wird von der App zur Laufzeit in Settings angezeigt
- `README.md` → Dokumentation für GitHub/Entwickler

---

### 2. Changelog aktualisieren

```bash
# Editiere CHANGELOG.md
## [0.8.X] - 2025-XX-XX

### 🐛 Bug Fixes
- Fixed XYZ

### Build
- Build Number: Y
```

### 3. Git Commit & Tag

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "Release v0.8.X - [Kurze Beschreibung]"
git tag v0.8.X
git push origin master --tags
```

---

## Beispiel Release-Historie

| Version | Build | Type | Beschreibung |
|---------|-------|------|--------------|
| 0.8.7   | 12    | -    | Aktueller Stand |
| 0.8.8   | 13    | 🐛   | Bugfix: Crash beim Start behoben |
| 0.8.9   | 14    | 🐛   | Bugfix: Photo Upload Fix |
| 0.9.0   | 15    | ✨   | Feature: Dark Mode verbessert |
| 0.9.1   | 16    | 🐛   | Bugfix: Dark Mode Crash |
| 1.0.0   | 17    | 💥   | Breaking: Neue DB Version 9 |

---

## ❌ Häufige Fehler

### Fehler 1: Nur Build Number erhöhen
```yaml
version: 0.8.7+12  →  0.8.7+13  # ❌ FALSCH
```
**Problem**: Tester sehen "0.8.7" und denken, es gibt kein Update!

### Fehler 2: Build Number vergessen
```yaml
version: 0.8.7+12  →  0.8.8+12  # ❌ FALSCH
```
**Problem**: Google Play Store erkennt gleiches Build Number als bereits uploaded.

### Fehler 4: app_version.dart vergessen
```yaml
# pubspec.yaml
version: 0.8.8+13  # ✅ Aktualisiert

# lib/utils/app_version.dart
static const String version = '0.8.7+12';  # ❌ FALSCH - Nicht aktualisiert!
```
**Problem**: Settings-Screen zeigt alte Version! Nutzer sehen nicht, welche Version installiert ist.

### Fehler 3: PATCH bei Feature-Update
```yaml
version: 0.8.7+12  →  0.8.8+13  # ❌ FALSCH (wenn neue Features)
```
**Problem**: MINOR sollte erhöht werden bei neuen Features.

---

## ✅ Richtige Beispiele

### Bugfix Release
```yaml
# Vorher
version: 0.8.7+12

# Nachher (Bugfix)
version: 0.8.8+13
```

### Feature Release
```yaml
# Vorher
version: 0.8.9+15

# Nachher (Neues Feature)
version: 0.9.0+16
```

### Hotfix nach Feature
```yaml
# Vorher
version: 0.9.0+16

# Nachher (Schneller Bugfix)
version: 0.9.1+17
```

---

## Notizen

- **Build Number**: Wird automatisch von Google Play Store geprüft, muss immer aufsteigend sein
- **Version String**: Das, was Nutzer sehen - MUSS sich bei jedem Update ändern!
- **Git Tags**: Helfen bei Rollbacks und Release-Tracking
- **CHANGELOG**: Immer synchron mit Version halten

---

**Letzte Aktualisierung**: 2025-11-08
**Aktuelles Schema**: Semantic Versioning 2.0.0
