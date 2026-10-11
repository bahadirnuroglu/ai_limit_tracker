#!/bin/bash
# Kalıcı imza kimliği: "AI Limit Tracker Code Signing" adlı, kendinden imzalı kod imzalama sertifikası üretir ve
# giriş Anahtar Zinciri'ne ekler (sadece codesign kullanabilir). Sistem güven ayarlarına DOKUNMAZ; Gatekeeper
# uyarısı yine çıkar (bunun için Apple Developer ID gerekir).
#
# Neden: ad-hoc imzada her derleme macOS için "başka uygulama"dır; kullanıcılar her güncellemede Claude Code
# Anahtar Zinciri iznini yeniden verir. Sabit sertifikayla izin güncellemelerde kalır ve uygulama içi güncelleme
# yeni sürümün AYNI sertifikayla imzalandığını doğrular.
#
# Bir kez çalıştır:  bash tools/make-signing-cert.sh
# Yedek: Anahtar Erişimi > "AI Limit Tracker Code Signing" > Dışa Aktar (.p12). Kaybolursa sonraki güncelleme
# uygulama içinden kurulamaz (doğrulama reddeder), kullanıcılar dmg'yi elle kurar.
set -euo pipefail
NAME="AI Limit Tracker Code Signing"

if security find-identity -p codesigning | grep -q "$NAME"; then
    echo "Zaten var: $NAME"; exit 0
fi

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
umask 077
cat > "$WORK/c.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
/usr/bin/openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -days 7300 -nodes \
    -config "$WORK/c.cnf" 2>/dev/null
PASS=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
    -out "$WORK/id.p12" -passout "pass:$PASS" 2>/dev/null
security import "$WORK/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "Eklendi: $NAME. Artık build-app.sh bu kimlikle imzalar."
