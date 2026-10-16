import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.components
import qs.services

// Ask Claude from the launcher: "ai how do I undo my last git commit". Nothing
// is sent while you type; Enter sends the prompt to Claude through the CLI
// (`claude -p`, your own login and plan, no tools, no saved session) and the
// answer comes back as a result, in full in the preview. Enter on it copies;
// Tab: paste into the app you came from, or continue as a conversation in a
// terminal. Settings: Launcher, Ask Claude (on / off, the model).
LauncherProvider {
    id: root

    name: "Ask Claude"
    icon: "auto_awesome"
    keyword: "ai"
    global: false

    readonly property var shared: Plugins.instance("launcher")
    readonly property bool enabled: shared?.askOn ?? true

    // The last prompt asked, and how it went.
    property string prompt: ""
    property string answer: ""
    property string failure: ""
    property bool busy: false
    // The search being shown, for publishing the answer into it.
    property int lastSeq: -1
    property string lastText: ""

    readonly property string system: "You are answering from a quick launcher on a Linux desktop. Answer in at most 8 short lines of plain text: no markdown, no headings, no preamble. If the question needs the web or files you can't see, say so in one line."

    function query(text: string, seq: int): var {
        lastSeq = seq;
        lastText = text;
        return build(text);
    }

    function build(text: string): var {
        if (!enabled)
            return [];
        if (text === "")
            return [{
                    title: "Ask Claude",
                    subtitle: "Type a question, then Enter. Nothing is sent until you press Enter; it uses your Claude plan.",
                    icon: "auto_awesome",
                    score: 1,
                    highlight: false,
                    keepOpen: true,
                    run: () => {}
                }];
        const out = [];
        const mine = prompt === text;
        if (mine && (busy || answer || failure))
            out.push(answerResult());
        out.push({
            title: mine && (answer || failure) ? "Ask again" : `Ask Claude: ${text}`,
            subtitle: "Enter sends this text to Claude (your plan)",
            icon: "send",
            score: 100,
            top: !mine,
            key: "",
            highlight: false,
            keepOpen: true,
            preview: { kind: "info", icon: "auto_awesome", title: "Ask Claude", lines: [text, "Sent only when you press Enter. Answers in a few lines; Tab on the answer for more."] },
            run: () => ask(text)
        });
        return out;
    }

    function answerResult(): var {
        if (busy)
            return {
                title: "Thinking…",
                subtitle: prompt,
                icon: "hourglass_top",
                score: 300,
                top: true,
                key: "",
                highlight: false,
                keepOpen: true,
                preview: { kind: "prose", title: prompt, text: "Claude is answering…" },
                run: () => {}
            };
        if (failure)
            return {
                title: "Claude couldn't answer",
                subtitle: failure,
                icon: "error",
                score: 300,
                top: true,
                key: "",
                highlight: false,
                keepOpen: true,
                preview: { kind: "prose", title: prompt, text: failure },
                run: () => {}
            };
        const text = answer, asked = prompt;
        return {
            title: text.split("\n")[0],
            subtitle: "Claude   ·   Enter copies the answer",
            icon: "auto_awesome",
            score: 300,
            top: true,
            key: "",
            highlight: false,
            preview: { kind: "prose", title: asked, text: text },
            run: () => Clipboard.copyText(text),
            actions: [
                {
                    label: "Paste it into the app",
                    icon: "content_paste_go",
                    run: () => {
                        Clipboard.copyText(text);
                        Paste.now(false);
                    }
                },
                {
                    label: "Continue as a conversation in a terminal",
                    icon: "terminal",
                    run: () => Quickshell.execDetached(["foot", "claude", asked])
                },
                {
                    label: "Copy the question",
                    icon: "content_copy",
                    run: () => Clipboard.copyText(asked)
                }
            ]
        };
    }

    function ask(text: string): void {
        ripple.running = false;
        prompt = text;
        answer = "";
        failure = "";
        busy = true;
        const model = (shared?.askModel ?? "").trim();
        // claude lives in ~/.local/bin, which the shell's PATH may lack.
        ripple.command = ["sh", "-c", 'c=$(command -v claude || echo "$HOME/.local/bin/claude"); exec "$c" -p --no-session-persistence --tools "" "$@"', "sh", ...(model ? ["--model", model] : []), "--append-system-prompt", system, "--", text];
        ripple.running = true;
        limit.restart();
        publish(lastSeq, build(lastText));
    }

    function done(code: int, out: string, err: string): void {
        limit.stop();
        busy = false;
        const o = out.trim();
        if (code === 0 && o)
            answer = o;
        else
            failure = (err.trim() || o).split("\n")[0].slice(0, 200) || `claude exited with ${code}`;
        publish(lastSeq, build(lastText));
    }

    readonly property Process ripple: Process {
        id: ripple

        workingDirectory: Quickshell.env("HOME")
        stdout: StdioCollector {
            id: stdout
        }
        stderr: StdioCollector {
            id: stderr
        }
        onExited: code => root.done(code, stdout.text, stderr.text)
    }

    // A stuck call is let go after a minute and a half.
    readonly property Timer limiter: Timer {
        id: limit

        interval: 90000
        onTriggered: {
            ripple.running = false;
            root.busy = false;
            root.failure = "It took too long.";
            root.publish(root.lastSeq, root.build(root.lastText));
        }
    }
}
