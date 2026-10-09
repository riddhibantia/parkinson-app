import { describe, expect, it } from "vitest";
import fs from "fs";
import path from "path";

/** Static guards: forbidden legacy patterns must not exist in the new app. */
const SRC = path.resolve(__dirname, "../src");
const walk = (dir: string): string[] =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? walk(p) : [p];
  });

const allFiles = () => walk(SRC).filter((f) => /\.(ts|tsx)$/.test(f));
/** Code under test, with comments stripped: prose may NAME a forbidden
 *  pattern to document its absence, but code must not USE it. */
const codeOf = (f: string) =>
  fs
    .readFileSync(f, "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .split("\n")
    .map((line) => line.replace(/\/\/.*$/, ""));
const grep = (re: RegExp) =>
  allFiles().flatMap((f) =>
    codeOf(f).map((line, i) => ({ f, line, i })).filter((x) => re.test(x.line)),
  );

describe("no legacy violations in new frontend", () => {
  it("no forbidden timing sources", () => {
    const hits = grep(/Date\.now\(\)|new Date\(\)\.getTime\(\)/);
    expect(hits).toEqual([]);
  });
  it("no synthetic chart data", () => {
    const hits = grep(/fallbackBase|synthetic|illustrative preview|visual diagram/);
    expect(hits).toEqual([]);
  });
  it("no wrong-session fallback", () => {
    const hits = grep(/firstOrNull|effectiveSessions\.first|\?\? sessions\[0\]/);
    expect(hits).toEqual([]);
  });
  it("no hardcoded research references", () => {
    const hits = grep(/108\.0|85\.0.*ref|210\.0.*ref/);
    expect(hits).toEqual([]);
  });
  it("no diagnostic language", () => {
    const hits = grep(/Parkinson's detected|You have Parkinson|Parkinson's probability|Diagnosis confirmed|diagnostic result/i);
    expect(hits).toEqual([]);
  });
  it("no practice-session machinery (identifiers, not prose)", () => {
    const hits = grep(/familiarization|requiredPractice|screening.?ready|practiceSession|practice_session/i);
    expect(hits).toEqual([]);
  });
  it("no Flutter imports", () => {
    const hits = grep(/flutter|riverpod|go_router|fl_chart/i);
    expect(hits).toEqual([]);
  });
  it("no blended score", () => {
    const hits = grep(/combined[_ ]score|blended|parkinson.*risk.*score/i);
    expect(hits).toEqual([]);
  });
  it("no raw content persistence", () => {
    const hits = grep(/typedText|typed_content|keystrokes\.push\(e\.key\)/);
    expect(hits).toEqual([]);
  });
});
