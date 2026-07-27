export function buildConnector(name, options = {}) {
  const prefix = options.prefix || "EH";
  const sequence = options.sequence ?? 1;
  return {
    id: `${prefix}-${String(sequence).padStart(2, "0")}`,
    name,
    shape: options.shape || "rectangular-block",
    rows: options.rows || [],
  };
}

export function insertConnectorIntoHarness(harness, connector, placement = "after", anchorId = null) {
  const connectors = Array.isArray(harness?.connectors) ? harness.connectors.slice() : [];
  const anchorIndex = anchorId ? connectors.findIndex((entry) => entry.id === anchorId) : -1;

  const nextConnectors = [...connectors];
  if (anchorIndex >= 0 && placement === "before") {
    nextConnectors.splice(anchorIndex, 0, connector);
  } else if (anchorIndex >= 0 && placement === "after") {
    nextConnectors.splice(anchorIndex + 1, 0, connector);
  } else {
    nextConnectors.push(connector);
  }

  return {
    ...harness,
    connectors: nextConnectors.map((entry, index) => ({
      ...entry,
      id: entry.id.replace(/\d+$/, String(index + 1).padStart(2, "0")),
    })),
  };
}

export function getEcuTypeById(id) {
  return ECU_TYPES.find((entry) => entry.id === id) || null;
}

export const ECU_TYPES = [
  {
    id: "ecm",
    name: "ECM / ECU",
    description: "Engine control module",
    pins: [
      { name: "Power", color: "Red" },
      { name: "Ground", color: "Black" },
      { name: "CAN High", color: "Green" },
      { name: "CAN Low", color: "White" },
    ],
    plugs: [
      {
        id: "main",
        name: "Main connector",
        pins: [
          { name: "Power", color: "Red" },
          { name: "Ground", color: "Black" },
          { name: "CAN High", color: "Green" },
          { name: "CAN Low", color: "White" },
        ],
      },
    ],
  },
  {
    id: "tcm",
    name: "TCM",
    description: "Transmission control module",
    pins: [
      { name: "Power", color: "Red" },
      { name: "Ground", color: "Black" },
      { name: "Data", color: "Blue" },
    ],
    plugs: [
      {
        id: "main",
        name: "Main connector",
        pins: [
          { name: "Power", color: "Red" },
          { name: "Ground", color: "Black" },
          { name: "Data", color: "Blue" },
        ],
      },
    ],
  },
];
