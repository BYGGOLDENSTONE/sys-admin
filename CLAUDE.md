# SYS_ADMIN - Proje Durumu

## Mevcut Aşama: VERTICAL SLICE TAMAMLANDI — Sırada DEMO
Tasarım çekirdek kararları tamamlandı (GDD v0.4). Vertical slice tamamlandı. Sırada Steam sayfası ve demo hazırlığı.

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

### Faz 4: Shader ve Efektler ✓
- [x] Bloom shader (neon parlama)
- [x] CRT shader (tarama çizgileri + chromatic aberration + barrel distortion)
- [x] Yapı kenar glow efekti (nabız animasyonu + geniş dış halo)
- [x] Veri parçacıkları iyileştirmesi (büyük, sık, zoom-adaptif)

### Faz 5: Temel Mekanik ✓
- [x] SimulationManager (1s tick, tüm mekaniği yönetir)
- [x] Veri birimi: 1 MB paket (MB/s hız, GB/TB ölçekleme)
- [x] Uplink veri üretimi (5 MB/s, rastgele tip dağılımı)
- [x] Storage doluluk mekaniği (100 MB kapasite, forward)
- [x] Data Broker → Credits kazanımı (3 MB/s, Clean only)
- [x] Power Cell zone mekaniği (kare grid, tüm tile zone içinde olmalı)
- [x] Heat birikimi + Coolant Rig soğutma (overheat + recovery)
- [x] Power Cell ısı üretimi (zone içindeki yapı sayısına orantılı)
- [x] Güçsüz yapı karartma (glow yok, sönük border/ikon) + overheat kırmızı overlay
- [x] Aktif olmayan bağlantılarda parçacık akışı durur (güçsüz veya storage dolu)
- [x] Zone önizlemesi (yerleştirme sırasında etkilenecek yapılar yeşil highlight)
- [x] Credits UI göstergesi

### Faz 6: Bilgi Paneli ve Mekanik Düzeltmeleri ✓
- [x] Detaylı yapı bilgi paneli (hover: durum, akış, doluluk, ısı, güç, zone bilgisi)
- [x] Canlı güncellenen istatistikler (RichTextLabel + BBCode renk kodlu)
- [x] Yapı tipi bazlı bilgi gösterimi (generator/storage/seller/power/coolant)
- [x] Isı mekanığı düzeltmesi: sadece çalışan yapılar ısı üretir
- [x] Kablo görünürlük düzeltmesi: inaktif kablolar görünür kalır (0.3 alpha)
- [x] Doğal soğuma sadece boştaki yapılara uygulanır (çalışanlar Coolant Rig şart)

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

## AutoPlay Test Sistemi

### Genel Bakış
Oyun mekaniklerini otomatik test edip veri toplayan sistem. JSON senaryolarla çalışır, headless modda test eder, Python ile analiz yapar.

### Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `scripts/testing/auto_play_manager.gd` | JSON senaryo okur, adım adım çalıştırır |
| `scripts/testing/data_collector.gd` | Her tick'te oyun state'ini snapshot'lar, JSON'a yazar |
| `resources/test_scenarios/*.json` | Test senaryoları |
| `testing/analyzer.py` | Python: sonuçları analiz eder, grafik çizer |

### Senaryo Formatı (JSON)
```json
{
  "name": "Test Adı",
  "actions": [
    {"action": "place", "building": "uplink", "cell": [10, 12], "id": "up1"},
    {"action": "connect", "from": "up1", "from_port": "right", "to": "st1", "to_port": "left"},
    {"action": "wait_ticks", "count": 30},
    {"action": "snapshot", "label": "checkpoint"},
    {"action": "assert", "check": "credits_gt", "value": 0},
    {"action": "remove", "id": "up1"}
  ]
}
```

### Desteklenen Aksiyonlar
| Aksiyon | Açıklama |
|---------|----------|
| `place` | Yapı yerleştir (building adı = .tres dosya adı) |
| `connect` | İki yapıyı bağla (id referanslarıyla) |
| `remove` | Yapı kaldır |
| `wait_ticks` | N tick bekle |
| `snapshot` | Anlık durum kaydı al |
| `assert` | Koşul kontrol (credits_gt/lt, building_overheated, building_active, storage_above/below) |

### Kullanım
```bash
# Headless senaryo çalıştır
"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin" --headless -- --scenario=res://resources/test_scenarios/basic_income.json

# Sonuçları analiz et
python testing/analyzer.py                    # En son sonucu otomatik bul
python testing/analyzer.py --no-charts        # Sadece konsol raporu
python testing/analyzer.py path/to/file.json  # Belirli dosya
```

### Ölçeklenebilirlik
- **Yeni yapı eklendi** → senaryoda hemen kullanılır, kod değişmez
- **Yeni aksiyon gerekli** → `auto_play_manager.gd`'ye `_handle_xxx()` method ekle
- **Yeni metrik gerekli** → `data_collector.gd`'de snapshot'a 1 satır ekle
- **Yeni test** → `resources/test_scenarios/` altına yeni JSON dosyası

### Programatik API (BuildingManager)
- `place_building_at(def: BuildingDefinition, cell: Vector2i) -> Node2D`
- `remove_building_at(cell: Vector2i) -> bool`
- Bu API'lar AutoPlay dışında da kullanılabilir (ör: tutorial, undo sistemi)

### Sonuç Dosyaları
- Konum: `user://test_results/` (Windows: `%APPDATA%/Godot/app_userdata/SYS_ADMIN/test_results/`)
- Format: JSON (tick bazlı snapshot'lar: credits, ısı, güç, storage, bağlantılar)

---

## Önemli Kurallar
- Kullanıcı teknik değil - ne ve neden açıkla, kod detayı değil
- Her commit kullanıcı onayı ile yapılır
- Commit ve push birlikte yapılır
- MCP bağlantısı yoksa klasik workflow: kod yaz → kullanıcı test et → hata paylaş
- Kod yazdıktan sonra önce otomatik test prosesini uygula, kullanıcıya sadece son test kalmalı
