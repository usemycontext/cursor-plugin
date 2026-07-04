#!/usr/bin/env node
// UseMyContext Cursor plugin - format validator.
//
// A zero-dependency check that this repository parses to the Cursor plugin
// marketplace format before it is published. It mirrors the checks the Cursor
// team's reviewer runs (manifests parse, names are lowercase kebab-case, the
// marketplace entry maps to a real plugin folder, referenced paths resolve, and
// rule/skill/agent/command files carry their required frontmatter). Run from the
// repository root: `node scripts/validate.mjs`.

import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";

const repoRoot = process.cwd();
const errors = [];

// Plugin names allow alphanumerics, hyphens, and periods; marketplace names
// allow alphanumerics and hyphens. Both must start and end with an alphanumeric.
const pluginNamePattern = /^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$/;
const marketplaceNamePattern = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/;

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function readJson(file, label) {
  let raw;
  try {
    raw = await fs.readFile(file, "utf8");
  } catch {
    errors.push(`${label} is missing: ${file}`);
    return null;
  }
  try {
    return JSON.parse(raw);
  } catch (e) {
    errors.push(`${label} is not valid JSON (${file}): ${e.message}`);
    return null;
  }
}

function isSafeRelativePath(value) {
  if (typeof value !== "string" || value.length === 0) return false;
  if (value.startsWith("http://") || value.startsWith("https://")) return true;
  if (path.isAbsolute(value)) return false;
  const normalized = path.posix.normalize(value.replace(/\\/g, "/"));
  return !normalized.startsWith("../") && normalized !== "..";
}

async function frontmatter(file) {
  const raw = (await fs.readFile(file, "utf8")).replace(/\r\n/g, "\n");
  if (!raw.startsWith("---\n")) return null;
  const end = raw.indexOf("\n---\n", 4);
  if (end === -1) return null;
  const fields = {};
  for (const line of raw.slice(4, end).split("\n")) {
    const i = line.indexOf(":");
    if (i === -1) continue;
    fields[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return fields;
}

async function walk(dir) {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const cur = stack.pop();
    for (const e of await fs.readdir(cur, { withFileTypes: true })) {
      const p = path.join(cur, e.name);
      if (e.isDirectory()) stack.push(p);
      else out.push(p);
    }
  }
  return out;
}

async function requireFrontmatter(file, label, keys, plugin) {
  const fm = await frontmatter(file);
  const rel = path.relative(repoRoot, file);
  if (!fm) {
    errors.push(`${plugin}: ${label} missing YAML frontmatter: ${rel}`);
    return;
  }
  for (const key of keys) {
    if (!fm[key]) errors.push(`${plugin}: ${label} missing "${key}" in frontmatter: ${rel}`);
  }
}

async function validateComponents(pluginDir, plugin) {
  const specs = [
    ["rules", [".md", ".mdc", ".markdown"], "rule", ["description"], null],
    ["skills", null, "skill", ["name", "description"], "SKILL.md"],
    ["agents", [".md", ".mdc", ".markdown"], "agent", ["name", "description"], null],
    ["commands", [".md", ".mdc", ".markdown", ".txt"], "command", ["name", "description"], null],
  ];
  for (const [dirName, exts, label, keys, basename] of specs) {
    const dir = path.join(pluginDir, dirName);
    if (!(await pathExists(dir))) continue;
    for (const file of await walk(dir)) {
      if (basename && path.basename(file) !== basename) continue;
      if (exts && !exts.includes(path.extname(file).toLowerCase())) continue;
      await requireFrontmatter(file, label, keys, plugin);
    }
  }
}

function referencedPaths(value) {
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) return value.flatMap(referencedPaths);
  if (value && typeof value === "object") {
    const out = [];
    if (typeof value.path === "string") out.push(value.path);
    if (typeof value.file === "string") out.push(value.file);
    return out;
  }
  return [];
}

async function main() {
  const marketplacePath = path.join(repoRoot, ".cursor-plugin", "marketplace.json");
  const marketplace = await readJson(marketplacePath, "Marketplace manifest");
  if (!marketplace) return finish();

  if (typeof marketplace.name !== "string" || !marketplaceNamePattern.test(marketplace.name)) {
    errors.push('Marketplace "name" must be lowercase kebab-case.');
  }
  if (!marketplace.owner || typeof marketplace.owner.name !== "string" || !marketplace.owner.name) {
    errors.push('Marketplace "owner.name" is required.');
  }
  if (!Array.isArray(marketplace.plugins) || marketplace.plugins.length === 0) {
    errors.push('Marketplace "plugins" must be a non-empty array.');
    return finish();
  }

  const seen = new Set();
  for (const [i, entry] of marketplace.plugins.entries()) {
    const label = `plugins[${i}]`;
    if (!entry || typeof entry !== "object") {
      errors.push(`${label} must be an object.`);
      continue;
    }
    if (typeof entry.name !== "string" || !pluginNamePattern.test(entry.name)) {
      errors.push(`${label}.name must be lowercase kebab-case.`);
      continue;
    }
    if (seen.has(entry.name)) errors.push(`Duplicate plugin name: "${entry.name}"`);
    seen.add(entry.name);

    if (!isSafeRelativePath(entry.source)) {
      errors.push(`${label}.source is not a safe relative path: "${entry.source}"`);
      continue;
    }
    const pluginDir = path.join(repoRoot, entry.source);
    if (!(await pathExists(pluginDir))) {
      errors.push(`${label}.source references a missing folder: "${entry.source}"`);
      continue;
    }

    const manifest = await readJson(
      path.join(pluginDir, ".cursor-plugin", "plugin.json"),
      `${entry.name} plugin manifest`
    );
    if (!manifest) continue;

    if (typeof manifest.name !== "string" || !pluginNamePattern.test(manifest.name)) {
      errors.push(`${entry.name}: plugin.json "name" must be lowercase kebab-case.`);
    }
    if (manifest.name && manifest.name !== entry.name) {
      errors.push(`${entry.name}: marketplace entry name does not match plugin.json name ("${manifest.name}").`);
    }

    for (const field of ["logo", "rules", "skills", "agents", "commands", "hooks", "mcpServers"]) {
      for (const value of referencedPaths(manifest[field])) {
        if (value.startsWith("http://") || value.startsWith("https://")) continue;
        if (!isSafeRelativePath(value)) {
          errors.push(`${entry.name}: field "${field}" has an invalid path "${value}".`);
          continue;
        }
        if (!(await pathExists(path.resolve(pluginDir, value)))) {
          errors.push(`${entry.name}: field "${field}" references a missing path "${value}".`);
        }
      }
    }

    await validateComponents(pluginDir, entry.name);
  }

  finish();
}

function finish() {
  if (errors.length > 0) {
    console.error("Validation failed:");
    for (const e of errors) console.error(`- ${e}`);
    process.exit(1);
  }
  console.log("Validation passed.");
}

await main();
