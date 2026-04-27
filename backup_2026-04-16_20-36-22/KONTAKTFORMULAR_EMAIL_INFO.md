# Kontaktformular - E-Mail-Inhalte

## Welche Daten werden gesendet?

Das Kontaktformular sendet folgende Daten per E-Mail:

1. **Name** (`from_name`) - Name des Absenders
2. **E-Mail** (`from_email`) - E-Mail-Adresse des Absenders
3. **Telefon** (`phone`) - Telefonnummer (optional, falls leer: "Nicht angegeben")
4. **Betreff** (`subject`) - Betreff der Nachricht (optional, falls leer: "Kontaktanfrage von [Name]")
5. **Nachricht** (`message`) - Die eigentliche Nachricht
6. **Reply-To** (`reply_to`) - E-Mail-Adresse für Antworten

## Wo wird das E-Mail-Template konfiguriert?

Das E-Mail-Template wird in **EmailJS** konfiguriert:

1. Gehe zu https://www.emailjs.com/
2. Logge dich ein
3. Gehe zu "Email Templates"
4. Öffne das in EmailJS hinterlegte Kontakt-Template (ID in der EmailJS-Konsole, nicht im App-Repo).
5. Stelle sicher, dass alle folgenden Variablen im Template verwendet werden:

### Verfügbare Template-Variablen:

- `{{to_email}}` - Empfänger (info@dj-ollerganove.de)
- `{{from_name}}` - Name des Absenders
- `{{from_email}}` - E-Mail des Absenders
- `{{phone}}` - Telefonnummer
- `{{subject}}` - Betreff
- `{{message}}` - Nachricht
- `{{reply_to}}` - Antwort-Adresse

### Beispiel-Template (HTML):

```html
<h2>Neue Kontaktanfrage von VibesBox</h2>

<p><strong>Name:</strong> {{from_name}}</p>
<p><strong>E-Mail:</strong> {{from_email}}</p>
<p><strong>Telefon:</strong> {{phone}}</p>
<p><strong>Betreff:</strong> {{subject}}</p>

<hr>

<h3>Nachricht:</h3>
<p>{{message}}</p>

<hr>

<p><small>Diese Nachricht wurde über VibesBox gesendet.</small></p>
<p><small>Antworten an: {{reply_to}}</small></p>
```

### Beispiel-Template (Plain Text):

```
Neue Kontaktanfrage von VibesBox

Name: {{from_name}}
E-Mail: {{from_email}}
Telefon: {{phone}}
Betreff: {{subject}}

---
Nachricht:
{{message}}

---
Diese Nachricht wurde über VibesBox gesendet.
Antworten an: {{reply_to}}
```

## Code-Stelle in der App

Die Daten werden in der Funktion `_sendEmailViaEmailJS` in `lib/main.dart` (Zeilen 3268-3312) gesendet.

Die gesendeten Daten findest du in Zeilen 3285-3293:
- `to_email`: 'info@dj-ollerganove.de'
- `from_name`: name
- `from_email`: email (oder 'noreply@dj-ollerganove.de' falls leer)
- `phone`: phone (oder 'Nicht angegeben' falls leer)
- `subject`: subject (oder 'Kontaktanfrage von $name' falls leer)
- `message`: message
- `reply_to`: email (oder 'noreply@dj-ollerganove.de' falls leer)

## Wichtig:

Wenn in der E-Mail nicht alle Felder erscheinen, musst du das EmailJS-Template anpassen und sicherstellen, dass alle Variablen (`{{from_name}}`, `{{from_email}}`, `{{phone}}`, `{{subject}}`, `{{message}}`, `{{reply_to}}`) im Template verwendet werden.




















































