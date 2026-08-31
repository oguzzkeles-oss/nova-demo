// NOVA ECE — saha çalışması çevrimdışı kabuğu. Sürüm dosya içeriğinden türetilir:
// index.html değişince önbellek adı değişir ve eski sürüm silinir.
const SURUM = 'nova-ece-5a04c36288';
const DOSYALAR = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./favicon.svg",
  "./favicon.ico",
  "./icons/app-icon-1024.png",
  "./icons/apple-touch-icon.png",
  "./icons/favicon-32.png",
  "./icons/icon-192.png",
  "./icons/icon-512.png"
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(SURUM).then((c) => c.addAll(DOSYALAR)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((adlar) => Promise.all(adlar.filter((a) => a !== SURUM).map((a) => caches.delete(a))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const istek = e.request;
  if (istek.method !== 'GET') return;
  // Gezinme: her zaman uygulama kabuğu (tek sayfa; yönlendirme hash ile yapılır)
  if (istek.mode === 'navigate') {
    e.respondWith(
      fetch(istek).catch(() => caches.match('./index.html').then((y) => y || caches.match('./'))),
    );
    return;
  }
  e.respondWith(
    caches.match(istek).then((y) => y || fetch(istek).then((yanit) => {
      if (yanit && yanit.status === 200 && yanit.type === 'basic') {
        const kopya = yanit.clone();
        caches.open(SURUM).then((c) => c.put(istek, kopya));
      }
      return yanit;
    }).catch(() => caches.match('./index.html'))),
  );
});
