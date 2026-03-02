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

## MCP Entegrasyonu (Godot MCP Server)

### Kurulu MCP: tomyud1/godot-mcp (32 araç)
- **Bağlantı:** WebSocket port 6505 (Godot Plugin ↔ MCP Server)
- **Gereksinim:** Godot editöründe "Godot AI Assistant tools MCP" eklentisi aktif olmalı
- **Doğrulama:** Godot editöründe sağ üstte "MCP Connected" (yeşil) görünmeli

### MCP Araçları ve Kullanım Kuralları

**Sahne İşlemleri:** Sahne oluştur, node ekle/sil, property ayarla, script bağla
**Dosya İşlemleri:** Proje dosyalarını tara, oku, script oluştur
**Proje Bilgisi:** Ayarlar, input map, collision layer, konsol hataları, sahne ağacı
**Script İşlemleri:** Kod düzenle, syntax doğrula, referans güncelle

### MCP Kullanım Öncelikleri
1. **Hata okuma:** Önce MCP ile `get console errors` ve sahne ağacını kontrol et
2. **Sahne düzenleme:** Basit node/property değişikliklerinde MCP kullan
3. **Script yazma:** Karmaşık scriptleri Edit/Write tool ile yaz, MCP ile doğrula
4. **Dosya arama:** Proje içi arama için MCP'nin filesystem taramasını kullan

---

## Loglama Kuralları

### YAPILACAK (Event-Based Loglama)
- Durum değişikliklerinde logla (yapı yerleştirildi, bağlantı kuruldu, veri işlendi)
- Hata anında logla (yetersiz güç, depolama dolu, bağlantı başarısız)
- Oyuncu aksiyonlarında logla (satın alma, yerleştirme, silme)
- Log formatı: `[SistemAdı] Olay açıklaması — ilgili_değer`
- Örnek: `[Power] Cell placed at (3,5) — zone_radius: 4`
- Örnek: `[Storage] Capacity full — current: 100/100`

### YAPILMAYACAK (Kaçınılacak Loglar)
- `_process()` veya `_physics_process()` içinde her frame log BASMA
- Timer tick'lerinde sürekli tekrar eden log BASMA
- Normal akışta "her şey yolunda" logu BASMA
- Büyük veri yapılarını (dictionary, array) serialize edip log BASMA

### Debug Seviyeleri
- **print()** → Geliştirme sırasında geçici, sonra kaldırılacak
- **push_warning()** → Beklenmedik ama kurtarılabilir durumlar
- **push_error()** → Gerçek hatalar, düzeltilmesi gereken şeyler
- Release build'de gereksiz print'ler temizlenmeli

---

## Önemli Kurallar
- Kullanıcı teknik değil - ne ve neden açıkla, kod detayı değil
- Her commit kullanıcı onayı ile yapılır
- Commit ve push birlikte yapılır
- MCP bağlantısı yoksa klasik workflow: kod yaz → kullanıcı test et → hata paylaş
