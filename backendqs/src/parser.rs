use std::iter::Peekable;
use std::str::Chars;

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Number(String),
    Ident(String),
    Plus,
    Minus,
    Star,
    Slash,
    Caret,
    LParen,
    RParen,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
    Comma,
    Dot,
    Equals,
    Eof,
}

fn split_ident(mut s: &str) -> Vec<String> {
    let keywords = ["sin", "cos", "tan", "csc", "sec", "cot", "arcsin", "arccos", "arctan", "ln", "log", "exp", "det", "sum", "integrate", "integral", "derivative", "infinity", "inf", "pi", "alpha", "beta", "gamma", "delta", "epsilon", "theta", "lambda", "omega", "from", "to", "of", "dx", "dy", "dz"];
    let mut result = Vec::new();
    while !s.is_empty() {
        let mut best_match = "";
        for kw in &keywords {
            if s.to_lowercase().starts_with(kw) {
                if kw.len() > best_match.len() {
                    best_match = kw;
                }
            }
        }
        if !best_match.is_empty() {
            result.push(s[..best_match.len()].to_string());
            s = &s[best_match.len()..];
        } else {
            let mut chars = s.chars();
            if let Some(c) = chars.next() {
                result.push(c.to_string());
                s = chars.as_str();
            }
        }
    }
    result
}

pub struct Lexer<'a> {
    chars: Peekable<Chars<'a>>,
    token_queue: Vec<Token>,
}

impl<'a> Lexer<'a> {
    pub fn new(input: &'a str) -> Self {
        Self {
            chars: input.chars().peekable(),
            token_queue: Vec::new(),
        }
    }

    fn consume_whitespace(&mut self) {
        while let Some(&c) = self.chars.peek() {
            if c.is_whitespace() {
                self.chars.next();
            } else {
                break;
            }
        }
    }

    pub fn next_token(&mut self) -> Token {
        if !self.token_queue.is_empty() {
            return self.token_queue.remove(0);
        }

        self.consume_whitespace();

        if let Some(&c) = self.chars.peek() {
            match c {
                '+' => { self.chars.next(); Token::Plus }
                '-' => { self.chars.next(); Token::Minus }
                '*' => { self.chars.next(); Token::Star }
                '/' => { self.chars.next(); Token::Slash }
                '^' => { self.chars.next(); Token::Caret }
                '(' => { self.chars.next(); Token::LParen }
                ')' => { self.chars.next(); Token::RParen }
                '[' => { self.chars.next(); Token::LBracket }
                ']' => { self.chars.next(); Token::RBracket }
                '{' => { self.chars.next(); Token::LBrace }
                '}' => { self.chars.next(); Token::RBrace }
                ',' => { self.chars.next(); Token::Comma }
                '=' => { self.chars.next(); Token::Equals }
                _ if c.is_ascii_digit() || c == '.' => {
                    if c == '.' {
                        self.chars.next();
                        if let Some(&next_c) = self.chars.peek() {
                            if !next_c.is_ascii_digit() {
                                return Token::Dot;
                            }
                        } else {
                            return Token::Dot;
                        }
                        let mut num = String::from(".");
                        while let Some(&c) = self.chars.peek() {
                            if c.is_ascii_digit() || c == '.' {
                                num.push(c);
                                self.chars.next();
                            } else {
                                break;
                            }
                        }
                        Token::Number(num)
                    } else {
                        let mut num = String::new();
                        while let Some(&c) = self.chars.peek() {
                            if c.is_ascii_digit() || c == '.' {
                                num.push(c);
                                self.chars.next();
                            } else {
                                break;
                            }
                        }
                        Token::Number(num)
                    }
                }
                _ if c.is_alphabetic() => {
                    let mut ident = String::new();
                    while let Some(&c) = self.chars.peek() {
                        if c.is_alphanumeric() || c == '_' {
                            ident.push(c);
                            self.chars.next();
                        } else {
                            break;
                        }
                    }
                    let parts = split_ident(&ident);
                    for part in parts {
                        self.token_queue.push(Token::Ident(part));
                    }
                    return self.token_queue.remove(0);
                }
                _ => {
                    self.chars.next();
                    self.next_token() // skip unknown
                }
            }
        } else {
            Token::Eof
        }
    }
}

#[derive(Debug, Clone)]
pub enum Expr {
    Number(String),
    Var(String),
    Add(Box<Expr>, Box<Expr>),
    Sub(Box<Expr>, Box<Expr>),
    Mul(Box<Expr>, Box<Expr>),
    Div(Box<Expr>, Box<Expr>),
    Pow(Box<Expr>, Box<Expr>),
    Neg(Box<Expr>),
    Func(String, Vec<Expr>),
    Integral(Box<Expr>, Box<Expr>), 
    IntegralBound(Box<Expr>, Box<Expr>, Box<Expr>, Box<Expr>),
    Sum(Box<Expr>, Box<Expr>, Box<Expr>, Box<Expr>),
    List(Vec<Expr>),
    Det(Box<Expr>),
    Derivative(Box<Expr>),
}

pub struct Parser<'a> {
    lexer: Lexer<'a>,
    current_token: Token,
}

impl<'a> Parser<'a> {
    pub fn new(input: &'a str) -> Self {
        let mut lexer = Lexer::new(input);
        let current_token = lexer.next_token();
        Self { lexer, current_token }
    }

    fn advance(&mut self) {
        self.current_token = self.lexer.next_token();
    }

    pub fn parse(&mut self) -> Result<Expr, String> {
        self.parse_expr(0)
    }

    fn get_precedence(&self, token: &Token) -> u8 {
        match token {
            Token::Plus | Token::Minus => 10,
            Token::Star | Token::Slash | Token::Dot => 20,
            Token::Ident(id) if id.eq_ignore_ascii_case("from") || id.eq_ignore_ascii_case("to") || (id.to_lowercase().starts_with('d') && id.len() == 2) => 0,
            Token::Comma | Token::Equals | Token::Eof => 0,
            // Implicit multiplication with identifiers, numbers, and parens binds tightly
            Token::Ident(_) | Token::Number(_) | Token::LParen | Token::LBrace => 25,
            Token::Caret => 30,
            _ => 0,
        }
    }

    fn is_implicit_mult(&self, token: &Token) -> bool {
        match token {
            Token::Ident(id) if id.eq_ignore_ascii_case("from") || id.eq_ignore_ascii_case("to") || (id.to_lowercase().starts_with('d') && id.len() == 2) => false,
            Token::Comma | Token::Equals => false,
            Token::Ident(_) | Token::Number(_) | Token::LParen | Token::LBrace => true,
            _ => false,
        }
    }

    fn parse_expr(&mut self, precedence: u8) -> Result<Expr, String> {
        let mut left = self.parse_prefix()?;

        while precedence < self.get_precedence(&self.current_token) {
            let op = self.current_token.clone();
            if self.is_implicit_mult(&op) {
                left = Expr::Mul(Box::new(left), Box::new(self.parse_expr(20)?));
            } else {
                self.advance();
                left = self.parse_infix(left, op)?;
            }
        }

        Ok(left)
    }

    fn parse_prefix(&mut self) -> Result<Expr, String> {
        match self.current_token.clone() {
            Token::Number(n) => {
                self.advance();
                Ok(Expr::Number(n))
            }
            Token::Ident(id) => {
                self.advance();
                
                // Parse function or wolfram calls: id(expr, ...) or id[expr, ...]
                let mut is_func_call = self.current_token == Token::LParen || self.current_token == Token::LBracket;
                if self.current_token == Token::LParen {
                    let lower_id = id.to_lowercase();
                    if matches!(lower_id.as_str(), "integrate" | "integral" | "sum" | "det" | "determinant") {
                        let mut depth = 1;
                        let mut has_comma = false;
                        let mut temp_tokens = Vec::new();
                        
                        while depth > 0 {
                            let next_tok = self.lexer.next_token();
                            if next_tok == Token::Eof {
                                temp_tokens.push(next_tok);
                                break;
                            }
                            match &next_tok {
                                Token::LParen | Token::LBracket | Token::LBrace => depth += 1,
                                Token::RParen | Token::RBracket | Token::RBrace => depth -= 1,
                                Token::Comma if depth == 1 => has_comma = true,
                                _ => {}
                            }
                            temp_tokens.push(next_tok);
                        }
                        
                        let mut new_queue = temp_tokens;
                        new_queue.append(&mut self.lexer.token_queue);
                        self.lexer.token_queue = new_queue;
                        
                        if !has_comma {
                            is_func_call = false;
                        }
                    }
                }
                
                if is_func_call {
                    let is_bracket = self.current_token == Token::LBracket;
                    self.advance();
                    let mut args = Vec::new();
                    if self.current_token != Token::RParen && self.current_token != Token::RBracket {
                        args.push(self.parse_expr(0)?);
                        while self.current_token == Token::Comma {
                            self.advance();
                            args.push(self.parse_expr(0)?);
                        }
                    }
                    if is_bracket {
                        if self.current_token == Token::RBracket { self.advance(); }
                    } else {
                        if self.current_token == Token::RParen { self.advance(); }
                    }
                    
                    if (id.eq_ignore_ascii_case("integrate") || id.eq_ignore_ascii_case("integral")) && args.len() == 2 {
                        return Ok(Expr::Integral(Box::new(args[0].clone()), Box::new(args[1].clone())));
                    }
                    if id.eq_ignore_ascii_case("derivative") && args.len() == 1 {
                        return Ok(Expr::Derivative(Box::new(args[0].clone())));
                    }
                    if id.eq_ignore_ascii_case("sum") && args.len() == 4 {
                        return Ok(Expr::Sum(Box::new(args[0].clone()), Box::new(args[1].clone()), Box::new(args[2].clone()), Box::new(args[3].clone())));
                    }

                    Ok(Expr::Func(id, args))
                } else {
                    if id.eq_ignore_ascii_case("sum") {
                        let inner_expr = self.parse_expr(0)?;
                        if self.current_token == Token::Comma {
                            self.advance();
                        } else if let Token::Ident(ref next_id) = self.current_token {
                            if next_id.eq_ignore_ascii_case("from") {
                                self.advance();
                            }
                        }
                        
                        let mut var = Expr::Var("n".into());
                        if let Token::Ident(var_name) = self.current_token.clone() {
                            if var_name.to_lowercase() != "to" && var_name.to_lowercase() != "from" {
                                var = Expr::Var(var_name);
                                self.advance();
                            }
                        }
                        
                        if self.current_token == Token::Equals {
                            self.advance();
                        }
                        
                        let start = self.parse_expr(0)?;
                        
                        if let Token::Ident(ref to_id) = self.current_token {
                            if to_id.eq_ignore_ascii_case("to") {
                                self.advance();
                            }
                        }
                        
                        let end = self.parse_expr(0)?;
                        
                        return Ok(Expr::Sum(Box::new(inner_expr), Box::new(var), Box::new(start), Box::new(end)));
                    }
                    if id.eq_ignore_ascii_case("integrate") || id.eq_ignore_ascii_case("integral") {
                        let inner_expr = self.parse_expr(0)?;
                        
                        let mut var = Expr::Var("x".into());
                        
                        if let Token::Ident(ref dx_id) = self.current_token {
                            if dx_id.to_lowercase().starts_with('d') && dx_id.len() == 2 {
                                var = Expr::Var(dx_id.chars().nth(1).unwrap().to_string());
                                self.advance();
                            }
                        }

                        if let Token::Ident(ref next_id) = self.current_token {
                            if next_id.eq_ignore_ascii_case("from") {
                                self.advance(); // consume "from"
                                let lower = self.parse_expr(0)?;
                                if let Token::Ident(ref to_id) = self.current_token {
                                    if to_id.eq_ignore_ascii_case("to") {
                                        self.advance(); // consume "to"
                                        let upper = self.parse_expr(0)?;
                                        
                                        // check if dx is AFTER the bounds
                                        if let Token::Ident(ref dx_id) = self.current_token {
                                            if dx_id.to_lowercase().starts_with('d') && dx_id.len() == 2 {
                                                var = Expr::Var(dx_id.chars().nth(1).unwrap().to_string());
                                                self.advance();
                                            }
                                        }

                                        return Ok(Expr::IntegralBound(Box::new(inner_expr), Box::new(var), Box::new(lower), Box::new(upper)));
                                    }
                                }
                            }
                        }
                        
                        return Ok(Expr::Integral(Box::new(inner_expr), Box::new(var)));
                    }
                    if id.eq_ignore_ascii_case("det") || id.eq_ignore_ascii_case("determinant") {
                        let inner_expr = self.parse_expr(0)?;
                        return Ok(Expr::Det(Box::new(inner_expr)));
                    }
                    if id.eq_ignore_ascii_case("derivative") {
                        if let Token::Ident(ref next_id) = self.current_token {
                            if next_id.eq_ignore_ascii_case("of") {
                                self.advance();
                            }
                        }
                        let inner_expr = self.parse_expr(0)?;
                        return Ok(Expr::Derivative(Box::new(inner_expr)));
                    }
                    
                    let lower_id = id.to_lowercase();
                    let is_func = matches!(lower_id.as_str(), "sin" | "cos" | "tan" | "csc" | "sec" | "cot" | "arcsin" | "arccos" | "arctan" | "ln" | "log" | "exp" | "derivative");
                    if is_func {
                        let arg = self.parse_expr(24)?;
                        if lower_id == "derivative" {
                            return Ok(Expr::Derivative(Box::new(arg)));
                        }
                        return Ok(Expr::Func(id, vec![arg]));
                    }
                    
                    Ok(Expr::Var(id))
                }
            }
            Token::Minus => {
                self.advance();
                let expr = self.parse_expr(25)?; // Precedence for prefix minus
                Ok(Expr::Neg(Box::new(expr)))
            }
            Token::LParen => {
                self.advance();
                let expr = self.parse_expr(0)?;
                if self.current_token == Token::RParen {
                    self.advance();
                }
                Ok(expr)
            }
            Token::LBrace => {
                self.advance();
                let mut elements = Vec::new();
                if self.current_token != Token::RBrace {
                    elements.push(self.parse_expr(0)?);
                    while self.current_token == Token::Comma {
                        self.advance();
                        elements.push(self.parse_expr(0)?);
                    }
                }
                if self.current_token != Token::RBrace {
                    return Err("Expected '}' at the end of list".into());
                }
                self.advance();
                Ok(Expr::List(elements))
            }
            _ => Err(format!("Unexpected token: {:?}", self.current_token)),
        }
    }

    fn parse_infix(&mut self, left: Expr, op: Token) -> Result<Expr, String> {
        match op {
            Token::Plus => Ok(Expr::Add(Box::new(left), Box::new(self.parse_expr(10)?))),
            Token::Minus => Ok(Expr::Sub(Box::new(left), Box::new(self.parse_expr(10)?))),
            Token::Star | Token::Dot => Ok(Expr::Mul(Box::new(left), Box::new(self.parse_expr(20)?))),
            Token::Slash => Ok(Expr::Div(Box::new(left), Box::new(self.parse_expr(20)?))),
            Token::Caret => Ok(Expr::Pow(Box::new(left), Box::new(self.parse_expr(29)?))), // Right-associative
            _ => Err("Expected infix operator".into()),
        }
    }
}

#[allow(dead_code)]
pub fn to_latex(expr: &Expr) -> String {
    match expr {
        Expr::Number(n) => n.clone(),
        Expr::Var(v) => {
            let v_lower = v.to_lowercase();
            match v_lower.as_str() {
                "alpha" | "beta" | "gamma" | "delta" | "epsilon" | "zeta" | "eta" | "theta" |
                "iota" | "kappa" | "lambda" | "mu" | "nu" | "xi" | "omicron" | "pi" | "rho" |
                "sigma" | "tau" | "upsilon" | "phi" | "chi" | "psi" | "omega" => format!("\\{}", v_lower),
                "infinity" | "inf" => "\\infty".into(),
                _ => {
                    if v.len() > 1 {
                        format!("\\text{{{}}}", v)
                    } else {
                        v.clone()
                    }
                }
            }
        }
        Expr::Add(l, r) => format!("{} + {}", to_latex(l), to_latex(r)),
        Expr::Sub(l, r) => format!("{} - {}", to_latex(l), to_latex(r)),
        Expr::Mul(l, r) => {
            let left_str = match **l {
                Expr::Add(_, _) | Expr::Sub(_, _) => format!("\\left({}\\right)", to_latex(l)),
                _ => to_latex(l),
            };
            let right_str = match **r {
                Expr::Add(_, _) | Expr::Sub(_, _) => format!("\\left({}\\right)", to_latex(r)),
                _ => to_latex(r),
            };
            format!("{} \\cdot {}", left_str, right_str)
        }
        Expr::Div(l, r) => format!("\\frac{{{}}}{{{}}}", to_latex(l), to_latex(r)),
        Expr::Pow(l, r) => {
            let left_str = match **l {
                Expr::Number(_) | Expr::Var(_) | Expr::Func(_, _) => to_latex(l),
                _ => format!("\\left({}\\right)", to_latex(l)),
            };
            format!("{}^{{{}}}", left_str, to_latex(r))
        }
        Expr::Neg(e) => {
            let e_str = match **e {
                Expr::Add(_, _) | Expr::Sub(_, _) => format!("\\left({}\\right)", to_latex(e)),
                _ => to_latex(e),
            };
            format!("-{}", e_str)
        }
        Expr::Integral(e, var) => format!("\\int {} \\, d{}", to_latex(e), to_latex(var)),
        Expr::IntegralBound(e, var, lower, upper) => format!("\\int_{{{}}}^{{{}}} {} \\, d{}", to_latex(lower), to_latex(upper), to_latex(e), to_latex(var)),
        Expr::Sum(e, var, start, end) => format!("\\sum_{{{}={}}}^{{{}}} {}", to_latex(var), to_latex(start), to_latex(end), to_latex(e)),
        Expr::Func(f, args) => {
            let f_lower = f.to_lowercase();
            let latex_args: Vec<String> = args.iter().map(to_latex).collect();
            match f_lower.as_str() {
                "sin" | "cos" | "tan" | "csc" | "sec" | "cot" | "arcsin" | "arccos" | "arctan" | "log" | "ln" | "exp" => {
                    if args.len() == 1 {
                        format!("\\{}\\left({}\\right)", f_lower, latex_args[0])
                    } else {
                        format!("\\text{{{}}}\\left({}\\right)", f, latex_args.join(", "))
                    }
                }
                "sqrt" => {
                    if args.len() == 1 {
                        format!("\\sqrt{{{}}}", latex_args[0])
                    } else {
                        format!("\\sqrt{{{}}}", latex_args.join(", "))
                    }
                }
                _ => format!("\\text{{{}}}\\left({}\\right)", f, latex_args.join(", ")),
            }
        }
        Expr::List(elements) => {
            let is_matrix = !elements.is_empty() && elements.iter().all(|e| matches!(e, Expr::List(_)));
            if is_matrix {
                let mut rows = Vec::new();
                for row_expr in elements {
                    if let Expr::List(row_elements) = row_expr {
                        let row_str: Vec<String> = row_elements.iter().map(to_latex).collect();
                        rows.push(row_str.join(" & "));
                    }
                }
                format!("\\begin{{bmatrix}} {} \\end{{bmatrix}}", rows.join(" \\\\ "))
            } else {
                let elements_str: Vec<String> = elements.iter().map(to_latex).collect();
                format!("\\begin{{bmatrix}} {} \\end{{bmatrix}}", elements_str.join(" & "))
            }
        }
        Expr::Det(e) => {
            if let Expr::List(ref elements) = **e {
                let is_matrix = !elements.is_empty() && elements.iter().all(|e| matches!(e, Expr::List(_)));
                if is_matrix {
                    let mut rows = Vec::new();
                    for row_expr in elements {
                        if let Expr::List(row_elements) = row_expr {
                            let row_str: Vec<String> = row_elements.iter().map(to_latex).collect();
                            rows.push(row_str.join(" & "));
                        }
                    }
                    return format!("\\begin{{vmatrix}} {} \\end{{vmatrix}}", rows.join(" \\\\ "));
                }
            }
            format!("\\det\\left({}\\right)", to_latex(e))
        }
        Expr::Derivative(e) => {
            let e_str = match **e {
                Expr::Add(_, _) | Expr::Sub(_, _) => format!("\\left({}\\right)", to_latex(e)),
                _ => to_latex(e),
            };
            format!("\\frac{{d}}{{dx}} {}", e_str)
        }
    }
}

#[allow(dead_code)]
pub fn parse_and_convert(input: &str) -> Result<String, String> {
    let mut parser = Parser::new(input);
    let expr = parser.parse()?;
    
    if parser.current_token != Token::Eof {
        return Err(format!("Unexpected tokens at end of input: {:?}", parser.current_token));
    }
    
    Ok(to_latex(&expr))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_arithmetic() {
        assert_eq!(parse_and_convert("1 + 2 * 3").unwrap(), "1 + 2 \\cdot 3");
        assert_eq!(parse_and_convert("x^2").unwrap(), "x^{2}");
        assert_eq!(parse_and_convert("1/2").unwrap(), "\\frac{1}{2}");
    }

    #[test]
    fn test_implicit_mult() {
        assert_eq!(parse_and_convert("2x").unwrap(), "2 \\cdot x");
        assert_eq!(parse_and_convert("x y").unwrap(), "x \\cdot y");
    }

    #[test]
    fn test_functions() {
        assert_eq!(parse_and_convert("sin(x)").unwrap(), "\\sin\\left(x\\right)");
        assert_eq!(parse_and_convert("xlnx").unwrap(), "x \\cdot \\ln\\left(x\\right)");
        assert_eq!(parse_and_convert("cos2pi").unwrap(), "\\cos\\left(2 \\cdot \\pi\\right)");
        assert_eq!(parse_and_convert("sinx").unwrap(), "\\sin\\left(x\\right)");
    }

    #[test]
    fn test_integrals() {
        assert_eq!(parse_and_convert("integrate x^2 dx").unwrap(), "\\int x^{2} \\, dx");
        assert_eq!(parse_and_convert("integral x^2 + 2 dx").unwrap(), "\\int x^{2} + 2 \\, dx");
        assert_eq!(parse_and_convert("integral xlnx from 1 to e").unwrap(), "\\int_{1}^{e} x \\cdot \\ln\\left(x\\right) \\, dx");
        assert_eq!(parse_and_convert("integral (2x-1)^2/3 dx").unwrap(), "\\int \\frac{\\left(2 \\cdot x - 1\\right)^{2}}{3} \\, dx");
    }

    #[test]
    fn test_sums() {
        assert_eq!(parse_and_convert("sum 1/n^2, n=1 to infinity").unwrap(), "\\sum_{n=1}^{\\infty} \\frac{1}{n^{2}}");
        assert_eq!(parse_and_convert("sum(n, n, 1, 10)").unwrap(), "\\sum_{n=1}^{10} n");
    }

    #[test]
    fn test_matrices() {
        assert_eq!(parse_and_convert("{{2, -1}, {1, 3}} . {{1, 2}, {3, 4}}").unwrap(), "\\begin{bmatrix} 2 & -1 \\\\ 1 & 3 \\end{bmatrix} \\cdot \\begin{bmatrix} 1 & 2 \\\\ 3 & 4 \\end{bmatrix}");
        assert_eq!(parse_and_convert("det {{2, 3}, {4, 5}}").unwrap(), "\\begin{vmatrix} 2 & 3 \\\\ 4 & 5 \\end{vmatrix}");
    }
}
