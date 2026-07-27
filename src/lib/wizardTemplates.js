export const HARNESS_WIZARD_TEMPLATES = {
  simple: {
    meta: {
      project: "New Harness Project",
      vehicle: "Custom harness",
    },
    connectors: [
      {
        id: "CONNECTOR-01",
        name: "Main connector",
        shape: "rectangular-block",
        rows: [
          {
            positions: 2,
            pins: [{ populated: true }, { populated: true }],
          },
        ],
      },
    ],
  },
};

export function buildHarnessProject(name, options = {}) {
  const template = HARNESS_WIZARD_TEMPLATES[options.template || "simple"];
  return {
    id: `project-${Date.now()}`,
    name,
    subtitle: options.vehicleName || template.meta.vehicle,
    count: template.connectors.length,
    harness: {
      meta: {
        project: name,
        vehicle: options.vehicleName || template.meta.vehicle,
      },
      connectors: template.connectors.map((connector) => ({
        ...connector,
        id: options.connectorPrefix ? `${options.connectorPrefix}-01` : connector.id,
        name: connector.name,
      })),
    },
  };
}
