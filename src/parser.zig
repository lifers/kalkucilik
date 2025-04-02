const std = @import("std");
const Expr = @import("expr.zig").Expr;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const wm = @import("win32").ui.windows_and_messaging;

pub const ParseError = error{
    ExpressionExpected,
    RightParenExpected,
    UnexpectedToken,
    OutOfMemory,
};

pub fn parseErrorMessage(e: ParseError) [:0]const u8 {
    return switch (e) {
        ParseError.ExpressionExpected => "Expected expression",
        ParseError.RightParenExpected => "Expected ')'",
        ParseError.UnexpectedToken => "Unexpected token",
        ParseError.OutOfMemory => "Out of memory",
    };
}

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    pos: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) Parser {
        return .{
            .tokens = tokens,
            .pos = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Parser) void {
        self.tokens.deinit();
    }

    pub fn parse(self: *Parser) !*Expr {
        const expr = self.expression();
        if (!self.is_at_end()) {
            return ParseError.UnexpectedToken;
        }
        return expr;
    }

    pub fn isAssignment(self: *Parser) ?[]const u8 {
        if (self.tokens.items.len >= 4 and
            self.tokens.items[0].type == TokenType.Let and
            self.tokens.items[1].type == TokenType.VarName and
            self.tokens.items[2].type == TokenType.Assign)
        {
            self.pos = 3;
            return self.tokens.items[1].lexeme;
        }
        return null;
    }

    fn expression(self: *Parser) !*Expr {
        var expr = try self.power();

        while (self.match(&.{ .Plus, .Minus })) {
            const op = self.prev();
            const right = try self.power();
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Binary = .{ .left = expr, .op = op, .right = right } };
            expr = new_expr;
        }

        return expr;
    }

    fn power(self: *Parser) !*Expr {
        var expr = try self.factor();

        while (self.match(&.{.Exponent})) {
            const op = self.prev();
            const right = try self.factor();
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Binary = .{ .left = expr, .op = op, .right = right } };
            expr = new_expr;
        }

        return expr;
    }

    fn factor(self: *Parser) !*Expr {
        var expr = try self.unary();

        while (self.match(&.{ .Multiply, .Divide })) {
            const op = self.prev();
            const right = try self.unary();
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Binary = .{ .left = expr, .op = op, .right = right } };
            expr = new_expr;
        }

        return expr;
    }

    fn unary(self: *Parser) !*Expr {
        if (self.match(&.{
            .Minus, .Sin,
            .Cos,   .Tan,
            .Asin,  .Acos,
            .Atan,  .Sinh,
            .Cosh,  .Tanh,
            .Asinh, .Acosh,
            .Atanh, .Sqrt,
            .Cbrt,
        })) {
            const op = self.prev();
            const right = try self.unary();
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Unary = .{ .op = op, .right = right } };
            return new_expr;
        } else {
            return self.primary();
        }
    }

    fn primary(self: *Parser) ParseError!*Expr {
        if (self.match(&.{ .Number, .Pi, .Euler, .Phi })) {
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Literal = self.prev() };
            return new_expr;
        } else if (self.match(&.{.LeftParen})) {
            const expr = try self.expression();
            _ = try self.consume(.RightParen);
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Grouping = expr };
            return new_expr;
        } else if (self.match(&.{.VarName})) {
            const new_expr = try self.allocator.create(Expr);
            new_expr.* = .{ .Variable = self.prev() };
            return new_expr;
        }

        _ = try self.consume(.Number);
        return ParseError.UnexpectedToken;
    }

    fn consume(self: *Parser, token: TokenType) ParseError!Token {
        if (self.check(token)) {
            return self.advance();
        }

        return switch (token) {
            .Number => ParseError.ExpressionExpected,
            .RightParen => ParseError.RightParenExpected,
            else => ParseError.UnexpectedToken,
        };
    }

    fn match(self: *Parser, token_types: []const TokenType) bool {
        for (token_types) |token| {
            if (self.check(token)) {
                _ = self.advance();
                return true;
            }
        }

        return false;
    }

    fn check(self: *Parser, token: TokenType) bool {
        if (self.is_at_end()) {
            return false;
        }

        return self.peek().type == token;
    }

    fn advance(self: *Parser) Token {
        if (!self.is_at_end()) {
            self.pos += 1;
        }

        return self.prev();
    }

    fn is_at_end(self: *Parser) bool {
        return self.peek().type == TokenType.EOF;
    }

    fn peek(self: *Parser) Token {
        return self.tokens.items[self.pos];
    }

    fn prev(self: *Parser) Token {
        return self.tokens.items[self.pos - 1];
    }
};
