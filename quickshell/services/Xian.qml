pragma Singleton

// The xianxia voice: Chinese numerals, the double-hour (时辰) and the glosses
// headings pair with their Latin names (from cave-abode's Xian.qml).

import QtQuick
import Quickshell

Singleton {
    readonly property var digits: ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    readonly property string branches: "子丑寅卯辰巳午未申酉戌亥"
    readonly property var animals: ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"]

    // Glosses for headings and tabs.
    readonly property var gloss: ({
            home: "首页",
            apps: "应用",
            media: "乐曲",
            audio: "声音",
            display: "显示",
            system: "系统",
            power: "灵力",
            network: "网络",
            bluetooth: "蓝牙",
            weather: "天象",
            calendar: "日历",
            notifications: "传音",
            session: "洞府",
            actions: "中枢",
            search: "寻",
            capture: "留影",
            wallpaper: "画卷",
            workspaces: "洞天",
            notes: "笔记",
            windows: "穿梭",
            clipboard: "剪贴"
        })

    function numeral(n: int): string {
        if (n < 10)
            return digits[n];
        if (n < 20)
            return "十" + (n % 10 ? digits[n % 10] : "");
        return digits[Math.floor(n / 10)] + "十" + (n % 10 ? digits[n % 10] : "");
    }

    function chineseDate(d: date): string {
        return numeral(d.getMonth() + 1) + "月" + numeral(d.getDate()) + "日";
    }

    // Double-hours start at 23:00 with 子 (Rat).
    function shichen(d: date): var {
        const i = Math.floor(((d.getHours() + 1) % 24) / 2);
        return {
            branch: branches.charAt(i),
            zh: branches.charAt(i) + "时",
            en: "Hour of the " + animals[i]
        };
    }
}
