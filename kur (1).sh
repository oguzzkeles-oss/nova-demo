#!/usr/bin/env bash
# NOVA ECE — okul.novaece.com ilk kurulum betiği
# Ne yapar: Caddy web sunucusunu kurar, Let's Encrypt sertifikasını otomatik alır,
#           demo uygulamasını /var/www/nova altına indirir ve yayına açar.
# Ne YAPMAZ: veritabanı, kullanıcı hesabı, gerçek veri. Bu aşamada sunucuda
#            hiçbir çocuk verisi tutulmaz — uygulama tarayıcıda çalışır.
# Çalıştırma: curl -fsSL https://raw.githubusercontent.com/oguzzkeles-oss/nova-demo/main/kur.sh | bash
set -euo pipefail

ALAN="okul.novaece.com"
KOK="/var/www/nova"
DEPO="https://raw.githubusercontent.com/oguzzkeles-oss/nova-demo/main"
SSH_PORT="${SSH_PORT:-23422}"

mavi(){ printf '\n\033[1;36m▸ %s\033[0m\n' "$*"; }
sari(){ printf '\033[1;33m!  %s\033[0m\n' "$*"; }
yesil(){ printf '\033[1;32m✓  %s\033[0m\n' "$*"; }
kirmizi(){ printf '\n\033[1;31m✗  %s\033[0m\n' "$*"; }
dur(){ kirmizi "$*"; exit 1; }

[ "$(id -u)" -eq 0 ] || dur "Bu betik root olarak çalıştırılmalı."

# ---------------------------------------------------------------- 1/6 DNS
mavi "1/6 · DNS kontrolü"
sunucu_ip="$(curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
alan_ip="$(getent ahostsv4 "$ALAN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
echo "   sunucu IP : ${sunucu_ip:-bilinmiyor}"
echo "   $ALAN → ${alan_ip:-çözümlenmedi}"
if [ -z "$alan_ip" ]; then
  dur "$ALAN henüz DNS'te yok.
   Türk Ticaret → Domain Yönetimi → novaece.com → DNS Pro
   Yeni kayıt:  Tür=A   Ad=okul   Değer=$sunucu_ip
   Kaydettikten 10-15 dakika sonra bu komutu yeniden çalıştırın."
fi
if [ -n "$sunucu_ip" ] && [ "$alan_ip" != "$sunucu_ip" ]; then
  dur "$ALAN başka bir IP'ye ($alan_ip) bakıyor; bu sunucu $sunucu_ip.
   A kaydını düzeltip 10-15 dakika sonra yeniden deneyin.
   (Yanlış IP ile sertifika alınamaz ve Let's Encrypt deneme hakkı harcanır.)"
fi
yesil "DNS doğru."

# ---------------------------------------------------------------- 2/6 paketler
mavi "2/6 · Caddy kurulumu"
if command -v caddy >/dev/null 2>&1; then
  yesil "Caddy zaten kurulu ($(caddy version | head -1))."
elif command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl gnupg ca-certificates debian-keyring debian-archive-keyring apt-transport-https ufw >/dev/null
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  # apt, _apt kullanıcısı olarak okur: okuma izni verilmezse depo görünmez
  chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  chmod o+r /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq
  apt-get install -y -qq caddy >/dev/null
  yesil "Caddy kuruldu (Debian/Ubuntu)."
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y -q dnf-plugins-core curl firewalld >/dev/null 2>&1 \
    || dnf install -y -q dnf5-plugins curl firewalld >/dev/null 2>&1 \
    || dur "copr eklentisi kurulamadı."
  dnf copr enable -y @caddy/caddy >/dev/null
  dnf install -y -q caddy >/dev/null
  yesil "Caddy kuruldu (RHEL/Alma/Rocky)."
else
  dur "Desteklenmeyen dağıtım: apt-get ya da dnf bulunamadı."
fi

# ---------------------------------------------------------------- 3/6 dosyalar
mavi "3/6 · Uygulama dosyaları"
mkdir -p "$KOK/icons"
indir(){
  if curl -fsSL --max-time 120 "$DEPO/$1" -o "$KOK/$1"; then
    echo "   ✓ $1  ($(du -h "$KOK/$1" | cut -f1))"
  else
    sari "indirilemedi, atlandı: $1"
    rm -f "$KOK/$1"
  fi
}
indir index.html
indir sw.js
indir manifest.webmanifest
for i in apple-touch-icon.png icon-192.png icon-512.png app-icon-1024.png; do indir "icons/$i"; done
[ -s "$KOK/index.html" ] || dur "index.html indirilemedi; kurulum durduruldu."
# Kurum uygulaması arama motorlarında listelenmemeli
printf 'User-agent: *\nDisallow: /\n' > "$KOK/robots.txt"
echo "   ✓ robots.txt (arama motorlarına kapalı)"
chown -R root:root "$KOK"
find "$KOK" -type f -exec chmod 644 {} \;
find "$KOK" -type d -exec chmod 755 {} \;
# SELinux açıksa Caddy'nin okuyabilmesi için etiketle
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
  chcon -R -t httpd_sys_content_t "$KOK" 2>/dev/null || sari "SELinux etiketi ayarlanamadı."
fi
yesil "Dosyalar $KOK altında."

# ---------------------------------------------------------------- 4/6 yapılandırma
mavi "4/6 · Caddy yapılandırması"
cat > /etc/caddy/Caddyfile <<CADDY
# NOVA ECE — otomatik TLS (Let's Encrypt)
$ALAN {
	root * $KOK
	encode zstd gzip

	header {
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options    "nosniff"
		X-Frame-Options           "SAMEORIGIN"
		Referrer-Policy           "no-referrer"
		-Server
	}

	# Service worker her zaman tazelensin; yoksa eski sürüm cihazda asılı kalır
	@sw path /sw.js /manifest.webmanifest
	header @sw Cache-Control "no-cache, must-revalidate"

	@varlik path /icons/*
	header @varlik Cache-Control "public, max-age=604800"

	try_files {path} /index.html
	file_server
}
CADDY
caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null 2>&1 || true
caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 || dur "Caddyfile geçersiz."
yesil "Yapılandırma yazıldı."

# ---------------------------------------------------------------- 5/6 güvenlik duvarı
mavi "5/6 · Güvenlik duvarı"
if command -v ufw >/dev/null 2>&1; then
  ufw allow "$SSH_PORT"/tcp >/dev/null 2>&1 || true
  ufw allow 22/tcp   >/dev/null 2>&1 || true
  ufw allow 80/tcp   >/dev/null 2>&1 || true
  ufw allow 443/tcp  >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || sari "ufw etkinleştirilemedi."
  yesil "ufw açık — izinli portlar: $SSH_PORT, 22, 80, 443."
elif command -v firewall-cmd >/dev/null 2>&1; then
  systemctl enable --now firewalld >/dev/null 2>&1 || true
  firewall-cmd --permanent --add-port="$SSH_PORT"/tcp >/dev/null 2>&1 || true
  firewall-cmd --permanent --add-service=ssh --add-service=http --add-service=https >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
  yesil "firewalld açık — izinli: ssh, $SSH_PORT, http, https."
else
  sari "Güvenlik duvarı aracı bulunamadı; atlandı."
fi

# ---------------------------------------------------------------- 6/6 başlat
mavi "6/6 · Servis"
systemctl enable caddy >/dev/null 2>&1 || true
systemctl restart caddy
echo "   sertifika alınıyor, 20 saniye bekleniyor…"
sleep 20

kod="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 25 "https://$ALAN/" 2>/dev/null || echo "000")"
echo
if [ "$kod" = "200" ]; then
  yesil "YAYINDA → https://$ALAN"
  echo "   HTTP durumu: $kod"
else
  sari "Sayfa henüz yanıt vermedi (durum: $kod)."
  echo "   Sertifika birkaç dakika sürebilir. Kontrol için:"
  echo "     systemctl status caddy --no-pager"
  echo "     journalctl -u caddy -n 40 --no-pager"
  echo "   (Caddy günlükleri journald'a yazar; ayrı log dosyası yoktur.)"
fi
echo
echo "Sonraki güncellemeler için aynı komutu yeniden çalıştırmanız yeterli;"
echo "dosyalar yeniden indirilir, sertifika korunur."
