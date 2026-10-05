#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "resource.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
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
  // Hochkant wie macOS (Content ~315x500), nicht Querformat.
  Win32Window::Size size(360, 640);
  if (!window.Create(L"VibesBox Sync", origin, size)) {
    return EXIT_FAILURE;
  }
  // App-Icon explizit setzen (Taskbar + Titelleiste).
  if (HWND hwnd = window.GetHandle()) {
    HICON icon = reinterpret_cast<HICON>(LoadImage(
        GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
        0, 0, LR_DEFAULTSIZE | LR_SHARED));
    if (icon) {
      SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(icon));
      SendMessage(hwnd, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(icon));
    }
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
