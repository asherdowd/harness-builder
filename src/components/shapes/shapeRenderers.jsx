import React from "react";
import { COLOR } from "../../theme.js";
import { gridLayout, normalizeRows } from "../../lib/geometry.js";
import { Pin } from "./Pin.jsx";
import { TaperedBody } from "./TaperedBody.jsx";

const SHAPES = {
  // Large bulkhead/junction blocks — wide, multi-row Sumitomo TS-style housing
  "rectangular-block": (rows) => {
    const { width, height } = gridLayout(rows);
    return { width: width + 14, height: height + 16, node: <TaperedBody rows={rows} taper={0.12} tabWidthRatio={0.32} cornerRadius={4} /> };
  },
  // Small single-row power block — flatter, tighter taper
  "inline-block": (rows) => {
    const { width, height } = gridLayout(rows, { colGap: 26, rowGap: 22, padX: 14, padY: 12, topExtra: 0 });
    return { width: width + 10, height: height + 10, node: <TaperedBody rows={rows} taper={0.1} tabWidthRatio={0.3} cornerRadius={3} ridge={false} /> };
  },
  // O2 sensor 4-pin — squarer housing, wider tab, more taper (Denso-style)
  "square-4pin": (rows) => {
    const { width, height } = gridLayout(rows, { colGap: 22, rowGap: 22, padX: 15, padY: 15, topExtra: 6 });
    return { width, height, node: <TaperedBody rows={rows} taper={0.22} tabWidthRatio={0.45} cornerRadius={6} /> };
  },
  "square-2pin": (rows) => {
    const { width, height } = gridLayout(rows, { colGap: 22, rowGap: 22, padX: 15, padY: 15, topExtra: 6 });
    return { width, height, node: <TaperedBody rows={rows} taper={0.22} tabWidthRatio={0.45} cornerRadius={6} /> };
  },
  // VSS 3-pin — narrow elongated trapezoid, rounder corners, no ridge
  "rounded-rectangle-3pin": (rows) => {
    const { width, height } = gridLayout(rows, { colGap: 22, rowGap: 20, padX: 16, padY: 13, topExtra: 0 });
    return { width, height, node: <TaperedBody rows={rows} taper={0.14} tabWidthRatio={0.36} cornerRadius={height / 2.6} ridge={false} /> };
  },
  // TPS 3-pin — round housing per firsthand description, 3 pins in one row
  "round-3blade": (rows) => {
    const d = 58;
    const positions = rows[0].pins;
    const spacing = 18;
    const startX = -((positions.length - 1) * spacing) / 2;
    return {
      width: d, height: d,
      node: (
        <>
          <circle cx={0} cy={0} r={d / 2} fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.5} />
          <rect x={-6} y={-d / 2 - 6} width={12} height={7} rx={2} fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.25} />
          {positions.map((p, i) => <Pin key={i} x={startX + i * spacing} y={2} populated={p.populated} />)}
        </>
      ),
    };
  },
  // Common 2-pin sensor plug (fan switch, tach, ECT, IACV, EGR) — flattened
  // rounded capsule with a small top tab, per reference photos
  "round-2pin-vertical": (rows) => {
    const w = 34, h = 58;
    const pins = [{ x: 0, y: -13, populated: rows[0].pins[0].populated }, { x: 0, y: 13, populated: rows[1].pins[0].populated }];
    return {
      width: w, height: h,
      node: (
        <>
          <rect x={-w / 2} y={-h / 2} width={w} height={h} rx={w / 2.4}
            fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.5} />
          <rect x={-6} y={-h / 2 - 6} width={12} height={7} rx={2}
            fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.25} />
          {pins.map((p, i) => <Pin key={i} {...p} />)}
        </>
      ),
    };
  },
  "single-bullet": () => {
    const w = 20, h = 40;
    return {
      width: w, height: h + 18,
      node: (
        <>
          <line x1={0} y1={-h / 2 - 18} x2={0} y2={-h / 2} stroke={COLOR.leadStroke} strokeWidth={2.5} />
          <rect x={-w / 2} y={-h / 2} width={w} height={h} rx={w / 2}
            fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.5} />
          <Pin x={0} y={0} populated={true} />
        </>
      ),
    };
  },
  "single-spade": () => {
    const w = 30, h = 16;
    return {
      width: w + 20, height: h,
      node: (
        <>
          <line x1={-w / 2 - 20} y1={0} x2={-w / 2} y2={0} stroke={COLOR.leadStroke} strokeWidth={2.5} />
          <path d={`M ${-w / 2} ${-h / 2} L ${w / 2 - 6} ${-h / 2} L ${w / 2} 0 L ${w / 2 - 6} ${h / 2} L ${-w / 2} ${h / 2} Z`}
            fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.5} />
          <Pin x={-w / 2 + 8} y={0} populated={true} />
        </>
      ),
    };
  },
  "ground-lug": () => {
    const r = 13;
    return {
      width: r * 2 + 22, height: r * 2 + 6,
      node: (
        <>
          <line x1={-r - 22} y1={0} x2={-r - 2} y2={0} stroke={COLOR.leadStroke} strokeWidth={3} />
          <circle cx={0} cy={0} r={r} fill="none" stroke={COLOR.bodyStroke} strokeWidth={4} />
          <circle cx={0} cy={0} r={r - 6} fill={COLOR.bg} />
        </>
      ),
    };
  },
  "soldered-splice": (rows) => {
    const pins = rows[0].pins;
    const angles = [-55, -18, 18, 55];
    const len = 30;
    return {
      width: 90, height: 60,
      node: (
        <>
          {pins.map((p, i) => {
            const rad = (angles[i] * Math.PI) / 180;
            const x2 = Math.sin(rad) * len;
            const y2 = -Math.cos(rad) * len;
            return (
              <g key={i}>
                <line x1={0} y1={0} x2={x2} y2={y2} stroke={COLOR.leadStroke} strokeWidth={2} />
                <Pin x={x2} y={y2} populated={p.populated} />
              </g>
            );
          })}
          <circle cx={0} cy={0} r={9} fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.5} />
        </>
      ),
    };
  },
  "single-wire-torn": () => {
    const pts = "0,-22 -4,-14 4,-8 -5,-2 3,4 -3,10 0,16";
    return {
      width: 26, height: 42,
      node: (
        <>
          <polyline points={pts} fill="none" stroke={COLOR.leadStroke} strokeWidth={2.5} strokeLinejoin="round" strokeLinecap="round" />
          <Pin x={0} y={16} populated={true} />
        </>
      ),
    };
  },
};

export function renderShape(shape, rows) {
  const fn = SHAPES[shape];
  if (!fn) {
    return { width: 40, height: 40, node: <circle r={18} fill="none" stroke="red" strokeDasharray="3,3" /> };
  }
  return fn(normalizeRows(shape, rows));
}
