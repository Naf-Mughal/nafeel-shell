.pragma library

// Where something floats (a menu, a select's list, a tooltip, a dialog): the
// panel it's in (the drawer's body, marked `navScope`). The frame only takes
// input inside an open panel, and a press outside one closes it; a panel
// clips to its shape: so floating things live inside their panel's body.
// Outside any panel (the desktop's own surface): the top of the item's tree,
// its window's content item.
function of(item) {
    let p = item?.parent ?? null, top = item ?? null;
    while (p) {
        if (p.navScope === true)
            return p;
        top = p;
        p = p.parent;
    }
    return top;
}
