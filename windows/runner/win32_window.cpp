#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

}  // namespace

class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() {
    if (registered_) {
      UnregisterClass(window_class_name_.c_str(), nullptr);
    }
  }

  const wchar_t* GetWindowClass() {
    if (!registered_) {
      WNDCLASS window_class = {};
      window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
      window_class.lpszClassName = window_class_name_.c_str();
      window_class.style = CS_HREDRAW | CS_VREDRAW;
      window_class.cbClsExtra = 0;
      window_class.cbWndExtra = 0;
      window_class.hInstance = GetModuleHandle(nullptr);
      window_class.hIcon =
          LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
      window_class.hbrBackground = 0;

      if (RegisterClass(&window_class) == 0) {
        return nullptr;
      }
      registered_ = true;
    }
    return window_class_name_.c_str();
  }

 private:
  bool registered_ = false;
  std::wstring window_class_name_ = L"FLUTTER_RUNNER_WIN32_WINDOW";
};

Win32Window::Win32Window() {}

Win32Window::~Win32Window() {
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  static WindowClassRegistrar class_registrar;
  const wchar_t* window_class = class_registrar.GetWindowClass();
  if (window_class == nullptr) {
    return false;
  }

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);

  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  return true;
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
}

void Win32Window::SetChildWindow(HWND child_window) {
  child_content_ = child_window;
  SetParent(child_window, window_handle_);
  RECT frame = GetClientArea();
  MoveWindow(child_window, 0, 0, frame.right - frame.left,
             frame.bottom - frame.top, TRUE);
}

HWND Win32Window::GetHandle() const {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      Destroy();
      return 0;

    case WM_DESTROY:
      window_handle_ = nullptr;
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_SIZE:
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, 0, 0, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
  }

  return DefWindowProc(hwnd, message, wparam, lparam);
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                       UINT const message,
                                       WPARAM const wparam,
                                       LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
    auto wnd = reinterpret_cast<Win32Window*>(cs->lpCreateParams);
    wnd->window_handle_ = window;
  }

  Win32Window* window_pointer = GetThisFromHandle(window);
  if (window_pointer) {
    return window_pointer->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

// static
Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}
