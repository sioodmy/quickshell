use anyhow::Result;
use regex::Regex;
use serde::Serialize;
use std::fs;
use std::path::Path;

#[derive(Serialize, Debug, Clone)]
pub struct AgendaItem {
    pub title: String,
    pub state: String,
    pub priority: String,
    pub tags: Vec<String>,
    pub depth: u32,
    pub deadline: String,
    pub deadline_time: String,
    pub scheduled: String,
    pub scheduled_time: String,
    pub closed: String,
    pub closed_time: String,
    pub body: String,
    pub file: String,
}

pub fn parse_directory(dir: &Path) -> Result<Vec<AgendaItem>> {
    let mut items = Vec::new();
    let re_heading = Regex::new(r"^(\*+)\s+(.*)").unwrap();
    let re_state = Regex::new(r"^(TODO|DONE|WAITING|CANCELLED|NEXT|HOLD)\s+(.*)").unwrap();
    let re_priority = Regex::new(r"^\[#([A-C])\]\s+(.*)").unwrap();
    let re_tags = Regex::new(r"^(.*?)\s+(:[a-zA-Z0-9_:]+:)\s*$").unwrap();
    
    let re_deadline = Regex::new(r"DEADLINE:\s*[<\[](\d{4}-\d{2}-\d{2})(?:\s+[A-Za-z]+)?(?:\s+(\d{2}:\d{2}))?").unwrap();
    let re_scheduled = Regex::new(r"SCHEDULED:\s*[<\[](\d{4}-\d{2}-\d{2})(?:\s+[A-Za-z]+)?(?:\s+(\d{2}:\d{2}))?").unwrap();
    let re_closed = Regex::new(r"CLOSED:\s*[<\[](\d{4}-\d{2}-\d{2})(?:\s+[A-Za-z]+)?(?:\s+(\d{2}:\d{2}))?").unwrap();

    if !dir.exists() || !dir.is_dir() {
        return Ok(items);
    }

    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some("org") {
            let filename = path.file_stem().unwrap().to_string_lossy().to_string();
            let content = match fs::read_to_string(&path) {
                Ok(c) => c,
                Err(_) => continue,
            };

            let mut current_item: Option<AgendaItem> = None;
            let mut body_lines_count = 0;

            for line in content.lines() {
                if let Some(cap) = re_heading.captures(line) {
                    if let Some(item) = current_item.take() {
                        items.push(item);
                    }

                    let depth = cap[1].len() as u32;
                    let mut rest = cap[2].to_string();
                    let mut state = String::new();
                    let mut priority = String::new();
                    let mut tags = Vec::new();

                    if let Some(scap) = re_state.captures(&rest) {
                        state = scap[1].to_string();
                        rest = scap[2].to_string();
                    }

                    if let Some(pcap) = re_priority.captures(&rest) {
                        priority = pcap[1].to_string();
                        rest = pcap[2].to_string();
                    }

                    let mut new_rest = rest.clone();
                    if let Some(tcap) = re_tags.captures(&rest) {
                        new_rest = tcap[1].trim_end().to_string();
                        let tags_str = tcap[2].to_string();
                        tags = tags_str.split(':').filter(|s| !s.is_empty()).map(|s| s.to_string()).collect();
                    } else {
                        new_rest = rest.trim_end().to_string();
                    }

                    current_item = Some(AgendaItem {
                        title: new_rest,
                        state,
                        priority,
                        tags,
                        depth,
                        deadline: String::new(),
                        deadline_time: String::new(),
                        scheduled: String::new(),
                        scheduled_time: String::new(),
                        closed: String::new(),
                        closed_time: String::new(),
                        body: String::new(),
                        file: filename.clone(),
                    });
                    body_lines_count = 0;
                    continue;
                }

                if let Some(item) = current_item.as_mut() {
                    if let Some(cap) = re_deadline.captures(line) {
                        item.deadline = cap[1].to_string();
                        if let Some(time_cap) = cap.get(2) {
                            item.deadline_time = time_cap.as_str().to_string();
                        }
                    }
                    if let Some(cap) = re_scheduled.captures(line) {
                        item.scheduled = cap[1].to_string();
                        if let Some(time_cap) = cap.get(2) {
                            item.scheduled_time = time_cap.as_str().to_string();
                        }
                    }
                    if let Some(cap) = re_closed.captures(line) {
                        item.closed = cap[1].to_string();
                        if let Some(time_cap) = cap.get(2) {
                            item.closed_time = time_cap.as_str().to_string();
                        }
                    }

                    let stripped = line.trim_start();
                    if !stripped.is_empty() && !stripped.starts_with(':') && !stripped.starts_with("DEADLINE:") && !stripped.starts_with("SCHEDULED:") && !stripped.starts_with("CLOSED:") && body_lines_count < 3 {
                        let is_timestamp_only = stripped.starts_with('[') || stripped.starts_with('<');
                        if !is_timestamp_only {
                            if !item.body.is_empty() {
                                item.body.push('\n');
                            }
                            item.body.push_str(stripped);
                            body_lines_count += 1;
                        }
                    }
                }
            }
            if let Some(item) = current_item {
                items.push(item);
            }
        }
    }

    items.sort_by(|a, b| {
        let order_a = state_order(&a.state);
        let order_b = state_order(&b.state);
        if order_a != order_b {
            return order_a.cmp(&order_b);
        }
        let date_a = effective_date(a);
        let date_b = effective_date(b);
        date_a.cmp(&date_b)
    });

    Ok(items)
}

fn state_order(state: &str) -> u32 {
    match state {
        "TODO" | "NEXT" => 0,
        "WAITING" => 1,
        "" => 2,
        "HOLD" => 3,
        "DONE" => 4,
        "CANCELLED" => 5,
        _ => 2,
    }
}

fn effective_date(item: &AgendaItem) -> String {
    if !item.deadline.is_empty() {
        item.deadline.clone()
    } else if !item.scheduled.is_empty() {
        item.scheduled.clone()
    } else {
        "9999-12-31".to_string()
    }
}
