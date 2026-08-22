#!/usr/bin/env bash
# Re-runs every check from SEO-AUDIT.md against the live site.
# Run before and after deploying the fixes to confirm each issue is resolved.
#
#   ./verify.sh
#
# Requires: curl, python3, dig
#
# Note: checks use `grep -q <<< "$var"` rather than `echo "$var" | grep -q`.
# grep -q exits on first match, which SIGPIPEs the writer; under `set -o pipefail`
# that turns a successful match into a non-zero pipeline status.

set -uo pipefail
SITE="https://core-asset-sol.com"
UA="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
PASS=0
FAIL=0

ok()    { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()   { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

code()     { curl -sS  -o /dev/null -w '%{http_code}' -A "$UA" --max-time 20 "$1"; }
code_l()   { curl -sSL -o /dev/null -w '%{http_code}' -A "$UA" --max-time 20 "$1"; }
body()     { curl -sSL -A "$UA" --max-time 25 "$1"; }
canon()    { grep -oiE '<link[^>]*rel="canonical"[^>]*>|<link[^>]*canonical[^>]*>' <<< "$1" \
             | head -1 | grep -oiE 'href="[^"]+"' | head -1 | cut -d'"' -f2; }

head_ "P0-1  Homepage business entity is a valid schema.org type"
HOME=$(body "$SITE/")
if grep -q '"@type": *"Recycling Center"' <<< "$HOME"; then
  bad 'homepage still declares "Recycling Center" - schema.org type names cannot contain spaces, so Google discards the whole entity'
elif grep -q '"@type": *"RecyclingCenter"' <<< "$HOME"; then
  ok "homepage declares RecyclingCenter (valid)"
else
  bad "no RecyclingCenter entity found on the homepage"
fi

head_ "P0-2  Every JSON-LD block on the site parses as valid JSON"
JSONLD_OUT=$(body "$SITE/specialty-equipment-we-handle" | python3 -c '
import sys, re, json
html = sys.stdin.read()
blocks = re.findall(r"<script[^>]+application/ld\+json[^>]*>(.*?)</script>", html, re.S | re.I)
errs = []
for i, b in enumerate(blocks, 1):
    try:
        json.loads(b)
    except Exception as e:
        errs.append(f"block #{i}: {e}")
print(len(blocks))
print("\n".join(errs))
')
NBLOCKS=$(head -1 <<< "$JSONLD_OUT")
ERRS=$(tail -n +2 <<< "$JSONLD_OUT" | sed '/^$/d')
if [ -z "$ERRS" ]; then
  ok "all $NBLOCKS JSON-LD blocks on /specialty-equipment-we-handle parse"
else
  while IFS= read -r e; do bad "/specialty-equipment-we-handle JSON-LD $e"; done <<< "$ERRS"
fi

head_ "P0-3  Sitemap contains no redirecting or non-200 URLs"
mapfile -t SMU < <(body "$SITE/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+')
echo "  sitemap declares ${#SMU[@]} URLs"
smbad=0
for u in "${SMU[@]}"; do
  c=$(code "$u")
  if [ "$c" != "200" ]; then bad "sitemap URL returns $c: $u"; smbad=1; fi
done
[ "$smbad" -eq 0 ] && ok "every sitemap URL returns 200 directly (no redirects)"

head_ "P0-4  www resolves, 301s to the apex, preserves the path, and lands on a 200"
if [ -z "$(dig +short www.core-asset-sol.com)" ]; then
  bad "www.core-asset-sol.com has NO DNS record - it does not resolve at all"
else
  ok "www.core-asset-sol.com resolves"
  # A 301 alone proves nothing. Check the target is right and actually loads - a rule
  # that emits a literal ':splat' placeholder returns a perfectly valid 301 to a 404.
  for p in / /contact /services/itad; do
    wcode=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "https://www.core-asset-sol.com$p")
    wloc=$(curl -sS -o /dev/null -w '%{redirect_url}' --max-time 20 "https://www.core-asset-sol.com$p")
    want="https://core-asset-sol.com$p"
    if [ "$wcode" != "301" ]; then
      bad "www$p returned $wcode (expected 301)"
    elif [[ "$wloc" == *":splat"* || "$wloc" == *":path"* || "$wloc" == *"*"* ]]; then
      bad "www$p 301s to an UNINTERPOLATED PLACEHOLDER: $wloc"
    elif [ "$wloc" != "$want" ]; then
      bad "www$p 301s to $wloc (expected $want) - path not preserved"
    else
      final=$(curl -sSL -o /dev/null -w '%{http_code}' --max-time 20 "https://www.core-asset-sol.com$p")
      if [ "$final" = "200" ]; then ok "www$p -> 301 -> $wloc -> 200"
      else bad "www$p 301s correctly but the destination returns $final"; fi
    fi
  done
  hcode=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "http://www.core-asset-sol.com/")
  if [ "$hcode" = "301" ]; then ok "http://www 301s"; else bad "http://www returns $hcode (expected 301)"; fi
fi

head_ "P1-1  Query-string URLs are 200+canonical or 301, never 302"
# Test a spread of parameter names. The original audit generalised from a single
# ?ref= probe; in fact only specific parameter names trigger a redirect, so name them.
qbad=0
for q in "ref=x" "utm_source=g" "utm_source=g&utm_medium=cpc" "gclid=abc" "fbclid=xyz" \
         "msclkid=q" "page=2" "id=1" "a=1&b=2"; do
  qc=$(code "$SITE/services?$q")
  case "$qc" in
    200|301) ;;
    302) bad "?$q returns 302 temporary - should be 200+canonical or 301"; qbad=1 ;;
    *)   bad "?$q returns $qc"; qbad=1 ;;
  esac
done
[ "$qbad" -eq 0 ] && ok "all tested query-string forms return 200 or 301 (no 302s)"

head_ "P1-2  The 404 template does not return HTTP 200"
c=$(code "$SITE/404")
if [ "$c" = "200" ]; then bad "/404 returns 200 (soft 404)"; else ok "/404 returns $c"; fi
c=$(code "$SITE/this-page-really-does-not-exist-98765")
if [ "$c" = "404" ]; then ok "unknown URLs correctly return 404"; else bad "unknown URL returned $c, expected 404"; fi

head_ "P1-3  Previously-404ing PDF now resolves"
c=$(code_l "$SITE/resources/Certificate-Of-Destruction.pdf")
if [ "$c" = "200" ]; then ok "Certificate-Of-Destruction.pdf resolves"; else bad "Certificate-Of-Destruction.pdf returns $c"; fi

head_ "P1-4  Navigation partials are not indexable"
for p in /partials/header /partials/footer; do
  xr=$(curl -sSI -A "$UA" --max-time 20 "$SITE$p" | tr -d '\r' | grep -i '^x-robots-tag' || true)
  if grep -qi noindex <<< "$xr"; then ok "$p sends X-Robots-Tag noindex"; else bad "$p has no noindex X-Robots-Tag"; fi
done
ROBOTS=$(body "$SITE/robots.txt")
if grep -qE 'Disallow: */partials/' <<< "$ROBOTS"; then
  ok "robots.txt disallows /partials/"
else
  bad "robots.txt does not disallow /partials/"
fi

head_ "P1-6  Previously-orphaned pages are in the sitemap"
SMLIST=$(printf '%s\n' "${SMU[@]}")
for p in /privacy /terms /sitemap; do
  if grep -qx "$SITE$p" <<< "$SMLIST"; then ok "$p is in the sitemap"; else bad "$p is missing from the sitemap"; fi
done

head_ "P1-7  Sitemap carries lastmod"
SM=$(body "$SITE/sitemap.xml")
if grep -q '<lastmod>' <<< "$SM"; then ok "sitemap has <lastmod>"; else bad "sitemap has no <lastmod> on any URL"; fi

head_ "P2-1  Header and footer are in the server-rendered HTML"
if grep -q 'id="header-placeholder"' <<< "$HOME"; then
  bad "header is injected client-side - Googlebot's first pass sees zero nav links"
else
  ok "no header placeholder - header appears to be server-rendered"
fi
if grep -q 'id="footer-placeholder"' <<< "$HOME"; then
  bad "footer is injected client-side - Googlebot's first pass sees zero footer links"
else
  ok "no footer placeholder - footer appears to be server-rendered"
fi

head_ "P2-2  sameAs lists all four live social profiles"
for s in linkedin.com/company/coreassetsolutions facebook.com/CoreAssetSolutions instagram.com/coreassetsolutions x.com/coreassetsol; do
  if grep -q "$s" <<< "$HOME"; then ok "sameAs includes $s"; else bad "sameAs is missing $s"; fi
done

head_ "P2-3  NAP is consistent between the homepage and the contact page"
a1=$(grep -oP '(?<="streetAddress": ")[^"]+' <<< "$HOME" | head -1)
a2=$(body "$SITE/contact" | grep -oP '(?<="streetAddress": ")[^"]+' | head -1)
if [ "$a1" = "$a2" ]; then ok "streetAddress matches: $a1"; else bad "streetAddress differs - home='$a1' contact='$a2'"; fi

head_ "Canonical integrity across every sitemap URL"
cbad=0
for u in "${SMU[@]}"; do
  can=$(canon "$(body "$u")")
  if [ "$can" != "$u" ]; then bad "canonical mismatch on $u -> ${can:-<none>}"; cbad=1; fi
done
[ "$cbad" -eq 0 ] && ok "all ${#SMU[@]} sitemap URLs self-canonicalise correctly"

head_ "Internal links never point at redirects or 404s"
LINKCHK=$(python3 - "$SITE" <<'PY'
import sys, re, urllib.request, urllib.error
from urllib.parse import urljoin
site = sys.argv[1]
req = lambda u: urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0 (compatible; Googlebot/2.1)"})
sm = urllib.request.urlopen(req(site + "/sitemap.xml"), timeout=25).read().decode()
urls = re.findall(r"<loc>([^<]+)</loc>", sm)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


opener = urllib.request.build_opener(NoRedirect)
cache, bad = {}, []
for u in urls:
    try:
        html = urllib.request.urlopen(req(u), timeout=25).read().decode("utf-8", "ignore")
    except Exception:
        continue
    for href in set(re.findall(r'href="(/[^"#]*)"', html)):
        t = urljoin(site, href)
        if t not in cache:
            try:
                cache[t] = opener.open(req(t), timeout=20).status
            except urllib.error.HTTPError as e:
                cache[t] = e.code
            except Exception:
                cache[t] = 0
        if cache[t] in (301, 302, 307, 308, 404, 410):
            bad.append((cache[t], t, u))
for c, t, src in sorted(set(bad)):
    print(f"[{c}] {t}  linked from {src}")
PY
)
if [ -z "$LINKCHK" ]; then
  ok "no internal link points at a redirect or error"
else
  while IFS= read -r l; do bad "$l"; done <<< "$LINKCHK"
fi

printf '\n\033[1mSUMMARY\033[0m  %d passed, %d failed\n\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
