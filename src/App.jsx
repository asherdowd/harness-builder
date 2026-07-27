import React from "react";
import { COLOR } from "./theme.js";
import { HARNESS } from "./data/harness.js";
import { TopBar } from "./components/nav/TopBar.jsx";
import { NavDrawer } from "./components/nav/NavDrawer.jsx";
import { HarnessCanvas } from "./components/HarnessCanvas.jsx";
import { ExistingProjectsView } from "./components/views/ExistingProjectsView.jsx";
import { NewProjectView } from "./components/views/NewProjectView.jsx";
import { SettingsView } from "./components/views/SettingsView.jsx";
import { createProject, initializeProjects } from "./lib/projectStore.js";

export default function App() {
  const [drawerOpen, setDrawerOpen] = React.useState(false);
  const [view, setView] = React.useState("canvas");
  const [projects, setProjects] = React.useState(() => initializeProjects());
  const [activeProject, setActiveProject] = React.useState(projects[0] ?? null);

  const titles = {
    canvas: activeProject?.name ?? HARNESS.meta.project,
    existing: "Existing Projects",
    new: "New Project",
    settings: "Settings",
  };

  const handleNavigate = (key) => {
    setView(key);
    setDrawerOpen(false);
  };

  const handleOpenProject = (project) => {
    setActiveProject(project);
    setView("canvas");
    setDrawerOpen(false);
  };

  const handleCreateProject = (name) => {
    const project = createProject(name, HARNESS);
    setProjects((current) => [...current, project]);
    setActiveProject(project);
    setView("canvas");
    setDrawerOpen(false);
    return project;
  };

  return (
    <div style={{ background: COLOR.bg, minHeight: "100vh", width: "100%", fontFamily: "ui-sans-serif, system-ui, sans-serif" }}>
      <TopBar onMenu={() => setDrawerOpen(true)} title={titles[view]} />
      <NavDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} view={view} onNavigate={handleNavigate} />

      {view === "canvas" && <HarnessCanvas project={activeProject ?? projects[0] ?? null} />}
      {view === "existing" && <ExistingProjectsView projects={projects} onOpenProject={handleOpenProject} />}
      {view === "new" && <NewProjectView onCreateProject={handleCreateProject} />}
      {view === "settings" && <SettingsView />}
    </div>
  );
}
