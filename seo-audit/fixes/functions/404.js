/**
 * Cloudflare Pages Function — make /404 return a real HTTP 404  (audit item P1-2)
 *
 * File location:  functions/404.js   (at the PROJECT ROOT, next to your build output
 *                                     dir — not inside it)
 * Route handled:  /404   only
 *
 * ---------------------------------------------------------------------------
 * Why a Function is required here
 * ---------------------------------------------------------------------------
 * The _redirects file cannot do this. Cloudflare Pages only supports 301, 302, 303,
 * 307 and 308 in _redirects. A line like `/404 /404 404` is silently ignored — no
 * warning, no error, it just does nothing. Status codes outside 3xx require a
 * Function.
 *
 * ---------------------------------------------------------------------------
 * IMPORTANT — do NOT make this a catch-all
 * ---------------------------------------------------------------------------
 * From Cloudflare's docs: "Redirects defined in the _redirects file are not applied
 * to requests served by Pages Functions, even if the Function route matches the URL
 * pattern."
 *
 * So if you write this as functions/[[path]].js, it intercepts EVERY request and your
 * entire _redirects file stops working — the www redirect, the .html redirects, all
 * of it. Keeping the file at functions/404.js scopes it to the single /404 route and
 * leaves _redirects handling everything else.
 *
 * ---------------------------------------------------------------------------
 * What this does
 * ---------------------------------------------------------------------------
 * Serves the exact same 404.html body you already have, with a 404 status instead of
 * 200. Your custom error page is already wired up correctly — unknown URLs like
 * /nope-xyz already return a genuine 404 with this page. The only defect is that the
 * template is ALSO reachable at /404 with a 200, which Google classifies as a soft
 * 404. This closes that.
 *
 * After deploying, you can remove these two lines from robots.txt:
 *     Disallow: /404
 *     Disallow: /404.html
 * They become unnecessary, and they are actively counterproductive — a Disallow stops
 * Googlebot fetching the URL, so it can never observe the 404 status that tells it to
 * drop the URL.
 *
 * Note on /404.html: Pages automatically 308-redirects it to /404, which then returns
 * 404. A 308 that lands on a 404 is fine and needs no further handling.
 */

export async function onRequest(context) {
  // Fetch the static 404.html asset without re-entering this Function.
  const url = new URL(context.request.url);
  const assetUrl = new URL("/404.html", url.origin);

  let body;
  try {
    const res = await context.env.ASSETS.fetch(new Request(assetUrl, { method: "GET" }));
    body = await res.text();
  } catch {
    body = "<!doctype html><meta charset=utf-8><title>Page Not Found</title><h1>404 — Page Not Found</h1>";
  }

  return new Response(body, {
    status: 404,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "x-robots-tag": "noindex",
    },
  });
}
