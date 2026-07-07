use anyhow::Result;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{SystemTime, Duration};

static WEATHER_CACHE: Mutex<Option<(SystemTime, WeatherData)>> = Mutex::new(None);

fn get_cache_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_default();
    let dir = PathBuf::from(home).join(".cache").join("quickshell");
    let _ = fs::create_dir_all(&dir);
    dir.join("backendqs_weather.json")
}

#[derive(Serialize, Deserialize, Clone)]
pub struct WeatherData {
    pub emoji: String,
    pub temp: String,
    pub location: String,
    pub condition: String,
    pub feels_like: String,
    pub humidity: String,
    pub wind: String,
    pub uv: String,
    pub weather_code: String,
    pub pressure: String,
    pub visibility: String,
    pub cloudcover: String,
    pub precip_mm: String,
    pub wind_gust: String,
    pub wind_dir: String,
    pub wind_degree: String,
    pub sunrise: String,
    pub sunset: String,
    pub moon_is_waxing: bool,
    pub moon_illumination: String,
    pub max_temp: String,
    pub min_temp: String,
    pub hourly_forecast: Vec<HourlyForecast>,
    pub daily_forecast: Vec<DailyForecast>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct HourlyForecast {
    pub hour: u32,
    pub temp: String,
    pub emoji: String,
    pub condition: String,
    #[serde(rename = "chanceOfRain")]
    pub chance_of_rain: String,
    pub day: u32,
    pub humidity: String,
    pub wind: String,
    #[serde(rename = "_absHour")]
    pub _abs_hour: u32,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct DailyForecast {
    #[serde(rename = "dayName")]
    pub day_name: String,
    pub date: String,
    #[serde(rename = "maxTemp")]
    pub max_temp: String,
    #[serde(rename = "minTemp")]
    pub min_temp: String,
    pub emoji: String,
    pub condition: String,
    pub sunrise: String,
    pub sunset: String,
    pub uv: String,
    #[serde(rename = "chanceOfRain")]
    pub chance_of_rain: String,
    pub wind: String,
    #[serde(rename = "weatherCode")]
    pub weather_code: String,
}

#[derive(Deserialize)]
struct GeoIp {
    lat: f64,
    lon: f64,
    city: String,
    country: String,
}

pub async fn fetch_weather(client: &Client) -> Result<WeatherData> {
    // 1. Check in-memory cache
    {
        let cache = WEATHER_CACHE.lock().unwrap();
        if let Some((time, data)) = &*cache {
            if let Ok(elapsed) = time.elapsed() {
                if elapsed < Duration::from_secs(60 * 15) { // 15 minutes
                    return Ok(data.clone());
                }
            }
        }
    }

    // 2. Check on-disk cache
    let cache_path = get_cache_path();
    if let Ok(metadata) = fs::metadata(&cache_path) {
        if let Ok(modified) = metadata.modified() {
            if let Ok(elapsed) = modified.elapsed() {
                if elapsed < Duration::from_secs(60 * 15) { // 15 minutes
                    if let Ok(content) = fs::read_to_string(&cache_path) {
                        if let Ok(data) = serde_json::from_str::<WeatherData>(&content) {
                            let mut cache = WEATHER_CACHE.lock().unwrap();
                            *cache = Some((modified, data.clone()));
                            return Ok(data);
                        }
                    }
                }
            }
        }
    }

    // 3. Get Location
    let geo: GeoIp = client.get("http://ip-api.com/json/")
        .send().await?
        .json().await?;

    let lat = geo.lat;
    let lon = geo.lon;
    let location = format!("{}, {}", geo.city, geo.country);

    // 2. Fetch Open-Meteo
    let url = format!(
        "https://api.open-meteo.com/v1/forecast?latitude={}&longitude={}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,cloud_cover,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,wind_speed_10m_max&timezone=auto",
        lat, lon
    );

    let res: serde_json::Value = client.get(&url).send().await?.json().await?;

    let current = &res["current"];
    let hourly = &res["hourly"];
    let daily = &res["daily"];

    let wmo_code = current["weather_code"].as_u64().unwrap_or(0) as u8;
    let wttr_code = map_wmo_to_wwo(wmo_code);
    let emoji = get_emoji(wttr_code);
    let condition = get_condition(wmo_code);

    let temp = format!("{}°C", current["temperature_2m"].as_f64().unwrap_or(0.0).round() as i32);
    let feels_like = format!("{}°C", current["apparent_temperature"].as_f64().unwrap_or(0.0).round() as i32);
    let humidity = format!("{}%", current["relative_humidity_2m"].as_u64().unwrap_or(0));
    
    let wind_speed = current["wind_speed_10m"].as_f64().unwrap_or(0.0);
    let wind_degree = current["wind_direction_10m"].as_u64().unwrap_or(0);
    let wind_dir_str = degree_to_dir(wind_degree as f64);
    let wind = format!("{} km/h {}", wind_speed.round() as i32, wind_dir_str);

    // Some fields not in current
    let uv = daily["uv_index_max"][0].as_f64().unwrap_or(0.0).round().to_string();
    
    let pressure = format!("{} hPa", current["surface_pressure"].as_f64().unwrap_or(0.0).round() as i32);
    let visibility = "10 km".to_string(); // not requested in current to avoid URL bloat, hardcoded or omit
    let cloudcover = format!("{}%", current["cloud_cover"].as_u64().unwrap_or(0));
    let precip_mm = format!("{} mm", current["precipitation"].as_f64().unwrap_or(0.0));
    let wind_gust = format!("{} km/h", current["wind_gusts_10m"].as_f64().unwrap_or(0.0).round() as i32);

    let max_temp = format!("{}°", daily["temperature_2m_max"][0].as_f64().unwrap_or(0.0).round() as i32);
    let min_temp = format!("{}°", daily["temperature_2m_min"][0].as_f64().unwrap_or(0.0).round() as i32);

    // time parsing for sunrise/sunset: "2023-01-01T07:00" -> "07:00"
    let parse_time = |t: &serde_json::Value| -> String {
        let s = t.as_str().unwrap_or("");
        if let Some(idx) = s.find('T') {
            s[idx+1..].to_string()
        } else {
            "".to_string()
        }
    };

    let sunrise = parse_time(&daily["sunrise"][0]);
    let sunset = parse_time(&daily["sunset"][0]);

    let (moon_is_waxing, moon_ill) = get_moon_phase();

    // Parse Hourly (Next 24 hours starting from now)
    let current_time_str = current["time"].as_str().unwrap_or("");
    let hourly_times = hourly["time"].as_array().unwrap();
    let mut current_idx = 0;
    for (i, t) in hourly_times.iter().enumerate() {
        if t.as_str().unwrap_or("") >= current_time_str {
            current_idx = i;
            break;
        }
    }

    let mut hourly_forecast = Vec::new();
    for i in current_idx..std::cmp::min(current_idx + 24, hourly_times.len()) {
        let t_str = hourly_times[i].as_str().unwrap_or("");
        let hour_num = parse_time(&serde_json::Value::String(t_str.to_string())).split(':').next().unwrap_or("0").parse::<u32>().unwrap_or(0);
        let day = if i >= 24 { 1 } else { 0 }; // rough day offset
        
        let hc = hourly["weather_code"][i].as_u64().unwrap_or(0) as u8;
        let hwwo = map_wmo_to_wwo(hc);

        hourly_forecast.push(HourlyForecast {
            hour: hour_num,
            temp: hourly["temperature_2m"][i].as_f64().unwrap_or(0.0).round().to_string(),
            emoji: get_emoji(hwwo),
            condition: get_condition(hc),
            chance_of_rain: hourly["precipitation_probability"][i].as_u64().unwrap_or(0).to_string(),
            day,
            humidity: hourly["relative_humidity_2m"][i].as_u64().unwrap_or(0).to_string(),
            wind: hourly["wind_speed_10m"][i].as_f64().unwrap_or(0.0).round().to_string(),
            _abs_hour: (day * 24) + hour_num,
        });
    }

    // Parse Daily (Next 7 days)
    let mut daily_forecast = Vec::new();
    let day_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    let times = daily["time"].as_array().unwrap();
    for i in 0..std::cmp::min(7, times.len()) {
        let dc = daily["weather_code"][i].as_u64().unwrap_or(0) as u8;
        let dwwo = map_wmo_to_wwo(dc);
        
        let d_str = times[i].as_str().unwrap_or("");
        // simple parsing to get day of week not strictly needed if we assume it's just today, tomorrow, next...
        // Let's use chrono to get day of week
        let day_name = if i == 0 {
            "Today".to_string()
        } else {
            if let Ok(ndt) = chrono::NaiveDate::parse_from_str(d_str, "%Y-%m-%d") {
                use chrono::Datelike;
                day_names[ndt.weekday().num_days_from_sunday() as usize].to_string()
            } else {
                "".to_string()
            }
        };

        daily_forecast.push(DailyForecast {
            day_name,
            date: d_str.to_string(),
            max_temp: daily["temperature_2m_max"][i].as_f64().unwrap_or(0.0).round().to_string(),
            min_temp: daily["temperature_2m_min"][i].as_f64().unwrap_or(0.0).round().to_string(),
            emoji: get_emoji(dwwo),
            condition: get_condition(dc),
            sunrise: parse_time(&daily["sunrise"][i]),
            sunset: parse_time(&daily["sunset"][i]),
            uv: daily["uv_index_max"][i].as_f64().unwrap_or(0.0).round().to_string(),
            chance_of_rain: daily["precipitation_probability_max"][i].as_u64().unwrap_or(0).to_string(),
            wind: format!("{} km/h", daily["wind_speed_10m_max"][i].as_f64().unwrap_or(0.0).round() as i32),
            weather_code: dwwo.to_string(),
        });
    }

    let res = WeatherData {
        emoji,
        temp,
        location,
        condition,
        feels_like,
        humidity,
        wind,
        uv,
        weather_code: wttr_code.to_string(),
        pressure,
        visibility,
        cloudcover,
        precip_mm,
        wind_gust,
        wind_dir: wind_dir_str.to_string(),
        wind_degree: wind_degree.to_string(),
        sunrise,
        sunset,
        moon_is_waxing,
        moon_illumination: format!("{:.0}%", moon_ill),
        max_temp,
        min_temp,
        hourly_forecast,
        daily_forecast,
    };

    // Save to cache
    {
        let mut cache = WEATHER_CACHE.lock().unwrap();
        *cache = Some((SystemTime::now(), res.clone()));
    }
    if let Ok(json) = serde_json::to_string(&res) {
        let _ = fs::write(&cache_path, json);
    }

    Ok(res)
}

fn map_wmo_to_wwo(wmo: u8) -> &'static str {
    match wmo {
        0 => "113",
        1 | 2 => "116",
        3 => "122",
        45 | 48 => "143",
        51 | 53 | 55 => "266",
        56 | 57 => "281",
        61 => "296",
        63 => "302",
        65 => "308",
        66 | 67 => "311",
        71 => "326",
        73 => "332",
        75 => "338",
        77 => "350",
        80 => "353",
        81 => "356",
        82 => "359",
        85 => "368",
        86 => "371",
        95 => "386",
        96 | 99 => "395",
        _ => "113",
    }
}

fn get_emoji(code: &str) -> String {
    let c = match code {
        "113" => "☀️",
        "116" => "⛅",
        "119" | "122" => "☁️",
        "143" | "248" | "260" => "🌫️",
        "176" | "353" => "🌦️",
        "179" | "182" | "185" | "227" | "311" | "314" | "317" | "320" | "323" | "326" | "350" | "362" | "365" | "368" | "374" | "377" => "🌨️",
        "200" | "386" | "389" | "392" => "⛈️",
        "230" | "329" | "332" | "335" | "338" | "371" | "395" => "❄️",
        "263" | "266" | "281" | "284" | "293" | "296" | "299" | "302" | "305" | "308" | "356" | "359" => "🌧️",
        _ => "❓",
    };
    c.to_string()
}

fn get_condition(wmo: u8) -> String {
    let s = match wmo {
        0 => "Clear sky",
        1 => "Mainly clear",
        2 => "Partly cloudy",
        3 => "Overcast",
        45 | 48 => "Fog",
        51 => "Light drizzle",
        53 => "Moderate drizzle",
        55 => "Dense drizzle",
        56 | 57 => "Freezing drizzle",
        61 => "Light rain",
        63 => "Moderate rain",
        65 => "Heavy rain",
        66 | 67 => "Freezing rain",
        71 => "Light snow",
        73 => "Moderate snow",
        75 => "Heavy snow",
        77 => "Snow grains",
        80 => "Light showers",
        81 => "Moderate showers",
        82 => "Violent showers",
        85 => "Light snow showers",
        86 => "Heavy snow showers",
        95 => "Thunderstorm",
        96 | 99 => "Thunderstorm with hail",
        _ => "Unknown",
    };
    s.to_string()
}

fn degree_to_dir(deg: f64) -> &'static str {
    let dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    let val = (deg / 22.5 + 0.5).floor() as usize;
    dirs[val % 16]
}

// holy fucking shiiit
fn get_moon_phase() -> (bool, f64) {
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs() as f64;
    // Known new moon: 2000-01-06 18:14 UTC -> 947182440
    let diff = now - 947182440.0;
    let lunar_cycle = 29.53058867 * 24.0 * 3600.0;
    let mut phase = (diff % lunar_cycle) / lunar_cycle;
    if phase < 0.0 { phase += 1.0; }

    let is_waxing = phase <= 0.5;

    let ill = if phase <= 0.5 { (phase / 0.5) * 100.0 } else { ((1.0 - phase) / 0.5) * 100.0 };
    (is_waxing, ill)
}

