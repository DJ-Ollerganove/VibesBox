#include "flutter_window.h"

#include <optional>
#include <variant>

#include "dj_watchdog.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "vibesbox_sync/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto& method = call.method_name();
        HWND hwnd = GetHandle();
        if (method == "setAlwaysOnTop") {
          bool on = false;
          if (const auto* args = call.arguments()) {
            if (const auto* flag = std::get_if<bool>(args)) {
              on = *flag;
            }
          }
          if (hwnd != nullptr) {
            ::SetWindowPos(hwnd, on ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                           SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "setLaunchWithDj") {
          bool on = false;
          if (const auto* args = call.arguments()) {
            if (const auto* flag = std::get_if<bool>(args)) {
              on = *flag;
            }
          }
          result->Success(flutter::EncodableValue(SetDjWatchAutostart(on)));
          return;
        }
        if (method == "ensureDjWatchAutostart") {
          result->Success(flutter::EncodableValue(EnsureDjWatchAutostart()));
          return;
        }
        if (method == "isLaunchWithDj") {
          result->Success(
              flutter::EncodableValue(IsDjWatchAutostartEnabled()));
          return;
        }
        if (method == "startDrag") {
          // Wie macOS isMovableByWindowBackground — Drag aus Flutter-Chrome.
          if (hwnd != nullptr) {
            ::ReleaseCapture();
            ::SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "minimize") {
          if (hwnd != nullptr) {
            ::ShowWindow(hwnd, SW_MINIMIZE);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "close") {
          if (hwnd != nullptr) {
            ::PostMessage(hwnd, WM_CLOSE, 0, 0);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // X / Schließen: Watcher soll Sync nicht sofort wieder öffnen,
  // solange die DJ-Software noch läuft (Einstellung bleibt an).
  MarkUiUserDismissed();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Frameless-Hit-Testing / NC-Calc vor Flutter, sonst bleibt HTCLIENT.
  if (message == WM_NCHITTEST || message == WM_NCCALCSIZE ||
      message == WM_NCACTIVATE || message == WM_NCPAINT) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
