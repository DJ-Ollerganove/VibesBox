# EmailJS Setup für Kontaktformular

## Schritt 1: EmailJS Account erstellen

1. Gehe zu https://www.emailjs.com/
2. Klicke auf "Sign Up" (kostenlos)
3. Erstelle einen Account

## Schritt 2: Email Service hinzufügen

1. In EmailJS Dashboard: "Email Services" → "Add New Service"
2. Wähle "Gmail" aus
3. Folge den Anweisungen, um Gmail zu verbinden
4. Notiere die **Service ID**

## Schritt 3: Email Template erstellen

1. In EmailJS Dashboard: "Email Templates" → "Create New Template"
2. Verwende folgende Template-Variablen:
   - `{{to_email}}` - Empfänger (info@dj-ollerganove.de)
   - `{{from_name}}` - Name des Absenders
   - `{{from_email}}` - Email des Absenders
   - `{{phone}}` - Telefonnummer
   - `{{subject}}` - Betreff
   - `{{message}}` - Nachricht
   - `{{reply_to}}` - Antwort-Adresse

3. Template-Beispiel:
   ```
   Von: {{from_name}} ({{from_email}})
   Telefon: {{phone}}
   Betreff: {{subject}}
   
   Nachricht:
   {{message}}
   ```

4. Notiere die **Template ID**

## Schritt 4: Public Key und User ID finden

1. In EmailJS Dashboard: "Account" → "General"
2. Notiere:
   - **User ID** (Public Key)
   - **Public Key** (falls separat angezeigt)

## Schritt 5: Werte in die App eintragen

Öffne `lib/main.dart` und suche nach `_sendEmailViaEmailJS` Funktion.

Ersetze:
- `YOUR_SERVICE_ID` mit deiner Service ID
- `YOUR_TEMPLATE_ID` mit deiner Template ID
- `YOUR_PUBLIC_KEY` mit deinem Public Key
- `YOUR_USER_ID` mit deiner User ID

## Schritt 6: Testen

1. App neu starten
2. Kontaktformular ausfüllen
3. Nachricht senden
4. Prüfe dein Email-Postfach (info@dj-ollerganove.de)

## Kosten

EmailJS ist kostenlos für:
- 200 Emails/Monat
- Für mehr benötigst du einen bezahlten Plan





















































