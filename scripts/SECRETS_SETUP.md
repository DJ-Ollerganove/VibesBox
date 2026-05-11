# Einmalige Einrichtung: Git-Push aus Cursor-Agent (Mac)

Das Agent-Terminal kann GitHub **HTTPS** nicht über den macOS-Schlüsselbund anmelden.

1. GitHub → **Settings → Developer settings → Personal access tokens** → Token mit Scope **`repo`** erzeugen.
2. Im Projektroot den Ordner **`secrets_cursor/`** anlegen – auch **im Finder** möglich (kein Name mit führendem Punkt).
3. Datei **`secrets_cursor/cursor_git.env`** anlegen mit genau einer Zeile (siehe auch `scripts/cursor_git_env.example`):

   `GITHUB_PAT=ghp_…`

4. Danach pusht der Agent mit: **`./scripts/git_push.sh`**

Ohne diese Datei bricht `git_push.sh` mit Exitcode **2** ab (absichtlich, damit nichts Unsicheres passiert).
