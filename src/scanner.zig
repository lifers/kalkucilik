const std = @import("std");
const Token = @import("token.zig").Token;
const TokenList = std.ArrayList(Token);
const TokenType = @import("token.zig").TokenType;
const win = @import("win32");
const wm = win.ui.windows_and_messaging;
const wg = win.globalization;
const UText = wg.UText;
const UBreakIterator = wg.UBreakIterator;
const eh = @import("err_handling.zig");

const assert = std.debug.assert;

pub const ScannerError = error{
    InvalidCharacter,
    OutOfBounds,
    OutOfMemory,
};

pub fn scannerErrorMessage(e: ScannerError) [:0]const u8 {
    return switch (e) {
        ScannerError.InvalidCharacter => "Invalid character",
        ScannerError.OutOfBounds => "Out of bounds",
        ScannerError.OutOfMemory => "Out of memory",
    };
}

pub const Scanner = struct {
    source: []const u8,
    unicode_text: *UText,
    start: usize,

    pub fn init(source: []const u8) ?Scanner {
        var status = wg.U_ZERO_ERROR;

        const ut = wg.utext_openUTF8(
            null,
            @ptrCast(source.ptr),
            @intCast(source.len),
            &status,
        ) orelse return null;
        eh.checkUErrorCode("icu failed", status);

        return .{
            .source = source,
            .unicode_text = ut,
            .start = 0,
        };
    }

    pub fn deinit(self: Scanner) void {
        _ = wg.utext_close(self.unicode_text);
    }

    pub fn scanTokens(self: *Scanner, allocator: std.mem.Allocator) !std.ArrayList(Token) {
        var tokens = TokenList.init(allocator);
        while (self.scanToken(&tokens)) |cont| {
            if (cont) {
                std.debug.assert(self.current() > self.start);
                self.start = self.current();
            } else {
                return tokens;
            }
        } else |err| {
            return err;
        }
    }

    fn current(self: *const Scanner) usize {
        return @intCast(wg.utext_getNativeIndex(self.unicode_text));
    }

    fn isAtEnd(self: *const Scanner) bool {
        return self.current() >= self.source.len;
    }

    fn scanToken(self: *Scanner, tokens: *TokenList) !bool {
        const c = wg.utext_next32(self.unicode_text);
        switch (c) {
            -1 => return ScannerError.OutOfBounds,
            '(' => try self.addToken(tokens, .LeftParen),
            ')' => try self.addToken(tokens, .RightParen),
            '+' => try self.addToken(tokens, .Plus),
            '*' => try self.addToken(tokens, .Multiply),
            '-' => try self.addToken(tokens, .Minus),
            '/' => try self.addToken(tokens, .Divide),
            '^' => try self.addToken(tokens, .Exponent),
            '=' => try self.addToken(tokens, .Assign),

            else => {
                const ct: wg.UCharCategory = @enumFromInt(wg.u_charType(c));
                switch (ct) {
                    wg.U_DECIMAL_DIGIT_NUMBER => {
                        self.advanceNumber();
                        try self.addToken(tokens, .Number);
                    },
                    wg.U_SPACE_SEPARATOR => {},
                    wg.U_UPPERCASE_LETTER, wg.U_LOWERCASE_LETTER => {
                        self.advanceIdent();
                        try self.addToken(tokens, self.matchWords());
                    },
                    else => return ScannerError.InvalidCharacter,
                }
            },
        }

        if (self.isAtEnd()) {
            try self.addToken(tokens, .EOF);
            return false;
        } else {
            return true;
        }
    }

    fn advanceNumber(self: *Scanner) void {
        while (!self.isAtEnd() and isDigit(self.peek())) {
            _ = self.advanceChar();
        }

        if (!self.isAtEnd() and self.peek() == '.') {
            _ = self.advanceChar();
            if (!self.isAtEnd() and isDigit(self.peek())) {
                while (!self.isAtEnd() and isDigit(self.peek())) {
                    _ = self.advanceChar();
                }
            } else {
                _ = self.rollbackChar();
            }
        }
    }

    fn advanceIdent(self: *Scanner) void {
        while (!self.isAtEnd() and isIdent(self.peek())) {
            _ = self.advanceChar();
        }
    }

    fn matchWords(self: *Scanner) TokenType {
        const w = self.currentLexeme();
        if (std.mem.eql(u8, w, "let")) {
            return .Let;
        } else if (std.mem.eql(u8, w, "pi")) {
            return .Pi;
        } else if (std.mem.eql(u8, w, "π")) {
            return .Pi;
        } else if (std.mem.eql(u8, w, "e")) {
            return .Euler;
        } else if (std.mem.eql(u8, w, "φ")) {
            return .Phi;
        } else if (std.mem.eql(u8, w, "phi")) {
            return .Phi;
        } else if (std.mem.eql(u8, w, "sin")) {
            return .Sin;
        } else if (std.mem.eql(u8, w, "cos")) {
            return .Cos;
        } else if (std.mem.eql(u8, w, "tan")) {
            return .Tan;
        } else if (std.mem.eql(u8, w, "asin")) {
            return .Asin;
        } else if (std.mem.eql(u8, w, "acos")) {
            return .Acos;
        } else if (std.mem.eql(u8, w, "atan")) {
            return .Atan;
        } else if (std.mem.eql(u8, w, "sinh")) {
            return .Sinh;
        } else if (std.mem.eql(u8, w, "cosh")) {
            return .Cosh;
        } else if (std.mem.eql(u8, w, "tanh")) {
            return .Tanh;
        } else if (std.mem.eql(u8, w, "asinh")) {
            return .Asinh;
        } else if (std.mem.eql(u8, w, "acosh")) {
            return .Acosh;
        } else if (std.mem.eql(u8, w, "atanh")) {
            return .Atanh;
        } else if (std.mem.eql(u8, w, "sqrt")) {
            return .Sqrt;
        } else if (std.mem.eql(u8, w, "cbrt")) {
            return .Cbrt;
        } else {
            return .VarName;
        }
    }

    fn currentLexeme(self: *Scanner) []const u8 {
        return self.source[self.start..self.current()];
    }

    fn readIdentifier(self: *Scanner, tokens: TokenList) !void {
        try self.addToken(tokens, .Identifier);
    }

    fn rollbackChar(self: *Scanner) void {
        _ = wg.utext_previous32(self.unicode_text);
    }

    fn peek(self: *Scanner) u32 {
        const c = wg.utext_current32(self.unicode_text);
        std.debug.assert(c >= 0);
        return @as(u32, @intCast(c));
    }

    fn advanceChar(self: *Scanner) u32 {
        const c = wg.utext_next32(self.unicode_text);
        std.debug.assert(c >= 0);
        return @as(u32, @intCast(c));
    }

    fn addToken(self: *Scanner, tokens: *TokenList, token_type: TokenType) !void {
        std.debug.assert(self.current() > self.start);
        const lexeme = self.currentLexeme();

        try tokens.append(.{ .type = token_type, .lexeme = lexeme, .pos = self.start });
    }
};

fn isDigit(c: u32) bool {
    return wg.u_charType(@intCast(c)) == @intFromEnum(wg.U_DECIMAL_DIGIT_NUMBER);
}

fn isIdent(c: u32) bool {
    if (c == '_') {
        return true;
    }
    const ct: wg.UCharCategory = @enumFromInt(wg.u_charType(@intCast(c)));
    return ct == wg.U_UPPERCASE_LETTER or
        ct == wg.U_LOWERCASE_LETTER or
        ct == wg.U_DECIMAL_DIGIT_NUMBER;
}

fn UCharCategoryMessage(ct: wg.UCharCategory) []const u8 {
    return switch (ct) {
        wg.U_DECIMAL_DIGIT_NUMBER => "Decimal Digit Number",
        wg.U_SPACE_SEPARATOR => "Space Separator",
        wg.U_UPPERCASE_LETTER => "Uppercase Letter",
        wg.U_LOWERCASE_LETTER => "Lowercase Letter",
        else => "Unknown",
    };
}
