pragma Singleton

// Weather from Open-Meteo, fetched by the shell itself: the place
// (the location setting) is looked up once with Open-Meteo's geocoding, then the
// forecast is fetched every 15 minutes and kept in
// ~/.cache/nafeel-shell/weather.json, so it shows straight away after a
// restart. The data has the same shape Noctalia's cache had (current,
// forecast_days, forecast_hours, location_name), which the views read.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // The Settings panel's Weather page.
    readonly property SettingsPage settings: SettingsPage {
        name: "weather"
        title: "Weather"
        gloss: "天气"
        icon: "partly_cloudy_day"
        order: 40
        description: "Where the forecast is for."

        SettingItem {
            key: "location"
            icon: "location_on"
            kind: "text"
            label: "Location"
            description: "A place name, looked up with Open-Meteo."
            placeholder: "City or town"
            def: ""
        }
        SettingItem {
            key: "weather.refresh"
            kind: "number"
            label: "Refresh every"
            def: 15
            min: 5
            max: 120
            step: 5
            unit: " min"
        }
    }
    readonly property string location: settings.v.location.trim()

    property var data: null
    readonly property var current: data?.current ?? null
    readonly property var days: data?.forecast_days ?? []
    readonly property var hours: data?.forecast_hours ?? []
    readonly property string place: data?.location_name ?? ""
    readonly property real temp: current?.temperature_c ?? 0
    readonly property string icon: current ? iconFor(current.weather_code, current.is_day) : "cloud"
    readonly property string description: current ? describe(current.weather_code) : ""

    readonly property string cachePath: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/nafeel-shell/weather.json`
    readonly property int refreshMinutes: settings.v["weather.refresh"]

    // WMO weather codes.
    function describe(code: int): string {
        if (code === 0)
            return "Clear";
        if (code <= 2)
            return "Partly cloudy";
        if (code === 3)
            return "Overcast";
        if (code <= 48)
            return "Fog";
        if (code <= 57)
            return "Drizzle";
        if (code <= 67)
            return "Rain";
        if (code <= 77)
            return "Snow";
        if (code <= 82)
            return "Showers";
        if (code <= 86)
            return "Snow showers";
        return "Thunderstorm";
    }

    function iconFor(code: int, day: bool): string {
        if (code === 0)
            return day === false ? "clear_night" : "clear_day";
        if (code <= 2)
            return day === false ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 3)
            return "cloud";
        if (code <= 48)
            return "foggy";
        if (code <= 67 || (code >= 80 && code <= 82))
            return "rainy";
        if (code <= 77 || code <= 86)
            return "weather_snowy";
        return "thunderstorm";
    }

    function refresh(): void {
        const where = root.location;
        if (!where)
            return;
        // Same place as the cache: straight to the forecast.
        if (data?.query === where && data?.latitude !== undefined) {
            forecast.fetch(data.latitude, data.longitude, data.location_name, where);
            return;
        }
        geocode.where = where;
        geocode.command = ["curl", "-fsS", "--max-time", "15", `https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&name=${encodeURIComponent(where)}`];
        geocode.running = true;
    }

    // The forecast, reshaped as the views read it.
    function shape(f: var, name: string, where: string): var {
        const c = f.current ?? {};
        const days = (f.daily?.time ?? []).map((t, i) => ({
                    date_iso: t,
                    temperature_max_c: f.daily.temperature_2m_max[i],
                    temperature_min_c: f.daily.temperature_2m_min[i],
                    weather_code: f.daily.weather_code[i],
                    sunrise_iso: f.daily.sunrise[i],
                    sunset_iso: f.daily.sunset[i]
                }));
        const hours = (f.hourly?.time ?? []).map((t, i) => ({
                    time_iso: t,
                    temperature_c: f.hourly.temperature_2m[i],
                    weather_code: f.hourly.weather_code[i],
                    is_day: !!f.hourly.is_day[i],
                    precipitation_probability_percent: f.hourly.precipitation_probability[i],
                    relative_humidity_percent: f.hourly.relative_humidity_2m[i],
                    wind_speed_kmh: f.hourly.wind_speed_10m[i]
                }));
        return {
            query: where,
            location_name: name,
            latitude: f.latitude,
            longitude: f.longitude,
            fetched_at: new Date().toISOString(),
            current: {
                time_iso: c.time,
                temperature_c: c.temperature_2m,
                apparent_temperature_c: c.apparent_temperature,
                relative_humidity_percent: c.relative_humidity_2m,
                is_day: !!c.is_day,
                weather_code: c.weather_code,
                wind_speed_kmh: c.wind_speed_10m,
                wind_direction_deg: c.wind_direction_10m,
                uv_index: c.uv_index
            },
            forecast_days: days,
            forecast_hours: hours
        };
    }

    Process {
        id: geocode

        property string where

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text).results?.[0];
                    if (!r)
                        return;
                    const name = [r.name, r.country].filter(Boolean).join(", ");
                    forecast.fetch(r.latitude, r.longitude, name, geocode.where);
                } catch (e) {}
            }
        }
    }

    Process {
        id: forecast

        property string name
        property string where

        function fetch(lat: real, lon: real, name: string, where: string): void {
            forecast.name = name;
            forecast.where = where;
            command = ["curl", "-fsS", "--max-time", "20", `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=auto&forecast_days=7` + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m,wind_direction_10m,uv_index" + "&hourly=temperature_2m,weather_code,is_day,precipitation_probability,relative_humidity_2m,wind_speed_10m" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = root.shape(JSON.parse(text), forecast.name, forecast.where);
                    root.data = d;
                    cache.setText(JSON.stringify(d));
                } catch (e) {}
            }
        }
    }

    FileView {
        id: cache

        path: root.cachePath
        printErrors: false
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {}
            // Fetch now when the cache is old (or for another place).
            const age = root.data?.fetched_at ? Date.now() - new Date(root.data.fetched_at).getTime() : Infinity;
            if (age > root.refreshMinutes * 60000 || root.data?.query !== root.location)
                root.refresh();
        }
        onLoadFailed: root.refresh()
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.cachePath.replace(/\/[^/]*$/, "")])

    Timer {
        running: true
        repeat: true
        interval: root.refreshMinutes * 60000
        onTriggered: root.refresh()
    }

    onLocationChanged: refresh()
}
