# NOVA ECE demo → demo.novaece.com (cPanel) kurulumu

Demo GitHub'da kalır. `main` dalına her yeni sürüm gönderildiğinde GitHub, dosyaları cPanel sunucusuna kendiliğinden yükler (`.github/workflows/cpanel-yukle.yml`). Sunucu bilgileri koda yazılmaz; GitHub'da şifreli "sır" olarak durur.

## 1. cPanel: alt alan adı
1. cPanel → **Domains** (eski panellerde **Subdomains**) → **Create A New Domain**.
2. Alan adı: `demo.novaece.com`. Belge kökü (Document Root): `demo.novaece.com` (cPanel önerdiği gibi kalsın).
3. Kaydet.

## 2. DNS kaydı
novaece.com'un DNS'i nerede yönetiliyorsa (alan adını aldığınız firma, Cloudflare ya da cPanel **Zone Editor**):
- Tür **A**, Ad **demo**, Değer: hosting sunucusunun IP adresi (cPanel ana sayfasında sağda **Shared IP Address** / **Paylaşılan IP**).
- Ana `novaece.com` kayıtlarına dokunmayın; ana site GitHub Pages'te kalır.
- Cloudflare kullanıyorsanız ilk kurulumda bulut simgesini gri (DNS only) bırakın; SSL alındıktan sonra turuncuya çevirebilirsiniz.

## 3. SSL (https)
cPanel → **SSL/TLS Status** → `demo.novaece.com` → **Run AutoSSL**. DNS yayıldıktan sonra (birkaç dakika–birkaç saat) sertifika gelir.

## 4. Yalnız demo klasörüne yetkili FTP hesabı
cPanel → **FTP Accounts** → **Add FTP Account**:
- Log in: `demo` (tam ad `demo@novaece.com` olur)
- Şifre: güçlü bir şifre (şifre yöneticisine kaydedin)
- Directory: `demo.novaece.com` (yalnız bu klasör; ana dizini vermeyin)
- Aynı sayfadaki **Configure FTP Client** bölümünden **FTP Server** adını not edin (ör. `ftp.novaece.com`).

## 5. GitHub sırları
github.com/oguzzkeles-oss/nova-demo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:
| Ad | Değer |
|---|---|
| `FTP_SERVER` | 4. adımdaki FTP sunucusu |
| `FTP_USERNAME` | `demo@novaece.com` |
| `FTP_PASSWORD` | FTP şifresi |

Şifreyi sohbete ya da bir dosyaya yazmayın; yalnız bu ekrana girin.

## 6. İlk yükleme
GitHub → **Actions** → **cPanel'e yükle** → **Run workflow**. Yeşil tik çıkınca https://demo.novaece.com/#/giris açılır. Sonraki sürümler kendiliğinden yüklenir.

## Notlar
- `.htaccess`: https'e yönlendirme, güvenlik başlıkları, `index.html` ve `sw.js` için önbellek kapalı (yeni sürüm hemen görünsün).
- Demo verileri tarayıcıda (IndexedDB) tutulur ve adrese bağlıdır: github.io'daki deneme verileri yeni adrese taşınmaz; demo kendi örnek verisiyle açılır.
- GitHub Pages adresi (oguzzkeles-oss.github.io/nova-demo) yedek olarak çalışmaya devam eder. Yeni adres açılınca novaece.com'daki demo bağlantıları demo.novaece.com'a çevrilecek.
