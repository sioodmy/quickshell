use std::process::Command;
use zbus::Connection;
use futures::StreamExt;

pub async fn start_logind_listener() {
    if let Ok(conn) = Connection::system().await {
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
        let mut stream = zbus::MessageStream::from(conn);
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
                                    if !is_sleep {
                                        crate::debug_log!("Wake up from sleep, reloading audio device...");
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
