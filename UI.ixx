module;
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
export module UI;

namespace UI {
    export void run_window(HINSTANCE hInstance, int nCmdShow);
}