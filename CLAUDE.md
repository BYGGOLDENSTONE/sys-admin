# SYS_ADMIN - Proje Durumu

## Mevcut Aşama: VERTICAL SLICE — Faz 1
Tasarım çekirdek kararları tamamlandı (GDD v0.4). Vertical slice geliştiriliyor.

## Tasarım Dökümanı
- **GDD:** `docs/GDD.md` (v0.4) - Tüm tasarım kararları burada

## Proje Özeti
- **Tür:** 2D Top-Down Chill Otomasyon/Management
- **Tema:** Cyberpunk / Netrunner
- **Motor:** Godot 4.6
- **Sanat:** Tamamen prosedürel (kod ile üretim) + shader efektleri

---

## Geliştirme Yol Haritası

### 1. VERTICAL SLICE (Şu an) — Steam sayfası için görsel test
### 2. DEMO — Haziran Steam Next Fest için oynanabilir demo
### 3. RELEASE — Tam oyun

---

## Vertical Slice Planı

### Faz 1: Temel Grid ve Yerleştirme
- [ ] Grid sistemi (tile-based yerleştirme alanı)
- [ ] Kamera kontrolleri (pan, zoom)
- [ ] Tek yapı yerleştirme/kaldırma (placeholder kutu)
- [ ] Arka plan: koyu grid çizgileri

### Faz 2: İlk Yapılar (Görsel)
- [ ] Uplink yapısı (prosedürel çizim + neon glow)
- [ ] Storage yapısı
- [ ] Data Broker yapısı
- [ ] Power Cell yapısı (kapsama alanı gösterimi)
- [ ] Coolant Rig yapısı
- [ ] Her yapının durum barları (doluluk, ısı)

### Faz 3: Bağlantı ve Veri Akışı
- [ ] Yapılar arası link çekme (kablo sistemi)
- [ ] Akan veri parçacıkları (yeşil 0/1'ler)
- [ ] Parlayan bağlantı çizgileri

### Faz 4: Shader ve Efektler
- [ ] Bloom shader (neon parlama)
- [ ] CRT shader (tarama çizgileri)
- [ ] Vignette (kenar kararma)
- [ ] Yapı kenar glow efekti

### Faz 5: Temel Mekanik
- [ ] Uplink veri üretimi (basit sayı akışı)
- [ ] Storage doluluk mekaniği
- [ ] Data Broker → Credits kazanımı
- [ ] Power Cell zone mekaniği (güç yoksa yapı durum)
- [ ] Heat birikimi + Coolant Rig soğutma

### Faz 6: Screenshot ve Steam Sayfası
- [ ] UI çerçevesi (Credits göstergesi, Heat/Trace barları)
- [ ] Ekran görüntüleri al
- [ ] Steam sayfası aç

---

## Önemli Kurallar
- Kullanıcı teknik değil - ne ve neden açıkla, kod detayı değil
- Her commit kullanıcı onayı ile yapılır
- Commit ve push birlikte yapılır
