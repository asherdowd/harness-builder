import { HARNESS } from "../data/harness.js";

export const PROJECT_STORAGE_KEY = "harness-builder-projects";

function createMemoryStorage() {
  return {
    getItem: () => null,
    setItem: () => undefined,
    removeItem: () => undefined,
  };
}

function getStorage(storage) {
  if (storage) return storage;
  if (typeof window !== "undefined" && window.localStorage) {
    return window.localStorage;
  }
  return createMemoryStorage();
}

export function buildSeedProject(harness = HARNESS) {
  return {
    id: "vx-b20z2",
    name: harness.meta.project,
    subtitle: harness.meta.vehicle,
    count: harness.connectors.length,
    harness,
  };
}

export function readProjects(storage) {
  const store = getStorage(storage);
  const raw = store.getItem(PROJECT_STORAGE_KEY);

  if (!raw) {
    return [];
  }

  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function writeProjects(projects, storage) {
  const store = getStorage(storage);
  store.setItem(PROJECT_STORAGE_KEY, JSON.stringify(projects));
  return projects;
}

export function initializeProjects(storage) {
  const existing = readProjects(storage);
  if (existing.length > 0) {
    return existing;
  }

  return writeProjects([buildSeedProject()], storage);
}

export function upsertProject(project, storage) {
  const projects = readProjects(storage);
  const index = projects.findIndex((item) => item.id === project.id);

  const nextProjects = index >= 0
    ? projects.map((item) => (item.id === project.id ? project : item))
    : [...projects, project];

  return writeProjects(nextProjects, storage);
}

export function createProject(name, harness = HARNESS, storage) {
  const project = {
    id: `project-${Date.now()}`,
    name,
    subtitle: harness.meta.vehicle,
    count: harness.connectors.length,
    harness,
  };

  upsertProject(project, storage);
  return project;
}
