import React from "react";
import { COLOR } from "./theme.js";
import { HARNESS } from "./data/harness.js";
import { TopBar } from "./components/nav/TopBar.jsx";
import { NavDrawer } from "./components/nav/NavDrawer.jsx";
import { HarnessCanvas } from "./components/HarnessCanvas.jsx";
import { ExistingProjectsView } from "./components/views/ExistingProjectsView.jsx";
import { NewProjectView } from "./components/views/NewProjectView.jsx";
import { SettingsView } from "./components/views/SettingsView.jsx";
import { createProject, getProjectComponents, initializeProjects } from "./lib/projectStore.js";
import { buildConnector, insertConnectorIntoHarness } from "./lib/harnessEditor.js";

export default function App() {
  const [drawerOpen, setDrawerOpen] = React.useState(false);
  const [view, setView] = React.useState("canvas");
  const [projects, setProjects] = React.useState(() => initializeProjects());
  const [activeProject, setActiveProject] = React.useState(projects[0] ?? null);
  const [activeComponentId, setActiveComponentId] = React.useState(null);

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
    const components = getProjectComponents(project);
    setActiveComponentId(components[0]?.id ?? null);
    setView("canvas");
    setDrawerOpen(false);
  };

  const handleCreateProject = (name, harness = HARNESS) => {
    const project = createProject(name, harness);
    setProjects((current) => [...current, project]);
    setActiveProject(project);
    setActiveComponentId(project.components?.[0]?.id ?? null);
    setView("canvas");
    setDrawerOpen(false);
    return project;
  };

  const activeComponents = React.useMemo(() => getProjectComponents(activeProject), [activeProject]);
  const activeComponent = activeComponents.find((component) => component.id === activeComponentId) || activeComponents[0] || null;

  const handleAddComponent = (type, payload = {}) => {
    if (!activeProject) return;

    const nextProject = {
      ...activeProject,
      components: [
        ...(activeProject.components || getProjectComponents(activeProject)),
        {
          type,
          id: `${type}-${Date.now()}`,
          name: type === "ecu" ? payload.name || "Connected ECU" : payload.name || "Added Harness",
          ...(type === "ecu"
            ? { ecu: { name: payload.name || "Connected ECU", typeId: payload.typeId || "ecm", plugs: payload.plugs || [] } }
            : { harness: payload.harness || HARNESS }),
        },
      ],
    };

    setProjects((current) => current.map((project) => (project.id === activeProject.id ? nextProject : project)));
    setActiveProject(nextProject);
    setActiveComponentId(nextProject.components[nextProject.components.length - 1].id);
  };

  const handleUpdateComponent = (componentId, updates) => {
    if (!activeProject) return;

    const nextComponents = (activeProject.components || getProjectComponents(activeProject)).map((component) => {
      if (component.id !== componentId) return component;
      return { ...component, ...updates };
    });

    const nextProject = { ...activeProject, components: nextComponents };
    setProjects((current) => current.map((project) => (project.id === activeProject.id ? nextProject : project)));
    setActiveProject(nextProject);
  };

  const handleDeleteComponent = (componentId) => {
    if (!activeProject) return;

    const nextComponents = (activeProject.components || getProjectComponents(activeProject)).filter((component) => component.id !== componentId);
    if (nextComponents.length === 0) {
      return;
    }

    const nextProject = { ...activeProject, components: nextComponents };
    setProjects((current) => current.map((project) => (project.id === activeProject.id ? nextProject : project)));
    setActiveProject(nextProject);
    setActiveComponentId(nextComponents[0].id);
  };

  const handleAddConnector = (componentId, connectorName, placement, anchorId) => {
    if (!activeProject) return;

    const nextComponents = (activeProject.components || getProjectComponents(activeProject)).map((component) => {
      if (component.id !== componentId || component.type !== "harness") return component;
      const connector = buildConnector(connectorName, { prefix: "EH" });
      const nextHarness = insertConnectorIntoHarness(component.harness, connector, placement, anchorId);
      return { ...component, harness: nextHarness };
    });

    const nextProject = { ...activeProject, components: nextComponents };
    setProjects((current) => current.map((project) => (project.id === activeProject.id ? nextProject : project)));
    setActiveProject(nextProject);
  };

  return (
    <div style={{ background: COLOR.bg, minHeight: "100vh", width: "100%", fontFamily: "ui-sans-serif, system-ui, sans-serif" }}>
      <TopBar onMenu={() => setDrawerOpen(true)} title={titles[view]} />
      <NavDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} view={view} onNavigate={handleNavigate} />

      {view === "canvas" && (
        <HarnessCanvas
          project={activeProject ?? projects[0] ?? null}
          component={activeComponent}
          components={activeComponents}
          onAddComponent={handleAddComponent}
          onSelectComponent={setActiveComponentId}
          onUpdateComponent={handleUpdateComponent}
          onDeleteComponent={handleDeleteComponent}
          onAddConnector={handleAddConnector}
        />
      )}
      {view === "existing" && <ExistingProjectsView projects={projects} onOpenProject={handleOpenProject} />}
      {view === "new" && <NewProjectView onCreateProject={handleCreateProject} />}
      {view === "settings" && <SettingsView />}
    </div>
  );
}
