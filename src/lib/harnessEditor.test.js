import { describe, expect, it } from "vitest";
import { buildConnector, insertConnectorIntoHarness, getEcuTypeById } from "./harnessEditor.js";

describe("harnessEditor", () => {
  it("inserts a connector before an anchor and renumbers the order", () => {
    const harness = {
      meta: { project: "Test" },
      connectors: [
        { id: "EH-01", name: "First", shape: "rectangular-block", rows: [] },
        { id: "EH-02", name: "Second", shape: "rectangular-block", rows: [] },
      ],
    };

    const nextHarness = insertConnectorIntoHarness(harness, buildConnector("New plug", { prefix: "EH" }), "before", "EH-02");

    expect(nextHarness.connectors.map((connector) => connector.name)).toEqual(["First", "New plug", "Second"]);
    expect(nextHarness.connectors[1].id).toBe("EH-02");
  });

  it("returns ECU type details for a known catalog item", () => {
    const ecuType = getEcuTypeById("ecm");

    expect(ecuType?.name).toBe("ECM / ECU");
    expect(ecuType?.pins.length).toBeGreaterThan(0);
  });
});
