# SYS_ADMIN - Proje Durumu

## Mevcut Aşama: VERTICAL SLICE — Faz 3 tamamlandı, Faz 4 sırada
Tasarım çekirdek kararları tamamlandı (GDD v0.4). Vertical slice geliştiriliyor.

## Tasarım Dökümanı
- **GDD:** `docs/GDD.md` (v0.4) - Tüm tasarım kararları burada

## Proje Özeti
- **Tür:** 2D Top-Down Chill Otomasyon/Management
- **Tema:** Cyberpunk / Netrunner
- **Motor:** Godot 4.6
- **Sanat:** Tamamen prosedürel (kod ile üretim) + shader efektleri

---

## Mimari Felsefe: Oyun Değil, Oyuncak Yap

### Temel İlke
Bu bir sistemler oyunu. Oyuncu sandbox dünyada kendi çözümlerini bulmalı — geliştiricinin düşünmediği yollar dahil. Hardcoded davranışlar değil, birbirine takılan Lego blokları.

### Component-Based Mimari (Kompozisyon)
Yapılar özel sınıflar değil, **component'lerin birleşimi:**

| Component | Ne Yapar |
|-----------|----------|
| `PortComponent` | Giriş/çıkış slotları, hangi veri tiplerini kabul eder |
| `ProcessorComponent` | Girdiyi çıktıya dönüştürür (kural Resource'dan gelir) |
| `StorageComponent` | Veri depolar, kapasite sınırı |
| `HeatComponent` | Isı üretir veya soğutur |
| `PowerComponent` | Güç tüketir veya sağlar (zone) |

**Yapı = Node2D + Component'ler.** Davranış component'lerden gelir, yapı sadece konteyner.

### Örnek: Aynı Parçalar, Farklı Yapılar
- **Uplink** = Port(çıkış: tüm tipler) + Heat(üretir)
- **Storage** = Port(giriş: hepsi) + Storage(kapasite: 100) + Heat(üretir)
- **Separator** = Port(giriş: karışık, çıkış: tip başına) + Processor(kural: tipe_göre_ayır)
- **Coolant Rig** = Heat(soğutur, zone) + Power(tüketir)

### Data-Driven Tasarım
- Yapı değerleri (hız, kapasite, ısı üretimi) → **Resource dosyalarında** (.tres), kodda değil
- İşleme kuralları (ne girer → ne çıkar) → Resource'da tanımlı
- Yeni yapı eklemek = yeni Resource oluşturmak, yeni kod yazmak değil

### Sistemler Arası İletişim
- Sistemler birbirini doğrudan çağırmaz
- Godot **signal** sistemi ile gevşek bağlı (loose coupling)
- Port'lar evrensel: çıkış tipi uyuşan her şey birbirine bağlanabilir
- Oyuncu beklenmedik kombinasyonlar bulabilmeli

### Kurallar
- Yapıya özel `if uplink then...` kodu YAZMA → component davranışı yaz
- Değerleri koda gömme → Resource dosyasına koy
- Yeni yapı için yeni script yazma → mevcut component'leri birleştir
- Sistem eklerken diğer sistemleri bilmek zorunda olma → signal ile haberleş

---

## Geliştirme Yol Haritası

### 1. VERTICAL SLICE (Şu an) — Steam sayfası için görsel test
### 2. DEMO — Haziran Steam Next Fest için oynanabilir demo
### 3. RELEASE — Tam oyun

---

## Vertical Slice Planı

### Faz 1: Temel Grid ve Yerleştirme ✓
- [x] Grid sistemi (tile-based yerleştirme alanı)
- [x] Kamera kontrolleri (pan, zoom)
- [x] Tek yapı yerleştirme/kaldırma (placeholder kutu)
- [x] Yapı seçim paneli (hangi yapıyı yerleştireceğini seçme UI'ı)
- [x] Arka plan: koyu grid çizgileri

### Faz 2: İlk Yapılar (Görsel) ✓
- [x] Uplink yapısı (prosedürel çizim + neon glow)
- [x] Storage yapısı
- [x] Data Broker yapısı
- [x] Power Cell yapısı (kapsama alanı gösterimi)
- [x] Coolant Rig yapısı
- [x] Her yapının durum barları (doluluk, ısı)
- [x] Tooltip / bilgi kutusu (yapı üzerine gelince isim + açıklama)
- [x] Kalan 8 yapının tanımları (Separator, Compressor, Decryptor, Recoverer, Quarantine, Research Lab, Splitter, Merger)
- [x] 13 yapının tamamı için benzersiz prosedürel ikonlar

### Faz 3: Bağlantı ve Veri Akışı ✓
- [x] Yapılar arası link çekme (kablo sistemi)
- [x] Akan veri parçacıkları (yeşil 0/1'ler)
- [x] Parlayan bağlantı çizgileri

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

## Godot Yolu ve Otomatik Test Prosesi

### Godot Çalıştırılabilir Dosya
- **Yol:** `D:\godot\Godot_v4.6-stable_win64_console.exe`
- Console versiyonu kullanılır (çıktıyı okuyabilmek için)

### Otomatik Test Akışı (Kod Yazıldıktan Sonra)
1. **Godot'u headless/console ile çalıştır** → projeyi aç
2. **MCP bağlantısı kontrol et** → `get_godot_status`
3. **Script doğrula** → `validate_script` ile syntax hataları kontrol et
4. **Sahne çalıştır** → Godot'u oyun modunda başlat
5. **Konsol loglarını oku** → `get_console_log` / `get_errors` ile hataları kontrol et
6. **Hata varsa düzelt** → döngüye gir, hata yoksa kullanıcıya bildir
7. **Kullanıcı son testi yapar** → sadece görsel/UX onay kalır

### Komutlar
```bash
# Editörü aç (MCP bağlantısı için gerekli)
"D:/godot/Godot_v4.6-stable_win64_console.exe" --editor --path "D:/godotproject/sys-admin"

# Oyunu çalıştır (test için)
"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin"
```

### DİKKAT: Godot Yeniden Açma Kuralı — HER SEFERINDE UYGULA
- Godot'u açmadan önce **HER ZAMAN** önce mevcut süreçleri öldür
- Üst üste açma YAPMA — port çakışması ve MCP bağlantı sorunlarına yol açar
- **Zorunlu sıra:**
  1. `taskkill /F /IM Godot_v4.6-stable_win64_console.exe` VE `taskkill /F /IM Godot_v4.6-stable_win64.exe`
  2. `tasklist | grep -i godot` ile süreç kalmadığını doğrula
  3. Ancak ondan sonra yeni Godot aç

---

## Önemli Kurallar
- Kullanıcı teknik değil - ne ve neden açıkla, kod detayı değil
- Her commit kullanıcı onayı ile yapılır
- Commit ve push birlikte yapılır
- MCP bağlantısı yoksa klasik workflow: kod yaz → kullanıcı test et → hata paylaş
- Kod yazdıktan sonra önce otomatik test prosesini uygula, kullanıcıya sadece son test kalmalı
