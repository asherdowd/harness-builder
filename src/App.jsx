import React from "react";
import { COLOR } from "./theme.js";
import { HARNESS } from "./data/harness.js";
import { TopBar } from "./components/nav/TopBar.jsx";
import { NavDrawer } from "./components/nav/NavDrawer.jsx";
import { HarnessCanvas } from "./components/HarnessCanvas.jsx";
import { ExistingProjectsView } from "./components/views/ExistingProjectsView.jsx";
import { NewProjectView } from "./components/views/NewProjectView.jsx";
import { SettingsView } from "./components/views/SettingsView.jsx";

export default function App() {
  const [drawerOpen, setDrawerOpen] = React.useState(false);
  const [view, setView] = React.useState("canvas");

  const titles = {
    canvas: HARNESS.meta.project,
    existing: "Existing Projects",
    new: "New Project",
    settings: "Settings",
  };

  const handleNavigate = (key) => {
    setView(key);
    setDrawerOpen(false);
  };

  return (
    <div style={{ background: COLOR.bg, minHeight: "100vh", width: "100%", fontFamily: "ui-sans-serif, system-ui, sans-serif" }}>
      <TopBar onMenu={() => setDrawerOpen(true)} title={titles[view]} />
      <NavDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} view={view} onNavigate={handleNavigate} />

      {view === "canvas" && <HarnessCanvas />}
      {view === "existing" && <ExistingProjectsView onOpenProject={() => handleNavigate("canvas")} />}
      {view === "new" && <NewProjectView />}
      {view === "settings" && <SettingsView />}
    </div>
  );
}
