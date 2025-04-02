const std = @import("std");
const win = @import("win32");
const wf = win.foundation;
const wm = win.ui.windows_and_messaging;
const wg = win.globalization;

pub fn checkEqual(T: type, a: T, b: T, msg: [:0]const u8) void {
    if (a != b) {
        fatal(msg);
    }
}

pub fn checkNotEqual(T: type, a: T, b: T, msg: [:0]const u8) T {
    if (a == b) {
        fatal(msg);
    }
    return a;
}

pub fn checkNotNull(T: type, a: ?T, msg: [:0]const u8) T {
    if (a == null) {
        fatal(msg);
    } else {
        return a.?;
    }
}

pub fn checkUErrorCode(msg: [:0]const u8, status: wg.UErrorCode) void {
    if (@intFromEnum(status) > @intFromEnum(wg.U_ZERO_ERROR)) {
        const s = wg.u_errorName(status);
        _ = wm.MessageBoxA(null, s, msg, wm.MB_ICONERROR);
        win.system.threading.ExitProcess(1);
    }
}

pub fn fatal(str: [:0]const u8) noreturn {
    const e = wf.GetLastError();
    const s: wf.PSTR = undefined; // will be freed by the OS when the process exits
    const wd = win.system.diagnostics.debug;
    if (wd.FormatMessageA(
        wd.FORMAT_MESSAGE_OPTIONS{
            .ALLOCATE_BUFFER = 1,
            .FROM_SYSTEM = 1,
            .IGNORE_INSERTS = 1,
        },
        null,
        @intFromEnum(e),
        0,
        s,
        1,
        null,
    ) == 0) {
        // var buf: [256]u8 = undefined;
        // var stream = std.io.fixedBufferStream(&buf);
        // var wr = stream.writer();
        // e.fmt().format("Error: {}", .{}, &wr) catch unreachable;
        _ = wm.MessageBoxA(null, "Unrecognized Error", str, wm.MB_ICONERROR);
        // if (std.fmt.allocPrintZ(std.heap.page_allocator, "Error {}", .{e.fmt()})) |msg| {
        //     _ = wm.MessageBoxA(null, msg, "Fatal Error", .{});
        // } else |ae| switch (ae) {
        //     error.OutOfMemory => _ = wm.MessageBoxA(null, "Out of memory", "Fatal Error", .{}),
        // }
    } else {
        _ = wm.MessageBoxA(null, s, str, wm.MB_ICONERROR);
    }

    win.system.threading.ExitProcess(@intFromEnum(e));
}
