module;
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <CommCtrl.h>
#include <cstdint>
module UI;

import WinRT;
import Parser;
import Environment;

size_t constexpr ID_EDIT{ 1 };
size_t constexpr ID_STATIC{ 2 };
size_t constexpr ID_LISTBOX{ 3 };
size_t constexpr ID_ABOUT{ 4 };
size_t constexpr ID_HELP{ 5 };
size_t constexpr ID_VARVIEW{ 6 };

struct Rect {
    int32_t x, y, w, h;

    constexpr Rect() : x{ CW_USEDEFAULT }, y{ CW_USEDEFAULT }, w{ CW_USEDEFAULT }, h{ CW_USEDEFAULT } {}
    constexpr Rect(int32_t x, int32_t y, int32_t w, int32_t h) : x{ x }, y{ y }, w{ w }, h{ h } {}
    constexpr Rect(int32_t w, int32_t h) : x{ CW_USEDEFAULT }, y{ CW_USEDEFAULT }, w{ w }, h{ h } {}
};

struct Window {
    HWND handle{ nullptr };
    Rect dim;

    Window() = default;

    void emplace(
        LPCWSTR className,
        DWORD dwStyle,
        size_t id,
        LPCWSTR windowName = L"",
        Rect r = Rect(),
        HWND hParent = nullptr,
        HINSTANCE hInstance = nullptr,
        LPVOID lpParam = nullptr
    ) {
        this->dim = r;
        this->handle = CreateWindowW(
            className, windowName, dwStyle, r.x, r.y, r.w, r.h,
            hParent, reinterpret_cast<HMENU>(id), hInstance, lpParam);
    }

    uint32_t GetDPI() const {
        return GetDpiForWindow(this->handle);
    }

    void SetFont(HFONT hFont) const {
        SendMessageW(this->handle, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
    }

    void UpdatePosition() const {
        MoveWindow(this->handle, this->dim.x, this->dim.y, this->dim.w, this->dim.h, TRUE);
    }

    void FillWidth(int32_t width) {
        this->dim.w = width;
        this->UpdatePosition();
    }

    void AlignRight(int32_t width) {
        this->dim.x = width - this->dim.w;
        this->UpdatePosition();
    }

    ~Window() {
        if (this->handle) {
            DestroyWindow(this->handle);
        }
    }
};

struct WindowData {
    Window hMain;
    Window hEdit;
    Window hStatic;
    Window hListBox;
    Window hVarView;
    Environment::environment env;
    std::vector<winrt::hstring> history;
    uint32_t dpi;

    void UpdateDPI() {
        this->dpi = this->hMain.GetDPI();
    }

    int32_t ScaleSize(int32_t size) const {
        return MulDiv(size, this->dpi, 96);
    }

    Rect ScaledRect(int32_t x, int32_t y, int32_t w, int32_t h) const {
        return {
            this->ScaleSize(x),
            this->ScaleSize(y),
            this->ScaleSize(w),
            this->ScaleSize(h)
        };
    }

    WindowData(LPCWSTR className, HINSTANCE hInstance) {
        this->dpi = GetDpiForSystem();
        this->hMain.emplace(
            className, WS_OVERLAPPEDWINDOW, 0, L"Kalkucilik",
            Rect(this->ScaleSize(600), this->ScaleSize(400)), nullptr, hInstance, this);
    }
};

void ShowAboutDialog(HWND hwnd) {
    MessageBoxW(hwnd, L"Kalkucilik\nVersion 1.0 \"Halifax\"\nCopyright © 2024-2025 Nagata Aptana", L"About", MB_OK | MB_ICONINFORMATION);
}

void ShowHelpDialog(HWND hwnd) {
    MessageBoxW(hwnd, L"Kalkucilik is a tiny calculator app that supports basic arithmetic operations and variable assignment.\n\n"
        L"Operators:\n"
        L"  +  Addition\n"
        L"  -  Subtraction\n"
        L"  *  Multiplication\n"
        L"  /  Division\n"
        L"  ^  Exponentiation\n\n"
        L"Functions:\n"
        L"  sqrt(x)  Square root\n"
        L"  cbrt(x)  Cube root\n"
        L"  ln(x)    Natural logarithm\n"
        L"  sin(x)   Sine\n"
        L"  cos(x)   Cosine\n"
        L"  tan(x)   Tangent\n"
        L"  abs(x)   Absolute value\n\n"
        L"Constants:\n"
        L"  pi  3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679\n"
        L"  e   2.7182818284590452353602874713526624977572470936999595749669676277240766303535475945713821785251664274\n\n"
        L"Variable assignment:\n"
        L"  Start an assignment with 'let' followed by a variable name and an expression.\n"
        L"  Variable names must start with a letter and can contain letters and underscores.\n"
        L"  Example: let x = 5 + 3\n\n"
        L"Press Enter to evaluate an expression.\n", L"Help", MB_OK | MB_ICONINFORMATION);
}

void AddToHistory(WindowData* data, std::wstring_view expression, std::wstring_view result) {
    data->history.emplace_back(expression);
    data->history.emplace_back(result);
    data->history.emplace_back(L"");

    SendMessageW(data->hListBox.handle, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(expression.data()));
    SendMessageW(data->hListBox.handle, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(result.data()));
    SendMessageW(data->hListBox.handle, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L""));
    // Scroll to the last entry
    SendMessageW(data->hListBox.handle, WM_VSCROLL, SB_BOTTOM, 0);
}

void UpdateVariableView(WindowData const* data) {
    ListView_DeleteAllItems(data->hVarView.handle);
    for (auto const& [name, value] : data->env.internal_map()) {
        auto const wName{ winrt::to_hstring(name) };
        auto const wValue{ winrt::to_hstring(value) };
        LVITEMW item{
            .mask = LVIF_TEXT,
            .iItem = 0,
            .iSubItem = 0,
            .pszText = LPWSTR(wName.c_str()),
        };
        ListView_InsertItem(data->hVarView.handle, &item);
        item.iSubItem = 1;
        item.pszText = LPWSTR(wValue.c_str());
        ListView_SetItem(data->hVarView.handle, &item);
    }
}

void UpdateResult(WindowData* data, bool store) {
    wchar_t buffer[1024] = {};
    auto const len{ GetWindowTextW(data->hEdit.handle, buffer, 1024) };
    auto const sv{ std::wstring_view(buffer, len) };
    auto [rname, result, rtype] { Parser::evaluate(sv, data->env) };
    if (rtype == Parser::ResultType::Assignment) {
        if (store) {
            data->env.set(rname, winrt::to_string(result));
            AddToHistory(data, sv, result);
            UpdateVariableView(data);
        }
    }
    else if (rtype == Parser::ResultType::Invalid || result.empty()) {
        result = L"Invalid expression";
    }
    else if (store) {
        AddToHistory(data, sv, result);
    }

    SetWindowTextW(data->hStatic.handle, result.c_str());
}

LRESULT CALLBACK EditProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
    auto const data{ reinterpret_cast<WindowData*>(dwRefData) };
    __assume(data != nullptr);

    switch (uMsg) {
    case WM_KEYDOWN:
        if (wParam == VK_RETURN) {
            UpdateResult(data, true);
        }
        break;
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_CREATE: {
        auto const create_struct{ reinterpret_cast<LPCREATESTRUCTW>(lParam) };
        auto const data{ reinterpret_cast<WindowData*>(create_struct->lpCreateParams) };
        __assume(data != nullptr);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(data));

        // Create menu bar
        HMENU const hMenu{ CreateMenu() };

        AppendMenuW(hMenu, MF_STRING, ID_ABOUT, L"About");
        AppendMenuW(hMenu, MF_STRING, ID_HELP, L"Help");
        SetMenu(hwnd, hMenu);

        data->dpi = GetDpiForWindow(hwnd);
        auto const rEdit{ data->ScaledRect(12, 220, 460, 24) };
        auto const rStatic{ data->ScaledRect(12, 260, 460, 24) };
        auto const rListBox{ data->ScaledRect(12, 12, 220, 200) };
        auto const rVarView{ data->ScaledRect(240, 12, 120, 180) };

        data->hEdit.emplace(
            WC_EDITW, WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, ID_EDIT, L"", rEdit, hwnd);
        data->hStatic.emplace(
            WC_STATICW, WS_CHILD | WS_VISIBLE, ID_STATIC, L"Enter an expression", rStatic, hwnd);
        data->hListBox.emplace(
            WC_LISTBOXW, WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_BORDER | LBS_NOTIFY, ID_LISTBOX, L"", rListBox, hwnd);
        data->hVarView.emplace(
            WC_LISTVIEWW, WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_BORDER | LVS_REPORT, ID_VARVIEW, L"", rVarView, hwnd);

        auto const hFont{ CreateFontW(data->ScaleSize(20), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                DEFAULT_QUALITY, DEFAULT_PITCH | FF_SWISS, L"Segoe UI") };

        data->hEdit.SetFont(hFont);
        data->hStatic.SetFont(hFont);
        data->hListBox.SetFont(hFont);
        data->hVarView.SetFont(hFont);

        LVCOLUMNW col{
            .mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM,
            .cx = data->ScaleSize(60),
            .pszText = LPWSTR(L"Variable"),
        };
        ListView_InsertColumn(data->hVarView.handle, 0, &col);

        col.pszText = LPWSTR(L"Value");
        col.cx = data->ScaleSize(60);
        ListView_InsertColumn(data->hVarView.handle, 1, &col);

        // subclass the edit control
        SetWindowSubclass(data->hEdit.handle, EditProc, 0, reinterpret_cast<DWORD_PTR>(data));
        break;
    }
    case WM_COMMAND: {
        if (LOWORD(wParam) == ID_ABOUT) {
            ShowAboutDialog(hwnd);
        }
        else if (LOWORD(wParam) == ID_HELP) {
            ShowHelpDialog(hwnd);
        }
        else if (LOWORD(wParam) == ID_EDIT && HIWORD(wParam) == EN_CHANGE) {
            auto const data{ reinterpret_cast<WindowData*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA)) };
            __assume(data != nullptr);
            UpdateResult(data, false);
        }
        break;
    }
    case WM_SIZE: {
        auto const width{ LOWORD(lParam) };
        auto const height{ HIWORD(lParam) };
        auto const data{ reinterpret_cast<WindowData*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA)) };
        __assume(data != nullptr);

        data->UpdateDPI();
        auto const rtlPadding{ data->ScaleSize(12) };
        data->hVarView.AlignRight(width - rtlPadding);
        data->hListBox.FillWidth(data->hVarView.dim.x - 2 * rtlPadding);
        data->hEdit.FillWidth(width - 2 * rtlPadding);
        data->hStatic.FillWidth(width - 2 * rtlPadding);
        InvalidateRect(hwnd, nullptr, TRUE);
        break;
    }
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, uMsg, wParam, lParam);
}


namespace UI {
    void run_window(HINSTANCE hInstance, int nCmdShow) {
        auto constexpr class_name{ L"CalculatorWindowClass" };

        WNDCLASSEXW const wc{
            .cbSize = sizeof(WNDCLASSEXW),
            .lpfnWndProc = WindowProc,
            .cbWndExtra = sizeof(WindowData*),
            .hInstance = hInstance,
            .hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW),
            .lpszClassName = class_name,
        };

        RegisterClassExW(&wc);

        WindowData data(class_name, hInstance);
        ShowWindow(data.hMain.handle, nCmdShow);

        MSG msg{};
        while (GetMessageW(&msg, nullptr, 0, 0)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
}