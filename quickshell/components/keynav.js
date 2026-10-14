.pragma library

// Keyboard navigation inside a panel: Tab and the arrows walk Qt's focus
// chain, kept to the panel the item is in (its `navScope` ancestor: a
// drawer's content), so focus never wanders into the bar or another
// (hidden, warm) panel.

function scopeOf(item) {
    for (let p = item; p; p = p.parent)
        if (p.navScope === true)
            return p;
    return null;
}

function usable(item) {
    for (let p = item; p; p = p.parent)
        if (!p.visible || !p.enabled)
            return false;
    return true;
}

// The next (or previous) focusable item after `from` within `scope`.
function step(from, scope, forward) {
    if (!from || !scope)
        return null;
    let c = from;
    for (let i = 0; i < 2000; i++) {
        c = c.nextItemInFocusChain(forward);
        if (!c || c === from)
            return null;
        if (scopeOf(c) === scope && usable(c))
            return c;
    }
    return null;
}

function give(item, reason) {
    item.forceActiveFocus(reason);
    if (item.focusByKey !== undefined)
        item.focusByKey = true;
}

// Move the keyboard from `item` to the next control of its panel.
function move(item, forward) {
    const next = step(item, scopeOf(item), forward);
    if (next) {
        give(next, forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
        return true;
    }
    return false;
}

// The panel's first control, starting from anything in the window.
function enter(scope, from, forward) {
    const next = step(from, scope, forward);
    if (next) {
        give(next, Qt.TabFocusReason);
        return true;
    }
    return false;
}
