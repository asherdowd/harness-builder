import React, { useMemo } from "react";
import { COLOR } from "../theme.js";
import { HARNESS } from "../data/harness.js";
import { wrapText } from "../lib/geometry.js";
import { renderShape } from "./shapes/shapeRenderers.jsx";

function renderHarnessView(harness) {
  const trunkX = 480;
  const gap = 150;
  const leadLength = 130;
  const topPad = 70;
  const bottomPad = 90;

  const layout = harness.connectors.map((conn, i) => {
    const side = i % 2 === 0 ? -1 : 1;
    const y = topPad + i * gap;
    const shapeData = renderShape(conn.shape, conn.rows);
    const anchorX = trunkX + side * leadLength;
    return { conn, side, y, anchorX, shapeData };
  });

  const totalHeight = topPad + (harness.connectors.length - 1) * gap + bottomPad;
  const svgWidth = 960;

  return { layout, totalHeight, svgWidth, trunkX, topPad, bottomPad };
}

export function HarnessCanvas({ project, component, components = [], onAddComponent, onSelectComponent, onUpdateComponent, onDeleteComponent }) {
  const activeComponent = component || project?.components?.[0] || null;
  const harness = activeComponent?.harness || HARNESS;
  const title = activeComponent?.name || harness.meta?.project || HARNESS.meta.project;
  const subtitle = activeComponent?.harness?.meta?.vehicle || harness.meta?.vehicle || HARNESS.meta.vehicle;

  const view = useMemo(() => {
    if (activeComponent?.type === "ecu") {
      return {
        mode: "ecu",
        title: activeComponent.name,
        subtitle: activeComponent.ecu?.name || "Connected ECU",
      };
    }

    return { mode: "harness", ...renderHarnessView(harness) };
  }, [activeComponent, harness]);

  const svgWidth = view.mode === "ecu" ? 960 : view.svgWidth;
  const totalHeight = view.mode === "ecu" ? 280 : view.totalHeight;
  const [editingName, setEditingName] = React.useState(activeComponent?.name || "");

  React.useEffect(() => {
    setEditingName(activeComponent?.name || "");
  }, [activeComponent?.id, activeComponent?.name]);

  const handleSaveName = () => {
    if (!activeComponent) return;
    onUpdateComponent?.(activeComponent.id, { name: editingName.trim() || activeComponent.name });
  };

  return (
    <div style={{ background: COLOR.bg, minHeight: "100%", width: "100%", fontFamily: "ui-sans-serif, system-ui, sans-serif" }}>
      <div style={{ padding: "16px 28px 8px", borderBottom: `1px solid ${COLOR.grid}` }}>
        <div style={{ color: "#e6e9ed", fontSize: 18, fontWeight: 600 }}>{title}</div>
        <div style={{ color: COLOR.nameText, fontSize: 12.5, marginTop: 2 }}>{subtitle}</div>
        {activeComponent && (
          <div style={{ display: "flex", gap: 8, marginTop: 12, flexWrap: "wrap", alignItems: "center" }}>
            <input
              value={editingName}
              onChange={(event) => setEditingName(event.target.value)}
              placeholder="Component name"
              style={{ background: "#12161d", border: `1px solid ${COLOR.grid}`, borderRadius: 8, color: "#e6e9ed", padding: "7px 10px", fontFamily: "inherit" }}
            />
            <button
              onClick={handleSaveName}
              style={{ background: "#2f6fed", border: "none", borderRadius: 8, color: "#fff", padding: "7px 10px", cursor: "pointer", fontFamily: "inherit" }}
            >
              Save
            </button>
            <button
              onClick={() => onDeleteComponent?.(activeComponent.id)}
              style={{ background: "#7a2e2e", border: "none", borderRadius: 8, color: "#fff", padding: "7px 10px", cursor: "pointer", fontFamily: "inherit" }}
            >
              Delete
            </button>
          </div>
        )}
        {components.length > 0 && (
          <div style={{ display: "flex", gap: 8, marginTop: 12, flexWrap: "wrap" }}>
            {components.map((item) => (
              <button
                key={item.id}
                onClick={() => onSelectComponent?.(item.id)}
                style={{
                  background: component?.id === item.id ? "#1d2531" : "#12161d",
                  border: `1px solid ${component?.id === item.id ? COLOR.bodyStroke : COLOR.grid}`,
                  borderRadius: 999, color: "#e6e9ed", padding: "6px 10px", cursor: "pointer", fontFamily: "inherit"
                }}
              >
                {item.type === "ecu" ? "ECU" : "Harness"}
              </button>
            ))}
            <button
              onClick={() => onAddComponent?.("ecu")}
              style={{ background: "#243041", border: "1px solid #3c506a", borderRadius: 999, color: "#e6e9ed", padding: "6px 10px", cursor: "pointer", fontFamily: "inherit" }}
            >
              + ECU
            </button>
            <button
              onClick={() => onAddComponent?.("harness")}
              style={{ background: "#243041", border: "1px solid #3c506a", borderRadius: 999, color: "#e6e9ed", padding: "6px 10px", cursor: "pointer", fontFamily: "inherit" }}
            >
              + Harness
            </button>
          </div>
        )}
      </div>

      <div style={{ overflow: "auto", maxHeight: "calc(100vh - 140px)" }}>
        <svg width={svgWidth} height={totalHeight} viewBox={`0 0 ${svgWidth} ${totalHeight}`}>
          <defs>
            <pattern id="grid" width="28" height="28" patternUnits="userSpaceOnUse">
              <path d="M 28 0 L 0 0 0 28" fill="none" stroke={COLOR.grid} strokeWidth="1" />
            </pattern>
          </defs>
          <rect x={0} y={0} width={svgWidth} height={totalHeight} fill="url(#grid)" />

          {view.mode === "ecu" ? (
            <>
              <rect x={260} y={70} width={440} height={140} rx={16} fill="#1b2230" stroke={COLOR.bodyStroke} strokeWidth={2} />
              <text x={480} y={120} textAnchor="middle" fill="#e6e9ed" fontSize={18} fontWeight={700}>ECU</text>
              <text x={480} y={148} textAnchor="middle" fill={COLOR.nameText} fontSize={13}>{activeComponent?.ecu?.name || "Connected ECU"}</text>
              <line x1={480} y1={210} x2={480} y2={280} stroke={COLOR.leadStroke} strokeWidth={2} />
            </>
          ) : (
            <>
              <rect x={view.trunkX - 14} y={view.topPad - 30} width={28} height={totalHeight - view.topPad - view.bottomPad + 60} rx={14}
                fill={COLOR.trunkFill} stroke={COLOR.trunkStroke} strokeWidth={2} />
              {[-5, 0, 5].map((dx, i) => (
                <line key={i} x1={view.trunkX + dx} y1={view.topPad - 26} x2={view.trunkX + dx} y2={totalHeight - view.bottomPad + 26}
                  stroke={COLOR.trunkStrand} strokeWidth={1} strokeDasharray="1,5" />
              ))}

              {view.layout.map(({ conn, side, y, anchorX, shapeData }) => {
                const trunkEdgeX = view.trunkX + side * 14;
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
            </>
          )}
        </svg>
      </div>
    </div>
  );
}
