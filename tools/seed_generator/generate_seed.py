"""
Wikidata SPARQL 기반 liquor_master 시드 생성기.

사용:
  python tools/seed_generator/generate_seed.py

설계:
  - P1056 (product) 역쿼리로 brand→product 관계 추출 (type-instance 아닌 brand 위주)
  - P31 직접 매칭도 병행 (subtype 놓침 방지)
  - 품질 필터: (nameKo 존재) OR (country 존재 AND Latin-script name)
  - 한국어 사용자 UX 우선 — 정크(이름만 있고 국가/한국어 없음) 배제
  - 기존 entry 완전 보존 + dedupe by canonicalName lowercase
"""

from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SEED_PATH = PROJECT_ROOT / "assets" / "seed" / "liquor_master.json"
CURATED_PATH = Path(__file__).resolve().parent / "curated_brands.json"

WDQS_ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = (
    "AlbiSeedGenerator/0.3 "
    "(https://github.com/RoastFried-RF/Albie; school project)"
)

# (Drink QID, category, subcategory, default ABV, per-category cap)
TARGETS: list[tuple[str, str, str | None, float | None, int]] = [
    # ── Whisky ──
    ("Q282",      "whisky", None,          40.0, 100),  # whisky (catch-all)
    ("Q22222",    "whisky", "irish",       40.0, 100),
    ("Q190721",   "whisky", "bourbon",     40.0, 100),
    ("Q849355",   "whisky", "japanese",    43.0, 100),
    ("Q5280528",  "whisky", "blended",     40.0, 100),
    # ── Wine ──
    ("Q506",      "wine",   None,          13.0, 100),
    ("Q321263",   "wine",   "sparkling",   12.0, 100),
    ("Q282537",   "wine",   "champagne",   12.0, 100),
    ("Q166713",   "wine",   "red",         13.0, 100),
    ("Q213503",   "wine",   "white",       12.0, 100),
    # ── Beer ──
    ("Q44",       "beer",   None,          5.0,  100),   # CAP aggressively
    # ── Spirits ──
    ("Q40348",    "spirit", "rum",         40.0, 100),
    ("Q33097",    "spirit", "gin",         40.0, 100),
    ("Q42302",    "spirit", "vodka",       40.0, 100),
    ("Q16599",    "spirit", "tequila",     38.0, 100),
    ("Q108195",   "spirit", "cognac",      40.0, 100),
    ("Q182109",   "spirit", "brandy",      40.0, 100),
    # ── Sake ──
    ("Q5805",     "sake",   None,          15.5, 100),
]

# Name blocklist — lowercase substrings that indicate wrong category (e.g.,
# wine regions tagged as whisky due to Wikidata P1056 leaks). Applied per-category.
CATEGORY_BLOCKLIST: dict[str, list[str]] = {
    "whisky": [
        "winery", "vineyard", "wine company", "dop ",
        "pgi", "pdo", "cava", "vintages",
    ],
    "wine": [
        "distillery", "brewery", "cider",
    ],
    "beer": [
        "wine", "winery", "distillery",
    ],
}

PRODUCT_QUERY = """\
SELECT DISTINCT ?item ?itemLabel ?itemKoLabel ?countryLabel WHERE {{
  ?item wdt:P1056 wd:{qid} .
  OPTIONAL {{
    ?item rdfs:label ?itemKoLabel .
    FILTER(LANG(?itemKoLabel) = "ko")
  }}
  OPTIONAL {{ ?item wdt:P17 ?country. }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}
LIMIT {limit}
"""

# Countries considered "notable" for a Korean-market drink app.
# Entries lacking nameKo but having these countries are still kept.
NOTABLE_COUNTRIES = {
    "South Korea", "Korea", "Japan",
    "Scotland", "United Kingdom", "Ireland",
    "United States of America", "United States",
    "France", "Italy", "Germany", "Spain", "Portugal",
    "Mexico", "Russia", "Canada", "Australia",
    "China", "Taiwan",
}

LATIN_RE = re.compile(r"^[A-Za-zÀ-ÿ0-9 .,'\-&()/+!]+$")


def run_sparql(query: str, retry: int = 3, timeout: int = 120) -> list[dict[str, Any]]:
    params = {"format": "json", "query": query}
    url = f"{WDQS_ENDPOINT}?{urlencode(params)}"
    for attempt in range(retry):
        try:
            req = Request(
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "application/sparql-results+json",
                },
            )
            with urlopen(req, timeout=timeout) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            return data.get("results", {}).get("bindings", [])
        except HTTPError as e:
            if e.code == 429:
                wait = 30 * (attempt + 1)
                print(f"    rate-limited, retry in {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            if e.code == 500:
                print(f"    WDQS 500 (query too expensive, skip): {e.reason}", file=sys.stderr)
                return []
            print(f"    HTTPError {e.code}: {e.reason}", file=sys.stderr)
            return []
        except URLError as e:
            print(f"    attempt {attempt+1} URL error: {e}", file=sys.stderr)
            time.sleep(5 * (attempt + 1))
        except Exception as e:
            print(f"    attempt {attempt+1} failed: {e}", file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    return []


def normalize_key(s: str) -> str:
    return " ".join(s.strip().lower().split())


def is_valid_name(name: str) -> bool:
    if not name or not name.strip():
        return False
    if name.startswith("Q") and len(name) > 1 and name[1:].isdigit():
        return False
    if len(name) > 80:
        return False
    return True


def passes_quality_filter(entry: dict[str, Any]) -> bool:
    """한국어 사용자에게 유용한 entry 만 유지.

    OK if:
      - nameKo 존재, OR
      - country 가 NOTABLE_COUNTRIES 중 하나 AND canonicalName 이 Latin-script
    """
    if entry.get("nameKo"):
        return _not_blocked(entry)
    country = entry.get("country")
    name = entry.get("canonicalName", "")
    if country in NOTABLE_COUNTRIES and LATIN_RE.match(name):
        return _not_blocked(entry)
    return False


def _not_blocked(entry: dict[str, Any]) -> bool:
    cat = entry.get("category") or ""
    name_lower = (entry.get("canonicalName") or "").lower()
    patterns = CATEGORY_BLOCKLIST.get(cat, [])
    for p in patterns:
        if p in name_lower:
            return False
    return True


def build_entry(
    item: dict[str, Any],
    category: str,
    subcategory: str | None,
    default_abv: float | None,
) -> dict[str, Any] | None:
    en = item.get("itemLabel", {}).get("value")
    ko = item.get("itemKoLabel", {}).get("value")
    country = item.get("countryLabel", {}).get("value")

    name = en or ko
    if not is_valid_name(name or ""):
        return None

    aliases: list[str] = []
    if ko:
        aliases.append(ko)
    if en and en.lower() not in [a.lower() for a in aliases]:
        aliases.append(en.lower())

    return {
        "canonicalName": name,
        "nameKo": ko,
        "aliases": aliases,
        "category": category,
        "subcategory": subcategory,
        "defaultAbv": default_abv,
        "country": country,
        "distillery": None,
    }


def fetch_category(
    qid: str,
    category: str,
    subcategory: str | None,
    default_abv: float | None,
    cap: int,
) -> list[dict[str, Any]]:
    query = PRODUCT_QUERY.format(qid=qid, limit=500)
    rows = run_sparql(query)
    out: list[dict[str, Any]] = []
    for row in rows:
        entry = build_entry(row, category, subcategory, default_abv)
        if entry and passes_quality_filter(entry):
            out.append(entry)
            if len(out) >= cap:
                break
    label = f"{category}/{subcategory or '-'}"
    print(f"  {qid:<10} {label:<22} rows={len(rows):>3} kept={len(out):>3} (cap {cap})")
    return out


def load_existing() -> list[dict[str, Any]]:
    text = SEED_PATH.read_text(encoding="utf-8")
    return json.loads(text)


def dedupe_key(entry: dict[str, Any]) -> str:
    return normalize_key(entry["canonicalName"])


def merge(existing: list[dict[str, Any]], new: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[str] = {dedupe_key(e) for e in existing}
    out = list(existing)
    for entry in new:
        k = dedupe_key(entry)
        if k in seen:
            continue
        seen.add(k)
        out.append(entry)
    return out


def sort_new_part(existing_len: int, entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    head = entries[:existing_len]
    tail = entries[existing_len:]
    tail.sort(
        key=lambda e: (
            e.get("category", "zzz"),
            e.get("subcategory") or "",
            e["canonicalName"].lower(),
        )
    )
    return head + tail


def write_seed(entries: list[dict[str, Any]]) -> None:
    lines = ["["]
    for i, e in enumerate(entries):
        comma = "," if i < len(entries) - 1 else ""
        lines.append("  " + json.dumps(e, ensure_ascii=False, separators=(",", ":")) + comma)
    lines.append("]")
    SEED_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    print("== Albi Seed Generator v0.3 ==")
    print(f"Output: {SEED_PATH}")
    existing = load_existing()
    print(f"Existing entries: {len(existing)}\n")
    existing_len = len(existing)

    all_new: list[dict[str, Any]] = []
    for qid, cat, sub, abv, cap in TARGETS:
        rows = fetch_category(qid, cat, sub, abv, cap)
        all_new.extend(rows)
        time.sleep(1.5)

    # Load curated Korean-market brands (옵션 B)
    if CURATED_PATH.exists():
        curated = json.loads(CURATED_PATH.read_text(encoding="utf-8"))
        print(f"\nCurated brands loaded: {len(curated)}")
        all_new = curated + all_new  # curated 가 우선권을 가져 Wikidata 값 덮어씀
    else:
        print(f"\nNo curated file at {CURATED_PATH}")

    print(f"Fetched total (post-filter + curated): {len(all_new)}")
    merged = merge(existing, all_new)
    merged = sort_new_part(existing_len, merged)
    added = len(merged) - existing_len
    print(f"After dedupe: {len(merged)} total (+{added} new)")
    write_seed(merged)
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
