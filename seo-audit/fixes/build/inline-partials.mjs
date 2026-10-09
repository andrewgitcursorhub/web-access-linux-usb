#!/usr/bin/env node
/**
 * Build-time header/footer inlining for core-asset-sol.com  (audit item P2-1)
 *
 * Fills
 *     <div id="header-placeholder"></div>
 *     <div id="footer-placeholder"></div>
 * with the real contents of partials/header.html and partials/footer.html, so the
 * navigation ships in the served HTML instead of being fetched by app.js at runtime.
 *
 * Why this approach: the site is hand-authored static HTML on Cloudflare Pages. This
 * keeps that authoring workflow exactly as it is (one header, one footer, edited in
 * one place) while removing the render dependency. No framework migration, no runtime
 * cost, no Pages Function.
 *
 * IMPORTANT - the wrapper divs are kept, and filled, rather than replaced.
 * assets/app.js depends on both of them:
 *   - loadPartial() looks up document.getElementById('header-placeholder'). If the
 *     element is gone it returns early and initHeaderChrome() never runs, which
 *     breaks the mobile menu button.
 *   - adjustFooter() selects '#footer-placeholder .site-footer'. If the wrapper is
 *     gone the footer spacing logic silently stops working.
 * Keeping the wrapper preserves both. See build/app.js.patch.md for the small
 * companion change to app.js that stops it re-fetching what is already inlined.
 *
 * Usage
 *     node build/inline-partials.mjs [--src .] [--out dist]
 *     node build/inline-partials.mjs --src dist --check
 *
 *     --check   verify only; exits non-zero if any page still has an EMPTY
 *               placeholder. Run against the build output in CI to stop a
 *               regression from shipping.
 *
 * Cloudflare Pages settings
 *     Build command:      node build/inline-partials.mjs --src . --out dist
 *     Build output dir:   dist
 */

import { readFile, writeFile, mkdir, readdir, copyFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const argVal = (name, fallback) => {
  const i = args.indexOf(name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
};
const SRC = path.resolve(argVal("--src", "."));
const OUT = path.resolve(argVal("--out", "dist"));
const CHECK_ONLY = args.includes("--check");

// Matches the placeholder div and captures its inner content so we can tell an
// empty placeholder (needs filling) from one that is already populated.
const placeholderRe = (id) =>
  new RegExp(`(<div\\s+id=["']${id}["'][^>]*>)([\\s\\S]*?)(</div>)`, "i");

const HEADER_RE = placeholderRe("header-placeholder");
const FOOTER_RE = placeholderRe("footer-placeholder");

const SKIP_DIRS = new Set(["node_modules", ".git", ".github", "dist", "build", "partials"]);

const red = (s) => `\x1b[31m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;
const yellow = (s) => `\x1b[33m${s}\x1b[0m`;

async function walk(dir, base = dir, acc = []) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".") && entry.name !== ".well-known") continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      await walk(full, base, acc);
    } else {
      acc.push(path.relative(base, full));
    }
  }
  return acc;
}

/**
 * Mark the current page in the nav. Renders as the active state and lets CSS drop
 * the self-link, which is a wasted internal link that Google ignores anyway.
 */
function markActive(html, pageUrlPath) {
  return html.replace(/<a([^>]*?)href="([^"]+)"([^>]*)>/gi, (match, pre, href, post) => {
    if (href !== pageUrlPath) return match;
    if (/aria-current=/i.test(match)) return match;
    return `<a${pre}href="${href}"${post} aria-current="page">`;
  });
}

/** Map a source file path to the URL path Cloudflare Pages serves it at. */
function urlPathFor(relPath) {
  let p = "/" + relPath.split(path.sep).join("/");
  if (p.endsWith("/index.html")) p = p.slice(0, -"index.html".length);
  else if (p.endsWith(".html")) p = p.slice(0, -".html".length);
  if (p.length > 1 && p.endsWith("/")) p = p.slice(0, -1);
  return p === "" ? "/" : p;
}

function fill(html, re, partial, urlPath, label, rel, problems) {
  const m = html.match(re);
  if (!m) {
    problems.push(`${rel}: no ${label} found`);
    return { html, filled: false };
  }
  if (m[2].trim().length > 0) {
    // Already populated. Re-running the build is a no-op, which keeps it idempotent.
    return { html, filled: false, already: true };
  }
  const replacement = `${m[1]}\n${markActive(partial, urlPath)}\n${m[3]}`;
  return { html: html.replace(re, () => replacement), filled: true };
}

async function main() {
  if (CHECK_ONLY) {
    const files = (await walk(SRC)).filter((f) => f.endsWith(".html"));
    const problems = [];
    for (const rel of files) {
      const html = await readFile(path.join(SRC, rel), "utf8");
      for (const [re, label] of [[HEADER_RE, "header"], [FOOTER_RE, "footer"]]) {
        const m = html.match(re);
        if (m && m[2].trim().length === 0) {
          problems.push(`${rel}: ${label}-placeholder is still EMPTY`);
        }
      }
    }
    if (problems.length) {
      console.error(red(`FAIL: ${problems.length} empty placeholder(s) found`));
      problems.forEach((p) => console.error("   " + p));
      process.exit(1);
    }
    console.log(green(`OK: no empty placeholders across ${files.length} HTML files`));
    return;
  }

  const headerPath = path.join(SRC, "partials", "header.html");
  const footerPath = path.join(SRC, "partials", "footer.html");
  for (const p of [headerPath, footerPath]) {
    if (!existsSync(p)) {
      console.error(red(`FATAL: missing partial ${path.relative(SRC, p)}`));
      process.exit(1);
    }
  }

  const header = (await readFile(headerPath, "utf8")).trim();
  const footer = (await readFile(footerPath, "utf8")).trim();

  const files = await walk(SRC);
  const htmlFiles = files.filter((f) => f.endsWith(".html"));
  const problems = [];
  let injected = 0;

  await mkdir(OUT, { recursive: true });

  for (const rel of files) {
    const srcFile = path.join(SRC, rel);
    const outFile = path.join(OUT, rel);
    await mkdir(path.dirname(outFile), { recursive: true });

    if (!rel.endsWith(".html")) {
      await copyFile(srcFile, outFile);
      continue;
    }

    let html = await readFile(srcFile, "utf8");
    const urlPath = urlPathFor(rel);

    const h = fill(html, HEADER_RE, header, urlPath, "header-placeholder", rel, problems);
    html = h.html;
    const f = fill(html, FOOTER_RE, footer, urlPath, "footer-placeholder", rel, problems);
    html = f.html;

    if (h.filled || f.filled) injected++;
    await writeFile(outFile, html, "utf8");
  }

  console.log(`Source        ${SRC}`);
  console.log(`Output        ${OUT}`);
  console.log(`HTML files    ${htmlFiles.length}`);
  console.log(`Injected into ${injected}`);
  console.log(`header.html   ${header.length} bytes`);
  console.log(`footer.html   ${footer.length} bytes`);

  if (problems.length) {
    console.log(yellow(`\n${problems.length} warning(s):`));
    problems.forEach((p) => console.log("   " + p));
    console.log(yellow("A page with no placeholder is usually intentional. Flip this to"));
    console.log(yellow("process.exit(1) if you want every page to be required to have one."));
  }
  console.log(green("\nBuild complete."));
}

main().catch((e) => {
  console.error(red("FATAL: " + e.stack));
  process.exit(1);
});
