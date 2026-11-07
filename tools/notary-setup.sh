#!/bin/bash
# Noter onayı giriş bilgisini bir kez kaydeder (release.sh / build-dmg.sh "ailimit-notary" profilini kullanır):
#   bash tools/notary-setup.sh
# App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys'ten indirilen
# AuthKey_<KeyID>.p8 dosyasını İndirilenler / Masaüstü'nde bulur, yalnızca Issuer ID'yi sorar. Anahtar dosyası
# ~/.appstoreconnect/private_keys altına (yalnızca sen okuyabilirsin) taşınır.
set -euo pipefail

KEY=$(find "$HOME/Downloads" "$HOME/Desktop" "$HOME/.appstoreconnect/private_keys" -maxdepth 1 -name 'AuthKey_*.p8' 2>/dev/null | head -1 || true)
if [ -z "$KEY" ]; then
    echo "AuthKey_….p8 bulunamadı. App Store Connect → Users and Access → Integrations → App Store Connect API →"
    echo "Team Keys → + (Access: Developer) → Download API Key, sonra bu betiği tekrar çalıştır."
    exit 1
fi
KEY_ID=$(basename "$KEY" .p8); KEY_ID=${KEY_ID#AuthKey_}
echo "Anahtar: $(basename "$KEY")  (Key ID: $KEY_ID)"

read -rp "Issuer ID (aynı sayfanın üstünde, 69a6de8f-… gibi): " ISSUER
[ -n "$ISSUER" ] || { echo "Issuer ID boş."; exit 1; }

DEST="$HOME/.appstoreconnect/private_keys"
mkdir -p "$DEST" && chmod 700 "$DEST"
[ "$(dirname "$KEY")" = "$DEST" ] || mv "$KEY" "$DEST/"
chmod 600 "$DEST/AuthKey_$KEY_ID.p8"

xcrun notarytool store-credentials ailimit-notary --key "$DEST/AuthKey_$KEY_ID.p8" --key-id "$KEY_ID" --issuer "$ISSUER"
echo "Tamam: noter onayı profili \"ailimit-notary\" kaydedildi."
