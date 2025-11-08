# Android 15 Edge-to-Edge Migration Guide

## 🎯 Was ist Edge-to-Edge?

Ab Android 15 (API 35) zeigt das System Apps standardmäßig **randlos (edge-to-edge)** an. Das bedeutet:
- Content kann unter Status Bar und Navigation Bar angezeigt werden
- Mehr Bildschirmfläche verfügbar
- **ABER:** App muss System UI Insets beachten

## ✅ Was wurde bereits implementiert

### 1. MainActivity (Kotlin)
```kotlin
// ✅ WindowCompat.setDecorFitsSystemWindows(window, false)
// Aktiviert Edge-to-Edge Display
```

### 2. Dependencies
```kotlin
// ✅ androidx.core:core-ktx:1.13.1
// Für WindowCompat Support
```

### 3. Flutter Widgets
- `EdgeToEdgeScaffold` - Drop-in Replacement für Scaffold
- `EdgeToEdgeSafeArea` - Wrapper für Safe Area Padding

## 📱 Wie Apps sich verhalten

### Vor Android 15 (API < 35)
```
┌─────────────────┐
│   Status Bar    │ ← System UI
├─────────────────┤
│                 │
│   App Content   │ ← Deine App
│                 │
├─────────────────┤
│ Navigation Bar  │ ← System UI
└─────────────────┘
```

### Ab Android 15 (API 35+)
```
┌─────────────────┐
│ Status Bar      │ ← Transparent
│   App Content   │ ← Kann darunter sein!
│                 │
│                 │
│   App Content   │
│ Navigation Bar  │ ← Transparent
└─────────────────┘
```

## 🛠️ Best Practices

### DO ✅
```dart
// Verwende SafeArea für wichtigen Content
SafeArea(
  child: Text('Wichtiger Text'),
)

// Oder EdgeToEdgeScaffold
EdgeToEdgeScaffold(
  appBar: AppBar(title: Text('Titel')),
  body: MyContent(),
)
```

### DON'T ❌
```dart
// NICHT: Content ohne SafeArea bei Edge-to-Edge
Scaffold(
  body: Text('Kann unter System UI verschwinden!'),
)
```

## 🔍 Testing Checklist

### Android 15+ Testing
- [ ] Status Bar überlappt nicht mit AppBar
- [ ] Bottom Navigation nicht von System Gestures verdeckt
- [ ] Dialogs sind centered und nicht abgeschnitten
- [ ] Floating Action Buttons nicht von Navigation Bar verdeckt

### Samsung Flip Testing (Foldable)
- [ ] Edge-to-Edge funktioniert auf innerem Display
- [ ] Cover Screen zeigt UI korrekt
- [ ] Fold/Unfold behält UI State

### Dark/Light Mode Testing
- [ ] Status Bar Icons sind sichtbar (hell/dunkel)
- [ ] Navigation Bar Icons sind sichtbar
- [ ] Kein Kontrast-Problem

## 📊 Kompatibilität

| Android Version | Edge-to-Edge | Handling |
|----------------|--------------|----------|
| Android 5-14 (API 21-34) | ❌ Opt-In | `WindowCompat` aktiviert es |
| Android 15+ (API 35+) | ✅ Standard | Automatisch aktiv |

## 🚀 Migration für bestehende Screens

### Option 1: EdgeToEdgeScaffold verwenden (empfohlen)
```dart
// Alt
Scaffold(
  appBar: AppBar(...),
  body: MyWidget(),
)

// Neu
EdgeToEdgeScaffold(
  appBar: AppBar(...),
  body: MyWidget(),
)
```

### Option 2: Manuell SafeArea hinzufügen
```dart
Scaffold(
  body: SafeArea(
    child: MyWidget(),
  ),
)
```

## ⚠️ Bekannte Probleme

### Problem: Content wird von Status Bar überlappt
**Lösung:** Wrap mit `SafeArea`

### Problem: Bottom Sheet wird von Keyboard verdeckt
**Lösung:** Verwende `MediaQuery.of(context).viewInsets.bottom`

### Problem: Foldable zeigt UI falsch nach Fold
**Lösung:** Lifecycle Observer bereits implementiert (siehe `main.dart`)

## 📝 Weitere Ressourcen

- [Android Edge-to-Edge Docs](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
- [Flutter SafeArea Widget](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
- [Material Design 3 - Edge-to-Edge](https://m3.material.io/foundations/layout/applying-layout/window-size-classes)

## ✅ Checklist für neue Screens

Wenn du einen neuen Screen erstellst:
- [ ] Verwende `EdgeToEdgeScaffold` statt `Scaffold`
- [ ] Teste auf Android 15 Emulator
- [ ] Teste Dark/Light Mode
- [ ] Teste mit Keyboard (TextField Screens)
- [ ] Teste auf Samsung Flip (Foldable)

---

**Version:** 0.8.7+12
**Letzte Aktualisierung:** 2025-11-08
**Target SDK:** 35 (Android 15)
