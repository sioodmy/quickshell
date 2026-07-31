use orgize::Org;
use orgize::elements::{Element, Timestamp, Datetime};
use orgize::export::{DefaultHtmlHandler, HtmlHandler};
use std::io::{Write, Result as IOResult, Error as IOError};
use urlencoding::encode;

pub struct AgendaEvent {
    pub id: String,
    pub title: String,
    pub label: String,
    pub display_date: String,
}

#[derive(Default)]
pub struct CustomHtmlHandler {
    inner: DefaultHtmlHandler,
    pub headline_counter: usize,
    pub events: Vec<AgendaEvent>,
}

fn dt_to_ics(dt: &Datetime) -> String {
    let mut s = format!("{:04}{:02}{:02}", dt.year, dt.month, dt.day);
    if let (Some(h), Some(m)) = (dt.hour, dt.minute) {
        s.push_str(&format!("T{:02}{:02}00", h, m));
    } else {
        s.push_str("T000000"); // default to start of day
    }
    s
}

fn format_dt_display(dt: &Datetime) -> String {
    let mut s = format!("{:04}-{:02}-{:02} {}", dt.year, dt.month, dt.day, dt.dayname);
    if let (Some(h), Some(m)) = (dt.hour, dt.minute) {
        s.push_str(&format!(" {:02}:{:02}", h, m));
    }
    s
}

fn render_m3_date_widget<W: Write>(w: &mut W, label: &str, dt: &Datetime, summary: &str) -> IOResult<()> {
    let dt_str = dt_to_ics(dt);
    let display_str = format_dt_display(dt);
    
    let ics_content = format!(
        "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nDTSTART:{}\r\nSUMMARY:{}\r\nEND:VEVENT\r\nEND:VCALENDAR",
        dt_str, summary
    );
    let b64_ics = encode(&ics_content);
    let data_uri = format!("data:text/calendar;charset=utf-8,{}", b64_ics);
    
    write!(w, r#"<a href="{}" download="event.ics" class="m3-date-widget" title="Add to Calendar">"#, data_uri)?;
    write!(w, r#"<span class="m3-date-icon">📅</span>"#)?;
    if !label.is_empty() {
        write!(w, r#"<span class="m3-date-title">{}</span>"#, label)?;
    }
    write!(w, r#"<span class="m3-date-value">{}</span>"#, display_str)?;
    write!(w, r#"</a>"#)
}

fn get_timestamp_dt<'a>(ts: &'a Timestamp<'a>) -> Option<&'a Datetime<'a>> {
    match ts {
        Timestamp::Active { start, .. } | Timestamp::Inactive { start, .. } | Timestamp::ActiveRange { start, .. } | Timestamp::InactiveRange { start, .. } => Some(start),
        _ => None,
    }
}

impl HtmlHandler<IOError> for CustomHtmlHandler {
    fn start<W: Write>(&mut self, mut w: W, element: &Element) -> IOResult<()> {
        match element {
            Element::Title(title) => {
                self.headline_counter += 1;
                let id = format!("headline-{}", self.headline_counter);
                
                if let Some(planning) = &title.planning {
                    if let Some(scheduled) = &planning.scheduled {
                        if let Some(dt) = get_timestamp_dt(scheduled) {
                            self.events.push(AgendaEvent {
                                id: id.clone(),
                                title: title.raw.to_string(),
                                label: "SCHEDULED".to_string(),
                                display_date: format_dt_display(dt),
                            });
                        }
                    }
                    if let Some(deadline) = &planning.deadline {
                        if let Some(dt) = get_timestamp_dt(deadline) {
                            self.events.push(AgendaEvent {
                                id: id.clone(),
                                title: title.raw.to_string(),
                                label: "DEADLINE".to_string(),
                                display_date: format_dt_display(dt),
                            });
                        }
                    }
                }
                
                write!(w, r#"<div id="{}" class="m3-headline-container">"#, id)?;
                write!(w, r#"<div class="m3-headline-header">"#)?;
                
                if let Some(keyword) = &title.keyword {
                    let is_done = keyword == "DONE" || keyword == "CANCELED";
                    let state_class = if is_done { "m3-todo-done" } else { "m3-todo-active" };
                    write!(w, r#"<span class="m3-todo-widget {}">{}</span>"#, state_class, keyword)?;
                }
                
                write!(w, "<h{} class=\"m3-headline-title level-{}\">", if title.level <= 6 { title.level } else { 6 }, title.level)?;
                return Ok(());
            }
            Element::Timestamp(ts) => {
                if let Some(dt) = get_timestamp_dt(ts) {
                    render_m3_date_widget(&mut w, "", dt, "Event")?;
                }
                return Ok(());
            }
            Element::Text { value } => {
                let escaped = orgize::export::HtmlEscape(value).to_string();
                
                lazy_static::lazy_static! {
                    static ref URL_REGEX: regex::Regex = regex::Regex::new(r"https?://[^\s<>]+").unwrap();
                }
                let result = URL_REGEX.replace_all(&escaped, |caps: &regex::Captures| {
                    let url = &caps[0];
                    let mut short_url = url;
                    if short_url.starts_with("https://") { short_url = &short_url[8..]; }
                    else if short_url.starts_with("http://") { short_url = &short_url[7..]; }
                    
                    let short_url_display = if short_url.len() > 30 {
                        format!("{}...", &short_url[..27])
                    } else {
                        short_url.to_string()
                    };
                    format!(r#"<a href="{}" class="raw-url" target="_blank">{}</a>"#, url, short_url_display)
                });
                
                write!(w, "{}", result)?;
                return Ok(());
            }
            _ => self.inner.start(w, element),
        }
    }

    fn end<W: Write>(&mut self, mut w: W, element: &Element) -> IOResult<()> {
        match element {
            Element::Title(title) => {
                write!(w, "</h{}>", if title.level <= 6 { title.level } else { 6 })?;
                
                if !title.tags.is_empty() {
                    write!(w, r#"<div class="m3-tags">"#)?;
                    for tag in &title.tags {
                        write!(w, r#"<span class="m3-tag-widget">{}</span>"#, tag)?;
                    }
                    write!(w, r#"</div>"#)?;
                }
                
                write!(w, r#"</div>"#)?; // end m3-headline-header
                
                if let Some(planning) = &title.planning {
                    let mut has_dates = false;
                    if planning.scheduled.is_some() || planning.deadline.is_some() || planning.closed.is_some() {
                        has_dates = true;
                        write!(w, r#"<div class="m3-planning">"#)?;
                    }
                    let raw_title = &title.raw;
                    if let Some(scheduled) = &planning.scheduled {
                        if let Some(dt) = get_timestamp_dt(scheduled) {
                            render_m3_date_widget(&mut w, "SCHEDULED", dt, raw_title)?;
                        }
                    }
                    if let Some(deadline) = &planning.deadline {
                        if let Some(dt) = get_timestamp_dt(deadline) {
                            render_m3_date_widget(&mut w, "DEADLINE", dt, raw_title)?;
                        }
                    }
                    if let Some(closed) = &planning.closed {
                        if let Some(dt) = get_timestamp_dt(closed) {
                            render_m3_date_widget(&mut w, "CLOSED", dt, raw_title)?;
                        }
                    }
                    if has_dates {
                        write!(w, r#"</div>"#)?;
                    }
                }
                
                write!(w, r#"</div>"#)?; // end m3-headline-container
                return Ok(());
            }
            Element::Timestamp(_) => {
                // Nothing to do for end of timestamp, we rendered everything in start
                return Ok(());
            }
            Element::Text { .. } => {
                // Handled in start
                return Ok(());
            }
            _ => self.inner.end(w, element),
        }
    }
}

pub fn render_org_to_html(content: &str) -> String {
    let org = Org::parse(content);
    let mut writer = Vec::new();
    let mut handler = CustomHtmlHandler::default();
    let _ = org.write_html_custom(&mut writer, &mut handler);
    let body = String::from_utf8_lossy(&writer).to_string();
    
    if handler.events.len() > 2 {
        let mut agenda_html = String::from(r#"<div class="m3-agenda"><h2>Upcoming Events</h2><div class="m3-agenda-list">"#);
        for ev in &handler.events {
            agenda_html.push_str(&format!(
                "<a href=\"#{}\" class=\"m3-agenda-item\" onclick=\"smoothScroll(event, '{}')\">\n\
                   <span class=\"m3-agenda-label\">{}</span>\n\
                   <span class=\"m3-agenda-title\">{}</span>\n\
                   <span class=\"m3-agenda-date\">📅 {}</span>\n\
                   </a>",
                ev.id, ev.id, ev.label, ev.title, ev.display_date
            ));
        }
        agenda_html.push_str("</div></div>");
        format!("{}{}", agenda_html, body)
    } else {
        body
    }
}

pub fn render_org_share_page(name: &str, content: &str) -> String {
    let html_content = render_org_to_html(content);
    
    // Capitalize first letter and strip .org
    let name_without_ext = name.strip_suffix(".org").unwrap_or(name);
    let mut c = name_without_ext.chars();
    let display_name = match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    };
    
    format!(
        r#"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{display_name}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Roboto:wght@400;500;700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
html,body{{height:100%;scroll-behavior:smooth}}
body{{font-family:system-ui,-apple-system,"Google Sans",Roboto,sans-serif;color:#e6e1e5;min-height:100dvh;padding:24px;overflow-x:hidden;background:#f5bde6;display:flex;justify-content:center;align-items:flex-start;line-height:1.6;font-size:15px}}
.bg{{position:fixed;inset:0;z-index:-2;background:#f5bde6}}
.orb{{position:absolute;border-radius:9999px;transform:translate3d(0,0,0)}}
.orb.one{{width:56vmax;height:56vmax;left:-8vmax;top:-10vmax;background:rgba(255,255,255,.40);animation:floatOne 8s ease-in-out infinite alternate}}
.orb.two{{width:52vmax;height:52vmax;right:-10vmax;top:-9vmax;background:rgba(198,160,246,.55);animation:floatTwo 10s ease-in-out infinite alternate}}
.orb.three{{width:34vmax;height:34vmax;left:14vmax;bottom:-9vmax;background:rgba(245,194,231,.35);animation:floatThree 12s ease-in-out infinite alternate}}
@keyframes floatOne{{0%{{transform:translate(0,0) rotate(0deg)}}100%{{transform:translate(12vmax,10vmax) rotate(22deg)}}}}
@keyframes floatTwo{{0%{{transform:translate(0,0) rotate(0deg)}}100%{{transform:translate(-14vmax,14vmax) rotate(-25deg)}}}}
@keyframes floatThree{{0%{{transform:translate(0,0)}}100%{{transform:translate(10vmax,-12vmax)}}}}
.scrim{{position:fixed;inset:0;z-index:-1;background:linear-gradient(180deg,rgba(18,16,26,.18),rgba(18,16,26,.06) 45%,rgba(18,16,26,.28))}}
.container{{max-width:800px;width:100%;margin-top:24px;margin-bottom:24px;position:relative;z-index:1}}
.card{{background:#1c1b1f;border:1px solid #2b2930;border-radius:28px;padding:32px 40px;box-shadow:0 10px 20px rgba(0,0,0,.31)}}
.header{{text-align:center;margin-bottom:32px}}
h1.main-title{{margin-top:0;font-size:28px;color:#f5bde6}}
a{{color:#cba6f7;text-decoration:none}}
a:hover{{text-decoration:underline}}
a.raw-url{{color:#ffffff;text-decoration:underline}}
ul, ol {{margin-left:24px;margin-bottom:16px;color:#cac4d0}}
p {{margin-bottom:16px}}
pre, code {{font-family:"JetBrains Mono",monospace;background:#2b2930;padding:3px 6px;border-radius:6px;font-size:0.9em;color:#cdd6f4}}
pre {{padding:16px;overflow-x:auto;display:block;margin-bottom:16px;border-radius:12px;border:1px solid #36343b}}
pre code {{padding:0;background:transparent;border:0}}
blockquote {{border-left:4px solid #cba6f7;margin:0 0 16px;padding-left:16px;color:#a6adc8;font-style:italic}}

/* M3 Custom Widgets */
.m3-headline-container {{margin-top:28px;margin-bottom:16px;padding:8px 12px;border-radius:12px;transition:background-color 0.5s ease-out}}
.m3-headline-header {{display:flex;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:8px}}
.m3-headline-title {{margin:0;color:#e6e1e5;flex-grow:1}}
.level-1 {{font-size:24px;color:#cba6f7}}
.level-2 {{font-size:20px;color:#f5bde6}}
.level-3 {{font-size:18px;color:#89b4fa}}
.level-4 {{font-size:16px}}
.level-5 {{font-size:15px}}
.level-6 {{font-size:14px}}

.m3-todo-widget {{display:inline-flex;align-items:center;padding:4px 10px;border-radius:12px;font-size:12px;font-weight:700;letter-spacing:0.5px;text-transform:uppercase;box-shadow:0 2px 4px rgba(0,0,0,0.2)}}
.m3-todo-active {{background:#f5bde6;color:#1c1b1f}}
.m3-todo-done {{background:#a6e3a1;color:#1c1b1f}}

.m3-tags {{display:flex;gap:6px;flex-wrap:wrap}}
.m3-tag-widget {{background:#313244;color:#cdd6f4;border:1px solid #45475a;border-radius:8px;padding:2px 8px;font-size:11px;font-weight:600}}

.m3-planning {{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px;margin-top:4px}}

.m3-date-widget {{display:inline-flex;align-items:center;background:#2b2930;color:#e6e1e5;border-radius:16px;padding:4px 12px;font-size:13px;text-decoration:none !important;border:1px solid #45475a;transition:transform 0.15s cubic-bezier(0.4, 0, 0.2, 1), background 0.15s;gap:6px;box-shadow:0 2px 8px rgba(0,0,0,0.15)}}
.m3-date-widget:hover {{background:#36343b;transform:translateY(-1px) scale(1.02);border-color:#585b70;box-shadow:0 4px 12px rgba(0,0,0,0.25)}}
.m3-date-widget:active {{transform:translateY(0) scale(0.98)}}
.m3-date-icon {{font-size:14px;opacity:0.8}}
.m3-date-title {{font-weight:700;color:#cba6f7;font-size:11px;letter-spacing:0.5px}}
.m3-date-value {{font-family:"JetBrains Mono",monospace;font-size:12px;color:#cdd6f4}}

/* Agenda Styling */
.m3-agenda {{background:#26242a;border-radius:20px;padding:24px;margin-bottom:32px;border:1px solid #36343b;box-shadow:0 4px 14px rgba(0,0,0,0.2)}}
.m3-agenda h2 {{margin-top:0;color:#f5bde6;font-size:20px;margin-bottom:16px}}
.m3-agenda-list {{display:flex;flex-direction:column;gap:10px}}
.m3-agenda-item {{display:flex;align-items:center;gap:12px;background:#1c1b1f;padding:12px 16px;border-radius:12px;text-decoration:none !important;transition:transform 0.2s, background 0.2s;border:1px solid #2b2930}}
.m3-agenda-item:hover {{background:#313244;transform:scale(1.01);border-color:#45475a}}
.m3-agenda-label {{font-size:10px;font-weight:700;color:#f5bde6;background:#36343b;padding:3px 8px;border-radius:8px;letter-spacing:0.5px}}
.m3-agenda-title {{flex-grow:1;color:#e6e1e5;font-weight:600;font-size:14px}}
.m3-agenda-date {{font-family:"JetBrains Mono",monospace;font-size:12px;color:#a6adc8;display:flex;align-items:center;gap:4px}}

@keyframes highlightFlash {{
    0% {{ background-color: rgba(203, 166, 247, 0.4); }}
    100% {{ background-color: transparent; }}
}}
.highlight-anim {{ animation: highlightFlash 1.5s ease-out; }}
</style>
</head>
<body>
<div class="bg">
  <div class="orb one"></div>
  <div class="orb two"></div>
  <div class="orb three"></div>
</div>
<div class="scrim"></div>
<div class="container">
<div class="card">
<div class="header">
<h1 class="main-title">{display_name}</h1>
</div>
<div class="content" id="org-content">
{html_content}
</div>
</div>
</div>
<script>
function smoothScroll(e, id) {{
    e.preventDefault();
    let el = document.getElementById(id);
    if (el) {{
        el.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
        el.classList.remove('highlight-anim');
        void el.offsetWidth; // trigger reflow
        el.classList.add('highlight-anim');
    }}
}}

// Auto-update mechanism for the shared Org file
setInterval(async () => {{
    try {{
        let res = await fetch(window.location.href);
        if (!res.ok) return;
        let text = await res.text();
        let parser = new DOMParser();
        let doc = parser.parseFromString(text, 'text/html');
        let newContent = doc.getElementById('org-content');
        let oldContent = document.getElementById('org-content');
        if (newContent && oldContent && newContent.innerHTML !== oldContent.innerHTML) {{
            oldContent.innerHTML = newContent.innerHTML;
        }}
    }} catch(e) {{
        console.error("Auto-update failed", e);
    }}
}}, 2000);
</script>
</body>
</html>"#,
        display_name = display_name,
        html_content = html_content
    )
}
