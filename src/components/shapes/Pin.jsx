import React from "react";
import { COLOR } from "../../theme.js";

export function Pin({ x, y, populated }) {
  return populated ? (
    <circle cx={x} cy={y} r={4.5} fill={COLOR.pinFill} stroke={COLOR.pinRing} strokeWidth={1.25} />
  ) : (
    <circle cx={x} cy={y} r={4.5} fill="none" stroke={COLOR.pinEmptyStroke} strokeWidth={1.25} strokeDasharray="2,2" />
  );
}
