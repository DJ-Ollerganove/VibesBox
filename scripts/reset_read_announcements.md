# Test-Reset: read_announcements für einen User leeren

Damit die globale Ankündigung beim DJ erneut als „ungelesen“ erscheint, muss die Ankündigungs-ID aus dem Feld `read_announcements` des User-Dokuments entfernt werden.

## User-ID (Test-DJ)

- **UID:** `ac8TzERL6VMRjHq7AOrNeer5yyA2`

## Option 1: Firebase Console

1. [Firebase Console](https://console.firebase.google.com) → Projekt **dj-ollerganove** (oder dein Projekt) öffnen.
2. **Firestore Database** → Collection **users** → Dokument mit ID `ac8TzERL6VMRjHq7AOrNeer5yyA2` öffnen.
3. Feld **read_announcements** bearbeiten:
   - Ist es ein **Array**: Die ID der Test-Ankündigung aus dem Array entfernen (oder das Feld leeren / löschen).
   - Ist es eine **Map**: Den Eintrag mit dem Key der Ankündigungs-ID entfernen.
4. Speichern.

Danach erscheint die Ankündigung beim nächsten Login (nach der 2,5‑Sekunden-Verzögerung) wieder als Popup.

## Option 2: Einmal-Skript (Node.js mit firebase-admin)

Im Projektroot (oder in `functions/`):

```bash
cd functions
node -e "
const admin = require('firebase-admin');
const uid = 'ac8TzERL6VMRjHq7AOrNeer5yyA2';
admin.initializeApp({ projectId: 'dj-ollerganove' });
const db = admin.firestore();
db.collection('users').doc(uid).update({ read_announcements: [] })
  .then(() => { console.log('read_announcements geleert'); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
"
```

(Hinweis: Dafür muss vorher `firebase-admin` installiert und ggf. ein Service-Account gesetzt sein.)
