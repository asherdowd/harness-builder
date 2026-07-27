import React from "react";
import { COLOR } from "../../theme.js";
import { EmptyState } from "../common/EmptyState.jsx";

export function NewProjectView() {
  const [selected, setSelected] = React.useState(null);

  const option = (key, label, desc) => (
    <button
      onClick={() => setSelected(key)}
      style={{
        flex: 1, textAlign: "left", background: selected === key ? "#1c2129" : "#171b21",
        border: `1px solid ${selected === key ? COLOR.bodyStroke : COLOR.grid}`, borderRadius: 8,
        padding: "18px 16px", cursor: "pointer", fontFamily: "inherit",
      }}
    >
      <div style={{ color: "#e6e9ed", fontSize: 15, fontWeight: 600 }}>{label}</div>
      <div style={{ color: COLOR.nameText, fontSize: 12.5, marginTop: 6, lineHeight: 1.4 }}>{desc}</div>
    </button>
  );

  return (
    <div style={{ padding: "20px 20px 40px" }}>
      <div style={{ color: COLOR.nameText, fontSize: 11, letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12, padding: "0 4px" }}>
        New Project — Select a Component Type
      </div>
      <div style={{ display: "flex", gap: 10 }}>
        {option("harness", "Harness", "A connector bundle with plugs, pins, and wire colors.")}
        {option("ecu", "ECU", "A control unit — plug-in, standalone, piggyback, etc.")}
      </div>
      {selected && (
        <div style={{ marginTop: 22 }}>
          <EmptyState
            eyebrow="Coming Next"
            title={selected === "harness" ? "Harness setup wizard" : "ECU setup wizard"}
            body="This step — plug shape, rows, pin orientation, and connector-type lookup (or ECU type + validation) — is the next piece we build."
          />
        </div>
      )}
    </div>
  );
}
