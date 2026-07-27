import React from "react";
import { COLOR } from "../../theme.js";
import { CloseIcon, ChevronRight } from "../icons/Icons.jsx";

export function NavDrawer({ open, onClose, view, onNavigate }) {
  const item = (key, label, indent = false) => (
    <button
      onClick={() => onNavigate(key)}
      style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        width: "100%", textAlign: "left", background: view === key ? "#1c2129" : "transparent",
        border: "none", cursor: "pointer", padding: indent ? "10px 16px 10px 34px" : "12px 16px",
        color: view === key ? COLOR.idText : "#d7dbe0",
        fontSize: indent ? 13.5 : 14.5, fontWeight: indent ? 500 : 600,
        borderRadius: 6, fontFamily: "inherit",
      }}
    >
      <span>{label}</span>
      {!indent && <ChevronRight />}
    </button>
  );

  return (
    <>
      {open && (
        <div onClick={onClose} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", zIndex: 40 }} />
      )}
      <div
        style={{
          position: "fixed", top: 0, left: open ? 0 : -300, height: "100vh", width: 280,
          background: "#171b21", borderRight: `1px solid ${COLOR.grid}`, zIndex: 50,
          transition: "left 0.22s ease", display: "flex", flexDirection: "column", padding: "18px 10px",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "4px 10px 18px" }}>
          <span style={{ color: COLOR.idText, fontSize: 12, letterSpacing: "0.14em", fontWeight: 700, textTransform: "uppercase", fontFamily: "ui-monospace, SFMono-Regular, monospace" }}>
            Harness Builder
          </span>
          <button onClick={onClose} style={{ background: "none", border: "none", cursor: "pointer", padding: 4 }}>
            <CloseIcon />
          </button>
        </div>

        <div style={{ color: COLOR.nameText, fontSize: 11, letterSpacing: "0.1em", textTransform: "uppercase", padding: "10px 16px 4px" }}>
          Projects
        </div>
        {item("existing", "Existing", true)}
        {item("new", "New", true)}

        <div style={{ height: 1, background: COLOR.grid, margin: "14px 8px" }} />

        {item("settings", "Settings")}
      </div>
    </>
  );
}
