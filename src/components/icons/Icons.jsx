import React from "react";

export function HamburgerIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
      <line x1="3" y1="6" x2="19" y2="6" stroke="#d7dbe0" strokeWidth="1.8" strokeLinecap="round" />
      <line x1="3" y1="11" x2="19" y2="11" stroke="#d7dbe0" strokeWidth="1.8" strokeLinecap="round" />
      <line x1="3" y1="16" x2="19" y2="16" stroke="#d7dbe0" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

export function CloseIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
      <line x1="4" y1="4" x2="16" y2="16" stroke="#d7dbe0" strokeWidth="1.8" strokeLinecap="round" />
      <line x1="16" y1="4" x2="4" y2="16" stroke="#d7dbe0" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

export function ChevronRight() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M6 3 L11 8 L6 13" stroke="#565e6a" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </svg>
  );
}
