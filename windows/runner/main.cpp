#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shobjidl.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Must match the AppUserModelID on the installer's shortcuts so the running
  // window, pinned shortcut and media/notification integration group together.
  ::SetCurrentProcessExplicitAppUserModelID(L"app.fermata.player");

#if defined(_DEBUG)
  // Debug builds only: attach to the parent console when present (e.g.,
  // 'flutter run') or create a new console when running with a debugger.
  // The runner is a /SUBSYSTEM:WINDOWS GUI app (add_executable(... WIN32 ...)
  // in runner/CMakeLists.txt), so profile/release builds never attach to or
  // open a console window.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
#endif

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  // Logical (DPI-independent) size; Dart (window_manager) may restore the
  // user's last window geometry afterwards.
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Fermata", origin, size)) {
    return EXIT_FAILURE;
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
