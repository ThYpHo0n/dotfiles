import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  createEventBus,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type RegisteredCommand,
} from "@earendil-works/pi-coding-agent";
import gitInfo from "./index.ts";
import {
  GIT_INFO_CHANNEL,
  type GitInfoState,
} from "../shared/dashboard-state.ts";

for (const initial of ["failure", "empty", "invalid"]) {
  test(`PR lookup retries ${initial} results only when inconclusive`, async (t) => {
    const directory = mkdtempSync(join(tmpdir(), "pi-git-info-"));
    const originalPath = process.env.PATH;
    t.after(() => {
      process.env.PATH = originalPath;
      rmSync(directory, { recursive: true, force: true });
    });
    execFileSync("git", ["init", "-b", "fixture", directory], {
      stdio: "ignore",
    });
    const calls = join(directory, "calls.json");
    writeFileSync(
      join(directory, "gh"),
      `#!${process.execPath}
const fs = require("node:fs");
const file = ${JSON.stringify(calls)};
const calls = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : [];
calls.push(process.argv.slice(2));
fs.writeFileSync(file, JSON.stringify(calls));
if (calls.length === 1) {
  if (${JSON.stringify(initial)} === "failure") process.exit(1);
  console.log(${JSON.stringify(initial === "empty" ? "[]" : "malformed JSON")});
} else {
  console.log(JSON.stringify([{ number: 19, url: "https://example.test/pr/19", state: "OPEN", isDraft: false }]));
}
`,
      { mode: 0o755 },
    );
    process.env.PATH = `${directory}:${originalPath}`;
    const handlers = new Map<
      string,
      (event: unknown, ctx: ExtensionCommandContext) => unknown
    >();
    const commands = new Map<string, RegisteredCommand>();
    const events = createEventBus();
    let state: GitInfoState | undefined;
    events.on(GIT_INFO_CHANNEL, (value) => {
      state = value as GitInfoState;
    });
    gitInfo({
      events,
      on: (
        name: string,
        handler: (event: unknown, ctx: ExtensionCommandContext) => unknown,
      ) => handlers.set(name, handler),
      registerCommand: (name: string, command: RegisteredCommand) =>
        commands.set(name, command),
    } as unknown as ExtensionAPI);
    const ctx = {
      cwd: directory,
      ui: { notify() {} },
    } as unknown as ExtensionCommandContext;
    t.after(async () => {
      await handlers.get("session_shutdown")?.({}, ctx);
    });
    const refresh = commands.get("pr")!;
    await refresh.handler("", ctx);
    handlers.get("input")!({}, ctx);
    // A forced refresh waits for the normal input refresh to finish.
    await refresh.handler("", ctx);
    const invocations: string[][] = JSON.parse(readFileSync(calls, "utf8"));
    assert.equal(invocations.length, initial === "empty" ? 2 : 3);
    assert.deepEqual(invocations[0], [
      "pr",
      "list",
      "--head",
      "fixture",
      "--state",
      "open",
      "--json",
      "number,url,state,isDraft",
    ]);
    assert.equal(state?.pullRequest?.number, 19);
  });
}
