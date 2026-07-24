use anyhow::Result;
use std::fs;
use crate::parser::Expr;

#[derive(Clone)]
struct Layout {
    svg: String,
    width: f64,
    height: f64,
    baseline: f64,
}

impl Layout {
    fn text(s: &str, font_size: f64, is_italic: bool) -> Self {
        let width = s.chars().count() as f64 * (font_size * 0.6);
        let height = font_size * 1.2;
        let baseline = font_size * 0.9;
        let s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
        let style = if is_italic { "font-style=\"italic\"" } else { "" };
        let svg = format!(r#"<text x="0" y="{baseline}" font-family="serif" font-weight="bold" font-size="{font_size}" {style} fill="currentColor">{s}</text>"#);
        Layout { svg, width, height, baseline }
    }

    fn text_scaled(s: &str, font_size: f64, is_italic: bool, scale_x: f64, scale_y: f64) -> Self {
        let mut layout = Self::text(s, font_size, is_italic);
        layout.width *= scale_x;
        layout.height *= scale_y;
        layout.baseline *= scale_y;
        layout.svg = format!("<g transform=\"scale({}, {})\">{}</g>", scale_x, scale_y, layout.svg);
        layout
    }
}

fn h_box(layouts: Vec<Layout>, spacing: f64) -> Layout {
    if layouts.is_empty() { return Layout::text("", 20.0, false); }
    let max_baseline = layouts.iter().map(|l| l.baseline).fold(0.0, f64::max);
    let max_descent = layouts.iter().map(|l| l.height - l.baseline).fold(0.0, f64::max);
    let height = max_baseline + max_descent;
    let mut svg = String::new();
    let mut current_x = 0.0;
    for l in layouts {
        let y_shift = max_baseline - l.baseline;
        svg.push_str(&format!("<g transform=\"translate({}, {})\">{}</g>", current_x, y_shift, l.svg));
        current_x += l.width + spacing;
    }
    current_x -= spacing;
    Layout { svg, width: current_x, height, baseline: max_baseline }
}

fn v_frac(top: Layout, bottom: Layout, font_size: f64) -> Layout {
    let width = top.width.max(bottom.width) + 10.0;
    let top_x = (width - top.width) / 2.0;
    let bottom_x = (width - bottom.width) / 2.0;
    let line_y = top.height + 4.0;
    let bottom_y = line_y + 4.0;
    let height = bottom_y + bottom.height;
    let baseline = line_y + font_size * 0.3;
    let svg = format!(
        "<g transform=\"translate({}, 0)\">{}</g>\
         <line x1=\"0\" y1=\"{}\" x2=\"{}\" y2=\"{}\" stroke=\"currentColor\" stroke-width=\"2\"/>\
         <g transform=\"translate({}, {})\">{}</g>",
        top_x, top.svg, line_y, width, line_y, bottom_x, bottom_y, bottom.svg
    );
    Layout { svg, width, height, baseline }
}

fn sup(base: Layout, exp: Layout) -> Layout {
    let exp_y = 0.0;
    let base_y = exp.height * 0.5;
    let width = base.width + exp.width;
    let height = base_y + base.height;
    let baseline = base_y + base.baseline;
    let svg = format!(
        "<g transform=\"translate(0, {})\">{}</g><g transform=\"translate({}, {})\">{}</g>",
        base_y, base.svg, base.width, exp_y, exp.svg
    );
    Layout { svg, width, height, baseline }
}

fn bracket(inner: &Layout, is_left: bool, is_bar: bool) -> Layout {
    let h = inner.height + 8.0;
    let w = if is_bar { 4.0 } else { 8.0 };
    let baseline = inner.baseline + 4.0;
    
    let d = if is_bar {
        format!("M {},0 L {},{}", w/2.0, w/2.0, h)
    } else if is_left {
        format!("M {},0 L 0,0 L 0,{} L {},{}", w, h, w, h)
    } else {
        format!("M 0,0 L {},0 L {},{} L 0,{}", w, w, h, h)
    };
    
    let svg = format!("<path d=\"{}\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>", d);
    Layout { svg, width: w, height: h, baseline }
}

fn render(expr: &Expr, font_size: f64) -> Layout {
    match expr {
        Expr::Number(n) => Layout::text(n, font_size, false),
        Expr::Var(v) => Layout::text(v, font_size, true),
        Expr::Add(a, b) => h_box(vec![render(a, font_size), Layout::text("+", font_size, false), render(b, font_size)], 4.0),
        Expr::Sub(a, b) => h_box(vec![render(a, font_size), Layout::text("−", font_size, false), render(b, font_size)], 4.0),
        Expr::Mul(a, b) => {
            let needs_dot = matches!((&**a, &**b), (Expr::Number(_), Expr::Number(_)));
            if needs_dot {
                h_box(vec![render(a, font_size), Layout::text("⋅", font_size, false), render(b, font_size)], 4.0)
            } else {
                h_box(vec![render(a, font_size), render(b, font_size)], 2.0)
            }
        },
        Expr::Div(a, b) => v_frac(render(a, font_size), render(b, font_size), font_size),
        Expr::Pow(a, b) => sup(render(a, font_size), render(b, font_size * 0.7)),
        Expr::Neg(a) => {
            let mut minus = Layout::text("−", font_size, false);
            minus.width = font_size * 0.45;
            h_box(vec![minus, render(a, font_size)], 0.0)
        },
        Expr::Func(name, args) => {
            let mut parts = vec![Layout::text(name, font_size, false), Layout::text("(", font_size, false)];
            for (i, arg) in args.iter().enumerate() {
                if i > 0 { parts.push(Layout::text(",", font_size, false)); }
                parts.push(render(arg, font_size));
            }
            parts.push(Layout::text(")", font_size, false));
            h_box(parts, 2.0)
        }
        Expr::Integral(expr, _dx) => {
            let inner = render(expr, font_size);
            let scale_y = (inner.height / (font_size * 1.2)).max(1.5);
            let mut int_sym = Layout::text_scaled("∫", font_size, false, 0.8, scale_y);
            let orig_baseline = font_size * 0.9 * scale_y;
            let target_baseline = int_sym.height / 2.0 + font_size * 0.3;
            let shift = target_baseline - orig_baseline;
            int_sym.svg = format!("<g transform=\"translate(0, {})\">{}</g>", shift, int_sym.svg);
            int_sym.baseline = target_baseline;
            h_box(vec![int_sym, inner, Layout::text("dx", font_size, false)], 4.0)
        }
        Expr::IntegralBound(expr, lower, upper, _dx) => {
            let inner = render(expr, font_size);
            let scale_y = (inner.height / (font_size * 1.2)).max(1.5);
            let mut int_sym = Layout::text_scaled("∫", font_size, false, 0.8, scale_y);
            let orig_baseline = font_size * 0.9 * scale_y;
            let target_baseline = int_sym.height / 2.0 + font_size * 0.3;
            let shift = target_baseline - orig_baseline;
            int_sym.svg = format!("<g transform=\"translate(0, {})\">{}</g>", shift, int_sym.svg);
            int_sym.baseline = target_baseline;
            let l = render(lower, font_size * 0.7);
            let u = render(upper, font_size * 0.7);
            let sym_width = int_sym.width.max(u.width).max(l.width);
            let u_x = (sym_width - u.width) / 2.0;
            let i_x = (sym_width - int_sym.width) / 2.0;
            let l_x = (sym_width - l.width) / 2.0;
            let u_y = 0.0;
            let i_y = u.height;
            let l_y = i_y + int_sym.height;
            let height = l_y + l.height;
            let baseline = i_y + int_sym.baseline;
            let svg = format!(
                "<g transform=\"translate({}, {})\">{}</g><g transform=\"translate({}, {})\">{}</g><g transform=\"translate({}, {})\">{}</g>",
                u_x, u_y, u.svg, i_x, i_y, int_sym.svg, l_x, l_y, l.svg
            );
            let int_block = Layout { svg, width: sym_width, height, baseline };
            h_box(vec![int_block, inner, Layout::text("dx", font_size, false)], 4.0)
        }
        Expr::Sum(expr, var, lower, upper) => {
            let sum_sym = Layout::text("Σ", font_size * 1.5, false);
            let l_text = h_box(vec![render(var, font_size*0.7), Layout::text("=", font_size*0.7, false), render(lower, font_size*0.7)], 2.0);
            let u_text = render(upper, font_size * 0.7);
            let sym_width = sum_sym.width.max(u_text.width).max(l_text.width);
            let u_x = (sym_width - u_text.width) / 2.0;
            let s_x = (sym_width - sum_sym.width) / 2.0;
            let l_x = (sym_width - l_text.width) / 2.0;
            let u_y = 0.0;
            let s_y = u_text.height;
            let l_y = s_y + sum_sym.height;
            let height = l_y + l_text.height;
            let baseline = s_y + sum_sym.baseline;
            let svg = format!(
                "<g transform=\"translate({}, {})\">{}</g><g transform=\"translate({}, {})\">{}</g><g transform=\"translate({}, {})\">{}</g>",
                u_x, u_y, u_text.svg, s_x, s_y, sum_sym.svg, l_x, l_y, l_text.svg
            );
            let sum_block = Layout { svg, width: sym_width, height, baseline };
            h_box(vec![sum_block, render(expr, font_size)], 4.0)
        }
        Expr::List(exprs) => {
            let is_matrix = !exprs.is_empty() && exprs.iter().all(|e| matches!(e, Expr::List(_)));
            if is_matrix {
                let mut rows = Vec::new();
                let mut max_col_widths = Vec::new();
                for row_expr in exprs {
                    if let Expr::List(cols) = row_expr {
                        let mut row_layouts = Vec::new();
                        for (i, col) in cols.iter().enumerate() {
                            let l = render(col, font_size);
                            if i >= max_col_widths.len() {
                                max_col_widths.push(l.width);
                            } else {
                                max_col_widths[i] = max_col_widths[i].max(l.width);
                            }
                            row_layouts.push(l);
                        }
                        rows.push(row_layouts);
                    }
                }
                let mut current_y = 0.0;
                let mut svg = String::new();
                let mut width: f64 = 0.0;
                for row in rows {
                    let mut current_x = 0.0;
                    let mut max_baseline = 0.0f64;
                    let mut max_height = font_size * 1.5;
                    for col in &row {
                        if col.baseline > max_baseline { max_baseline = col.baseline; }
                        if col.height > max_height { max_height = col.height; }
                    }
                    for (i, col_layout) in row.into_iter().enumerate() {
                        let col_width = max_col_widths[i];
                        let offset_x = current_x + (col_width - col_layout.width) / 2.0;
                        let offset_y = current_y + (max_baseline - col_layout.baseline);
                        svg.push_str(&format!("<g transform=\"translate({}, {})\">{}</g>", offset_x, offset_y, col_layout.svg));
                        current_x += col_width + 10.0;
                    }
                    width = width.max(current_x - 10.0);
                    current_y += max_height;
                }
                let height = current_y;
                let baseline = height / 2.0;
                let matrix_block = Layout { svg, width, height, baseline };
                return h_box(vec![bracket(&matrix_block, true, false), matrix_block.clone(), bracket(&matrix_block, false, false)], 2.0);
            }
            let mut parts = vec![Layout::text("{", font_size, false)];
            for (i, e) in exprs.iter().enumerate() {
                if i > 0 { parts.push(Layout::text(",", font_size, false)); }
                parts.push(render(e, font_size));
            }
            parts.push(Layout::text("}", font_size, false));
            h_box(parts, 4.0)
        }
        Expr::Det(expr) => {
            let inner = render(expr, font_size);
            h_box(vec![bracket(&inner, true, true), inner.clone(), bracket(&inner, false, true)], 2.0)
        }
        Expr::Derivative(expr) => {
            let frac = v_frac(Layout::text("d", font_size, false), Layout::text("dx", font_size, false), font_size);
            h_box(vec![frac, render(expr, font_size)], 4.0)
        }
    }
}

pub fn process_query(query: &str, out_path: Option<&str>, color: Option<&str>, _work_dir: Option<&std::path::Path>) -> Result<(String, Option<String>)> {
    let mut parser = crate::parser::Parser::new(query);
    let expr = parser.parse().map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    
    let layout = render(&expr, 96.0);
    let c = color.unwrap_or("black");
    
    let svg_content = format!(
        r#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="-5 -5 {} {}" width="{}" height="{}" color="{}">{}</svg>"#,
        layout.width + 10.0, layout.height + 10.0, layout.width + 10.0, layout.height + 10.0, c, layout.svg
    );
    
    if let Some(p) = out_path {
        fs::write(p, &svg_content)?;
        Ok((svg_content, Some(p.to_string())))
    } else {
        Ok((svg_content, None))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_process_query() {
        let (svg, _) = process_query("integrate x^2 from 1 to 2 dx", None, None, None).unwrap();
        assert!(svg.contains("<svg"));
        assert!(svg.contains("∫"));
    }
}
