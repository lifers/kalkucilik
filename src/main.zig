const std = @import("std");
const stdwin = @import("std").os.windows;
const win = @import("win32");
const wf = win.foundation;
const wm = win.ui.windows_and_messaging;
const wuc = win.ui.controls;
const eh = @import("err_handling.zig");
const wd = @import("window_data.zig");

const assert = std.debug.assert;

pub fn main() !void {
    const class_name = "Calc Window Class";
    const wg = win.graphics.gdi;
    const wsll = win.system.library_loader;
    const hInstance = eh.checkNotNull(
        wf.HINSTANCE,
        wsll.GetModuleHandleA(null),
        "GetModuleHandleA failed",
    );
    const wc = std.mem.zeroInit(wm.WNDCLASSEXA, .{
        .cbSize = @sizeOf(wm.WNDCLASSEXA),
        .lpfnWndProc = wd.windowProc,
        .cbWndExtra = @sizeOf(*wd.MainWindow),
        .hInstance = hInstance,
        .hbrBackground = @as(?wg.HBRUSH, @ptrFromInt(@as(usize, @intFromEnum(wm.COLOR_WINDOW)))),
        .lpszClassName = class_name,
    });
    _ = eh.checkNotEqual(u16, wm.RegisterClassExA(&wc), 0, "RegisterClassExA failed");

    eh.checkEqual(wf.BOOL, wuc.InitCommonControlsEx(&.{
        .dwICC = .{ .LISTVIEW_CLASSES = 1, .STANDARD_CLASSES = 1 },
        .dwSize = @sizeOf(wuc.INITCOMMONCONTROLSEX),
    }), 1, "InitCommonControlsEx failed");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer eh.checkEqual(std.heap.Check, gpa.deinit(), .ok, "memory leak detected");

    var mw: wd.MainWindow = undefined;
    mw.init(class_name, hInstance, gpa.allocator());
    defer mw.deinit();

    eh.checkEqual(wf.BOOL, mw.show(.{ .SHOWNORMAL = 1 }), 0, "ShowWindow failed");

    var msg: wm.MSG = std.mem.zeroInit(wm.MSG, .{});
    while (wm.GetMessageA(&msg, null, 0, 0) != 0) {
        _ = wm.TranslateMessage(&msg);
        _ = wm.DispatchMessageA(&msg);
    }
}
