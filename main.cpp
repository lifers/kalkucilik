#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
import UI;

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow) {
    UI::run_window(hInstance, nCmdShow);

    return 0;
}