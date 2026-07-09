import { expect, test } from "bun:test";
import { promptMentionMarkdown, promptTextWithAutoContext } from "./promptMentions";

test("prompt mention serialization matches Codex markdown links", () => {
  expect(promptMentionMarkdown({
    kind: "at",
    label: "coterm",
    name: "coterm",
    path: "/Users/lawrence/fun/coterm-hq",
  })).toBe("[coterm](/Users/lawrence/fun/coterm-hq)");

  expect(promptMentionMarkdown({
    displayName: "Codex",
    kind: "agent",
    name: "codex",
    path: "provider://codex",
  })).toBe("[@Codex](provider://codex)");

  expect(promptMentionMarkdown({
    kind: "skill",
    name: "codex-review",
    path: "skill://codex-review",
  })).toBe("[$codex-review](skill://codex-review)");
});

test("prompt mention serialization escapes markdown labels and destinations", () => {
  expect(promptMentionMarkdown({
    kind: "at",
    label: "work [tree]",
    name: "work [tree]",
    path: "/tmp/work tree/(current)",
  })).toBe("[work \\[tree\\]](/tmp/work%20tree/\\(current\\))");
});

test("auto context prepends the workspace mention only when enabled and absent", () => {
  const mention = {
    kind: "at" as const,
    label: "coterm",
    name: "coterm",
    path: "/Users/lawrence/fun/coterm-hq",
  };

  expect(promptTextWithAutoContext("fix ui", mention, true))
    .toBe("[coterm](/Users/lawrence/fun/coterm-hq)\n\nfix ui");
  expect(promptTextWithAutoContext("fix ui", mention, false)).toBe("fix ui");
  expect(promptTextWithAutoContext("[coterm](/Users/lawrence/fun/coterm-hq)\n\nfix ui", mention, true))
    .toBe("[coterm](/Users/lawrence/fun/coterm-hq)\n\nfix ui");
});
