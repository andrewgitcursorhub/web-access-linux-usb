# Standard Operating Procedure — SAS Self-Encrypting Drive (SED) Media Sanitization

**Document:** SOP-SED-SANITIZE
**Revision:** 1.0
**Applies to:** TCG Enterprise SSC SAS self-encrypting hard disk drives (e.g., Seagate Cheetah 15K.7 `ST3600957SS`, Savvio/Enterprise `ST600MM0069`) attached to a Dell PERC HBA330 in HBA/IT (passthrough) mode.
**Boot environment:** Ubuntu 24.04 LTS live USB with Seagate `sed_cli` / `TCGstorageAPI`, `openSeaChest`, `sg3_utils`, `lsscsi`, `python3`.
**Standards:** IEEE 2883-2022 (Purge); NIST SP 800-88 Rev. 1 (Purge, Cryptographic Erase).

> ⚠️ **Every command in this SOP permanently destroys data. There is no undo. Always confirm the target drive by serial number before executing any erase.**

---

## 1. Purpose

Provide a repeatable, auditable procedure to cryptographically **Purge** SAS SEDs and to produce documented verification evidence acceptable for a paid, third-party media-sanitization engagement.

## 2. Scope & method summary

| Drive state | Sanitization method | TCG operation | Standard |
|---|---|---|---|
| Unowned + unlocked, SANITIZE **not** supported | `sed_cli` band erase via **EraseMaster** | `Erase` method on each locking range (Band 0 = global) | IEEE 2883-2022 Purge / NIST 800-88 Purge |
| Owned or **locked** | `sed_cli` **PSID revert** | `RevertSP` (AdminSP) authenticated as PSID | IEEE 2883-2022 Purge / NIST 800-88 Purge |
| SANITIZE crypto erase supported | `openSeaChest_Erase --sanitize cryptoerase` | SCSI SANITIZE (crypto) | IEEE 2883-2022 Purge / NIST 800-88 Purge |

All three regenerate the drive's Media Encryption Key (MEK), rendering prior data cryptographically unrecoverable.

## 3. Prerequisites

1. Boot the target server from the Ubuntu 24.04 live USB; obtain a root shell (`sudo -i`).
2. Confirm the HBA is in passthrough/IT mode so each drive enumerates individually.
3. **Start a session transcript** so every command, timestamp, and hash is captured verbatim:
   ```bash
   mkdir -p /root/sanitize-logs
   script -a /root/sanitize-logs/session-$(date +%Y%m%dT%H%M%S).log
   ```
4. Record operator name and date/time for the engagement record.

## 4. Key environment facts (read before starting)

- **`sed_cli` runs inside a chroot.** The launcher `/usr/local/bin/sed_cli` → `/usr/local/libexec/cas-tcgstorageapi-run` → `chroot` into:
  ```
  RUNTIME=/opt/cas-vendor-packages/seagate/tcgstorageapi/runtime-rootfs
  ```
  The tool's working directory inside the chroot is `/`, so the JSON key-manager file must be placed at **`$RUNTIME/<WWN>.json`**.
- **Always pass `--keymanager=json`.** The default is `vault`; without a configured Vault server it fails with `requests.exceptions.MissingSchema: Invalid URL 'v1/sys/capabilities'`.
- **`/dev/sgX` is a SCSI-generic (passthrough) node, not a block device.** `sed_cli` and `openSeaChest` use it, but a plain `dd` **read** on it hangs. For reads use `sg_dd if=/dev/sgX ...` **or** the block node `/dev/sdX`.
- **Device node numbers renumber across reboots/rescans.** Re-verify the serial before every operation.
- **Never `cat`/`dd` raw binary to the terminal** (it injects control codes and corrupts your log). Pipe reads through `xxd`, `sha256sum`, `strings`, etc. If the terminal garbles, run `reset`.

Set the runtime path variable for this session:
```bash
RUNTIME=/opt/cas-vendor-packages/seagate/tcgstorageapi/runtime-rootfs
```

---

## 5. Procedure

### Step 1 — Inventory and identify the drive

```bash
lsscsi -g                                  # map block (/dev/sdX) <-> generic (/dev/sgX)
sudo sg_inq /dev/sgX | grep -i -E 'serial|product|vendor'
```

Record for the drive under test: **model, serial number (SN), `/dev/sgX`, `/dev/sdX`**. Use the **serial number** as the primary identifier throughout. Set working variables:

```bash
DEV=/dev/sgX          # generic node for sed_cli / sg_dd
SN=XXXXXXXX           # serial number from sg_inq
```

### Step 2 — Query drive state (choose the path)

```bash
sudo sed_cli --device=$DEV --operation=printdriveinfo --keymanager=json
```

Record `TCG Config`, `WWN`, `MSID`, `MaxLBA`, `Is Owned`, `Is Locked`. Decide:

- **`Is Owned = False` and `Is Locked = False`** → **Path A** (EraseMaster band erase), Step 4A.
- **`Is Owned = True` or `Is Locked = True`** → **Path B** (PSID revert), Step 4B.
- If you prefer/openSeaChest reports `Sanitize Crypto Erase (Purge)` supported → **Path C**, Step 4C.

Capability check (optional, informative):
```bash
sudo openSeaChest_Erase -d $DEV --showEraseSupport
```

Range count (for the record):
```bash
sudo /usr/local/libexec/cas-tcgstorageapi-run python3 -c "from TCGstorageAPI.tcgapi import Sed as SED; i=SED('$DEV').lockingInfo(); print('MaxRanges =', i.MaxRanges, '| MaxReEncryptions =', i.MaxReEncryptions, '| KeysAvailableCfg =', i.KeysAvailableCfg)"
```

Enumerate ranges to confirm only the global range holds data (all others `RangeLength = 0x0`):
```bash
for b in $(seq 0 15); do echo "== Band $b =="; sudo sed_cli --device=$DEV --operation=printbandinfo --bandno=$b --keymanager=json 2>&1; done
```
> Note: `printbandinfo --bandno=0` prints `Opalv2 does not support Global Range` and no range fields — this is a known, harmless quirk of the reporting function (it does **not** affect the erase). Bands beyond `MaxRanges` will error; that boundary confirms the count.

### Step 3 — PRE-sanitization sampling & verification (A/B/C)

Run the verification block **before** erasing (see Section 6 for the reusable script). Capture strings, entropy, gzip, and multi-offset hashes labeled `PRE`. This establishes the baseline (data present).

```bash
sudo /root/verify_sample.sh $DEV PRE $SN
```

> Reads use `sg_dd` (works on the `/dev/sgX` generic node). Do **not** use plain `dd` on `/dev/sgX`.

---

### Step 4A — Sanitize: EraseMaster band erase (unowned + unlocked)

**4A.1 — Read WWN + MSID and place the credential file (correct location + state):**
```bash
INFO=$(sudo sed_cli --device=$DEV --operation=printdriveinfo --keymanager=json)
WWN=$(printf '%s\n' "$INFO"  | awk '/^WWN/{print $NF}')
MSID=$(printf '%s\n' "$INFO" | awk '/^MSID/{print $NF}')
echo "Parsed -> WWN=$WWN  MSID=$MSID"     # sanity-check before writing

printf '{ "SID": "%s", "EraseMaster": "%s", "BandMaster0": "%s", "BandMaster1": "%s" }\n' \
  "$MSID" "$MSID" "$MSID" "$MSID" | sudo tee "$RUNTIME/$WWN.json" >/dev/null

sudo cat "$RUNTIME/$WWN.json"             # verify placement + contents
```
> Rationale: on a factory-default (unowned) drive all credentials default to the MSID (`SID = EraseMaster = BandMaster = MSID`). The JSON key manager will not auto-populate this, so it must be seeded. The file must live at `$RUNTIME/<WWN>.json` because the tool runs chrooted with CWD `/`.

**4A.2 — Erase the global range (and any other configured range):**
```bash
sudo sed_cli --device=$DEV --operation=eraseband --bandno=0 --keymanager=json
```
Expect `Band0 sucessfully erased`. The follow-up message `Take ownership of drive before adding a band` is expected and harmless (the erase already completed). Repeat for any additional band that Step 2 showed as configured (`--bandno=N`).

**4A.3 — Confirm post-state:**
```bash
sudo sed_cli --device=$DEV --operation=printdriveinfo --keymanager=json
```
Expect `Is Owned = False`, `Is Locked = False`, no errors. Proceed to Step 5.

---

### Step 4B — Sanitize: PSID revert (owned or locked)

Use when Step 2 shows `Is Owned = True` or `Is Locked = True` (EraseMaster ≠ MSID, so Path A cannot authenticate).

**4B.1 — Read the PSID** (32 characters) from the drive's physical paper label / QR code. It cannot be derived in software.

**4B.2 — Revert (full-drive crypto erase; erases all ranges at once):**
```bash
sudo sed_cli --device=$DEV --operation=revertdrive --psid=<PSID_FROM_LABEL> --keymanager=json
```
A 15-second `REVERT SP will commence …` countdown precedes execution. No credential JSON file is required for this path.

**4B.3 — Confirm post-state:**
```bash
sudo sed_cli --device=$DEV --operation=printdriveinfo --keymanager=json
```
Expect `Is Owned = False`, `Is Locked = False`. Document method as **TCG `RevertSP` (PSID authority)**. Proceed to Step 5.

---

### Step 4C — Sanitize: SCSI SANITIZE crypto erase (when supported)

Use when `--showEraseSupport` lists `Sanitize Crypto Erase (Purge)`.
```bash
sudo openSeaChest_Erase -d $DEV --sanitize cryptoerase --poll --confirm this-will-erase-data
```
Crypto erase completes in seconds. Document method as **SCSI SANITIZE Cryptographic Erase**. Proceed to Step 5.
> If the drive reports "PI formatting may require write after crypto erase," complete Step 7 (PI restore) before reuse.

---

### Step 5 — POST-sanitization sampling & verification (A/B/C)

Run the same verification block **after** erasing, labeled `POST`:
```bash
sudo /root/verify_sample.sh $DEV POST $SN
```

**Acceptance criteria (POST):**
- **A. Strings** — no coherent/meaningful strings. (Random data yields short gibberish runs at low `-n`; use `-n 10` and confirm none are words/filenames/paths.)
- **B. Entropy** — Shannon entropy ≈ **8.0 bits/byte** (typically ≥ 7.99 on a ≥1 MB sample).
- **C. Incompressibility** — gzip output size ≥ original size (ratio ≥ ~1.0); random data does not compress.
- **Multi-offset hashes** — all distinct (no repeating pattern / not uniform), spanning LBA 0 to near `MaxLBA`.
- **Structure absent** — LBA 0 has no partition table and no `55 aa` boot signature at offset `0x1FE`.

Compare against the `PRE` results: the baseline should show the change (e.g., recoverable strings / lower entropy / compressibility present pre, absent post). If POST fails any criterion, **do not certify** — see Step 8 remediation.

### Step 6 — (Optional) Restore Protection Information / reformat

If the client requires the drive returned with T10 PI (or a specific sector format):
```bash
sudo openSeaChest_Format -d $DEV --showSupportedFormats
sudo openSeaChest_Format -d $DEV --formatUnit current --protectionType 2 --poll --confirm this-will-erase-data
sudo sg_readcap -l /dev/sdX        # verify prot_en / p_type   (use the BLOCK node)
```
PI types: `--protectionType 0` (none) / `1` / `2` / `3`. sg_format equivalents: Type 1 = `--fmtpinfo=2`; Type 2 = `--fmtpinfo=3 --pfu=0`; Type 3 = `--fmtpinfo=3 --pfu=1`.
> Document PI restore as a **separate step** from the sanitization; it is a "Clear"-level format and must not be recorded as the Purge method.

### Step 7 — Cleanup (per drive)

```bash
sudo rm -f "$RUNTIME/$WWN.json"     # remove seeded credential file (contains MSID)
```
Remove any credential files created during Path A. (Path B/C create none.) Retain the verification `.bin`/`.txt` artifacts and the `script` transcript as evidence.

### Step 8 — Repeat / remediation

Repeat Steps 1–7 for each drive (re-derive `DEV`, `SN`, `WWN`, `MSID` per drive — they are unique).

If POST verification fails:
1. Confirm `$DEV` still maps to serial `$SN` (`sg_inq`) — renumbering is the most common cause of a "readable" post-read.
2. Power-cycle / rescan the drive and re-read.
3. Re-run `printdriveinfo` and re-issue the erase; watch for `sucessfully erased` with no error.
4. Escalate to an alternate Purge method (PSID `revertdrive`, or `openSeaChest_Erase --sanitize overwrite --poll` where supported).

---

## 6. Reusable verification script (`/root/verify_sample.sh`)

Create once; used for both PRE and POST. Implements checks **A (strings), B (entropy), C (gzip)** plus multi-offset hashing. Uses `sg_dd` so it works on `/dev/sgX`.

```bash
#!/usr/bin/env bash
# Usage: verify_sample.sh <device> <PRE|POST> <serial>
set -u
DEV="$1"; PHASE="$2"; SN="$3"
OUT="/root/sanitize-logs/${SN}"; mkdir -p "$OUT"
SAMPLE="$OUT/${PHASE}_1mb.bin"

# 1 MB sample for entropy/compression/strings
sudo sg_dd if="$DEV" bs=512 count=2048 skip=2000000 of="$SAMPLE" 2>/dev/null

echo "===== ${PHASE} verification | SN=${SN} | ${DEV} | $(date -u +%Y%m%dT%H%M%SZ) ====="

echo "-- A. strings (min length 10; expect only gibberish / none post-erase) --"
strings -n 10 "$SAMPLE" | tee "$OUT/${PHASE}_strings.txt" | head
echo "A: $(wc -l < "$OUT/${PHASE}_strings.txt") run(s) >= 10 printable chars"

echo "-- B. Shannon entropy (8.0 = perfectly random) --"
python3 -c "import collections,math; d=open('$SAMPLE','rb').read(); n=len(d); c=collections.Counter(d); H=-sum((v/n)*math.log2(v/n) for v in c.values()); print(f'entropy = {H:.5f} bits/byte')" | tee "$OUT/${PHASE}_entropy.txt"

echo "-- C. gzip incompressibility (comp >= orig => high entropy) --"
orig=$(stat -c%s "$SAMPLE"); comp=$(gzip -c "$SAMPLE" | wc -c)
python3 -c "print(f'orig={$orig} comp={$comp} ratio={$comp/$orig:.4f}')" | tee "$OUT/${PHASE}_gzip.txt"

echo "-- multi-offset SHA-256 (expect distinct/random across the span) --"
: > "$OUT/${PHASE}_offsets.txt"
for off in 0 1000000 500000000; do
  sudo sg_dd if="$DEV" bs=512 count=8 skip="$off" of=/tmp/_s.bin 2>/dev/null
  echo "offset $off  sha256=$(sha256sum /tmp/_s.bin | cut -d' ' -f1)  strings10=$(strings -n 10 /tmp/_s.bin | wc -l)" | tee -a "$OUT/${PHASE}_offsets.txt"
done
echo "===== end ${PHASE} ====="
```

Install:
```bash
sudo tee /root/verify_sample.sh >/dev/null   # then paste the script, or create with an editor
sudo chmod +x /root/verify_sample.sh
```
> Adjust the near-end offset (`500000000`) and add one near `MaxLBA` for full-span coverage on larger drives.

### Interpreting A/B/C

| Check | PRE (data present) | POST (purged) |
|---|---|---|
| **A. strings** | may show real words/paths/filenames | only short gibberish or none |
| **B. entropy** | often < 8.0 if plaintext/compressible | ≈ 8.0 bits/byte |
| **C. gzip** | may compress (comp < orig) | does not compress (comp ≥ orig) |
| offsets | patterned/zeros possible | all distinct, random |

> If a drive already held encrypted/random data, PRE may also look high-entropy. In that case rely on operation success + POST criteria + drive state as the primary evidence.

---

## 7. Per-drive documentation record (fill one per drive)

| Field | Value |
|---|---|
| Drive model | |
| Serial number | |
| WWN | |
| Interface / SSC | SAS / TCG Enterprise SSC |
| MSID (recorded) | |
| MaxLBA | |
| MaxRanges | |
| Is Owned / Is Locked (pre) | |
| Sanitization method | Erase (EraseMaster) / RevertSP (PSID) / SANITIZE cryptoerase |
| TCG operation | |
| Standard | IEEE 2883-2022 Purge; NIST SP 800-88 Rev. 1 Purge |
| Tool + version | `sed_cli`/`TCGstorageAPI` / `openSeaChest` (record version) |
| Operator | |
| Date/Time (UTC) | |
| Operation output | `Band0 sucessfully erased` / revert OK / sanitize OK |
| PRE verification | strings / entropy / gzip / offsets (attach) |
| POST verification | strings=~0 meaningful / entropy≈8.0 / gzip≥1.0 / offsets distinct (attach) |
| PI restored (if any) | Type __ (separate Clear-level format) |
| Credential file removed | Yes |
| Result | PASS / FAIL |

Attach: the `script` transcript and the `PRE_*`/`POST_*` files under `/root/sanitize-logs/<SN>/`.

---

## 8. Sample certification statement

> Media identified by serial **&lt;SN&gt;** (model &lt;model&gt;, WWN &lt;wwn&gt;) was sanitized to the **Purge** level via cryptographic erase by invoking the TCG Enterprise SSC **&lt;Erase method on all locking ranges / RevertSP&gt;** authenticated with the **&lt;EraseMaster / PSID&gt;** authority, regenerating the drive's Media Encryption Key and rendering all previously stored data cryptographically unrecoverable. Verified by post-sanitization read sampling across the addressable span: no recoverable data strings, Shannon entropy ≈ 8.0 bits/byte, incompressible content, and absence of prior filesystem structure. Compliant with **IEEE 2883-2022** and **NIST SP 800-88 Rev. 1**. Operator: &lt;name&gt;. Date/Time (UTC): &lt;timestamp&gt;. Tools: &lt;tool + version&gt;.

---

## 9. Troubleshooting quick reference

| Symptom | Cause | Fix |
|---|---|---|
| `MissingSchema: Invalid URL 'v1/sys/capabilities'` | Default `vault` key manager, no Vault server | Add `--keymanager=json` |
| `KeyError: 'EraseMaster'` | Credential JSON not found in chroot CWD | Place file at `$RUNTIME/<WWN>.json` |
| `printbandinfo --bandno=0` shows "Opalv2 does not support Global Range" | Known reporting quirk | Harmless; does not affect erase |
| `dd if=/dev/sgX` hangs | `sgX` is a passthrough node, not a block device | Use `sg_dd if=/dev/sgX …` or read `/dev/sdX` |
| Post-read shows "readable" bytes | Misread ASCII column, or wrong device after renumbering | Verify serial (`sg_inq`); run A/B/C — random ≈ entropy 8.0 |
| Terminal shows binary garbage | Raw binary echoed to TTY | `reset`; never `cat`/`dd` binary to terminal |
| `ent: command not found` | Package not on live image | Use the Python Shannon-entropy one-liner (Check B) |
