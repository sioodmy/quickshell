use std::collections::HashMap;
use std::fs;
use std::path::Path;

/// Maps MAC addresses (HID_UNIQ) to (battery_level, is_charging)
pub fn get_sysfs_batteries() -> HashMap<String, (f64, bool)> {
    let mut map = HashMap::new();
    let ps_dir = Path::new("/sys/class/power_supply");
    
    if let Ok(entries) = fs::read_dir(ps_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            
            // Check if it's a battery
            if let Ok(type_str) = fs::read_to_string(path.join("type")) {
                if type_str.trim().to_lowercase() != "battery" {
                    continue;
                }
            } else {
                continue;
            }
            
            // Get capacity
            let capacity = if let Ok(cap_str) = fs::read_to_string(path.join("capacity")) {
                cap_str.trim().parse::<f64>().unwrap_or(-1.0)
            } else {
                -1.0
            };
            
            if capacity < 0.0 {
                continue;
            }
            
            // Get charging status
            let charging = if let Ok(status_str) = fs::read_to_string(path.join("status")) {
                let s = status_str.trim().to_lowercase();
                s == "charging" || s == "full"
            } else {
                false
            };
            
            // Link to HID device to get MAC address (HID_UNIQ)
            // The uevent file of the parent device usually contains HID_UNIQ
            let device_uevent_path = path.join("device").join("uevent");
            if let Ok(uevent) = fs::read_to_string(device_uevent_path) {
                for line in uevent.lines() {
                    if let Some(uniq) = line.strip_prefix("HID_UNIQ=") {
                        let mac = uniq.trim().to_uppercase();
                        if !mac.is_empty() {
                            map.insert(mac, (capacity / 100.0, charging));
                        }
                    }
                }
            }
        }
    }
    
    map
}
