import React, { useMemo } from "react";
import { COLOR } from "../theme.js";
import { HARNESS } from "../data/harness.js";
import { wrapText } from "../lib/geometry.js";
import { renderShape } from "./shapes/shapeRenderers.jsx";

export function HarnessCanvas() {
  const trunkX = 480;
  const gap = 150;
  const leadLength = 130;
  const topPad = 70;
  const bottomPad = 90;

  const layout = useMemo(() => {
    return HARNESS.connectors.map((conn, i) => {
      const side = i % 2 === 0 ? -1 : 1;
      const y = topPad + i * gap;
      const shapeData = renderShape(conn.shape, conn.rows);
      const anchorX = trunkX + side * leadLength;
      return { conn, side, y, anchorX, shapeData };
    });
  }, []);

  const totalHeight = topPad + (HARNESS.connectors.length - 1) * gap + bottomPad;
  const svgWidth = 960;

  return (
    <div style={{ background: COLOR.bg, minHeight: "100%", width: "100%", fontFamily: "ui-sans-serif, system-ui, sans-serif" }}>
      <div style={{ padding: "16px 28px 8px", borderBottom: `1px solid ${COLOR.grid}` }}>
        <div style={{ color: "#e6e9ed", fontSize: 18, fontWeight: 600 }}>{HARNESS.meta.project}</div>
        <div style={{ color: COLOR.nameText, fontSize: 12.5, marginTop: 2 }}>{HARNESS.meta.vehicle}</div>
      </div>

      <div style={{ overflow: "auto", maxHeight: "calc(100vh - 140px)" }}>
        <svg width={svgWidth} height={totalHeight} viewBox={`0 0 ${svgWidth} ${totalHeight}`}>
          <defs>
            <pattern id="grid" width="28" height="28" patternUnits="userSpaceOnUse">
              <path d="M 28 0 L 0 0 0 28" fill="none" stroke={COLOR.grid} strokeWidth="1" />
            </pattern>
          </defs>
          <rect x={0} y={0} width={svgWidth} height={totalHeight} fill="url(#grid)" />

          {/* trunk cable */}
          <rect x={trunkX - 14} y={topPad - 30} width={28} height={totalHeight - topPad - bottomPad + 60} rx={14}
            fill={COLOR.trunkFill} stroke={COLOR.trunkStroke} strokeWidth={2} />
          {[-5, 0, 5].map((dx, i) => (
            <line key={i} x1={trunkX + dx} y1={topPad - 26} x2={trunkX + dx} y2={totalHeight - bottomPad + 26}
              stroke={COLOR.trunkStrand} strokeWidth={1} strokeDasharray="1,5" />
          ))}

          {layout.map(({ conn, side, y, anchorX, shapeData }, i) => {
            const trunkEdgeX = trunkX + side * 14;
            const labelLines = wrapText(conn.name, 20);
            const labelX = anchorX + side * (shapeData.width / 2 + 10);
            return (
              <g key={conn.id}>
                <path
                  d={`M ${trunkEdgeX} ${y} C ${trunkEdgeX + side * 40} ${y}, ${anchorX - side * 30} ${y}, ${anchorX} ${y}`}
                  fill="none" stroke={COLOR.leadStroke} strokeWidth={2}
                />
                <circle cx={trunkEdgeX} cy={y} r={2.5} fill={COLOR.trunkStroke} />
                <g transform={`translate(${anchorX}, ${y})`}>{shapeData.node}</g>
                <text x={labelX} y={y - 6} textAnchor={side === -1 ? "end" : "start"}
                  fill={COLOR.idText} fontSize={12} fontWeight={700}
                  fontFamily="ui-monospace, SFMono-Regular, monospace">
                  {conn.id}
                </text>
                {labelLines.map((line, li) => (
                  <text key={li} x={labelX} y={y + 10 + li * 13} textAnchor={side === -1 ? "end" : "start"}
                    fill={COLOR.nameText} fontSize={11}>
                    {line}
                  </text>
                ))}
              </g>
            );
          })}
        </svg>
      </div>
    </div>
  );
}
