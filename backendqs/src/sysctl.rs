use serde::Serialize;
use std::process::Command;

#[derive(Serialize)]
pub struct DeviceItem {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub active: bool,
}

pub fn get_bluetooth_devices() -> Vec<DeviceItem> {
    let mut devices = Vec::new();
    if let Ok(output) = Command::new("bluetoothctl").arg("devices").output() {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            if line.starts_with("Device ") {
                let parts: Vec<&str> = line.splitn(3, ' ').collect();
                if parts.len() == 3 {
                    let mac = parts[1];
                    let name = parts[2].to_string();
                    
                    // Check if paired
                    if let Ok(info) = Command::new("bluetoothctl").arg("info").arg(mac).output() {
                        let info_text = String::from_utf8_lossy(&info.stdout);
                        if info_text.contains("Paired: yes") {
                            devices.push(DeviceItem {
                                id: mac.to_string(),
                                name,
                                kind: "bluetooth".to_string(),
                                active: info_text.contains("Connected: yes"),
                            });
                        }
                    }
                }
            }
        }
    }
    devices
}

pub fn get_wifi_networks() -> Vec<DeviceItem> {
    let mut devices = Vec::new();
    let mut saved_connections = std::collections::HashSet::new();

    // Get saved connections
    if let Ok(output) = Command::new("nmcli").arg("-t").arg("-f").arg("NAME").arg("connection").arg("show").output() {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            if !line.is_empty() {
                saved_connections.insert(line.to_string());
            }
        }
    }

    if let Ok(output) = Command::new("nmcli").arg("-t").arg("-f").arg("SSID,ACTIVE,SIGNAL,SECURITY").arg("dev").arg("wifi").output() {
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
