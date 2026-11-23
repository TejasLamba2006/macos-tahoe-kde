.pragma library

function scaleFor(hovered, distance, width) {
    if (!hovered || width <= 0 || !isFinite(distance)) return 1;
    const influence = Math.max(0, 1 - Math.abs(distance) / (width * 2.25));
    return Math.min(1.24, 1 + 0.24 * influence * influence);
}
