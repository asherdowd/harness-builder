import React from "react";
import { COLOR } from "../../theme.js";

export function SettingsView() {
  const row = (label, hint) => (
    <div style={{
      display: "flex", justifyContent: "space-between", alignItems: "center",
      padding: "14px 16px", borderBottom: `1px solid ${COLOR.grid}`,
    }}>
      <div>
        <div style={{ color: "#e6e9ed", fontSize: 14 }}>{label}</div>
        <div style={{ color: COLOR.nameText, fontSize: 12, marginTop: 2 }}>{hint}</div>
      </div>
      <div style={{ width: 38, height: 22, borderRadius: 11, background: "#2b3038", border: `1px solid ${COLOR.grid}` }} />
    </div>
  );

  return (
    <div style={{ padding: "20px 20px 40px" }}>
      <div style={{ color: COLOR.nameText, fontSize: 11, letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 12, padding: "0 4px" }}>
        Settings
      </div>
      <div style={{ background: "#171b21", border: `1px solid ${COLOR.grid}`, borderRadius: 8, overflow: "hidden" }}>
        {row("Dark mode", "Not wired up yet")}
        {row("Export preferences", "Not wired up yet")}
        {row("Suggestion preferences", "Not wired up yet")}
      </div>
    </div>
  );
}
