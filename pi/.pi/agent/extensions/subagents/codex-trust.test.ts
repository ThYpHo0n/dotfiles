import assert from "node:assert/strict";
import test from "node:test";
import { Effect } from "effect";
import { codexBackend } from "./src/backends/codex.ts";

test("Codex rejects untrusted projects before resolving or starting the CLI", async () => {
  await assert.rejects(
    Effect.runPromise(
      Effect.scoped(
        codexBackend.spawn({
          prompt: "test",
          title: "untrusted project",
          cwd: process.cwd(),
          parent: { parentCwd: process.cwd(), projectTrusted: false },
        }),
      ),
    ),
    /Codex subagents require a trusted working directory/,
  );
});
