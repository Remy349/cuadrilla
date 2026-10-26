// Validate the generated V2 agent frontmatter against OpenCode's official V2 schema
// (the `@opencode/schema` npm package, the same definitions OpenCode 2.x decodes with).
//
//   npm install --prefix <dir> @opencode/schema@<version>
//   python3 scripts/build.py --json | OPENCODE_SCHEMA_DIR=<dir> node scripts/check-v2-schema.mjs
//
// Fails on fields V2 does not know (they would be ignored with only a log line), on invalid
// values, and on permission rules that aren't {action, resource, effect}.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const dir = process.env.OPENCODE_SCHEMA_DIR;
if (!dir) {
  console.error("Set OPENCODE_SCHEMA_DIR to the folder where @opencode/schema is installed");
  process.exit(2);
}
const load = (path) => import(pathToFileURL(join(dir, "node_modules", path)).href);
const { Schema } = await load("effect/dist/index.js");
const { ConfigAgent } = await load("@opencode/schema/dist/config/agent.js");
const { version } = JSON.parse(readFileSync(join(dir, "node_modules/@opencode/schema/package.json"), "utf8"));

const agents = JSON.parse(readFileSync(0, "utf8"));
const decode = Schema.decodeUnknownSync(ConfigAgent.Info, { errors: "all", onExcessProperty: "error" });

let failures = 0;
for (const [name, frontmatter] of Object.entries(agents)) {
  try {
    decode(frontmatter);
    console.log(`ok - ${name}`);
  } catch (error) {
    failures++;
    console.error(`FAIL - ${name}\n${error.message}\n`);
  }
}
console.log(`\n${Object.keys(agents).length} agents checked against @opencode/schema ${version}: ${failures} failed`);
process.exit(failures ? 1 : 0);
