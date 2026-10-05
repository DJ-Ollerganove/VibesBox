#ifndef RUNNER_DJ_WATCHDOG_H_
#define RUNNER_DJ_WATCHDOG_H_

#include <string>

// True wenn argv --dj-watch / -dj-watch enthält.
bool HasDjWatchArgument();

// Leichter Hintergrund-Watcher ohne Flutter-Fenster.
// Startet die UI, sobald eine integrierte DJ-Software läuft.
int RunDjWatchdog();

// Verhindert doppelte UI-Instanzen. true = diese Instanz darf weiterlaufen.
bool AcquireUiSingleInstance();

// HKCU Run-Eintrag setzen/entfernen und Watcher sofort starten/stoppen.
bool SetDjWatchAutostart(bool enabled);

// Aktuellen Zustand des Run-Eintrags.
bool IsDjWatchAutostartEnabled();

#endif  // RUNNER_DJ_WATCHDOG_H_
