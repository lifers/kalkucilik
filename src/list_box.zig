const win = @import("win32");
const wf = win.foundation;
const wg = win.graphics.gdi;
const wuc = win.ui.controls;
const wuw = win.ui.windows_and_messaging;
const wd = @import("window.zig");
const eh = @import("err_handling.zig");
// const cid = @import("component_id.zig");

pub const ListBox = struct {
    internal: wd.Window,

    pub fn create(parent: wf.HWND, pos: wd.Rect, id: comptime_int) ListBox {
        return .{
            .internal = wd.Window.init(
                wuc.WC_LISTBOXA,
                "",
                .{
                    .CHILD = 1,
                    .VISIBLE = 1,
                    .VSCROLL = 1,
                    .BORDER = 1,
                    .ACTIVECAPTION = 1, // LBS_NOTIFY
                },
                pos,
                parent,
                id,
                null,
                null,
            ),
        };
    }

    pub fn setFont(self: *ListBox, font: wg.HFONT) void {
        self.internal.setFont(font);
    }

    pub fn updatePosition(self: *const ListBox) void {
        self.internal.updatePosition();
    }

    pub fn alignRight(self: *ListBox, width: i32, margin: i32) void {
        self.internal.alignRight(width, margin);
    }

    pub fn fillHeight(self: *ListBox, height: i32, margin: i32) void {
        self.internal.fillHeight(height, margin);
    }

    pub fn fillWidth(self: *ListBox, width: i32, margin: i32) void {
        self.internal.fillWidth(width, margin);
    }

    pub fn addString(self: *ListBox, text: [:0]const u8) void {
        _ = wuw.SendMessageA(
            self.internal.handle,
            wuw.LB_ADDSTRING,
            0,
            @intCast(@intFromPtr(text.ptr)),
        );
    }

    pub fn verticalScrollBottom(self: *ListBox) void {
        _ = wuw.SendMessageA(
            self.internal.handle,
            wuw.WM_VSCROLL,
            wuw.SB_BOTTOM,
            0,
        );
    }
};
