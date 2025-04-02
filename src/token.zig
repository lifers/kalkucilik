pub const TokenType = enum {
    Number,
    Plus,
    Minus,
    Multiply,
    Divide,
    LeftParen,
    RightParen,
    Exponent,
    Let,
    VarName,
    Assign,
    EOF,

    // Constants
    Pi,
    Euler,
    Phi,

    // Functions
    Sin,
    Cos,
    Tan,
    Asin,
    Acos,
    Atan,
    Sinh,
    Cosh,
    Tanh,
    Asinh,
    Acosh,
    Atanh,
    Sqrt,
    Cbrt,

    pub fn toString(self: TokenType) []const u8 {
        return switch (self) {
            .Number => "Number",
            .Plus => "Plus",
            .Minus => "Minus",
            .Multiply => "Multiply",
            .Divide => "Divide",
            .LeftParen => "LeftParen",
            .RightParen => "RightParen",
            .Exponent => "Exponent",
            .Let => "Let",
            .VarName => "VarName",
            .Assign => "Assign",
            .EOF => "EOF",

            // Constants
            .Pi => "Pi",
            .Euler => "Euler",
            .Phi => "Phi",

            // Functions
            .Sin => "Sin",
            .Cos => "Cos",
            .Tan => "Tan",
            .Asin => "Asin",
            .Acos => "Acos",
            .Atan => "Atan",
            .Sinh => "Sinh",
            .Cosh => "Cosh",
            .Tanh => "Tanh",
            .Asinh => "Asinh",
            .Acosh => "Acosh",
            .Atanh => "Atanh",
            .Sqrt => "Sqrt",
            .Cbrt => "Cbrt",
        };
    }
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    pos: usize,
};
