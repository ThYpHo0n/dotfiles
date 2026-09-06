import assert from "node:assert/strict";
import test from "node:test";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { KeybindingsManager } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { WorkflowDashboard } from "./dashboard.ts";
import { emptyUsage, type Theme, type WorkflowDetails } from "./model.ts";

test("workflow transcript strips terminal controls from content and tool names", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "pi-dashboard-"));
  const previous = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = directory;
  t.after(() => {
    if (previous === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previous;
    rmSync(directory, { recursive: true, force: true });
  });
  mkdirSync(join(directory, "workflows", "wf_fixture"), { recursive: true });
  const details: WorkflowDetails = {
    runId: "wf_fixture",
    background: true,
    status: "completed",
    startedAt: 0,
    phases: [],
    agents: [
      {
        index: 0,
        label: "agent",
        state: "done",
        startedAt: 0,
        preview: "",
        usage: emptyUsage(),
        transcript: [
          {
            role: "toolResult",
            name: "shell\u001b]0;spoofed\u0007",
            text: "before\u001b]52;c;payload\u0007after\n\u001b[31mred\u001b[0m",
          },
        ],
      },
    ],
  };
  const theme = {
    fg: (_color: string, text: string) => text,
    bold: (text: string) => text,
  } as Theme;
  const dashboard = new WorkflowDashboard(
    { requestRender() {}, terminal: { rows: 30 } } as unknown as TUI,
    theme,
    {
      matches: (data: string, key: string) =>
        data === "enter" && key === "tui.select.confirm",
      getKeys: () => [],
    } as unknown as KeybindingsManager,
    () => new Map([[details.runId, details]]),
    "test",
    new Set(),
    () => {},
    details.runId,
  );
  try {
    dashboard.handleInput("l");
    dashboard.handleInput("enter");
    const output = dashboard.render(100).join("\n");
    assert.match(output, /RESULT shell/);
    assert.match(output, /beforeafter/);
    assert.match(output, /red/);
    assert.doesNotMatch(output, /spoofed|payload|[\u001b\u0007]/);
  } finally {
    dashboard.dispose();
  }
});
