const std = @import("std");
const Token = @import("token.zig").Token;
const wg = @import("win32").globalization;
const wuw = @import("win32").ui.windows_and_messaging;
const fm = @import("formatter.zig");
const eh = @import("err_handling.zig");

extern fn sin(x: f64) callconv(.C) f64;
extern fn cos(x: f64) callconv(.C) f64;
extern fn tan(x: f64) callconv(.C) f64;
extern fn asin(x: f64) callconv(.C) f64;
extern fn acos(x: f64) callconv(.C) f64;
extern fn atan(x: f64) callconv(.C) f64;
extern fn sinh(x: f64) callconv(.C) f64;
extern fn cosh(x: f64) callconv(.C) f64;
extern fn tanh(x: f64) callconv(.C) f64;
extern fn asinh(x: f64) callconv(.C) f64;
extern fn acosh(x: f64) callconv(.C) f64;
extern fn atanh(x: f64) callconv(.C) f64;
extern fn sqrt(x: f64) callconv(.C) f64;
extern fn cbrt(x: f64) callconv(.C) f64;

pub const Expr = union(enum) {
    Literal: Token,
    Variable: Token,
    Unary: struct { op: Token, right: *Expr },
    Binary: struct { left: *Expr, op: Token, right: *Expr },
    Grouping: *Expr,

    fn checkLiteral(token: Token, fmt: *const ?*anyopaque, act: std.mem.Allocator) f64 {
        if (token.type == .Pi) {
            return std.math.pi;
        } else if (token.type == .Euler) {
            return std.math.e;
        } else if (token.type == .Phi) {
            return std.math.phi;
        }

        var len: i32 = 0;
        var ec: wg.UErrorCode = wg.U_ZERO_ERROR;

        eh.checkEqual(?*u16, wg.u_strFromUTF8(
            null,
            0,
            &len,
            @ptrCast(token.lexeme.ptr),
            @intCast(token.lexeme.len),
            &ec,
        ), null, "calculate text length failed");
        // eh.checkUErrorCode("calculate text length failed", ec);
        ec = wg.U_ZERO_ERROR;

        const arr = act.alloc(u16, @intCast(len)) catch eh.fatal("allocate memory failed");

        _ = wg.u_strFromUTF8(
            @ptrCast(arr.ptr),
            @intCast(arr.len),
            null,
            @ptrCast(token.lexeme.ptr),
            @intCast(token.lexeme.len),
            &ec,
        );
        eh.checkUErrorCode("convert utf8 to utf16 failed", ec);

        const value = wg.unum_parseDouble(
            fmt,
            @ptrCast(arr.ptr),
            @intCast(arr.len),
            null,
            &ec,
        );
        eh.checkUErrorCode("parse literal failed", ec);

        return value;
    }

    pub fn evaluate(
        self: *const Expr,
        fmt: *const ?*anyopaque,
        act: std.mem.Allocator,
        env: *const std.HashMap([]const u8, f64, std.hash_map.StringContext, 80),
    ) !f64 {
        switch (self.*) {
            .Literal => return checkLiteral(self.Literal, fmt, act),
            .Unary => {
                const value = try self.Unary.right.evaluate(fmt, act, env);
                switch (self.Unary.op.type) {
                    .Minus => return -value,
                    .Sin => return sin(value),
                    .Cos => return cos(value),
                    .Tan => return tan(value),
                    .Asin => return asin(value),
                    .Acos => return acos(value),
                    .Atan => return atan(value),
                    .Sinh => return sinh(value),
                    .Cosh => return cosh(value),
                    .Tanh => return tanh(value),
                    .Asinh => return asinh(value),
                    .Acosh => return acosh(value),
                    .Atanh => return atanh(value),
                    .Sqrt => return sqrt(value),
                    .Cbrt => return cbrt(value),
                    else => unreachable,
                }
            },
            .Binary => {
                const left = try self.Binary.left.evaluate(fmt, act, env);
                const right = try self.Binary.right.evaluate(fmt, act, env);

                switch (self.Binary.op.type) {
                    .Plus => return left + right,
                    .Minus => return left - right,
                    .Multiply => return left * right,
                    .Divide => {
                        if (right == 0) {
                            return EvaluateError.DivideByZero;
                        } else {
                            return left / right;
                        }
                    },
                    .Exponent => return std.math.pow(f64, left, right),
                    else => unreachable,
                }
            },
            .Grouping => return self.Grouping.evaluate(fmt, act, env),
            .Variable => {
                const value = env.get(self.Variable.lexeme);
                if (value) |v| {
                    return v;
                } else {
                    return EvaluateError.UnknownVariable;
                }
            },
        }
    }
};

pub const EvaluateError = error{
    DivideByZero,
    InvalidCharacter,
    OutOfMemory,
    UnknownVariable,
};
