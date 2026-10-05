#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "dj_watchdog.h"
#include "flutter_window.h"
#include "resource.h"
#include "utils.h"

namespace {

#ifndef ICON_SMALL2
#define ICON_SMALL2 2
#endif

void ApplyAppIcon(HWND hwnd) {
  if (!hwnd) {
    return;
  }
  HINSTANCE module = GetModuleHandle(nullptr);
  // Ohne AppUserModelID nutzt die Taskleiste diese Fenster-Icons.
  HICON big = reinterpret_cast<HICON>(LoadImage(
      module, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
      GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), 0));
  HICON small_icon = reinterpret_cast<HICON>(LoadImage(
      module, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0));
  if (big) {
    SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big));
  }
  if (small_icon) {
    SendMessage(hwnd, WM_SETICON, ICON_SMALL,
                reinterpret_cast<LPARAM>(small_icon));
    // Taskleisten-Button (Win10/11) nutzt oft ICON_SMALL2.
    SendMessage(hwnd, WM_SETICON, ICON_SMALL2,
                reinterpret_cast<LPARAM>(small_icon));
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (HasDjWatchArgument()) {
    return RunDjWatchdog();
  }

  if (!AcquireUiSingleInstance()) {
    return EXIT_SUCCESS;
  }

  // DJ-Watchdog: Registrierung über Einstellungen (Default an) beim UI-Load.
  // Kein erzwungenes Enable hier – sonst überschreibt es einen bewussten Aus-Haken.

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(40, 40);
  // Hochkant wie macOS (Content ~360x640).
  Win32Window::Size size(360, 640);
  if (!window.Create(L"VibesBox Sync", origin, size)) {
    return EXIT_FAILURE;
  }
  // App-Icon explizit setzen (Taskbar + Titelleiste).
  if (HWND hwnd = window.GetHandle()) {
    ApplyAppIcon(hwnd);
    // Fenstergroesse nach Create nochmal erzwingen (Client ~360x640).
    RECT rc = {0, 0, 360, 640};
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
    SetWindowPos(hwnd, nullptr, 40, 40, rc.right - rc.left, rc.bottom - rc.top,
                 SWP_NOZORDER | SWP_NOACTIVATE);
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
