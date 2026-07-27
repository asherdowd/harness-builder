import React from "react";
import { COLOR } from "../../theme.js";
import { gridLayout, roundedPolyPath } from "../../lib/geometry.js";
import { Pin } from "./Pin.jsx";

// Tapered trapezoid housing modeled on real Sumitomo/Denso-style Honda sensor
// connectors: narrower at the bottom, a raised locking tab on top, and a
// ridge line suggesting the housing's release-tab seam.
export function TaperedBody({ rows, cornerRadius = 5, taper = 0.16, tabWidthRatio = 0.4, ridge = true }) {
  const { width, height, pins } = gridLayout(rows);
  const topW = width;
  const botW = width * (1 - taper);
  const pts = [
    { x: -topW / 2, y: -height / 2 },
    { x: topW / 2, y: -height / 2 },
    { x: botW / 2, y: height / 2 },
    { x: -botW / 2, y: height / 2 },
  ];
  const tabW = Math.max(14, topW * tabWidthRatio);
  return (
    <>
      <path d={roundedPolyPath(pts, cornerRadius)} fill={COLOR.bodyFill} stroke={COLOR.bodyStroke} strokeWidth={1.5} />
      <path
        d={roundedPolyPath(
          [
            { x: -tabW / 2, y: -height / 2 - 8 },
            { x: tabW / 2, y: -height / 2 - 8 },
            { x: tabW / 2 - 2, y: -height / 2 + 2 },
            { x: -tabW / 2 + 2, y: -height / 2 + 2 },
          ],
          2
        )}
        fill={COLOR.bodyFill}
        stroke={COLOR.bodyStroke}
        strokeWidth={1.25}
      />
      {ridge && (
        <line x1={-topW / 2 + 4} y1={-height / 2 + 7} x2={topW / 2 - 4} y2={-height / 2 + 7}
          stroke={COLOR.bodyStroke} strokeWidth={1} opacity={0.55} />
      )}
      {pins.map((p, i) => <Pin key={i} {...p} />)}
    </>
  );
}
