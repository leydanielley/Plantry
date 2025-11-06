# Google Play Console - Data Safety Sektion Antworten

## Für die Google Play Console "Data Safety" Sektion

### 1. Does your app collect or share any of the required user data types?
**Antwort: NO** ❌

**Begründung:**
- Plantry sammelt KEINE Nutzerdaten
- Alle Daten werden nur lokal auf dem Gerät gespeichert
- Keine Datenübertragung an Server oder Drittanbieter
- Keine User Accounts, keine Analytics, keine Werbung

---

### 2. Is all of the user data collected by your app encrypted in transit?
**Antwort: Not applicable** (da keine Daten übertragen werden)

---

### 3. Do you provide a way for users to request that their data is deleted?
**Antwort: YES** ✅

**Begründung:**
- Nutzer können in den App-Einstellungen die Datenbank zurücksetzen
- Deinstallation der App löscht alle lokalen Daten automatisch
- Nutzer haben volle Kontrolle über ihre Daten

---

## Für die "Privacy Policy URL" Sektion

### Privacy Policy URL:
```
https://deinedomain.com/plantry/privacy-policy.html
```

**WICHTIG:** Du musst die `privacy-policy-template.html` auf einem öffentlichen Server hochladen!

**Optionen:**
1. **GitHub Pages** (kostenlos):
   - Erstelle ein Repository
   - Aktiviere GitHub Pages
   - URL: `https://deinusername.github.io/plantry-privacy/privacy-policy.html`

2. **Google Sites** (kostenlos)

3. **Eigene Webseite** (falls vorhanden)

---

## Detaillierte Antworten für Data Safety Formular

### App Permissions (Berechtigungen)

**1. Camera Permission (Kamera)**
- **Warum benötigt:** Fotos von Pflanzen aufnehmen
- **Optional:** Ja, App funktioniert auch ohne Kamera
- **Datensammlung:** NEIN - Fotos werden nur lokal gespeichert

**2. Storage/Photos Permission (Speicher)**
- **Warum benötigt:** Fotos speichern und Backups erstellen
- **Optional:** Teilweise (für Backup-Funktion erforderlich)
- **Datensammlung:** NEIN - nur lokale Speicherung

**3. Internet Permission**
- **Warum benötigt:** Für Share-Funktion (Backup-Dateien teilen via Email/Apps)
- **Optional:** Ja, App funktioniert komplett offline
- **Datensammlung:** NEIN - keine Datenübertragung an Server

---

## Text für "What data does your app collect?" (KEINE auswählen!)

**Plantry collects NO user data.**

All information entered by users (plant data, photos, grow logs, settings) is stored **exclusively on the user's device** using local SQLite database and file storage.

The app:
- Does NOT create user accounts
- Does NOT transmit data to any server
- Does NOT use analytics or tracking
- Does NOT share data with third parties
- Does NOT use advertising frameworks
- Does NOT collect device identifiers
- Does NOT access location data
- Does NOT access contacts or personal information

The only way data leaves the device is if the user explicitly chooses to export a backup file and manually shares it via email or other apps.

---

## Text für Data Safety Section (Copy & Paste für Google Play)

### English Version:
```
DATA COLLECTION AND PRIVACY

Plantry is a 100% offline, privacy-first application. We do not collect, transmit, or share any user data.

HOW YOUR DATA IS HANDLED:
• All data is stored locally on your device only
• No user accounts or registration required
• No internet connection required for app functionality
• No data transmission to servers or third parties
• No analytics, tracking, or advertising

DATA YOU CREATE:
• Plant information and grow logs
• Photos (stored in app's private directory)
• Room and equipment settings
• App preferences

YOUR CONTROL:
• Export/Import: Create backup files for your own use
• Delete: Clear all data via Settings or by uninstalling
• Share: Only if you manually export and share backup files

PERMISSIONS:
• Camera: Take plant photos (optional)
• Storage: Save photos and backups (optional)
• Internet: Only for sharing backup files via email/messaging apps (optional)

We take your privacy seriously. Since everything stays on your device, your data remains completely private and secure.
```

### Deutsche Version:
```
DATENERFASSUNG UND DATENSCHUTZ

Plantry ist eine 100% offline, datenschutzorientierte Anwendung. Wir sammeln, übertragen oder teilen keine Nutzerdaten.

SO WERDEN IHRE DATEN VERARBEITET:
• Alle Daten werden nur lokal auf Ihrem Gerät gespeichert
• Keine Benutzerkonten oder Registrierung erforderlich
• Keine Internetverbindung für App-Funktionalität erforderlich
• Keine Datenübertragung an Server oder Drittanbieter
• Keine Analytics, Tracking oder Werbung

VON IHNEN ERSTELLTE DATEN:
• Pflanzeninformationen und Anbautagebücher
• Fotos (im privaten App-Verzeichnis gespeichert)
• Raum- und Ausrüstungseinstellungen
• App-Einstellungen

IHRE KONTROLLE:
• Export/Import: Backup-Dateien für eigene Nutzung erstellen
• Löschen: Alle Daten über Einstellungen oder durch Deinstallation löschen
• Teilen: Nur wenn Sie Backup-Dateien manuell exportieren und teilen

BERECHTIGUNGEN:
• Kamera: Pflanzenfotos aufnehmen (optional)
• Speicher: Fotos und Backups speichern (optional)
• Internet: Nur zum Teilen von Backup-Dateien via E-Mail/Messaging-Apps (optional)

Wir nehmen Ihre Privatsphäre ernst. Da alles auf Ihrem Gerät bleibt, bleiben Ihre Daten vollständig privat und sicher.
```

---

## Häufige Google Play Fragen

### "Your app has the INTERNET permission. Are you sure you don't collect data?"
**Antwort:**
"The INTERNET permission is required by Android for the share functionality, which allows users to send backup files via email or messaging apps. The app does not initiate any network connections itself. All data remains on the device unless the user explicitly exports and shares a backup file."

### "You use camera/storage. This counts as collecting data!"
**Antwort:**
"These permissions are used to store data locally on the user's device only. Photos and data never leave the device automatically. Google's policy distinguishes between local storage and data collection/transmission. We do not collect, transmit, or access this data remotely."

---

## Checkliste für Google Play Console Data Safety

- [ ] **Does your app collect or share user data?** → NO
- [ ] **Data Safety Section** → Add the text above
- [ ] **Privacy Policy URL** → Upload HTML and add link
- [ ] **App category** → Select appropriate category (Tools, Productivity, or Lifestyle)
- [ ] **Content rating** → Complete questionnaire (likely Everyone or Teen)
- [ ] **Target audience** → 18+ recommended (plant growing context)
- [ ] **Advertising** → NO ads in this app
- [ ] **In-app purchases** → NO purchases
- [ ] **Data deletion instructions** → In Privacy Policy (Settings → Reset Database)

---

## WICHTIG für die Veröffentlichung

1. **Upload die privacy-policy-template.html auf einen öffentlichen Server**
2. **Füge die URL in Google Play Console ein**
3. **Beantworte alle Fragen mit "NO data collection"**
4. **Kopiere den Text oben in das Data Safety Feld**
5. **Bei Rückfragen von Google: Verweise auf die vollständige Privacy Policy URL**

---

**Erstellt am:** 3. November 2025
**App Version:** 0.7.0
