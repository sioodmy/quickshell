use std::process::Command;
use zbus::Connection;
use futures::StreamExt;

async fn acquire_sleep_inhibitor(conn: &Connection) -> Option<zbus::zvariant::OwnedFd> {
    match conn.call_method(
        Some("org.freedesktop.login1"),
        "/org/freedesktop/login1",
        Some("org.freedesktop.login1.Manager"),
        "Inhibit",
        &("sleep", "quickshell", "Lock screen before sleep", "delay"),
    ).await {
        Ok(reply) => {
            if let Ok((fd,)) = reply.body().deserialize::<(zbus::zvariant::OwnedFd,)>() {
                crate::debug_log!("Successfully acquired logind sleep delay inhibitor");
                Some(fd)
            } else {
                crate::debug_log!("Failed to deserialize inhibitor FD");
                None
            }
        }
        Err(e) => {
            crate::debug_log!("Failed to acquire logind sleep inhibitor: {:?}", e);
            None
        }
    }
}

pub async fn start_logind_listener() {
    if let Ok(conn) = Connection::system().await {
        let mut sleep_inhibitor = acquire_sleep_inhibitor(&conn).await;

        if let Ok(dbus_proxy) = zbus::fdo::DBusProxy::new(&conn).await {
            if let Ok(rule) = zbus::MatchRule::builder()
                .msg_type(zbus::message::Type::Signal)
                .interface("org.freedesktop.login1.Session").unwrap()
                .build().try_into() 
            {
                let _ = dbus_proxy.add_match_rule(rule).await;
            }
            if let Ok(rule) = zbus::MatchRule::builder()
                .msg_type(zbus::message::Type::Signal)
                .interface("org.freedesktop.login1.Manager").unwrap()
                .member("PrepareForSleep").unwrap()
                .build().try_into()
            {
                let _ = dbus_proxy.add_match_rule(rule).await;
            }
        }
        let mut stream = zbus::MessageStream::from(conn.clone());
        crate::debug_log!("Listening for logind Lock and PrepareForSleep signals...");
        while let Some(msg) = stream.next().await {
            if let Ok(msg) = msg {
                let header = msg.header();
                if let Some(interface) = header.interface() {
                    if interface.as_str() == "org.freedesktop.login1.Session" {
                        if let Some(member) = header.member() {
                            if member.as_str() == "Lock" {
                                crate::debug_log!("Received logind Lock signal, triggering quickshell lock!");
                                let _ = Command::new("quickshell")
                                    .args(["ipc", "call", "lock", "lock"])
                                    .spawn();
                            }
                        }
                    } else if interface.as_str() == "org.freedesktop.login1.Manager" {
                        if let Some(member) = header.member() {
                            if member.as_str() == "PrepareForSleep" {
                                if let Ok(is_sleep) = msg.body().deserialize::<bool>() {
                                    if is_sleep {
                                        crate::debug_log!("Received PrepareForSleep(true), locking quickshell before sleep!");
                                        let _ = Command::new("quickshell")
                                            .args(["ipc", "call", "lock", "lock"])
                                            .spawn();
                                        if sleep_inhibitor.is_some() {
                                            tokio::time::sleep(std::time::Duration::from_millis(200)).await;
                                            sleep_inhibitor = None;
                                        }
                                    } else {
                                        crate::debug_log!("Wake up from sleep, reloading audio device & re-acquiring inhibitor...");
                                        sleep_inhibitor = acquire_sleep_inhibitor(&conn).await;
                                        if let Some(player) = crate::music::PLAYER.get() {
                                            player.reload_device();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

