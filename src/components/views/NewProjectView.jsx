import React from "react";
import { COLOR } from "../../theme.js";
import { EmptyState } from "../common/EmptyState.jsx";

export function NewProjectView({ onCreateProject }) {
  const [selected, setSelected] = React.useState(null);
  const [projectName, setProjectName] = React.useState("");

  const option = (key, label, desc) => (
    <button
      key={key}
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

  const handleCreate = () => {
    if (!selected || !projectName.trim()) return;
    onCreateProject(projectName.trim());
  };

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
        <div style={{ marginTop: 22, display: "grid", gap: 12 }}>
          <label style={{ display: "grid", gap: 8 }}>
            <span style={{ color: COLOR.nameText, fontSize: 12.5, textTransform: "uppercase", letterSpacing: "0.08em" }}>Project name</span>
            <input
              value={projectName}
              onChange={(event) => setProjectName(event.target.value)}
              placeholder={selected === "harness" ? "My harness project" : "My ECU project"}
              style={{
                background: "#171b21", border: `1px solid ${COLOR.grid}`, borderRadius: 8,
                color: "#e6e9ed", padding: "12px 14px", fontFamily: "inherit"
              }}
            />
          </label>

          <button
            onClick={handleCreate}
            disabled={!projectName.trim()}
            style={{
              alignSelf: "start", background: projectName.trim() ? "#2f6fed" : "#243041",
              color: "#fff", border: "none", borderRadius: 8, padding: "10px 14px",
              cursor: projectName.trim() ? "pointer" : "not-allowed", fontFamily: "inherit"
            }}
          >
            Create project
          </button>
        </div>
      )}

      {!selected && (
        <div style={{ marginTop: 22 }}>
          <EmptyState
            eyebrow="Coming Next"
            title="Harness setup wizard"
            body="Select a component type to start creating a new project entry."
          />
        </div>
      )}
    </div>
  );
}
