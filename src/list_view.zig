const win = @import("win32");
const wf = win.foundation;
const wg = win.graphics.gdi;
const wuc = win.ui.controls;
const wuw = win.ui.windows_and_messaging;
const wd = @import("window.zig");
const eh = @import("err_handling.zig");
// const cid = @import("component_id.zig");

pub const ListView = struct {
    internal: wd.Window,

    pub fn create(parent: wf.HWND, pos: wd.Rect, id: comptime_int) ListView {
        return .{
            .internal = wd.Window.init(
                wuc.WC_LISTVIEWA,
                "",
                .{
                    .CHILD = 1,
                    .VISIBLE = 1,
                    .VSCROLL = 1,
                    .BORDER = 1,
                    .ACTIVECAPTION = 1, // LVS_REPORT
                },
                pos,
                parent,
                id,
                null,
                null,
            ),
        };
    }

    pub fn setFont(self: *ListView, font: wg.HFONT) void {
        self.internal.setFont(font);
    }

    pub fn insertColumn(self: *ListView, index: usize, text: [:0]u8, width: i32) void {
        const column: wuc.LVCOLUMNA = .{
            .mask = .{ .TEXT = 1, .WIDTH = 1, .FMT = 1, .SUBITEM = 1 },
            .pszText = text.ptr,
            .cx = width,
            .fmt = .{ .CENTER = 1 },
            .iSubItem = @intCast(index),
            // Unimportant fields
            .cchTextMax = 0,
            .iImage = 0,
            .iOrder = 0,
            .cxMin = 0,
            .cxDefault = 0,
            .cxIdeal = 0,
        };

        eh.checkEqual(wf.LRESULT, wuw.SendMessageA(
            self.internal.handle,
            wuc.LVM_INSERTCOLUMNA,
            index,
            @intCast(@intFromPtr(&column)),
        ), @intCast(index), "InsertColumn failed");
    }

    pub fn deleteAllItems(self: *ListView) void {
        eh.checkEqual(wf.LRESULT, wuw.SendMessageA(
            self.internal.handle,
            wuc.LVM_DELETEALLITEMS,
            0,
            0,
        ), 1, "DeleteAllItems failed");
    }

    pub fn insertItem(self: *ListView, row: i32, text: [:0]u8) void {
        const item: wuc.LVITEMA = .{
            .mask = wuc.LVIF_TEXT,
            .pszText = text.ptr,
            .iItem = row,
            // Unimportant fields
            .cchTextMax = 0,
            .iSubItem = 0,
            .state = 0,
            .stateMask = 0,
            .iImage = 0,
            .lParam = 0,
            .iIndent = 0,
            .cColumns = 0,
            .puColumns = null,
            .piColFmt = null,
            .iGroup = 0,
            .iGroupId = .NONE,
        };

        eh.checkEqual(wf.LRESULT, wuw.SendMessageA(
            self.internal.handle,
            wuc.LVM_INSERTITEMA,
            0,
            @intCast(@intFromPtr(&item)),
        ), @intCast(row), "InsertItem failed");
    }

    pub fn setItemText(self: *ListView, row: i32, col: i32, text: [:0]u8) void {
        const item: wuc.LVITEMA = .{
            .mask = wuc.LVIF_TEXT,
            .pszText = text.ptr,
            .iItem = row,
            .iSubItem = col,
            // Unimportant fields
            .cchTextMax = 0,
            .state = 0,
            .stateMask = 0,
            .iImage = 0,
            .lParam = 0,
            .iIndent = 0,
            .cColumns = 0,
            .puColumns = null,
            .piColFmt = null,
            .iGroup = 0,
            .iGroupId = .NONE,
        };

        eh.checkEqual(wf.LRESULT, wuw.SendMessageA(
            self.internal.handle,
            wuc.LVM_SETITEMA,
            0,
            @intCast(@intFromPtr(&item)),
        ), 1, "SetItemText failed");
    }

    pub fn updatePosition(self: *const ListView) void {
        self.internal.updatePosition();
    }

    pub fn alignRight(self: *ListView, width: i32, margin: i32) void {
        self.internal.alignRight(width, margin);
    }

    pub fn fillHeight(self: *ListView, height: i32, margin: i32) void {
        self.internal.fillHeight(height, margin);
    }

    pub fn fillWidth(self: *ListView, width: i32, margin: i32) void {
        self.internal.fillWidth(width, margin);
    }

    pub fn x(self: *ListView) i32 {
        return self.internal.dim.x;
    }
};
