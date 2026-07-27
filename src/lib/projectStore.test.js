import { describe, expect, it } from "vitest";
import { createProject, getProjectComponents, initializeProjects, readProjects, writeProjects } from "./projectStore.js";

function createMemoryStorage() {
  const store = new Map();
  return {
    getItem(key) {
      return store.has(key) ? store.get(key) : null;
    },
    setItem(key, value) {
      store.set(key, value);
    },
    removeItem(key) {
      store.delete(key);
    },
  };
}

describe("projectStore", () => {
  it("initializes with a seed project when no projects exist", () => {
    const storage = createMemoryStorage();

    const projects = initializeProjects(storage);

    expect(projects).toHaveLength(1);
    expect(projects[0].name).toContain("VX Engine Harness");
  });

  it("creates and persists a new project", () => {
    const storage = createMemoryStorage();
    const project = createProject("Garage build", undefined, storage);

    const projects = readProjects(storage);

    expect(project.name).toBe("Garage build");
    expect(projects).toHaveLength(1);
    expect(projects[0].id).toBe(project.id);
  });

  it("writes projects as JSON", () => {
    const storage = createMemoryStorage();
    const projects = [{ id: "a", name: "Alpha" }];

    writeProjects(projects, storage);

    expect(readProjects(storage)).toEqual(projects);
  });

  it("normalizes projects into a component list", () => {
    const project = {
      id: "project-1",
      name: "Garage build",
      harness: { meta: { project: "Garage build" }, connectors: [] },
    };

    const components = getProjectComponents(project);

    expect(components).toHaveLength(1);
    expect(components[0].type).toBe("harness");
  });
});
