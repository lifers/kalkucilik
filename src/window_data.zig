const std = @import("std");
const stdwin = @import("std").os.windows;
const win = @import("win32");
const wf = win.foundation;
const wg = win.globalization;
const wgg = win.graphics.gdi;
const wh = win.ui.hi_dpi;
const wm = win.ui.windows_and_messaging;
const wuk = win.ui.input.keyboard_and_mouse;
const ws = win.ui.shell;
const eh = @import("err_handling.zig");
const ex = @import("expr.zig");
const fm = @import("formatter.zig");
const ps = @import("parser.zig");
const sc = @import("scanner.zig");
// const bf = @import("big_float.zig").bf;

const Window = @import("window.zig").Window;
const Rect = @import("window.zig").Rect;
const ListBox = @import("list_box.zig").ListBox;
const ListView = @import("list_view.zig").ListView;

const assert = std.debug.assert;

// The main control structure for the application.
// Must live on the stack.
pub const MainWindow = struct {
    main: Window,
    edit: Window,
    static: Window,
    historybox: ListBox,
    varview: ListView,
    dpi: u32,
    env: std.HashMap([]const u8, f64, std.hash_map.StringContext, 80),
    env_allocator: std.mem.Allocator,
    fmt: *?*anyopaque,

    const ID_EDIT = 1;
    const ID_STATIC = 2;
    const ID_LISTBOX = 3;
    const ID_VARVIEW = 4;

    pub fn init(
        self: *MainWindow,
        lpClassName: [*:0]align(1) const u8,
        hInstance: wf.HINSTANCE,
        allocator: std.mem.Allocator,
    ) void {
        self.dpi = wh.GetDpiForSystem();
        assert(self.dpi > 0);

        self.main = Window.init(
            lpClassName,
            "Kalkucilik",
            wm.WS_OVERLAPPEDWINDOW,
            Rect.init_size(self.scaleSize(600), self.scaleSize(400)),
            null,
            0,
            hInstance,
            self,
        );

        self.env_allocator = allocator;
        self.env = std.StringHashMap(f64).init(self.env_allocator);

        var parseError: wg.UParseError = undefined;
        var errorCode: wg.UErrorCode = wg.U_ZERO_ERROR;
        self.fmt = wg.unum_open(
            wg.UNUM_DECIMAL,
            null,
            0,
            "en_US",
            &parseError,
            &errorCode,
        ) orelse eh.fatal("unum_open failed");
    }

    pub fn deinit(self: *MainWindow) void {
        wg.unum_close(self.fmt);
    }

    pub fn finalize(self: *MainWindow, parent: wf.HWND) void {
        const wc = win.ui.controls;

        self.dpi = wh.GetDpiForWindow(parent);
        self.edit = Window.init(
            wc.WC_EDITA,
            "",
            wm.WINDOW_STYLE{
                .CHILD = 1,
                .VISIBLE = 1,
                .BORDER = 1,
                ._7 = 1, // ES_AUTOHSCROLL
            },
            self.scaleRect(.{ .x = 12, .y = 220, .w = 460, .h = 24 }),
            parent,
            ID_EDIT,
            null,
            null,
        );
        self.edit.subclass(editProc, ID_EDIT, self);

        self.static = Window.init(
            wc.WC_STATICA,
            "Enter expression",
            wm.WINDOW_STYLE{ .CHILD = 1, .VISIBLE = 1 },
            self.scaleRect(.{ .x = 12, .y = 260, .w = 460, .h = 24 }),
            parent,
            ID_STATIC,
            null,
            null,
        );

        // put in top left
        self.historybox = ListBox.create(
            parent,
            self.scaleRect(.{ .x = 12, .y = 12, .w = 220, .h = 200 }),
            ID_LISTBOX,
        );

        // put in top right
        self.varview = ListView.create(
            parent,
            self.scaleRect(.{ .x = 240, .y = 12, .w = 180, .h = 180 }),
            ID_VARVIEW,
        );

        const font = wgg.CreateFontA(
            self.scaleSize(20),
            0,
            0,
            wgg.FW_NORMAL,
            wgg.FW_DONTCARE,
            0,
            0,
            0,
            wgg.DEFAULT_CHARSET,
            wgg.OUT_DEFAULT_PRECIS,
            wgg.CLIP_DEFAULT_PRECIS,
            wgg.DEFAULT_QUALITY,
            wgg.FF_SWISS,
            "Segoe UI",
        ) orelse eh.fatal("CreateFontA failed");

        self.main.setFont(font);
        self.edit.setFont(font);
        self.static.setFont(font);
        self.historybox.setFont(font);
        self.varview.setFont(font);

        var var_header = "Variable".*;
        self.varview.insertColumn(0, &var_header, self.scaleSize(90));
        var val_header = "Value".*;
        self.varview.insertColumn(1, &val_header, self.scaleSize(90));

        assert(@as(?*MainWindow, @ptrCast(self)) != null);
        assert(@as(?wf.HWND, @ptrCast(self.main.handle)) != null);
        assert(@as(?wf.HWND, @ptrCast(self.edit.handle)) != null);
        assert(@as(?wf.HWND, @ptrCast(self.static.handle)) != null);
    }

    pub fn show(self: *const MainWindow, ncmdshow: wm.SHOW_WINDOW_CMD) wf.BOOL {
        return wm.ShowWindow(self.main.handle, ncmdshow);
    }

    pub fn processInput(self: *MainWindow, store: bool) void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const input = self.edit.getText(allocator) catch {
            self.static.setText("Enter expression");
            return;
        };

        var scanner = sc.Scanner.init(input) orelse eh.fatal("Scanner init failed");
        defer scanner.deinit();
        const tokens = scanner.scanTokens(allocator) catch |err| {
            self.static.setText(sc.scannerErrorMessage(err));
            return;
        };

        var parser = ps.Parser.init(allocator, tokens);
        defer parser.deinit();
        const varname = parser.isAssignment();
        const expr = parser.parse() catch |err| {
            self.static.setText(ps.parseErrorMessage(err));
            return;
        };

        const value = expr.evaluate(self.fmt, allocator, &self.env) catch |err| {
            self.static.setText(switch (err) {
                ex.EvaluateError.DivideByZero => "Division by zero",
                ex.EvaluateError.InvalidCharacter => "Invalid character",
                ex.EvaluateError.OutOfMemory => "Out of memory",
                ex.EvaluateError.UnknownVariable => "Unknown variable",
            });
            return;
        };

        const buf = printFloat(value, self.fmt, allocator) catch {
            self.static.setText("Out of memory");
            return;
        };
        self.static.setText(@ptrCast(buf.ptr));

        if (store) {
            self.addHistory(input, buf);

            if (varname) |name| {
                const key = self.env_allocator.dupe(u8, name) catch {
                    self.static.setText("Out of memory");
                    return;
                };
                self.env.put(key, value) catch {
                    self.static.setText("Out of memory");
                    return;
                };
                self.updateVariable();
            }
        }
    }

    pub fn getWindowData(hwnd: wf.HWND) *MainWindow {
        const mwptr: usize = @intCast(eh.checkNotEqual(
            isize,
            wm.GetWindowLongPtrA(hwnd, wm.GWLP_USERDATA),
            0,
            "GetWindowLongPtrA failed",
        ));
        const mw: *MainWindow = @ptrFromInt(mwptr);
        return mw;
    }

    pub fn processCommand(self: *MainWindow, wparam: wf.WPARAM) void {
        const id = win.zig.loword(wparam);
        const code = win.zig.hiword(wparam);
        if (id == ID_EDIT and code == wm.EN_CHANGE) {
            self.processInput(false);
        }
    }

    pub fn processResize(self: *MainWindow, width: i32, height: i32) void {
        assert(@as(?*MainWindow, @ptrCast(self)) != null);
        assert(@as(?wf.HWND, @ptrCast(self.main.handle)) != null);
        assert(@as(?wf.HWND, @ptrCast(self.edit.handle)) != null);
        assert(@as(?wf.HWND, @ptrCast(self.static.handle)) != null);
        assert(width > 0);
        assert(height > 0);

        self.main.dim.w = width;
        self.main.dim.h = height;
        self.dpi = self.main.getDpi();

        const h_margin = self.scaleSize(12);
        self.varview.alignRight(width, h_margin);
        self.historybox.fillWidth(self.varview.x(), h_margin);
        self.edit.fillWidth(width, h_margin);
        self.static.fillWidth(width, h_margin);

        const v_margin = self.scaleSize(16);
        self.static.alignBottom(height, v_margin);
        self.edit.alignBottom(self.static.dim.y, v_margin);
        self.historybox.fillHeight(self.edit.dim.y, v_margin);
        self.varview.fillHeight(self.edit.dim.y, v_margin);

        self.edit.updatePosition();
        self.static.updatePosition();
        self.historybox.updatePosition();
        self.varview.updatePosition();
        _ = eh.checkNotEqual(
            wf.BOOL,
            wgg.InvalidateRect(self.main.handle, null, 1),
            0,
            "InvalidateRect failed",
        );
    }

    pub fn scaleSize(self: *const MainWindow, size: i32) i32 {
        return win.system.windows_programming.MulDiv(size, @intCast(self.dpi), 96);
    }

    pub fn scaleRect(self: *const MainWindow, rect: Rect) Rect {
        return .{
            .x = self.scaleSize(rect.x),
            .y = self.scaleSize(rect.y),
            .w = self.scaleSize(rect.w),
            .h = self.scaleSize(rect.h),
        };
    }

    fn addHistory(self: *MainWindow, expr: [:0]const u8, result: [:0]const u8) void {
        self.historybox.addString(expr);
        self.historybox.addString(result);
        self.historybox.addString("");
        self.historybox.verticalScrollBottom();
    }

    fn updateVariable(self: *MainWindow) void {
        self.varview.deleteAllItems();
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var iter = self.env.iterator();
        while (iter.next()) |kv| {
            const value_str = printFloat(kv.value_ptr.*, self.fmt, allocator) catch {
                eh.fatal("printFloat failed");
            };
            // _ = wm.MessageBoxA(null, value_str, "debug", wm.MB_OK);
            const name_str = allocator.dupeZ(u8, kv.key_ptr.*) catch {
                self.static.setText("Out of memory");
                return;
            };
            self.varview.insertItem(0, name_str);
            self.varview.setItemText(0, 1, value_str);
        }
    }
};

fn editProc(
    hwnd: ?wf.HWND,
    msg: u32,
    wparam: wf.WPARAM,
    lparam: wf.LPARAM,
    _: usize,
    dwRefData: usize,
) callconv(stdwin.WINAPI) wf.LRESULT {
    std.debug.assert(hwnd != null);
    std.debug.assert(dwRefData != 0);
    const mw: *MainWindow = @ptrFromInt(dwRefData);

    switch (msg) {
        wm.WM_KEYDOWN, wm.WM_SYSKEYDOWN => {
            if (@as(u16, @intCast(wparam)) == @intFromEnum(wuk.VK_RETURN)) {
                mw.processInput(true);
            }
        },
        else => {},
    }
    return ws.DefSubclassProc(hwnd, msg, wparam, lparam);
}

pub fn windowProc(
    hwnd: wf.HWND,
    msg: u32,
    wparam: wf.WPARAM,
    lparam: wf.LPARAM,
) callconv(stdwin.WINAPI) wf.LRESULT {
    switch (msg) {
        wm.WM_CREATE => {
            assert(lparam > 0);
            const create_struct: *const wm.CREATESTRUCTA = @ptrFromInt(@as(usize, @intCast(lparam)));
            assert(create_struct.lpCreateParams != null);
            const mw: *MainWindow = @alignCast(@ptrCast(create_struct.lpCreateParams));
            _ = wm.SetWindowLongPtrA(hwnd, wm.GWLP_USERDATA, @intCast(@intFromPtr(mw)));
            mw.finalize(hwnd);
            assert(MainWindow.getWindowData(hwnd) == mw);
        },
        wm.WM_COMMAND => {
            MainWindow.getWindowData(hwnd).processCommand(wparam);
        },
        wm.WM_SIZE => {
            const width = win.zig.loword(lparam);
            const height = win.zig.hiword(lparam);
            MainWindow.getWindowData(hwnd).processResize(width, height);
        },
        wm.WM_DESTROY => {
            wm.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return wm.DefWindowProcA(hwnd, msg, wparam, lparam);
}

fn printFloat(value: f64, fmt: *?*anyopaque, allocator: std.mem.Allocator) ![:0]u8 {
    var ec = wg.U_ZERO_ERROR;

    // get the length of the formatted string
    const wide_len = wg.unum_formatDouble(
        fmt,
        value,
        null,
        0,
        null,
        &ec,
    );
    ec = wg.U_ZERO_ERROR;

    const wide_buf = try allocator.alloc(u16, @intCast(wide_len));
    _ = wg.unum_formatDouble(
        fmt,
        value,
        @ptrCast(wide_buf.ptr),
        @intCast(wide_buf.len),
        null,
        &ec,
    );
    eh.checkUErrorCode("format double failed", ec);

    var len: i32 = undefined;
    _ = wg.u_strToUTF8(
        null,
        0,
        &len,
        @ptrCast(wide_buf.ptr),
        @intCast(wide_buf.len),
        &ec,
    );
    ec = wg.U_ZERO_ERROR;

    const buf = try allocator.alloc(u8, @intCast(len + 1));
    _ = wg.u_strToUTF8(
        @ptrCast(buf.ptr),
        @intCast(buf.len),
        null,
        @ptrCast(wide_buf.ptr),
        @intCast(wide_buf.len),
        &ec,
    );
    eh.checkUErrorCode("convert utf16 to utf8 failed", ec);
    buf[@intCast(len)] = 0;

    return buf[0..@intCast(len) :0];
}
