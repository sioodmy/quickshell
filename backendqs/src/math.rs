use anyhow::{anyhow, Context, Result};
use std::fs;
use std::process::Command;

pub fn process_query(query: &str, out_path: Option<&str>, color: Option<&str>, work_dir: Option<&std::path::Path>) -> Result<(String, Option<String>)> {
    let latex = crate::parser::parse_and_convert(query)
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;

    latex_to_svg(&latex, out_path, work_dir, color).map_err(|e| anyhow::anyhow!("Render Error: {}", e))
}

fn latex_to_svg(latex: &str, out_path: Option<&str>, work_dir: Option<&std::path::Path>, color: Option<&str>) -> Result<(String, Option<String>)> {
    let temp_dir_guard;
    let path = if let Some(d) = work_dir {
        d
    } else {
        temp_dir_guard = tempfile::tempdir()?;
        temp_dir_guard.path()
    };

    let tex_path = path.join("math.tex");
    let pdf_path = path.join("math.pdf");
    let svg_path = path.join("math.svg");

    let tex_content = format!(
        r#"\documentclass[preview]{{standalone}}
\usepackage{{amsmath}}
\usepackage{{amssymb}}
\begin{{document}}
$ {latex} $
\end{{document}}"#,
        latex = latex
    );

    fs::write(&tex_path, tex_content)?;

    let tectonic_output = Command::new("tectonic")
        .arg(tex_path.to_str().unwrap())
        .current_dir(path)
        .output()
        .context("Failed to run tectonic")?;

    if !tectonic_output.status.success() {
        let err_msg = String::from_utf8_lossy(&tectonic_output.stderr);
        return Err(anyhow!("Tectonic failed to compile LaTeX: {}", err_msg));
    }

    let pdftocairo_output = Command::new("pdftocairo")
        .args(&["-svg", pdf_path.to_str().unwrap(), svg_path.to_str().unwrap()])
        .output()
        .context("Failed to run pdftocairo")?;

    if !pdftocairo_output.status.success() {
        let err_msg = String::from_utf8_lossy(&pdftocairo_output.stderr);
        return Err(anyhow!("pdftocairo failed to generate SVG: {}", err_msg));
    }

    let mut svg_content = fs::read_to_string(&svg_path)?;

    if let Some(c) = color {
        svg_content = svg_content
            .replace("rgb(0%, 0%, 0%)", c)
            .replace("rgb(0%,0%,0%)", c)
            .replace("#000000", c);
    }

    if let Some(p) = out_path {
        fs::write(p, &svg_content)?;
        Ok((svg_content, Some(p.to_string())))
    } else {
        Ok((svg_content, None))
    }
}
