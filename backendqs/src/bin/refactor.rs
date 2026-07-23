use std::fs;

fn main() {
    let mut content = fs::read_to_string("src/main.rs").unwrap();

    let req_start = content.find("#[derive(Deserialize, Debug)]\n#[serde(tag = \"action\")]\nenum DaemonRequest {").unwrap();
    let req_end = content[req_start..].find("}\n").unwrap() + req_start + 2;
    content.replace_range(req_start..req_end, "");

    let ev_start = content.find("#[derive(Serialize)]\n#[serde(tag = \"type\")]\nenum DaemonEvent {").unwrap();
    let ev_end = content[ev_start..].find("}\n").unwrap() + ev_start + 2;
    content.replace_range(ev_start..ev_end, "");

    let dto_start = content.find("#[derive(Serialize)]\npub struct MusicStateDto {").unwrap();
    let dto_end = content[dto_start..].find("}\n").unwrap() + dto_start + 2;
    content.replace_range(dto_start..dto_end, "");

    content = content.replace("mod music_remote;\n", "mod music_remote;\nmod api;\nmod context;\nmod handler;\n");
    content = content.replace("DaemonRequest", "api::DaemonRequest");
    content = content.replace("DaemonEvent", "api::DaemonEvent");
    content = content.replace("MusicStateDto", "api::MusicStateDto");

    let match_start = content.find("                tokio::spawn(async move {\n                    match req {").unwrap();
    let match_end = content[match_start..].find("});\n            }\n        }\n    }\n\n    Ok(())\n}").unwrap() + match_start;

    let extracted_match = &content[match_start..match_end];

    let mut handler_content = String::from("use crate::api::{DaemonRequest, DaemonEvent};\nuse crate::context::AppContext;\nuse std::sync::atomic::Ordering;\nuse std::sync::Arc;\nuse crate::*;\n\npub async fn handle_request(req: DaemonRequest, ctx: AppContext, assigned_search_gen: Option<u64>) {\n");
    
    // extract the inner `match req { ... }` block
    let inner_start = extracted_match.find("match req {").unwrap();
    let inner_match = &extracted_match[inner_start..].trim_end();
    
    let match_block = inner_match.replace(" tx,", " ctx.tx.clone(),")
        .replace(" tx)", " ctx.tx.clone())")
        .replace(" tx.", " ctx.tx.")
        .replace("&client", "&ctx.client")
        .replace("&notes_dir", "&ctx.notes_dir")
        .replace("frecency_state", "ctx.frecency_state")
        .replace("&file_index", "&ctx.file_index")
        .replace("bookmark_index", "ctx.bookmark_index")
        .replace("file_search_generation", "ctx.file_search_generation")
        .replace("cliphist_state", "ctx.cliphist_state")
        .replace("ocr_sem", "ctx.ocr_sem")
        .replace("file_share.", "ctx.file_share.")
        .replace("file_share_progress_active", "ctx.file_share_progress_active")
        .replace("music_remote_state", "ctx.music_remote_state");

    handler_content.push_str("    ");
    handler_content.push_str(&match_block);
    handler_content.push_str("\n}\n");

    let helpers_start = content.find("async fn handle_cliphist_list(").unwrap();
    let helpers = &content[helpers_start..];
    let helpers = helpers.replace("tmpsc::Sender<DaemonEvent>", "tokio::sync::mpsc::Sender<crate::api::DaemonEvent>")
                         .replace("tmpsc::Sender<api::DaemonEvent>", "tokio::sync::mpsc::Sender<crate::api::DaemonEvent>");
    
    handler_content.push_str("\n");
    handler_content.push_str(&helpers);

    content.replace_range(helpers_start.., "");

    fs::write("src/handler.rs", handler_content).unwrap();

    let new_spawn = r#"
                let ctx = context::AppContext {
                    tx: tx_event.clone(),
                    client: client.clone(),
                    notes_dir: notes_dir.clone(),
                    frecency_state: frecency_state.clone(),
                    file_index: file_index.clone(),
                    bookmark_index: bookmark_index.clone(),
                    file_search_generation: file_search_generation.clone(),
                    cliphist_state: cliphist_state.clone(),
                    ocr_sem: ocr_sem.clone(),
                    file_share: file_share.clone(),
                    file_share_progress_active: file_share_progress_active.clone(),
                    music_remote_state: music_remote_state.clone(),
                };

                tokio::spawn(async move {
                    handler::handle_request(req, ctx, assigned_search_gen).await;
"#;

    let var_block_start = content.find("                let tx = tx_event.clone();").unwrap();
    let var_block_end = content.find("                let assigned_search_gen = match &req {").unwrap();
    
    // We remove the cloned variables block, leaving `assigned_search_gen`
    content.replace_range(var_block_start..var_block_end, "");
    
    let match_start2 = content.find("                tokio::spawn(async move {\n                    match req {").unwrap();
    let match_end2 = content[match_start2..].find("});\n            }\n        }\n    }\n\n    Ok(())\n}").unwrap() + match_start2;
    
    content.replace_range(match_start2..match_end2, new_spawn);

    fs::write("src/main.rs", content).unwrap();
}
