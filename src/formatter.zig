const std = @import("std");
const win = @import("win32");
const wg = win.globalization;
const L = win.zig.L;
const eh = @import("err_handling.zig");

pub const FormatError = error{OutOfMemory};

pub const NumberFormat = struct {
    internal: *wg.UNumberFormatter,
    parser: *?*anyopaque,
    parse_err: *wg.UParseError,

    pub fn init(locale: [:0]const u8, allocator: std.mem.Allocator) !NumberFormat {
        var err = wg.U_ZERO_ERROR;
        const skeleton = L("precision-unlimited");
        const uformatter = wg.unumf_openForSkeletonAndLocale(
            @ptrCast(skeleton),
            @intCast(skeleton.len),
            locale,
            &err,
        ) orelse eh.fatal("unumf_openForSkeletonAndLocale failed");

        const err_msg = try allocator.create(wg.UParseError);

        const uparser = wg.unum_open(
            wg.UNUM_DECIMAL,
            null,
            0,
            locale,
            err_msg,
            &err,
        ) orelse eh.fatal("unum_open failed");

        eh.checkUErrorCode("Unicode Error", err);
        return .{
            .internal = uformatter,
            .parser = uparser,
            .parse_err = err_msg,
        };
    }

    pub fn deinit(self: NumberFormat) void {
        wg.unum_close(self.parser);
        wg.unumf_close(self.internal);
    }

    pub fn formatF64(self: *const NumberFormat, value: f64, allocator: std.mem.Allocator) ![*:0]const u8 {
        var err = wg.U_ZERO_ERROR;
        const uresult = wg.unumf_openResult(&err) orelse eh.fatal("unumf_openResult failed");
        defer wg.unumf_closeResult(uresult);

        wg.unumf_formatDouble(self.internal, value, uresult, &err);

        const utf16len = wg.unumf_resultToString(uresult, null, 0, &err);
        if (err != wg.U_BUFFER_OVERFLOW_ERROR) {
            eh.checkUErrorCode("Unicode Error", err);
            unreachable;
        } else {
            std.debug.assert(utf16len > 0);
            err = wg.U_ZERO_ERROR;
        }
        const utf16buf = try allocator.alloc(u16, @intCast(utf16len));
        eh.checkEqual(i32, wg.unumf_resultToString(
            uresult,
            @ptrCast(utf16buf.ptr),
            utf16len,
            &err,
        ), utf16len, "Error converting number to string");

        var utf8len: i32 = undefined;
        _ = wg.u_strToUTF8(null, 0, &utf8len, @ptrCast(utf16buf), utf16len, &err);
        if (err != wg.U_BUFFER_OVERFLOW_ERROR) {
            eh.checkUErrorCode("Unicode Error", err);
            unreachable;
        } else {
            std.debug.assert(utf8len > 0);
            err = wg.U_ZERO_ERROR;
        }
        var utf8buf: [*:0]u8 = @ptrCast(try allocator.alloc(u8, @intCast(utf8len + 1)));
        eh.checkEqual(?[*:0]u8, wg.u_strToUTF8(
            @ptrCast(utf8buf),
            utf8len + 1,
            &utf8len,
            @ptrCast(utf16buf.ptr),
            utf16len,
            &err,
        ), utf8buf, "Error converting UTF-16 to UTF-8");
        std.debug.assert(utf8len > 0);
        utf8buf[@intCast(utf8len)] = 0;

        eh.checkUErrorCode("Unicode Errro", err);
        return utf8buf;
    }

    pub fn parseF64(self: *const NumberFormat, text: *const []const u8, allocator: std.mem.Allocator) !f64 {
        var err = wg.U_ZERO_ERROR;
        var utf16len: i32 = undefined;
        _ = wg.u_strFromUTF8(null, 0, &utf16len, @ptrCast(text.ptr), @intCast(text.len), &err);
        if (err != wg.U_BUFFER_OVERFLOW_ERROR) {
            eh.checkUErrorCode("Unicode Error", err);
            unreachable;
        } else {
            std.debug.assert(utf16len > 0);
            err = wg.U_ZERO_ERROR;
        }
        var utf16buf = try allocator.alloc(u16, @intCast(utf16len + 1));
        eh.checkEqual(?*u16, wg.u_strFromUTF8(
            @ptrCast(utf16buf.ptr),
            utf16len + 1,
            &utf16len,
            @ptrCast(text.ptr),
            @intCast(text.len),
            &err,
        ), @ptrCast(utf16buf.ptr), "Error converting UTF-8 to UTF-16");
        utf16buf[@intCast(utf16len)] = 0;

        var parsepos: i32 = 0;
        const value = wg.unum_parseDouble(self.parser, @ptrCast(utf16buf.ptr), utf16len, &parsepos, &err);
        // std.debug.assert(parsepos == utf16len);
        eh.checkUErrorCode("Unicode Error", err);
        return value;
    }
};
