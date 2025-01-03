module;
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <CommCtrl.h>
export module UI;

import WinRT;
import Parser;
import Environment;

size_t constexpr ID_EDIT{ 1 };
size_t constexpr ID_STATIC{ 2 };
size_t constexpr ID_LISTBOX{ 3 };
size_t constexpr ID_ABOUT{ 4 };
size_t constexpr ID_SETTINGS{ 5 };

int ScaleDPI(int x, HWND hWnd) {
    return MulDiv(x, GetDpiForWindow(hWnd), 96);
}

struct WindowData {
    HWND hEdit;
    HWND hStatic;
    HWND hListBox;
    Environment::environment env;
    std::vector<winrt::hstring> history;
};

void ShowAboutDialog(HWND hwnd) {
    MessageBoxW(hwnd, L"Expression Parser\nVersion 1.0\nCreated by Your Name", L"About", MB_OK | MB_ICONINFORMATION);
}

void ShowSettingsDialog(HWND hwnd) {
    MessageBoxW(hwnd, L"Settings dialog not implemented yet.", L"Settings", MB_OK | MB_ICONINFORMATION);
}

void AddToHistory(WindowData* data, std::wstring_view expression, std::wstring_view result) {
    data->history.emplace_back(expression);
    data->history.emplace_back(result);
    data->history.emplace_back(L"");

    SendMessageW(data->hListBox, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(expression.data()));
    SendMessageW(data->hListBox, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(result.data()));
    SendMessageW(data->hListBox, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L""));
    // Scroll to the last entry
    SendMessageW(data->hListBox, WM_VSCROLL, SB_BOTTOM, 0);
}

void UpdateResult(WindowData* data, bool store) {
    wchar_t buffer[1024] = {};
    auto const len{ GetWindowTextW(data->hEdit, buffer, 1024) };
    auto const sv{ std::wstring_view(buffer, len) };
    auto [rname, result, rtype] { Parser::evaluate(sv, data->env) };
    if (rtype == Parser::ResultType::Assignment) {
        if (store) {
            data->env.set(rname, winrt::to_string(result));
            AddToHistory(data, sv, result);
        }
    }
    else if (rtype == Parser::ResultType::Invalid || result.empty()) {
        result = L"Invalid expression";
    }
    else if (store) {
        AddToHistory(data, sv, result);
    }

    SetWindowTextW(data->hStatic, result.c_str());
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
        AppendMenuW(hMenu, MF_STRING, ID_SETTINGS, L"Settings");
        SetMenu(hwnd, hMenu);

        data->hEdit = winrt::check_pointer(CreateWindowExW(0, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL,
            ScaleDPI(12, hwnd), ScaleDPI(220, hwnd), ScaleDPI(460, hwnd), ScaleDPI(24, hwnd),
            hwnd, reinterpret_cast<HMENU>(ID_EDIT), nullptr, nullptr));
        data->hStatic = winrt::check_pointer(CreateWindowExW(0, L"STATIC", L"Enter an expression",
            WS_CHILD | WS_VISIBLE,
            ScaleDPI(12, hwnd), ScaleDPI(260, hwnd), ScaleDPI(460, hwnd), ScaleDPI(24, hwnd),
            hwnd, reinterpret_cast<HMENU>(ID_STATIC), nullptr, nullptr));
        data->hListBox = winrt::check_pointer(CreateWindowExW(0, L"LISTBOX", L"",
            WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_BORDER | LBS_NOTIFY,
            ScaleDPI(12, hwnd), ScaleDPI(12, hwnd), ScaleDPI(460, hwnd), ScaleDPI(200, hwnd),
            hwnd, reinterpret_cast<HMENU>(ID_LISTBOX), nullptr, nullptr));

        auto const hFont{ CreateFontW(ScaleDPI(20, hwnd), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                DEFAULT_QUALITY, DEFAULT_PITCH | FF_SWISS, L"Segoe UI") };

        SendMessageW(data->hListBox, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
        SendMessageW(data->hEdit, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
        SendMessageW(data->hStatic, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);

        // subclass the edit control
        SetWindowSubclass(data->hEdit, EditProc, 0, reinterpret_cast<DWORD_PTR>(data));
        break;
    }
    case WM_COMMAND: {
        if (LOWORD(wParam) == ID_ABOUT) {
            ShowAboutDialog(hwnd);
        } else if (LOWORD(wParam) == ID_SETTINGS) {
            ShowSettingsDialog(hwnd);
        } else if (LOWORD(wParam) == ID_EDIT && HIWORD(wParam) == EN_CHANGE) {
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

        MoveWindow(data->hListBox, ScaleDPI(12, hwnd), ScaleDPI(12, hwnd), ScaleDPI(width - 20, hwnd), ScaleDPI(200, hwnd), TRUE);
        MoveWindow(data->hEdit, ScaleDPI(12, hwnd), ScaleDPI(220, hwnd), ScaleDPI(width - 20, hwnd), ScaleDPI(24, hwnd), TRUE);
        MoveWindow(data->hStatic, ScaleDPI(12, hwnd), ScaleDPI(260, hwnd), ScaleDPI(width - 20, hwnd), ScaleDPI(24, hwnd), TRUE);
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
    export void run_window(HINSTANCE hInstance, int nCmdShow) {
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

        WindowData data;

        HWND const hwnd{
            winrt::check_pointer(CreateWindowExW(
                0, class_name, L"Expression Parser", WS_OVERLAPPEDWINDOW,
                CW_USEDEFAULT, CW_USEDEFAULT,
                MulDiv(500, GetDpiForSystem(), 96),
                MulDiv(400, GetDpiForSystem(), 96),
                nullptr, nullptr, hInstance, &data
        )) };

        ShowWindow(hwnd, nCmdShow);

        MSG msg{};
        while (GetMessageW(&msg, nullptr, 0, 0)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
}