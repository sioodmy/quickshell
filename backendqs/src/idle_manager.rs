use std::process::Command;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use wayland_client::{
    protocol::{wl_registry, wl_seat},
    Connection, Dispatch, QueueHandle,
};
use wayland_protocols::ext::idle_notify::v1::client::{
    ext_idle_notification_v1, ext_idle_notifier_v1,
};

// Sane defaults
const LOCK_TIMEOUT_MS: u32 = 5 * 60 * 1000;
const SLEEP_TIMEOUT_MS: u32 = 15 * 60 * 1000;

lazy_static::lazy_static! {
    pub static ref COCAINE_ENABLED: Arc<Mutex<bool>> = Arc::new(Mutex::new(false));
}

pub fn set_cocaine_enabled(enabled: bool) {
    if let Ok(mut lock) = COCAINE_ENABLED.lock() {
        *lock = enabled;
    }
}

struct AppData {
    seat: Option<wl_seat::WlSeat>,
    notifier: Option<ext_idle_notifier_v1::ExtIdleNotifierV1>,
    lock_notification: Option<ext_idle_notification_v1::ExtIdleNotificationV1>,
    sleep_notification: Option<ext_idle_notification_v1::ExtIdleNotificationV1>,
    cocaine_active: bool,
}

impl Dispatch<wl_registry::WlRegistry, ()> for AppData {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global { name, interface, .. } = event {
            match &interface[..] {
                "wl_seat" => {
                    state.seat = Some(registry.bind::<wl_seat::WlSeat, _, _>(name, 1, qh, ()));
                }
                "ext_idle_notifier_v1" => {
                    state.notifier = Some(registry.bind::<ext_idle_notifier_v1::ExtIdleNotifierV1, _, _>(
                        name,
                        1,
                        qh,
                        (),
                    ));
                }
                _ => {}
            }
        }
    }
}

impl Dispatch<wl_seat::WlSeat, ()> for AppData {
    fn event(_: &mut Self, _: &wl_seat::WlSeat, _: wl_seat::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

impl Dispatch<ext_idle_notifier_v1::ExtIdleNotifierV1, ()> for AppData {
    fn event(_: &mut Self, _: &ext_idle_notifier_v1::ExtIdleNotifierV1, _: ext_idle_notifier_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

#[derive(Debug)]
struct NotificationData {
    is_sleep: bool,
}

impl Dispatch<ext_idle_notification_v1::ExtIdleNotificationV1, NotificationData> for AppData {
    fn event(
        _: &mut Self,
        _: &ext_idle_notification_v1::ExtIdleNotificationV1,
        event: ext_idle_notification_v1::Event,
        data: &NotificationData,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            ext_idle_notification_v1::Event::Idled => {
                let is_cocaine = *COCAINE_ENABLED.lock().unwrap_or_else(|e| e.into_inner());
                if is_cocaine {
                    crate::debug_log!("Wayland Idled (is_sleep: {}) - IGNORED due to Cocaine mode", data.is_sleep);
                    return;
                }
                
                crate::debug_log!("Wayland Idled (is_sleep: {})", data.is_sleep);
                if data.is_sleep {
                    let _ = Command::new("systemctl").arg("suspend").spawn();
                } else {
                    let _ = Command::new("quickshell").args(["ipc", "call", "lock", "lock"]).spawn();
                }
            }
            ext_idle_notification_v1::Event::Resumed => {
                crate::debug_log!("Wayland Resumed (is_sleep: {})", data.is_sleep);
            }
            _ => {}
        }
    }
}

pub fn spawn_idle_manager() {
    std::thread::spawn(|| {
        if let Ok(conn) = Connection::connect_to_env() {
            let mut event_queue = conn.new_event_queue();
            let qh = event_queue.handle();
            let display = conn.display();
            
            let mut app_data = AppData {
                seat: None,
                notifier: None,
                lock_notification: None,
                sleep_notification: None,
                cocaine_active: false,
            };
            
            let _registry = display.get_registry(&qh, ());
            
            // Roundtrip to get globals
            event_queue.roundtrip(&mut app_data).unwrap();
            
            if let (Some(seat), Some(notifier)) = (&app_data.seat, &app_data.notifier) {
                app_data.lock_notification = Some(notifier.get_idle_notification(
                    LOCK_TIMEOUT_MS,
                    seat,
                    &qh,
                    NotificationData { is_sleep: false },
                ));
                app_data.sleep_notification = Some(notifier.get_idle_notification(
                    SLEEP_TIMEOUT_MS,
                    seat,
                    &qh,
                    NotificationData { is_sleep: true },
                ));
                app_data.cocaine_active = false;
                
                crate::debug_log!("Idle manager started. Lock: {}ms, Sleep: {}ms", LOCK_TIMEOUT_MS, SLEEP_TIMEOUT_MS);
                
                loop {
                    if let Err(e) = event_queue.blocking_dispatch(&mut app_data) {
                        crate::debug_log!("Wayland idle manager dispatch error: {:?}", e);
                        break;
                    }
                }
            } else {
                crate::debug_log!("Wayland idle manager could not find wl_seat or ext_idle_notifier_v1");
            }
        } else {
            crate::debug_log!("Wayland idle manager could not connect to Wayland display");
        }
    });
}
