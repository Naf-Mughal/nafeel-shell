import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// The clipboard history, by keyword only ("cb"; what you copied can be
// private, so it never shows in the unscoped list): newest first when empty,
// fuzzy on the text when typed. Enter pastes into the app you came from;
// Tab: copy only, pin, delete.
LauncherProvider {
    name: "Clipboard"
    icon: "content_paste"
    keyword: "cb"
    global: false
    answersEmpty: true
    weight: 1
    limit: 40

    function flat(t: string): string {
        return t.trim().replace(/\s+/g, " ");
    }

    function query(text: string, seq: int): var {
        const out = [];
        const entries = Clipboard.entries;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const preview = flat(e.preview ?? "");
            const s = text === "" ? 100 - Math.min(i, 90) : Fuzzy.score(preview, text);
            if (s <= 0)
                continue;
            const index = i;
            out.push({
                title: e.image ? "Image" : preview.length > 160 ? preview.slice(0, 160) + "…" : preview || "(empty)",
                subtitle: `${e.pinned ? "Pinned   ·   " : ""}${e.image ? (e.mime ?? "") : (e.preview ?? "").length + " characters"}`,
                icon: e.image ? "image" : e.pinned ? "keep" : "content_paste",
                score: s,
                preview: () => e.image ? { kind: "image", path: Clipboard.imageFile(index) } : { kind: "text", text: Clipboard.text(index, 3000) },
                key: "",
                highlight: !e.image,
                run: () => {
                    Clipboard.activate(index, false);
                    Paste.now(e.image === true);
                },
                actions: [
                    {
                        label: "Copy only",
                        icon: "content_copy",
                        run: () => Clipboard.activate(index, false)
                    },
                    {
                        label: e.pinned ? "Unpin" : "Pin",
                        icon: "keep",
                        run: () => Clipboard.togglePin(index)
                    },
                    {
                        label: "Delete",
                        icon: "delete",
                        run: () => Clipboard.remove(index)
                    }
                ]
            });
        }
        return out;
    }
}
