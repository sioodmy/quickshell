use serde::Serialize;
use tokio::process::Command;
use std::collections::HashMap;
use zbus::zvariant::{OwnedObjectPath, OwnedValue};

#[derive(Serialize)]
pub struct DeviceItem {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub active: bool,
}

pub async fn get_bluetooth_devices() -> Vec<DeviceItem> {
    let mut devices = Vec::new();
    
    if let Ok(connection) = zbus::Connection::system().await {
        if let Ok(proxy) = zbus::Proxy::new(
            &connection,
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
        ).await {
            let result: Result<HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>, _> = proxy.call("GetManagedObjects", &()).await;
            if let Ok(objects) = result {
                for (path, interfaces) in objects {
                    if let Some(device_props) = interfaces.get("org.bluez.Device1") {
                        let name = device_props.get("Name").and_then(|v| <&str>::try_from(&**v).ok()).unwrap_or("Unknown").to_string();
                        let paired: bool = device_props.get("Paired").and_then(|v| bool::try_from(&**v).ok()).unwrap_or(false);
                        let connected: bool = device_props.get("Connected").and_then(|v| bool::try_from(&**v).ok()).unwrap_or(false);
                        let address: String = device_props.get("Address").and_then(|v| <&str>::try_from(&**v).ok()).unwrap_or("").to_string();
                        
                        if paired && !name.is_empty() {
                            devices.push(DeviceItem {
                                id: address,
                                name,
                                kind: "bluetooth".to_string(),
                                active: connected,
                            });
                        }
                    }
                }
            }
        }
    }
    
    devices
}

pub async fn get_wifi_networks() -> Vec<DeviceItem> {
    let mut devices = Vec::new();
    let mut saved_connections = std::collections::HashSet::new();

    // Get saved connections
    if let Ok(output) = Command::new("nmcli").arg("-t").arg("-f").arg("NAME").arg("connection").arg("show").output().await {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            if !line.is_empty() {
                saved_connections.insert(line.to_string());
            }
        }
    }

    if let Ok(output) = Command::new("nmcli").arg("-t").arg("-f").arg("SSID,ACTIVE,SIGNAL,SECURITY").arg("dev").arg("wifi").output().await {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 4 {
                let name = parts[0].to_string();
                let active = parts[1] == "yes";
                let signal = parts[2].to_string();
                let _security = parts[3].to_string();
                
                if !name.is_empty() {
                    // Check if this network is saved
                    let is_saved = saved_connections.iter().any(|saved| saved == &name || saved.starts_with(&name));
                    
                    if is_saved {
                        let kind = format!("WiFi • {}%", signal);
                        devices.push(DeviceItem {
                            id: name.clone(),
                            name,
                            kind,
                            active,
                        });
                    }
                }
            }
        }
    }
    devices
}
