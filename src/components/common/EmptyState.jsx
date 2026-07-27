import React from "react";
import { COLOR } from "../../theme.js";

export function EmptyState({ eyebrow, title, body }) {
  return (
    <div style={{ padding: "60px 28px", textAlign: "center", maxWidth: 380, margin: "0 auto" }}>
      <div style={{ color: COLOR.idText, fontSize: 11, letterSpacing: "0.14em", textTransform: "uppercase", fontFamily: "ui-monospace, SFMono-Regular, monospace", marginBottom: 10 }}>
        {eyebrow}
      </div>
      <div style={{ color: "#e6e9ed", fontSize: 17, fontWeight: 600, marginBottom: 8 }}>{title}</div>
      <div style={{ color: COLOR.nameText, fontSize: 13.5, lineHeight: 1.5 }}>{body}</div>
    </div>
  );
}
