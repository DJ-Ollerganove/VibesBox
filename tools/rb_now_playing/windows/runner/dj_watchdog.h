#ifndef RUNNER_DJ_WATCHDOG_H_
#define RUNNER_DJ_WATCHDOG_H_

// True wenn argv --dj-watch / -dj-watch enthält.
bool HasDjWatchArgument();

// Leichter Hintergrund-Watcher ohne Flutter-Fenster.
// Startet die UI, sobald eine integrierte DJ-Software läuft.
int RunDjWatchdog();

// Verhindert doppelte UI-Instanzen. true = diese Instanz darf weiterlaufen.
bool AcquireUiSingleInstance();

// HKCU Run-Eintrag setzen/entfernen und Watcher sofort starten.
// Bei disabled: Run-Key entfernen → Watcher beendet sich selbst.
bool SetDjWatchAutostart(bool enabled);

// Convenience: Run-Key setzen + Watcher starten (idempotent).
bool EnsureDjWatchAutostart();

// Run-Eintrag entfernen (z. B. Deinstallation).
bool ClearDjWatchAutostart();

// True wenn der Run-Eintrag vorhanden ist.
bool IsDjWatchAutostartEnabled();

// Nutzer hat die UI per X geschlossen: bis alle DJ-Apps beendet sind
// nicht automatisch neu starten. Autostart-Einstellung bleibt an.
void MarkUiUserDismissed();

#endif  // RUNNER_DJ_WATCHDOG_H_
