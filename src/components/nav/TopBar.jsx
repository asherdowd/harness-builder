import React from "react";
import { COLOR } from "../../theme.js";
import { HamburgerIcon } from "../icons/Icons.jsx";

export function TopBar({ onMenu, title }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 14, padding: "14px 18px",
      borderBottom: `1px solid ${COLOR.grid}`, background: COLOR.bg,
    }}>
      <button onClick={onMenu} style={{ background: "none", border: "none", cursor: "pointer", padding: 4 }}>
        <HamburgerIcon />
      </button>
      <div style={{ color: "#e6e9ed", fontSize: 15, fontWeight: 600 }}>{title}</div>
    </div>
  );
}
