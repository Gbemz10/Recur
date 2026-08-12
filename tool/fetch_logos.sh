#!/usr/bin/env bash
#
# Downloads every bank and merchant logo into assets/logos/ so the app stops
# depending on third-party CDNs at runtime.
#
# Why this matters: the bank picker is the screen where we ask someone to
# connect a real bank account. If the logos are blank because a CDN is
# having a bad day, that screen looks broken at exactly the moment trust
# matters most. Bundled assets also load instantly and work offline.
#
# Usage:
#   chmod +x tool/fetch_logos.sh
#   ./tool/fetch_logos.sh
#
# Re-runnable. Skips files that already exist; pass --force to refetch.
#
# Note on merchant logos: these come from Google's favicon endpoint, which
# is undocumented and tops out around 128px. Fine for the small marks we
# render, but if you want crisp assets, replace them by hand with official
# press-kit downloads.

set -euo pipefail

cd "$(dirname "$0")/.."
OUT="assets/logos"
mkdir -p "$OUT"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    echo ''
  fi
}

# Google's favicon service doesn't 404 for domains it doesn't know — it
# quietly returns a generic globe. That globe is a perfectly valid PNG, so a
# magic-byte check waves it through and you end up shipping a globe as a
# brand's logo. (This is exactly how a wrong Chicken Republic logo got in:
# the un-hyphenated domain isn't theirs, so Google served the placeholder.)
#
# So: fetch the globe once from a domain that definitely doesn't exist,
# fingerprint it, and reject anything that matches.
GLOBE_SUM=''
fingerprint_placeholder() {
  local tmp="$OUT/.globe.probe"
  local bogus='recur-nonexistent-domain-check.invalid'
  if curl -fsSL --max-time 15 -o "$tmp" \
      "https://www.google.com/s2/favicons?sz=64&domain=$bogus" 2>/dev/null; then
    GLOBE_SUM=$(sha256_of "$tmp")
    [[ -n "$GLOBE_SUM" ]] && printf 'Placeholder fingerprint: %s…\n\n' "${GLOBE_SUM:0:12}"
  fi
  rm -f "$tmp"
}

fetch() {
  local name="$1" url="$2"
  local dest="$OUT/$1.png"
  # Dot-prefixed so a half-finished download never gets picked up by the
  # Flutter asset bundler.
  local tmp="$OUT/.$1.download"

  if [[ -f "$dest" && $FORCE -eq 0 ]]; then
    printf '  skip  %s\n' "$name"
    return 0
  fi

  if ! curl -fsSL --retry 2 --retry-delay 1 --max-time 30 -o "$tmp" "$url" 2>/dev/null; then
    rm -f "$tmp"
    printf '  FAIL  %s (download failed)\n' "$name"
    return 0
  fi

  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    printf '  FAIL  %s (empty response)\n' "$name"
    return 0
  fi

  # Verify it's actually an image by magic bytes.
  #
  # This deliberately avoids grep: BSD grep on macOS aborts with "illegal
  # byte sequence" the moment it meets binary data in a UTF-8 locale, which
  # is exactly what a PNG is. od is POSIX and doesn't care.
  local magic
  magic=$(od -An -tx1 -N4 < "$tmp" | tr -d ' \n')
  case "$magic" in
    89504e47) ;;  # PNG
    47494638) ;;  # GIF
    52494646) ;;  # RIFF (WebP)
    ffd8ff??) ;;  # JPEG
    *)
      rm -f "$tmp"
      printf '  BAD   %s (magic bytes: %s)\n' "$name" "${magic:-none}"
      return 0
      ;;
  esac

  # Reject the "I don't know this domain" globe.
  if [[ -n "$GLOBE_SUM" ]] && [[ "$(sha256_of "$tmp")" == "$GLOBE_SUM" ]]; then
    rm -f "$tmp"
    printf '  SKIP  %s (placeholder globe, not a real logo)\n' "$name"
    return 0
  fi

  mv "$tmp" "$dest"
  printf '  ok    %s (%s)\n' "$name" "$(du -h "$dest" | cut -f1 | tr -d ' \t')"
}

CDN="https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto"

echo "Banks →  $OUT"
fetch bank_access_bank                "$CDN/v1731835318/access-bank_u0pg90.png"
fetch bank_guaranty_trust_bank        "$CDN/v1731834954/Guaranty_Trust_Bank_odgbdu.png"
fetch bank_zenith_bank                "$CDN/v1731908201/Zenith_Bank_h40m09.png"
fetch bank_first_bank_of_nigeria      "$CDN/v1731835216/First_Bank_of_Nigeria_drawyb.png"
fetch bank_united_bank_for_africa     "$CDN/v1731908162/United_Bank_For_Africa_om7axi.png"
fetch bank_kuda_bank                  "$CDN/v1731835102/Kuda_Bank_f5nrij.png"
fetch bank_opay                       "$CDN/v1731910673/OPay_Digital_Services_Limited__OPay_zyh5d0.png"
fetch bank_moniepoint_mfb             "$CDN/v1731907889/Moniepoint_MFB_hxoelg.png"
fetch bank_palmpay                    "$CDN/v1731910656/PalmPay_lzs7yt.png"
fetch bank_sterling_bank              "$CDN/v1731908098/Sterling_Bank_ooipqt.png"
fetch bank_fidelity_bank              "$CDN/v1731835222/Fidelity_Bank_lkl2mr.png"
fetch bank_union_bank_of_nigeria      "$CDN/v1731908157/Union_Bank_of_Nigeria_i8mtrj.png"
fetch bank_wema_bank                  "$CDN/v1731908191/Wema_Bank_cr2pvu.png"
fetch bank_stanbic_ibtc_bank          "$CDN/v1731908079/Stanbic_IBTC_Bank_qjczcl.png"
fetch bank_ecobank_nigeria            "$CDN/v1731835234/Ecobank_Nigeria_qdd70j.png"
fetch bank_first_city_monument_bank   "$CDN/v1731835213/First_City_Monument_Bank_aeufbo.png"
fetch bank_polaris_bank               "$CDN/v1731907984/Polaris_Bank_irqlkv.png"
fetch bank_keystone_bank              "$CDN/v1731835110/Keystone-Bank_cvicmd.png"
fetch bank_providus_bank              "$CDN/v1731908004/Providus_Bank_oo0ue2.png"
fetch bank_jaiz_bank                  "$CDN/v1731835113/Jaiz_Bank_fambas.png"

# Merchant logos have no single reliable source, so each one gets a chain of
# candidates and we take the first that returns a real image.
#
# Google 404s at sz=128 for domains it hasn't indexed at that size, which is
# what killed DStv, MTN, Showmax and i-Fitness on the first run. Dropping to
# sz=64, trying alternative domains, and falling back to DuckDuckGo's icon
# service covers most of them.
#
# DuckDuckGo serves from a .ico path but usually returns PNG bytes. The
# magic-byte check decides — if it really is an .ico, Flutter can't decode
# it and we reject it rather than shipping a broken asset.
g128() { printf 'https://www.google.com/s2/favicons?sz=128&domain=%s' "$1"; }
g64()  { printf 'https://www.google.com/s2/favicons?sz=64&domain=%s' "$1"; }
ddg()  { printf 'https://icons.duckduckgo.com/ip3/%s.ico' "$1"; }

fetch_any() {
  local name="$1"; shift
  local dest="$OUT/$name.png"

  if [[ -f "$dest" && $FORCE -eq 0 ]]; then
    printf '  skip  %s\n' "$name"
    return 0
  fi

  local url
  for url in "$@"; do
    if fetch "$name" "$url" >/dev/null 2>&1 && [[ -f "$dest" ]]; then
      printf '  ok    %s (%s)\n' "$name" "$(du -h "$dest" | cut -f1 | tr -d ' \t')"
      return 0
    fi
  done
  printf '  FAIL  %s (no source returned a usable image)\n' "$name"
}

echo
fingerprint_placeholder

# Sweep anything already on disk that turns out to be the placeholder, so a
# bad logo from an earlier run gets replaced rather than silently kept.
if [[ -n "$GLOBE_SUM" ]]; then
  for existing in "$OUT"/*.png; do
    [[ -e "$existing" ]] || continue
    if [[ "$(sha256_of "$existing")" == "$GLOBE_SUM" ]]; then
      printf 'Removing placeholder that slipped through: %s\n' "$(basename "$existing")"
      rm -f "$existing"
    fi
  done
fi

echo "Merchants →  $OUT"
fetch_any netflix  "$(g128 netflix.com)"      "$(g64 netflix.com)"      "$(ddg netflix.com)"
fetch_any dstv     "$(g128 dstv.com)"          "$(g64 dstv.com)" \
                   "$(g128 dstv.co.za)"        "$(g64 dstv.co.za)" \
                   "$(g64 multichoice.com)"    "$(g64 multichoicegroup.com)" \
                   "$(ddg dstv.com)"           "$(ddg dstv.co.za)" \
                   "$(ddg multichoice.com)"
fetch_any mtn      "$(g128 mtn.ng)"           "$(g64 mtn.ng)" \
                   "$(g64 mtnonline.com)"     "$(g64 mtn.com)"          "$(ddg mtn.ng)"
fetch_any spotify  "$(g128 spotify.com)"      "$(g64 spotify.com)"      "$(ddg spotify.com)"
fetch_any openai   "$(g128 openai.com)"       "$(g64 openai.com)"       "$(ddg openai.com)"
fetch_any canva    "$(g128 canva.com)"        "$(g64 canva.com)"        "$(ddg canva.com)"
fetch_any showmax  "$(g128 showmax.com)"       "$(g64 showmax.com)" \
                   "$(g64 showmax.co.za)"      "$(ddg showmax.com)"
fetch_any apple    "$(g128 apple.com)"        "$(g64 apple.com)"        "$(ddg apple.com)"
fetch_any ifitness "$(g128 ifitness.com.ng)"   "$(g64 ifitness.com.ng)" \
                   "$(g64 ifitnessng.com)"     "$(g64 i-fitness.com.ng)" \
                   "$(ddg ifitness.com.ng)"    "$(ddg ifitnessng.com)"
fetch_any bolt     "$(g128 bolt.eu)"          "$(g64 bolt.eu)"          "$(ddg bolt.eu)"
fetch_any chicken_republic \
                   "$(g128 chicken-republic.com)" "$(g64 chicken-republic.com)" \
                   "$(ddg chicken-republic.com)"  "$(g64 foodconceptsplc.com)"


# Clear any stragglers from an interrupted run.
rm -f "$OUT"/.*.download 2>/dev/null || true

COUNT=$(find "$OUT" -name '*.png' | wc -l | tr -d ' \t')
echo
echo "Done. $COUNT logos in $OUT"
if [[ "$COUNT" -eq 0 ]]; then
  echo "Nothing downloaded — check your connection and try again."
  exit 1
fi
echo "Run 'flutter pub get' if this is the first time, then hot restart."
