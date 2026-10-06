#include "dj_watchdog.h"

#include <windows.h>
#include <tlhelp32.h>
#include <shellapi.h>

#include <algorithm>
#include <string>
#include <vector>

namespace {

constexpr wchar_t kWatchMutex[] = L"Local\\VibesBoxSyncDjWatch";
constexpr wchar_t kUiMutex[] = L"Local\\VibesBoxSyncUI";
constexpr wchar_t kRunValueName[] = L"VibesBoxSyncDjWatch";
constexpr DWORD kPollMs = 2500;

std::wstring ToLower(std::wstring s) {
  std::transform(s.begin(), s.end(), s.begin(), [](wchar_t c) {
    return static_cast<wchar_t>(::towlower(c));
  });
  return s;
}

std::wstring ExePath() {
  wchar_t buf[MAX_PATH];
  DWORD n = ::GetModuleFileNameW(nullptr, buf, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return L"";
  }
  return std::wstring(buf, n);
}

bool ExeStillInstalled() {
  const std::wstring exe = ExePath();
  if (exe.empty()) {
    return false;
  }
  const DWORD attrs = ::GetFileAttributesW(exe.c_str());
  return attrs != INVALID_FILE_ATTRIBUTES &&
         (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

bool HasArg(const std::wstring& needle) {
  int argc = 0;
  LPWSTR* argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (!argv) {
    return false;
  }
  bool found = false;
  for (int i = 0; i < argc; ++i) {
    std::wstring a = ToLower(argv[i] ? argv[i] : L"");
    if (a == needle) {
      found = true;
      break;
    }
  }
  ::LocalFree(argv);
  return found;
}

// Prozessnamen (ohne Pfad), lowercase – keep in sync with Mac DjWatchdog.swift
bool IsIntegratedDjProcess(const std::wstring& image_lower) {
  if (image_lower.find(L"vibesbox") != std::wstring::npos) {
    return false;
  }
  if (image_lower.find(L"rekordbox") != std::wstring::npos &&
      image_lower.find(L"agent") == std::wstring::npos) {
    return true;
  }
  if (image_lower.find(L"serato") != std::wstring::npos) {
    return true;
  }
  if (image_lower.find(L"mixxx") != std::wstring::npos) {
    return true;
  }
  if (image_lower.find(L"traktor") != std::wstring::npos) {
    return true;
  }
  if (image_lower.find(L"virtualdj") != std::wstring::npos ||
      image_lower.find(L"virtual dj") != std::wstring::npos ||
      image_lower.find(L"atomix") != std::wstring::npos) {
    return true;
  }
  if (image_lower.find(L"djay") != std::wstring::npos) {
    return true;
  }
  if (image_lower.find(L"enginedj") != std::wstring::npos ||
      image_lower.find(L"engine dj") != std::wstring::npos ||
      image_lower.find(L"engine prime") != std::wstring::npos) {
    return true;
  }
  // Engine.exe allein ist zu generisch – nur mit Leerzeichen/Brand.
  if (image_lower == L"engine.exe") {
    return true;
  }
  return false;
}

bool ProcessListContainsDj() {
  HANDLE snap =
      ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snap == INVALID_HANDLE_VALUE) {
    return false;
  }
  PROCESSENTRY32W pe{};
  pe.dwSize = sizeof(pe);
  bool found = false;
  if (::Process32FirstW(snap, &pe)) {
    do {
      std::wstring name = ToLower(pe.szExeFile);
      if (IsIntegratedDjProcess(name)) {
        found = true;
        break;
      }
    } while (::Process32NextW(snap, &pe));
  }
  ::CloseHandle(snap);
  return found;
}

bool MutexAlreadyExists(const wchar_t* name) {
  HANDLE h = ::OpenMutexW(SYNCHRONIZE, FALSE, name);
  if (h) {
    ::CloseHandle(h);
    return true;
  }
  return false;
}

bool IsUiRunning() { return MutexAlreadyExists(kUiMutex); }

std::wstring DismissMarkerPath() {
  wchar_t appdata[MAX_PATH];
  DWORD n = ::GetEnvironmentVariableW(L"APPDATA", appdata, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return L"";
  }
  return std::wstring(appdata) + L"\\VibesBoxRbTool\\watch_dismissed";
}

bool EnsureSupportDir() {
  wchar_t appdata[MAX_PATH];
  DWORD n = ::GetEnvironmentVariableW(L"APPDATA", appdata, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return false;
  }
  const std::wstring dir = std::wstring(appdata) + L"\\VibesBoxRbTool";
  if (::CreateDirectoryW(dir.c_str(), nullptr) ||
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    return true;
  }
  return false;
}

bool IsUiDismissed() {
  const std::wstring path = DismissMarkerPath();
  if (path.empty()) {
    return false;
  }
  const DWORD attrs = ::GetFileAttributesW(path.c_str());
  return attrs != INVALID_FILE_ATTRIBUTES &&
         (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

void ClearUiDismissed() {
  const std::wstring path = DismissMarkerPath();
  if (!path.empty()) {
    ::DeleteFileW(path.c_str());
  }
}

void SetUiDismissed() {
  if (!EnsureSupportDir()) {
    return;
  }
  const std::wstring path = DismissMarkerPath();
  if (path.empty()) {
    return;
  }
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    ::CloseHandle(file);
  }
}

void LaunchUi() {
  if (IsUiRunning()) {
    return;
  }
  const std::wstring exe = ExePath();
  if (exe.empty()) {
    return;
  }
  STARTUPINFOW si{};
  si.cb = sizeof(si);
  PROCESS_INFORMATION pi{};
  // Leere CommandLine → normale UI (ohne --dj-watch).
  std::wstring cmd = L"\"" + exe + L"\"";
  std::vector<wchar_t> mutable_cmd(cmd.begin(), cmd.end());
  mutable_cmd.push_back(L'\0');
  if (::CreateProcessW(exe.c_str(), mutable_cmd.data(), nullptr, nullptr, FALSE,
                       0, nullptr, nullptr, &si, &pi)) {
    ::CloseHandle(pi.hThread);
    ::CloseHandle(pi.hProcess);
  }
}

HKEY OpenRunKey(bool write) {
  HKEY key = nullptr;
  REGSAM access = KEY_READ | (write ? KEY_WRITE : 0);
  if (::RegOpenKeyExW(HKEY_CURRENT_USER,
                      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0,
                      access, &key) != ERROR_SUCCESS) {
    return nullptr;
  }
  return key;
}

std::wstring RunCommandLine() {
  const std::wstring exe = ExePath();
  if (exe.empty()) {
    return L"";
  }
  return L"\"" + exe + L"\" --dj-watch";
}

bool WriteRunKey() {
  HKEY key = OpenRunKey(true);
  if (!key) {
    return false;
  }
  const std::wstring cmd = RunCommandLine();
  if (cmd.empty()) {
    ::RegCloseKey(key);
    return false;
  }
  const bool ok =
      ::RegSetValueExW(
          key, kRunValueName, 0, REG_SZ,
          reinterpret_cast<const BYTE*>(cmd.c_str()),
          static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t))) ==
      ERROR_SUCCESS;
  ::RegCloseKey(key);
  return ok;
}

void LaunchWatchdogDetached() {
  if (MutexAlreadyExists(kWatchMutex)) {
    return;
  }
  const std::wstring exe = ExePath();
  if (exe.empty()) {
    return;
  }
  std::wstring cmd = L"\"" + exe + L"\" --dj-watch";
  STARTUPINFOW si{};
  si.cb = sizeof(si);
  PROCESS_INFORMATION pi{};
  std::vector<wchar_t> mutable_cmd(cmd.begin(), cmd.end());
  mutable_cmd.push_back(L'\0');
  if (::CreateProcessW(exe.c_str(), mutable_cmd.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    ::CloseHandle(pi.hThread);
    ::CloseHandle(pi.hProcess);
  }
}

}  // namespace

bool HasDjWatchArgument() {
  return HasArg(L"--dj-watch") || HasArg(L"-dj-watch");
}

bool AcquireUiSingleInstance() {
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kUiMutex);
  if (!mutex) {
    return true;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(mutex);
    // Bestehendes Fenster in den Vordergrund holen, falls gefunden.
    HWND hwnd = ::FindWindowW(nullptr, L"VibesBox Sync");
    if (hwnd) {
      if (::IsIconic(hwnd)) {
        ::ShowWindow(hwnd, SW_RESTORE);
      }
      ::SetForegroundWindow(hwnd);
    }
    return false;
  }
  // Mutex-Handle leaken absichtlich: lebt bis Prozessende.
  return true;
}

bool IsDjWatchAutostartEnabled() {
  HKEY key = OpenRunKey(false);
  if (!key) {
    return false;
  }
  wchar_t value[1024];
  DWORD type = 0;
  DWORD size = sizeof(value);
  const LONG rc =
      ::RegQueryValueExW(key, kRunValueName, nullptr, &type,
                         reinterpret_cast<LPBYTE>(value), &size);
  ::RegCloseKey(key);
  return rc == ERROR_SUCCESS && type == REG_SZ;
}

bool SetDjWatchAutostart(bool enabled) {
  if (enabled) {
    const bool ok = WriteRunKey();
    if (ok) {
      LaunchWatchdogDetached();
    }
    return ok;
  }
  HKEY key = OpenRunKey(true);
  if (!key) {
    return false;
  }
  ::RegDeleteValueW(key, kRunValueName);
  ::RegCloseKey(key);
  // Laufender Watcher prüft periodisch den Run-Key und beendet sich.
  return true;
}

bool EnsureDjWatchAutostart() { return SetDjWatchAutostart(true); }

bool ClearDjWatchAutostart() { return SetDjWatchAutostart(false); }

int RunDjWatchdog() {
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kWatchMutex);
  if (!mutex) {
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(mutex);
    return EXIT_SUCCESS;
  }

  // Beobachten solange Run-Key gesetzt und EXE vorhanden.
  // Run-Key entfernt (Einstellung aus) → sauber beenden.
  // EXE fehlt (Deinstallation) → ebenfalls beenden.
  // Nach manuellem X: nicht neu starten, bis alle DJ-Apps weg sind.
  for (;;) {
    if (!ExeStillInstalled()) {
      break;
    }
    if (!IsDjWatchAutostartEnabled()) {
      break;
    }
    const bool dj_running = ProcessListContainsDj();
    if (!dj_running) {
      // Nächste DJ-Session darf Sync wieder automatisch öffnen.
      ClearUiDismissed();
    } else if (!IsUiRunning() && !IsUiDismissed()) {
      LaunchUi();
    }
    ::Sleep(kPollMs);
  }

  ::CloseHandle(mutex);
  return EXIT_SUCCESS;
}

void MarkUiUserDismissed() { SetUiDismissed(); }
