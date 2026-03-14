# Plantry Design System

## Designphilosophie

Plantry ist eine Pflanzen-Management-App. Das Design soll sich anfühlen wie ein hochwertiges, dunkles Tool — nicht wie ein Template oder Baukasten. Jedes Element gehört zusammen. Der User soll beim Öffnen denken: "Das sieht professionell aus."

Referenz-Feeling: Premium Smart-Home-Apps (dark mode), nicht Material-Default.

---

## Farbpalette

> **Single Source of Truth:** `lib/theme/design_tokens.dart` (Klasse `DT`)
> Keine Farben hardcoden — immer `DT.*` verwenden.

### Hintergrund-System (3 Stufen Tiefe)
| Token | Hex | Verwendung |
|---|---|---|
| `DT.canvas` | `#050505` | Scaffold-Background, tiefster Hintergrund |
| `DT.surface` | `#0E0E0E` | Cards, Container |
| `DT.elevated` | `#161616` | Inputs, Buttons, verschachtelte Cards |

### Akzentfarben (Cyber / Bitget Style)
| Token | Hex | Bedeutung |
|---|---|---|
| `DT.accent` | `#00FFBB` | Primär-Akzent (Cyber Mint) — CTAs, aktive States |
| `DT.secondary` | `#00CCFF` | Electric Blue — Info, Links |
| `DT.warning` | `#FFBB00` | Warnungen, Zeitangaben |
| `DT.error` | `#FF3366` | Fehler, Destruktive Aktionen |
| `DT.success` | `#00FFBB` | Erfolg (Alias für accent) |
| `DT.info` | `#8833FF` | Info-Badges, Lila-Highlights |

### Text
| Token | Hex | Verwendung |
|---|---|---|
| `DT.textPrimary` | `#FFFFFF` | Überschriften, wichtiger Text |
| `DT.textSecondary` | `#9E9E9E` | Untertitel, Labels |
| `DT.textTertiary` | `#505050` | Platzhalter, deaktiviert |

### Borders & Glass
| Token | Wert | Verwendung |
|---|---|---|
| `DT.border` | `#1A1A1A` | Trennlinien |
| `DT.glassBorder` | white 8% | Card-Borders (glass effect) |
| `DT.glassBackground` | white 3% | Card-Hintergrund (glass) |

### Semantische Farbe-Hintergründe (für Alerts/Badges)
- Fehler-BG: `DT.error.withValues(alpha: 0.08)` + Border: `DT.error.withValues(alpha: 0.3)`
- Warnung-BG: `DT.warning.withValues(alpha: 0.08)` + Border: `DT.warning.withValues(alpha: 0.3)`
- Erfolg-BG: `DT.success.withValues(alpha: 0.08)` + Border: `DT.success.withValues(alpha: 0.3)`

---

## Typografie

- **Display**: 28-30px, Weight 700, Letter-spacing -0.8 — App-Titel
- **Headline**: 20-22px, Weight 700, Letter-spacing -0.3 — Card-Titel (Hero)
- **Title**: 14-15px, Weight 600 — Grid-Card Labels, Section-Titel
- **Body**: 13-14px, Weight 400 — Beschreibungstexte
- **Caption**: 11-12px, Weight 500, Letter-spacing 0.5 — Badges, Metadata

Alles Roboto (System-Font, kein Google Fonts Download nötig).

---

## Spacing & Grid

- **Base Unit**: 4px
- **Content Padding**: 20px horizontal, 24px top
- **Card Gap**: 12px (zwischen Cards)
- **Card Inner Padding**: 20px (Hero), 16px (Grid-Tiles)
- **Section Gap**: 24px (zwischen Header und Content, zwischen Sections)

---

## Card-System

### Grundregel
Alle Cards nutzen DASSELBE Dekorations-Rezept. Keine Ausnahmen.

### Card-Dekoration
Nie manuell — immer `DT.cardDeco()` oder `DT.cardDecoFlat()` verwenden:

```dart
DT.cardDeco()      // Glass: white 3% BG + white 8% Border, Radius 16
DT.cardDecoFlat()  // Solid: DT.elevated BG + glass Border, Radius 16
DT.glassDeco()     // Alias für cardDeco()
```

### Card-Varianten (nur Layout innen verschieden)
1. **Hero Card** (volle Breite, ~140px hoch)
   - Links: Titel + Untertitel
   - Rechts: Icon/Bild (80px)
   - Innerer Aufbau: Row → [Column(texts), Image]

2. **Grid Card** (halbe Breite, ~148px hoch)
   - Zentriert: Icon (50px) + Label
   - Optional: Stat-Badge oben rechts
   - Innerer Aufbau: Stack → [Badge?, Column(icon, text)]

3. **List Card** (volle Breite, ~72px hoch, für Expert-Features)
   - Links: Icon (36px) + Titel/Subtitle → Rechts: Chevron
   - Innerer Aufbau: Row → [Icon, Column(texts), Chevron]

### VERBOTEN auf Cards
- Farbige Borders
- Farbige Hintergründe/Gradients pro Card
- Dekorative Formen (Kreise, Blobs)
- Unterschiedliche Border-Radii
- Unterschiedliche Shadow-Stärken

---

## Interaktionen

### Tap-Feedback
- Scale-Animation: 1.0 → 0.97, 100ms, EaseInOut
- Kein Ripple (InkWell), kein Highlight-Color
- Jede tappbare Fläche nutzt denselben BouncyTile-Wrapper

### Staggered Entry
- Cards erscheinen nacheinander beim Screen-Load
- Delay pro Item: 80-100ms
- Animation: Fade (0→1) + SlideUp (6% → 0), Duration 350ms, EaseOutCubic

### Navigation
- Standard MaterialPageRoute
- Kein Hero-Transition zwischen Screens (vorerst)

---

## Dashboard-Layout

```
┌──────────────────────────┐
│ Greeting      [Settings] │  ← Header, kein AppBar
│ Plantry                  │
├──────────────────────────┤
│                          │
│  ┌────────────────────┐  │  ← Hero Card (Pflanzen)
│  │ Pflanzen    [IMG]  │  │
│  │ 12 Pflanzen       │  │
│  └────────────────────┘  │
│                          │
│  ┌─────────┐ ┌─────────┐│  ← Grid Row 1
│  │  [IMG]  │ │  [IMG]  ││
│  │Anbauten │ │ Räume   ││
│  └─────────┘ └─────────┘│
│                          │
│  ┌─────────┐ ┌─────────┐│  ← Grid Row 2
│  │  [IMG]  │ │  [IMG]  ││
│  │ Dünger  │ │ Ernten  ││
│  └─────────┘ └─────────┘│
│                          │
│  (Expert Mode:)          │
│  ┌─────────┐ ┌─────────┐│  ← Grid Row 3
│  │  [IMG]  │ │  [IMG]  ││
│  │  RDWC   │ │ Kalkul. ││
│  └─────────┘ └─────────┘│
│                          │
│        v1.1.0            │  ← Footer, dezent
└──────────────────────────┘
```

---

## Hintergrund

- Fester Farbwert `#0C0C0C`
- KEIN Gradient, KEIN animierter Background, KEINE Glow-Effekte
- Die Cards selbst erzeugen die visuelle Hierarchie durch ihre Shadows

---

## Icon-Behandlung

- Die existierenden PNG-Icons werden als Content-Bilder behandelt
- Keine farbigen Container um Icons
- Icons sitzen direkt auf der Card-Surface
- Größen: 80px (Hero), 50px (Grid), 36px (List)

---

## Settings-Button

- Oben rechts im Header
- Gleiche Card-Dekoration wie alles andere (Depth 1, Shadow)
- Icon: `tune_rounded`, 20px, Secondary-Textfarbe
- Größe: 46x46px, Border-Radius 14px

---

## Regeln für zukünftige Screens

1. Jeder neue Screen nutzt dasselbe Card-System
2. Kein Screen darf eigene Farben/Borders/Shadows erfinden
3. Die Akzentfarbe (Grün) erscheint max. 2-3 mal pro Screen
4. Text-Hierarchie immer: Primary → Secondary → Tertiary
5. Abstände immer Vielfache von 4px
6. Keine dekorativen Elemente die keinen Zweck haben
