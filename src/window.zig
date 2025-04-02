const std = @import("std");
const eh = @import("err_handling.zig");
const win = @import("win32");
const wf = win.foundation;
const wg = win.graphics.gdi;
const wh = win.ui.hi_dpi;
const wm = win.ui.windows_and_messaging;
const ws = win.ui.shell;

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn default() Rect {
        return .{
            .x = wm.CW_USEDEFAULT,
            .y = wm.CW_USEDEFAULT,
            .w = wm.CW_USEDEFAULT,
            .h = wm.CW_USEDEFAULT,
        };
    }

    pub fn init_location(x: i32, y: i32) Rect {
        return .{
            .x = x,
            .y = y,
            .w = wm.CW_USEDEFAULT,
            .h = wm.CW_USEDEFAULT,
        };
    }

    pub fn init_size(w: i32, h: i32) Rect {
        return .{
            .x = wm.CW_USEDEFAULT,
            .y = wm.CW_USEDEFAULT,
            .w = w,
            .h = h,
        };
    }
};

pub const Window = struct {
    handle: wf.HWND,
    dim: Rect,

    pub fn init(
        lpClassName: [*:0]align(1) const u8,
        lpWindowName: [*:0]const u8,
        dwStyle: wm.WINDOW_STYLE,
        dim: Rect,
        hParent: ?wf.HWND,
        id: usize,
        hInstance: ?wf.HINSTANCE,
        lpParam: ?*anyopaque,
    ) Window {
        return .{
            .handle = eh.checkNotNull(
                wf.HWND,
                wm.CreateWindowExA(
                    .{},
                    lpClassName,
                    lpWindowName,
                    dwStyle,
                    dim.x,
                    dim.y,
                    dim.w,
                    dim.h,
                    hParent,
                    @ptrFromInt(id),
                    hInstance,
                    lpParam,
                ),
                "CreateWindowExA failed",
            ),
            .dim = dim,
        };
    }

    pub fn subclass(self: *const Window, proc: ws.SUBCLASSPROC, id: usize, data: *anyopaque) void {
        eh.checkEqual(wf.BOOL, ws.SetWindowSubclass(
            self.handle,
            proc,
            id,
            @intFromPtr(data),
        ), 1, "SetWindowSubclass failed");
    }

    pub fn setText(self: *const Window, text: [*:0]const u8) void {
        eh.checkEqual(wf.BOOL, wm.SetWindowTextA(self.handle, text), 1, "SetWindowTextA failed");
    }

    pub fn getText(self: *const Window, allocator: std.mem.Allocator) ![:0]const u8 {
        const len = wm.GetWindowTextLengthA(self.handle);
        if (len == 0) {
            return error.EmptyText;
        }

        var text = try allocator.alloc(u8, @intCast(len + 1));
        const copied = wm.GetWindowTextA(self.handle, @ptrCast(text.ptr), len + 1);
        return text[0..@intCast(copied) :0];
    }

    pub fn getDpi(self: *const Window) u32 {
        return wh.GetDpiForWindow(self.handle);
    }

    pub fn setFont(self: *const Window, font: wg.HFONT) void {
        _ = wm.SendMessageA(self.handle, wm.WM_SETFONT, @intFromPtr(font), 1);
    }

    pub fn updatePosition(self: *const Window) void {
        _ = wm.MoveWindow(
            self.handle,
            self.dim.x,
            self.dim.y,
            self.dim.w,
            self.dim.h,
            1,
        );
    }

    pub fn fillWidth(self: *Window, width: i32, margin: i32) void {
        self.dim.w = width - 2 * margin;
    }

    pub fn fillHeight(self: *Window, height: i32, margin: i32) void {
        self.dim.h = height - 2 * margin;
    }

    pub fn alignRight(self: *Window, width: i32, margin: i32) void {
        self.dim.x = width - self.dim.w - margin;
    }

    pub fn alignBottom(self: *Window, height: i32, margin: i32) void {
        self.dim.y = height - self.dim.h - margin;
    }
};
