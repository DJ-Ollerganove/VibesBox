#ifndef RUNNER_DJ_WATCHDOG_H_
#define RUNNER_DJ_WATCHDOG_H_

// True wenn argv --dj-watch / -dj-watch enthält.
bool HasDjWatchArgument();

// Leichter Hintergrund-Watcher ohne Flutter-Fenster.
// Startet die UI, sobald eine integrierte DJ-Software läuft.
int RunDjWatchdog();

// Verhindert doppelte UI-Instanzen. true = diese Instanz darf weiterlaufen.
bool AcquireUiSingleInstance();

// Immer: HKCU-Run setzen (idempotent) und Watcher starten falls nötig.
bool EnsureDjWatchAutostart();

// Run-Eintrag entfernen (Deinstallation). Watcher beendet sich, wenn EXE fehlt.
bool ClearDjWatchAutostart();

// True wenn der Run-Eintrag vorhanden ist.
bool IsDjWatchAutostartEnabled();

#endif  // RUNNER_DJ_WATCHDOG_H_
