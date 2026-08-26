use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use zbus_polkit_agent::{
    agent_session::{Message, PolkitAgentSession, Response},
    polkit_agent_instance,
    server::Error,
    Identity, UnixUser,
};

lazy_static::lazy_static! {
    pub static ref POLKIT_CHANNELS: Arc<Mutex<HashMap<String, mpsc::Sender<String>>>> =
        Arc::new(Mutex::new(HashMap::new()));
}

/// The State object created by `boot` and passed to authenticate/cancel callbacks.
pub struct PolkitState {
    pub tx_event: mpsc::Sender<crate::api::DaemonEvent>,
}

async fn authenticate<'a>(
    state: &'a mut PolkitState,
    action_id: &'a str,
    msg: &'a str,
    icon_name: &'a str,
    _details: HashMap<&'a str, &'a str>,
    cookie: &'a str,
    mut identifiers: Vec<Identity<'a>>,
) -> Result<(), Error> {
    use std::io::Write;
    let mut file = std::fs::OpenOptions::new().create(true).append(true).open("/tmp/polkit.log").unwrap();
    writeln!(file, "authenticate called with action_id: {}, msg: {}, identities: {:?}", action_id, msg, identifiers).unwrap();

    if identifiers.is_empty() {
        writeln!(file, "Identifiers is empty").unwrap();
        return Err(Error::Failed);
    }

    let identify: UnixUser = match identifiers.remove(0).try_into() {
        Ok(u) => u,
        Err(e) => {
            writeln!(file, "Failed to convert identity: {:?}", e).unwrap();
            return Err(Error::Failed);
        }
    };
    let mut session = match PolkitAgentSession::new(identify, cookie) {
        Ok(s) => s,
        Err(e) => {
            writeln!(file, "Failed to create session: {:?}", e).unwrap();
            return Err(e.into());
        }
    };

    let (tx, mut rx) = mpsc::channel::<String>(1);
    POLKIT_CHANNELS.lock().await.insert(cookie.to_string(), tx);

    let mut retry_count: i32 = 3;
    let mut success = false;

    while retry_count >= 0 {
        while !session.is_complete() {
            let message = session.async_dispatch().await?;
            match message {
                Message::Request { prompt, .. } => {
                    let _ = state.tx_event.send(crate::api::DaemonEvent::PolkitShowAuth {
                        action_id: action_id.to_string(),
                        message: msg.to_string(),
                        icon_name: icon_name.to_string(),
                        cookie: cookie.to_string(),
                        user_name: session.user_name().to_string(),
                        prompt: prompt.clone(),
                    }).await;

                    if let Some(password) = rx.recv().await {
                        session.response(Response {
                            password: &password,
                        })?;
                    } else {
                        POLKIT_CHANNELS.lock().await.remove(cookie);
                        let _ = state.tx_event.send(crate::api::DaemonEvent::PolkitDismiss {
                            cookie: cookie.to_string(),
                        }).await;
                        return Err(Error::Cancelled);
                    }
                }
                Message::Error { .. } => {
                    break;
                }
                Message::Info { .. } => {
                    // Informational, ignore
                }
                Message::Complete(_) => {
                    break;
                }
            }
        }

        if session.succeeded() {
            success = true;
            break;
        }
        session.restart()?;
        retry_count -= 1;
    }

    POLKIT_CHANNELS.lock().await.remove(cookie);
    let _ = state.tx_event.send(crate::api::DaemonEvent::PolkitResult {
        cookie: cookie.to_string(),
        success,
    }).await;

    if !success {
        return Err(Error::Failed);
    }
    Ok(())
}

async fn cancel_authentication<'a>(
    state: &'a mut PolkitState,
    cookie: &'a str,
) -> Result<(), Error> {
    if let Some(_tx) = POLKIT_CHANNELS.lock().await.remove(cookie) {
        let _ = state.tx_event.send(crate::api::DaemonEvent::PolkitDismiss {
            cookie: cookie.to_string(),
        }).await;
    }
    Ok(())
}

pub async fn start_agent(tx_event: mpsc::Sender<crate::api::DaemonEvent>) {
    let object_path = "/org/waycrate/PolicyKit1/AuthenticationAgent";

    // Retry connection a few times if session bus is slow
    for _ in 0..5 {
        let tx = tx_event.clone();
        match polkit_agent_instance(
            move || PolkitState { tx_event: tx },
            authenticate,
            cancel_authentication,
        )
        .connect(object_path)
        .await
        {
            Ok(_conn) => {
                use std::io::Write;
                if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open("/tmp/polkit.log") {
                    writeln!(f, "[backendqs] Polkit agent registered successfully on {}", object_path).unwrap();
                }
                eprintln!("[backendqs] Polkit agent registered successfully.");
                // Keep the connection alive indefinitely
                std::future::pending::<()>().await;
                return;
            }
            Err(e) => {
                use std::io::Write;
                if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open("/tmp/polkit.log") {
                    writeln!(f, "[backendqs] Failed to register polkit agent: {}", e).unwrap();
                }
                eprintln!("[backendqs] Failed to register polkit agent: {}", e);
                tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            }
        }
    }
    use std::io::Write;
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open("/tmp/polkit.log") {
        writeln!(f, "[backendqs] Polkit agent: gave up after 5 retries.").unwrap();
    }
    eprintln!("[backendqs] Polkit agent: gave up after 5 retries.");
}
