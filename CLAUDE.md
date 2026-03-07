# SYS_ADMIN - Proje Durumu

## Mevcut Asama: v2.0 YENIDEN TASARIM — Grid Routing + Zengin Mekanik + Devre Karti Estetigi
Oyun sifirdan yeniden tasarlandi. Eski point-to-point kablo sistemi, tekduze isleyiciler ve zayif gorsellik yerine: Factorio-tarz grid routing, 9 farkli mekanik, Tron-tarz devre karti estetigi. Hedef: $9.99 fiyat, 100K+ satis, Haziran 2026 Steam Next Fest.

## Tasarim Dokumani
- **GDD:** `docs/GDD.md` (v2.0) — Tum tasarim kararlari burada

## Proje Ozeti
- **Tur:** 2D Top-Down Chill Otomasyon
- **Tema:** Cyberpunk / Netrunner / Siberuzay
- **Motor:** Godot 4.6
- **Sanat:** Tamamen prosedürel (kod ile uretim) + shader efektleri
- **Vizyon:** Oyuncunun fabrikasi yukaridan bakildiginda canli bir devre karti gibi gorunur

---

## Mimari Felsefe

### Temel Ilke: Oyun Degil, Oyuncak Yap
Sistemler oyunu. Oyuncu sandbox dunyada kendi cozumlerini bulur. Hardcoded davranislar degil, birbirine takilan Lego bloklari.

### Component-Based Mimari (Kompozisyon)

Yapilar ozel siniflar degil, **component Resource'larinin birlesiimi.** Her component `resources/components/` altinda ayri bir Resource scripti.

**Yapi = BuildingDefinition + opsiyonel component'ler:**
```
@export var generator: GeneratorComponent          # Uplink
@export var classifier: ClassifierComponent        # Classifier
@export var separator: SeparatorComponent          # Separator
@export var dual_input: DualInputComponent         # Decryptor, Compiler
@export var probabilistic: ProbabilisticComponent  # Recoverer
@export var capacity_processor: CapacityComponent  # Quarantine
@export var replicator: ReplicatorComponent        # Replicator
@export var producer: ProducerComponent            # Research Lab
@export var storage: StorageComponent              # Storage
@export var splitter: SplitterComponent            # Splitter
@export var merger: MergerComponent                # Merger
@export var gig_board: GigBoardComponent           # Gig Board
@export var upgrade: UpgradeComponent              # Upgrade destegi
```

### Yapi-Component Eslesmesi

| Yapi | Component(ler) | Benzersiz Mekanik |
|------|---------------|-------------------|
| **Uplink** | `generator` | Kaynaktan veri ceker |
| **Classifier** | `classifier` | Content tipine gore N cikis |
| **Separator** | `separator` | State'e gore 4 cikis |
| **Decryptor** | `dual_input` | Veri + Key → Clean (surekli Key tuketir) |
| **Recoverer** | `probabilistic` | %70 basari + Residue yan urunu |
| **Quarantine** | `capacity_processor` | 50 MB kapasite, doldur/bosalt dongusu |
| **Compiler** | `dual_input` | 2 Clean → 1 Refined (tarif sistemi) |
| **Replicator** | `replicator` | 1 → 2 kopya (yavas, degerli) |
| **Research Lab** | `producer` | Research(Clean) → Key uretir |
| **Storage** | `storage` | Buffer + malzeme havuzu |
| **Splitter** | `splitter` | 1→2 esit dagitim |
| **Merger** | `merger` | 2→1 birlestirme |
| **Bridge** | (ozel) | Kablo kesisme noktasi |
| **Gig Board** | `gig_board` | Sozlesme terminali |

### Grid Kablo Sistemi (YENI — v2.0)
Eski point-to-point kablo sistemi TAMAMEN degisiyor:
- Kablolar grid karelerinde tile-by-tile dosenilir
- Her kablo segmenti bir grid hucresi kaplar
- Iki kablo ayni hucreyi paylasamaz
- Kesisme icin Bridge binasi gerekli
- Veri kablo boyunca gorulebilir sekilde akar

**Veri Yapilari:**
- `CableSegment`: pozisyon (grid cell), yon, gorsel state
- `CablePath`: iki port arasi siralı segment listesi
- `CableGrid`: 2D array — hangi hucreler kablo iceriyor

### Data-Driven Tasarim
- Yapi degerleri → component sub-resource olarak .tres dosyasinda
- Yeni yapi eklemek = yeni .tres + mevcut component'leri birlestirmek
- Yeni davranis = yeni component Resource scripti
- Compiler tarifleri = data resource (.tres)

### Sistemler Arasi Iletisim
- Sistemler birbirini dogrudan cagirmaz
- Godot signal sistemi ile gevsek bagli (loose coupling)
- Port'lar evrensel: cikis tipi uyusan her sey birbirine baglanabilir

### Kurallar — HER DEGISIKLIKTE UYGULA
- **ASLA** `building_type == "xxx"` string kontrolu YAZMA → `if def.component != null` kullan
- **ASLA** yapiya ozel davranisi if/match ile kodlama → component varligini kontrol et
- Degerleri koda gomme → component Resource'a koy
- Yeni yapi icin yeni script yazma → mevcut component'leri .tres'de birlestir
- Sistem eklerken diger sistemleri bilmek zorunda olma → signal ile haberles

---

## Mevcut Kod Durumu

### Calisan Sistemler
- Grid sistemi (`grid_system.gd`) — 512x512, hucre yonetimi + kablo hucre takibi
- Grid kablo sistemi (`connection_manager.gd` + `connection_layer.gd`) — L-shaped routing, grid-based rendering
- Veri modeli (`data_enums.gd`) — 6 content + 4 state tam
- Bina yerlestirme (`building.gd` + `building_manager.gd`) — grid-based placement + kablo routing
- Simulasyon (`simulation_manager.gd`) — veri akisi, uretim, isleme (credits/seller kaldirildi)
- Fog of War (`fog_layer.gd`) — chunk-based
- Kamera (`camera.gd`) — zoom + pan
- Undo sistemi (`undo_manager.gd`) — kablo path destegi eklendi
- Shader'lar (`bloom_vignette.gdshader`, `crt.gdshader`)
- UI (top_bar, building_panel, tooltip, minimap)
- Test sistemi (auto_play_manager, data_collector)
- Prosedürel bina ikonlari (building.gd icinde)

### Degistirilmesi Gereken (Henuz Yapilmadi)
- **Harita uretimi** — ring/halka sistemi → rastgele dagitim (Factorio modeli)
- **Kaynak isimleri** — ISP Backbone, Public Database → Otomat, ATM, Akilli Kilit vb.
- **Component mimarisi** — tek ProcessorComponent + rule string → her mekanik ayri component
- **Ekonomi** — upgrade maliyetleri henuz yok (v2.0 Veri=Malzeme sistemi bekliyor)

### Silinen Dosyalar (v2.0 Temizligi)
- `data_broker.tres` + `seller_component.gd` — SILINDI (para birimi yok)
- `compressor.tres` — SILINDI (scope disinda)
- `research_collector_component.gd` — SILINDI (ProducerComponent olacak)
- Ring border kodu (`grid_system.gd`'den kaldirildi)
- Credits/Research/PatchData UI ve signal'leri kaldirildi

### Mevcut .tres Dosyalari (9 bina, 8 kaynak)
**Binalar:** uplink, storage, separator, decryptor, recoverer, quarantine, research_lab, splitter, merger
**Kaynaklar:** isp_backbone, public_database, biotech_lab, corporate_server, government_archive, military_network, dark_web_node, blackwall_fragment
**Component'ler:** generator, processor, storage, upgrade (4 adet)

---

## Gelistirme Yol Haritasi v2.0 (Demo Odakli)

**Demo Kapsami (GDD Bolum 17):** 10 bina, 12-15 kaynak, 5 content, 3 state (Clean/Corrupted/Encrypted T1-T2), Malware/Quarantine/Gig Board YOK

### Faz 1: Grid Temeli + Eski Sistem Temizligi
- [x] Eski sistem temizligi (Data Broker, Compressor, ring kodu, seller component kaldirildi)
- [x] Grid kablo routing sistemi (L-shaped pathfinding, grid hucre takibi)
- [x] Kablo rendering (grid-based polyline + glow + akan veri partikulleri)
- [x] Temel kablo gorseli (grid boyutunda kanal + veri akis animasyonu)
- [ ] Bridge binasi (kablo kesisme noktasi)
- [ ] Splitter binasi (mevcut .tres var, component ayristir)
- [ ] Merger binasi (mevcut .tres var, component ayristir)
- [ ] Mevcut binalari kontrol: Uplink, Storage, Separator (calisiyor)
- [ ] Otomat kaynagi (ISP Backbone → Otomat olarak guncelle, Standard Clean only)

### Faz 2: Content Ayirma + Kolay Kaynaklar
- [ ] Classifier binasi + ClassifierComponent (content tipine gore N cikis)
- [ ] Kaynaklarda birden fazla content tipi
- [ ] Kolay kaynaklar: Otomat, ATM, Akilli Kilit, Trafik Kamerasi (.tres guncelle/olustur)
- [ ] State depolama maliyet farklari (Clean=1, Encrypted=2, Corrupted=3)
- [ ] Recoverer component ayristir (ProcessorComponent → ProbabilisticComponent, %70 basari + residue)
- [ ] Residue mekanigi (yan urun akisi)

### Faz 3: Sifreleme Pipeline'i + Orta Kaynaklar
- [ ] Research Lab yeniden yapilandir (ResearchCollector → ProducerComponent, Key uretimi)
- [ ] Decryptor yeniden yapilandir (ProcessorComponent → DualInputComponent, veri + key cift girdi)
- [ ] Key uretim + dagitim sistemi (Research Lab → kablo → Decryptor)
- [ ] Orta kaynaklar: Hastane Terminali, Halk Kutuphanesi, Magaza Sunucusu (.tres olustur)
- [ ] Encrypted state isleme (T1-T2)

### Faz 4: Crafting + Uretim + Zor Kaynaklar
- [ ] Compiler binasi + DualInputComponent (2 farkli Clean → 1 Refined)
- [ ] Refined malzeme sistemi
- [ ] Malzeme ile yapi uretme (ekonomi: credits → Veri = Malzeme)
- [ ] Kesif = Kilit Acma sistemi
- [ ] 4-5 Compiler tarifi (.tres)
- [ ] Zor kaynaklar: Corporate Server, Biyotek Labi (.tres guncelle)
- [ ] Replicator binasi + ReplicatorComponent (1 → 2 kopya, yavas)

### Faz 5: Harita + Prosedürel Dagitim (Demo Kapsaminda)
- [ ] Harita uretimini ring → rastgele dagitima cevir
- [ ] Spawn garanti kurallari (en az 2 kolay yakin, her content tipinden en az 1)
- [ ] Demo icin 12-15 kaynak/harita (kolay + orta + birkac zor gorunur)
- [ ] Kolay/orta/zor dagitim oranlari (cok zor demo'da YOK — Malware yok)
- [ ] Fog of war (mevcut, test et ve dogrula)
- [ ] Kaynak isimleri GDD ile esle (somut isimler: Otomat, ATM, Hastane vb.)

### Faz 6: Polish + Demo Build
- [ ] Tier sistemi (T1-T2 demo icin)
- [ ] Gorsel polish (tam devre karti estetigi — kablo + bina + zoom seviyeleri)
- [ ] Ses sistemi (bina sesleri, kablo snap, ambient, bildirimler)
- [ ] Demo milestone sistemi (GDD Bolum 17 — 7 milestone)
- [ ] Tutorial akisi
- [ ] Dengeleme testleri
- [ ] Steam Next Fest demo build (4-6 saat icerik)

### Her Fazda Surekli
- Bina bilgi paneli guncellemesi
- Tooltip guncellemesi
- AutoPlay test senaryolari
- Component-based mimari kurallarina uygunluk (rule string → ayri component)
- Gorsel polish iterasyonu

---

## MCP Entegrasyonu (Godot MCP Server)

### Kurulu MCP: tomyud1/godot-mcp (32 arac)
- **Baglanti:** WebSocket port 6505 (Godot Plugin <-> MCP Server)
- **Gereksinim:** Godot editorunde "Godot AI Assistant tools MCP" eklentisi aktif olmali
- **Dogrulama:** Godot editorunde sag ustte "MCP Connected" (yesil) gorunmeli

### MCP Kullanim Oncelikleri
1. **Hata okuma:** Once MCP ile konsol hatalari ve sahne agacini kontrol et
2. **Sahne duzenleme:** Basit node/property degisikliklerinde MCP kullan
3. **Script yazma:** Karmasik scriptleri Edit/Write tool ile yaz, MCP ile dogrula
4. **Dosya arama:** Proje ici arama icin MCP'nin filesystem taramasini kullan

---

## Loglama Kurallari

### YAPILACAK (Event-Based Loglama)
- Durum degisikliklerinde logla (yapi yerlestirildi, baglanti kuruldu, veri islendi)
- Hata aninda logla (depolama dolu, baglanti basarisiz, veri reddedildi)
- Oyuncu aksiyonlarinda logla (uretim, yerlestirme, silme)
- Log formati: `[SistemAdi] Olay aciklamasi — ilgili_deger`

### YAPILMAYACAK
- `_process()` veya `_physics_process()` icinde her frame log BASMA
- Timer tick'lerinde surekli tekrar eden log BASMA
- Buyuk veri yapilarini serialize edip log BASMA

### Debug Seviyeleri
- **print()** → Gelistirme sirasinda gecici
- **push_warning()** → Beklenmedik ama kurtarilabilir durumlar
- **push_error()** → Gercek hatalar

---

## Godot Yolu ve Test Prosesi

### Godot Calistirilabilir Dosya
- **Yol:** `D:\godot\Godot_v4.6-stable_win64_console.exe`

### Test Akisi
1. Godot'u headless/console ile calistir
2. MCP baglantisi kontrol et → `get_godot_status`
3. Script dogrula → `validate_script`
4. Sahne calistir
5. Konsol loglarini oku → `get_console_log` / `get_errors`
6. Hata varsa duzelt, yoksa kullaniciya bildir
7. Kullanici son testi yapar

### Komutlar
```bash
# Editoru ac
"D:/godot/Godot_v4.6-stable_win64_console.exe" --editor --path "D:/godotproject/sys-admin"

# Oyunu calistir
"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin"
```

### DIKKAT: Godot Yeniden Acma Kurali
- Godot'u acmadan once HER ZAMAN once mevcut surecleri oldur
- Ust uste acma YAPMA
- **Zorunlu sira:**
  1. `taskkill /F /IM Godot_v4.6-stable_win64_console.exe` VE `taskkill /F /IM Godot_v4.6-stable_win64.exe`
  2. `tasklist | grep -i godot` ile surec kalmadigini dogrula
  3. Ancak ondan sonra yeni Godot ac

---

## AutoPlay Test Sistemi

### Genel Bakis
Oyun mekaniklerini otomatik test edip veri toplayan sistem. JSON senaryolarla calisir, headless modda test eder.

### Dosyalar
| Dosya | Aciklama |
|-------|----------|
| `scripts/testing/auto_play_manager.gd` | JSON senaryo okur, adim adim calistirir |
| `scripts/testing/data_collector.gd` | Her tick'te snapshot, JSON'a yazar |
| `resources/test_scenarios/*.json` | Test senaryolari |
| `testing/analyzer.py` | Sonuclari analiz eder |

### Kullanim
```bash
# Headless senaryo calistir
"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin" --headless -- --scenario=res://resources/test_scenarios/test_name.json
```

---

## Onemli Kurallar
- Kullanici teknik degil — ne ve neden acikla, kod detayi degil
- Her commit kullanici onayi ile yapilir
- Commit ve push birlikte yapilir
- MCP baglantisi yoksa klasik workflow: kod yaz → kullanici test et → hata paylas
- Kod yazdiktan sonra once otomatik test prosesini uygula
