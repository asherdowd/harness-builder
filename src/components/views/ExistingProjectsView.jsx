import React from "react";
import { COLOR } from "../../theme.js";

export function ExistingProjectsView({ projects, onOpenProject }) {
  return (
    <div style={{ padding: "20px 20px 40px" }}>
      <div style={{ color: COLOR.nameText, fontSize: 11, letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12, padding: "0 4px" }}>
        Existing Projects
      </div>
      {projects.map((p) => (
        <button
          key={p.id}
          onClick={() => onOpenProject(p)}
          style={{
            display: "block", width: "100%", textAlign: "left", background: "#171b21",
            border: `1px solid ${COLOR.grid}`, borderRadius: 8, padding: "14px 16px",
            cursor: "pointer", marginBottom: 10, fontFamily: "inherit",
          }}
        >
          <div style={{ color: "#e6e9ed", fontSize: 14.5, fontWeight: 600 }}>{p.name}</div>
          <div style={{ color: COLOR.nameText, fontSize: 12.5, marginTop: 3 }}>{p.subtitle}</div>
          <div style={{ color: COLOR.idText, fontSize: 11, marginTop: 8, fontFamily: "ui-monospace, SFMono-Regular, monospace" }}>
            {p.count} connectors
          </div>
        </button>
      ))}
    </div>
  );
}
