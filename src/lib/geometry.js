// Grid-based pin layout for row/column style connectors.
export function gridLayout(rows, { colGap = 24, rowGap = 22, padX = 14, padY = 14, topExtra = 8 } = {}) {
  const maxCols = Math.max(...rows.map((r) => r.positions));
  const width = maxCols * colGap + padX * 2;
  const height = rows.length * rowGap + padY * 2 + topExtra;
  const pins = [];
  rows.forEach((row, ri) => {
    const rowWidth = (row.positions - 1) * colGap;
    const rowStartX = -rowWidth / 2;
    const y = -height / 2 + padY + topExtra + ri * rowGap;
    row.pins.forEach((p, pi) => {
      pins.push({ x: rowStartX + pi * colGap, y, populated: p.populated });
    });
  });
  return { width, height, pins };
}

// Builds a rounded-corner SVG path string through a convex polygon's points.
export function roundedPolyPath(pts, r) {
  const n = pts.length;
  let d = "";
  for (let i = 0; i < n; i++) {
    const prev = pts[(i - 1 + n) % n];
    const curr = pts[i];
    const next = pts[(i + 1) % n];
    const v1 = { x: curr.x - prev.x, y: curr.y - prev.y };
    const len1 = Math.hypot(v1.x, v1.y);
    const u1 = { x: v1.x / len1, y: v1.y / len1 };
    const cr = Math.min(r, len1 / 2, Math.hypot(next.x - curr.x, next.y - curr.y) / 2);
    const p1 = { x: curr.x - u1.x * cr, y: curr.y - u1.y * cr };
    const v2 = { x: next.x - curr.x, y: next.y - curr.y };
    const len2 = Math.hypot(v2.x, v2.y);
    const u2 = { x: v2.x / len2, y: v2.y / len2 };
    const p2 = { x: curr.x + u2.x * cr, y: curr.y + u2.y * cr };
    d += (i === 0 ? `M ${p1.x} ${p1.y} ` : `L ${p1.x} ${p1.y} `) + `Q ${curr.x} ${curr.y} ${p2.x} ${p2.y} `;
  }
  return d + "Z";
}

// Some connector families have a known, fixed physical row count for this
// Honda generation, independent of how the source data grouped the pins.
// A "square" 4-pin housing, for example, is physically always 2 rows of 2 —
// it can't be a flat single row (that would be a rectangle, not square).
// This re-chunks the flat pin list into the correct row count before layout.
export const FORCED_ROW_COUNT = {
  "square-4pin": 2,
  "square-2pin": 2,
};

export function normalizeRows(shape, rows) {
  const forced = FORCED_ROW_COUNT[shape];
  if (!forced) return rows;
  const flatPins = rows.flatMap((r) => r.pins);
  const rowSize = Math.ceil(flatPins.length / forced);
  const chunked = [];
  for (let i = 0; i < flatPins.length; i += rowSize) {
    const slice = flatPins.slice(i, i + rowSize);
    chunked.push({ positions: slice.length, pins: slice });
  }
  return chunked;
}

// Simple char-count based text wrap for SVG <text> labels (no <tspan> flow).
export function wrapText(text, maxChars) {
  const words = text.split(" ");
  const lines = [];
  let current = "";
  words.forEach((w) => {
    if ((current + " " + w).trim().length > maxChars) {
      lines.push(current.trim());
      current = w;
    } else {
      current = (current + " " + w).trim();
    }
  });
  if (current) lines.push(current);
  return lines.slice(0, 2);
}
