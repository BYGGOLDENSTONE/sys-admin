# SYS_ADMIN - Proje Durumu

## Mevcut Aşama: DEMO GELİŞTİRME — Faz 4 Tamamlandı → Kullanıcı Testi Bekliyor
Vertical slice tamamlandı. Demo Faz 1-3 tamamlandı. Faz 4 (Quarantine + Malware) implementasyonu bitti, kullanıcı testi bekliyor. Hedef: Haziran 2026 Steam Next Fest.

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

### Component-Based Mimari (Kompozisyon) — UYGULAMADA

Yapılar özel sınıflar değil, **component Resource'larının birleşimi.** Her component `resources/components/` altında ayrı bir Resource scripti:

| Component Resource | Dosya | Ne Yapar |
|-------------------|-------|----------|
| `GeneratorComponent` | `generator_component.gd` | Veri üretir (`generation_rate`, `data_weights`) |
| `StorageComponent` | `storage_component.gd` | Veri depolar (`capacity`, `forward_rate`) |
| `SellerComponent` | `seller_component.gd` | Veri satar (`sell_rate`, `credits_per_mb`, `accepted_types`) |
| `PowerProviderComponent` | `power_provider_component.gd` | Zone'da güç sağlar (`zone_radius`, `power_output`) |
| `CoolantComponent` | `coolant_component.gd` | Zone'da soğutur (`zone_radius`, `cooling_rate`) |
| `ProcessorComponent` | `processor_component.gd` | Veri işler (`processing_rate`, `input_types`, `output_type`, `rule`, `efficiency`) |
| `ResearchCollectorComponent` | `research_collector_component.gd` | Research verisini tüketip RP üretir (`collection_rate`, `accepted_types`, `research_per_mb`) |
| `UpgradeComponent` | `upgrade_component.gd` | Yapı upgrade yolunu tanımlar (`max_level`, `costs`, `stat_target`, `level_values`) |

**Yapı = BuildingDefinition + opsiyonel component'ler.** `BuildingDefinition`'da her component nullable export:
```
@export var generator: GeneratorComponent    # null = bu yapı üretici değil
@export var storage: StorageComponent        # null = bu yapı depolama yapmaz
@export var seller: SellerComponent          # null = bu yapı satış yapmaz
@export var upgrade: UpgradeComponent        # null = bu yapı upgrade edilemez
...
```

**Helper methodlar** (`BuildingDefinition` üzerinde):
- `get_zone_radius() -> float` — power_provider veya coolant'tan zone_radius döner
- `is_infrastructure() -> bool` — power_provider veya coolant varsa true
- `get_storage_capacity() -> int` — storage varsa capacity döner

### Mevcut Yapı-Component Eşlemesi
- **Uplink** = `generator` component (5 MB/s, karma veri)
- **Storage** = `storage` component (100 MB kapasite)
- **Data Broker** = `seller` component (3 MB/s, Clean only)
- **Power Cell** = `power_provider` component (192px zone, 50W)
- **Coolant Rig** = `coolant` component (192px zone, 2°C/s)
- **Separator** = `processor` component (rule="separator", 5 MB/s, %60 verimlilik) + `storage` (20 MB buffer)
- **Compressor** = `processor` component (rule="compressor", 5 MB/s, %75 verimlilik) + `storage` (10 MB buffer)
- **Decryptor** = `processor` component (rule="decryptor", 4 MB/s, %70 verimlilik, encrypted→research) + `storage` (10 MB buffer)
- **Research Lab** = `research_collector` component (5 MB/s, 1 RP/MB) + `storage` (20 MB buffer)
- **Recoverer** = `processor` component (rule="recoverer", 4 MB/s, %70 verimlilik, corrupted→patch data) + `storage` (10 MB buffer)
- **Quarantine** = `processor` component (rule="quarantine", 4 MB/s, %100 verimlilik, malware→imha) + `storage` (10 MB buffer) + `upgrade` (processing_rate)
- **Splitter/Merger vb.** = henüz component yok (pasif yapılar, demo'da aktifleşecek)

### Data-Driven Tasarım
- Yapı değerleri → **component sub-resource** olarak .tres dosyasında
- Yeni yapı eklemek = yeni .tres + mevcut component'leri birleştirmek
- Yeni davranış = yeni component Resource scripti + SimulationManager'da handler

### Sistemler Arası İletişim
- Sistemler birbirini doğrudan çağırmaz
- Godot **signal** sistemi ile gevşek bağlı (loose coupling)
- Port'lar evrensel: çıkış tipi uyuşan her şey birbirine bağlanabilir
- Oyuncu beklenmedik kombinasyonlar bulabilmeli

### Kurallar — HER DEĞİŞİKLİKTE UYGULA
- **ASLA** `building_type == "xxx"` string kontrolü YAZMA → `if def.component != null` kullan
- **ASLA** yapıya özel davranışı if/match ile kodlama → component varlığını kontrol et
- Değerleri koda gömme → component Resource'a koy
- Yeni yapı için yeni script yazma → mevcut component'leri .tres'de birleştir
- Yeni mekanik gerekiyorsa → yeni component Resource scripti oluştur
- Sistem eklerken diğer sistemleri bilmek zorunda olma → signal ile haberleş
- `SimulationManager`'da tip kontrolü: `b.definition.generator != null` (string değil)
- `building.gd`'de alan erişimi: `definition.get_zone_radius()`, `definition.get_storage_capacity()`, `definition.is_infrastructure()` (doğrudan alan değil)

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
- [x] Power Cell zone mekaniği (kare bazlı: her kare ayrı PC'den güç alabilir)
- [x] Heat birikimi + Coolant Rig soğutma (overheat + recovery)
- [x] Power Cell ısı üretimi (zone içindeki çalışan yapı kare sayısına orantılı)
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

## Demo Planı

### Faz 1: Separator + Compressor ✓
- [x] Separator aktifleştirme (ham veriyi tiplere ayırma, %60 verimlilik)
- [x] Compressor aktifleştirme (veri sıkıştırma, %75 çıktı)
- [x] ProcessorComponent entegrasyonu (SimulationManager'da _update_processing)
- [x] Port-aware veri gönderme (_push_data_from port filtresi)
- [x] Separator filtre mekaniği (clean → right port, diğer → bottom port)
- [x] Keşif sistemi (bilinmeyen veri tipleri ??? → ilk keşif anı + bildirim)
- [x] Bilgi paneli güncelleme (processor yapılar: hız, verimlilik, filtre bilgisi)
- [x] AutoPlay test senaryosu (separator_compressor_test.json — PASSED)

### Faz 2: Decryptor + Research Lab ✓
- [x] Decryptor aktifleştirme (Encrypted → Research, 4 MB/s, %70 verimlilik)
- [x] Research Lab aktifleştirme (Research puanı biriktirme, 5 MB/s, 1 RP/MB)
- [x] ResearchCollectorComponent oluşturma (yeni component)
- [x] "research" veri tipi ekleme (5. tip, keşif sistemi dahil)
- [x] Teknoloji ağacı UI ([T] tuşuyla açılır, RP ile yapı kilidi açma)
- [x] Research puanı UI göstergesi (Credits yanında)
- [x] Veri tipi filtresi (accepts_data_type — yapılar sadece işleyebildikleri tipleri kabul eder)
- [x] Bilgi paneli + tooltip güncelleme (Decryptor, Research Lab, renk kodları)
- [x] AutoPlay test senaryosu (decryptor_research_test.json — PASSED)
- [x] Görsel mod senaryo desteği (senaryo bitince oyun kapanmaz)

### Faz 2 Düzeltmeleri ✓
- [x] **Her porttan tek kablo kuralı** — 1 output port = 1 kablo çıkış, 1 input port = 1 kablo giriş
- [x] **Processor yapılarda buffer kaldırma** — Separator/Compressor/Decryptor'da doluluk barı gizle, gönderilemeyen veri otomatik silinsin (tıkanma olmasın)
- [x] **Parçacık efekti düzeltmesi** — Veri akışı durduğunda downstream kablo parçacıkları da durmalı
- [x] **Ctrl+sürükle yapı taşıma** — Ctrl basılıyken yapıyı kablolarıyla birlikte yeni konuma taşı

### Faz 3: Recoverer + Patch Data ✓
- [x] Recoverer aktifleştirme (Corrupted → Patch Data, 4 MB/s, %70 verimlilik)
- [x] Patch Data global kaynak + UI göstergesi (Credits/Research yanında)
- [x] UpgradeComponent sistemi (data-driven, .tres konfigürasyonlu)
- [x] Yapı upgrade mekaniği (get_effective_value, 6 yapıda 3 seviye upgrade)
- [x] Yapı seçim + Upgrade UI paneli ("Geliştir" butonu, maliyet, stat gösterimi)
- [x] Tooltip güncelleme (Recoverer bilgisi, upgrade seviye gösterimi, efektif değerler)

### Faz 4: Quarantine + Malware (Kullanıcı Testi Bekliyor)
- [x] Quarantine aktifleştirme (Malware bertaraf, 4 MB/s, %100 imha)
- [x] Malware ısı hasarı (malware tutan yapılara 0.3°C/s per MB ekstra ısı)
- [x] Uyarı sistemi UI (ilk malware hasarında kırmızı bildirim)
- [x] Malware görsel overlay (mor-kırmızı titreme, overheat'ten ayrı)
- [x] Tooltip güncelleme (Quarantine giriş/çıkış, malware uyarı satırı)
- [x] UpgradeComponent (processing_rate: 4→5→6→8 MB/s, Patch Data maliyeti)
- [x] AutoPlay test senaryosu (quarantine_malware_test.json — PASSED)
- [ ] Kullanıcı görsel/UX testi

### Faz 5: Splitter + Merger
- [ ] Splitter aktifleştirme (1→N veri dağıtımı)
- [ ] Merger aktifleştirme (N→1 veri birleştirme)
- [ ] Kablo yönetimi iyileştirmeleri
- [ ] Bilgi paneli + tooltip güncelleme

### Faz 6: Trace + Veri Kaynakları
- [ ] Trace sistemi (global sayaç, kaynak erişimi kısıtlama)
- [ ] Trace UI göstergesi
- [ ] Uplink kaynak seçim menüsü (Web, Deep Web, Corporate, Military, Blackwall)
- [ ] Kaynak bazlı veri dağılımı farklılıkları

### Faz 7: Ekonomi + Undo/Redo
- [ ] Credits ile yapı satın alma sistemi
- [ ] Yapı mağazası UI
- [ ] Undo/Redo sistemi
- [ ] Fiyat dengeleme

### Faz 8: Hız Kontrolü + Polish
- [ ] Hız kontrolü (1x, 2x, 3x + duraklat)
- [ ] Overlay modları ([H] ısı haritası, [E] enerji haritası)
- [ ] Genel UI polish
- [ ] Yapı seçim paneli kategori grupları

### Her Fazda Sürekli
- Bilgi paneli güncellenmesi (yeni yapılar eklendikçe)
- Tooltip güncellenmesi
- Test ve dengeleme

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
