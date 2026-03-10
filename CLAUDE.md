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
@export var processor: ProcessorComponent          # Separator, Quarantine (rule-based)
@export var dual_input: DualInputComponent         # Decryptor, Compiler
@export var probabilistic: ProbabilisticComponent  # Recoverer
@export var producer: ProducerComponent            # Research Lab
@export var storage: StorageComponent              # Storage
@export var splitter: SplitterComponent            # Splitter
@export var merger: MergerComponent                # Merger
@export var compiler: CompilerComponent            # Compiler
@export var upgrade: UpgradeComponent              # Upgrade destegi
```

### Yapi-Component Eslesmesi

| Yapi | Component(ler) | Benzersiz Mekanik |
|------|---------------|-------------------|
| **Uplink** | `generator` | Kaynaktan veri ceker |
| **Classifier** | `classifier` | Content tipine gore N cikis |
| **Separator** | `processor` (rule="separator") | State/content filtre, 2 cikis |
| **Decryptor** | `dual_input` | Veri + Key → Clean (surekli Key tuketir) |
| **Recoverer** | `probabilistic` | %70 basari + Residue yan urunu |
| **Quarantine** | `processor` (rule="quarantine") | 50 MB kapasite, dol→flush(5s)→purge |
| **Compiler** | `compiler` | 2 Clean → 1 Refined (tarif sistemi) |
| **Research Lab** | `producer` | Research(Clean) → Key uretir |
| **Storage** | `storage` | Buffer + malzeme havuzu |
| **Splitter** | `splitter` | 1→2 esit dagitim |
| **Merger** | `merger` | 2→1 birlestirme |
| **Bridge** | (ozel) | Kablo kesisme noktasi |
| **Gig Board** | (henuz implemente edilmedi) | Sozlesme terminali |

### Grid Kablo Sistemi (v2.0.2 — Grid-by-Grid Routing)
Kablolar vertex-based (grid kesisim noktasi) edge sistemi kullanir:
- Oyuncu fareyi surukleyerek kabloyu elle cizer (otomatik pathfinding YOK)
- Kablolar grid kenarlarinda (vertex-to-vertex) ilerler, hucre merkezlerinden degil
- Her edge (kenar) iki vertex arasindaki baglanti — h_edges ve v_edges olarak takip edilir
- Iki kablo ayni edge'i paylasamaz (Bridge ile 2'ye kadar izin verilir)
- Kesisme icin Bridge binasi gerekli
- Veri kablo boyunca gorulebilir sekilde akar

**Kablo Cizim Sistemi (v2.0.2 — Grid-by-Grid):**
- Mouse her yeni grid vertex'e gectiginde 1 adim kablo karari alinir (frame-based chase YOK)
- Mouse vertex degismedikce islem yapilmaz (performans++)
- Hizli mouse hareketi icin vertex interpolasyonu (atlanan vertex'ler otomatik doldurulur)
- Backtrack: mouse mevcut path uzerinde geri giderse kablo otomatik kesilir
- Gorsel geri bildirim: gecerli path YESIL, engellenenmis kisim KIRMIZI

**Kablo Engelleme Kurali (v2.0.3 — Exempt Cells):**
- Temel kural: `_edge_touches_occupied(v1, v2, exempt_cells)` — edge'in yanindaki hucre doluysa engelle
- Capraz kose kontrolu: `is_turn_corner_occupied()` — kablo donuste capraz hucreye dokunmaz
- **Port Exit Exemption:** Kaynak/hedef binanin port exit vertex'leri etrafindaki 4 hucre muaf tutulur
- `_compute_port_exempt_cells()` → exit vertex etrafindaki hucreleri hesaplar
- Kablo cizimi baslarken FROM building exempt, baglanti tamamlanirken TO building de eklenir
- **Snap + Truncate:** Kablo exit vertex'ten gecip binaya uzanirsa, path otomatik kesilir (truncate)
- BFS tabanli `_find_snap_path()` → 3 adima kadar akilli yol bulma ile port'a snap
- Exit vertex'ler bina sinirinden 1 hucre disarida, port merkezine hizali

**Veri Yapilari:**
- `_cable_h_edges` / `_cable_v_edges`: kablo edge takibi (Vector2i → count)
- `_occupied_cells` / `_source_cells`: hucre doluluk takibi
- Cable path: `Array[Vector2i]` vertex listesi (port-to-port)

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
- Grid sistemi (`grid_system.gd`) — 512x512, hucre yonetimi + edge-based kablo takibi + exempt cell destegi
- Grid kablo sistemi (`connection_manager.gd` + `connection_layer.gd`) — Manuel vertex routing, edge-based rendering, port stub'lar, BFS snap
- Veri modeli (`data_enums.gd`) — 7 content (+ KEY) + 5 state + 5 RefinedType + Tier sistemi (T1-T4)
- Bina yerlestirme (`building.gd` + `building_manager.gd`) — grid-based placement + manuel kablo cizimi + malzeme maliyet sistemi
- Simulasyon (`simulation_manager.gd`) — veri akisi, uretim, isleme, compiler crafting, tier-aware processing
- Fog of War (`fog_layer.gd`) — chunk-based
- Kamera (`camera.gd`) — zoom + pan
- Undo sistemi (`undo_manager.gd`) — kablo path destegi eklendi
- Shader'lar (`bloom_vignette.gdshader`, `crt.gdshader`)
- UI (top_bar, building_panel, tooltip, minimap)
- Test sistemi (auto_play_manager, data_collector)
- Prosedürel bina ikonlari (building.gd icinde)
- Harita uretimi (`map_generator.gd`) — rastgele dagitim, difficulty-based, spawn garantileri
- Kaynak yonetimi (`source_manager.gd`) — difficulty-based kesfetme, uplink linking

### Degistirilmesi Gereken (Henuz Yapilmadi)
- **Component mimarisi** — Separator, Quarantine hala ProcessorComponent+rule kullanıyor → ayri component'lere gecis devam edecek
- **Yapi maliyetleri** — material_costs/refined_costs alani eklendi ama .tres'lerde henuz degerler set edilmedi (dengeleme bekliyor)

### Silinen Dosyalar (v2.0 Temizligi)
- `data_broker.tres` + `seller_component.gd` — SILINDI (para birimi yok)
- `compressor.tres` — SILINDI (scope disinda)
- `research_collector_component.gd` — SILINDI (ProducerComponent olacak)
- Ring border kodu (`grid_system.gd`'den kaldirildi)
- Credits/Research/PatchData UI ve signal'leri kaldirildi

### Renk Paleti (v2.0.3 — "Dark PCB" Palette C)

**State Renkleri:** Clean `#00ffaa`, Encrypted `#2288ff`, Corrupted `#ffaa00`, Malware `#ff1133`, Residue `#bbbb44`
**Content Renkleri:** Standard `#7788aa`, Financial `#ffcc00`, Biometric `#ff33aa`, Blueprint `#00ffcc`, Research `#9955ff`, Classified `#ff3388`, Key `#ffaa00`
**Refined Renkleri:** Calibrated `#22ffbb`, Recovery `#55bbff`, Security `#cc55ff`, Trade `#ffbb44`, Neural `#bb44ff`
**UI Accent:** `#00bbee` (teal-cyan)
**Arka Plan:** `#060a10` (koyu siyah), Grid: `#0f1520`, Bina gövde: `#0a0d14`
**Bina Renkleri (fonksiyon gruplari):** Routing=gri, Ayirma=teal, Isleme=amber, Uretim=mor, Depolama=yesil, Baslangic=cyan, Tehlike=kirmizi

### Mevcut .tres Dosyalari (12 bina, 14 kaynak)
**Binalar:** uplink, storage, separator, classifier, decryptor, recoverer, quarantine, research_lab, splitter, merger, bridge, compiler
**Kaynaklar:** isp_backbone (Otomat), atm, smart_lock, traffic_camera, public_database, hospital_terminal, public_library, shop_server, biotech_lab, corporate_server, government_archive, military_network, dark_web_node, blackwall_fragment
**Component'ler:** generator, processor, classifier, probabilistic, producer, dual_input, storage, upgrade, splitter, merger, compiler, compiler_recipe (12 adet)

---

## Gelistirme Yol Haritasi v2.0 (Demo Odakli)

**Demo Kapsami (GDD Bolum 17):** 10 bina, 12-15 kaynak, 5 content, 3 state (Clean/Corrupted/Encrypted T1-T2), Malware/Quarantine/Gig Board YOK

### Faz 1: Grid Temeli + Eski Sistem Temizligi
- [x] Eski sistem temizligi (Data Broker, Compressor, ring kodu, seller component kaldirildi)
- [x] Grid kablo routing sistemi (manuel vertex routing, edge-based takip, proximity bloklama)
- [x] Kablo rendering (vertex-based polyline + glow + akan veri partikulleri + port stub'lar)
- [x] Temel kablo gorseli (grid kenarlari boyunca kanal + veri akis animasyonu)
- [x] Bridge binasi (kablo kesisme noktasi — 1x1, allows_cable_crossing flag, 2 kablo destegi)
- [x] Splitter binasi (SplitterComponent ayristirildi, ProcessorComponent+rule kaldirildi)
- [x] Merger binasi (MergerComponent ayristirildi, ProcessorComponent+rule kaldirildi)
- [x] Mevcut binalari kontrol: Uplink, Storage, Separator (calisiyor)
- [x] Otomat kaynagi (ISP Backbone → Otomat, sadece Standard Clean)

### Faz 2: Content Ayirma + Kolay Kaynaklar
- [x] Classifier binasi + ClassifierComponent (content tipine gore N cikis, 3 output port)
- [x] Kaynaklarda birden fazla content tipi (Trafik Kamerasi: Standard + Biometric)
- [x] Kolay kaynaklar: ATM, Akilli Kilit, Trafik Kamerasi (.tres olusturuldu)
- [x] State depolama maliyet farklari (Clean=1, Encrypted=2, Corrupted=3, Malware=depolanamaz)
- [x] Recoverer component ayristirildi (ProcessorComponent → ProbabilisticComponent, %70 basari + residue)
- [x] Residue mekanigi (DataState.RESIDUE eklendi, Recoverer alt porttan Residue cikisi)
- [x] Classifier prosedürel ikonu eklendi
- [x] Tooltip guncellendi (Classifier + Recoverer bilgileri)

### Faz 3: Sifreleme Pipeline'i + Orta Kaynaklar
- [x] ProducerComponent olusturuldu (Research(Clean) tuketir → Key uretir, 5 MB → 1 Key)
- [x] DualInputComponent olusturuldu (cift girdi: veri + key, key yoksa durur)
- [x] Research Lab yeniden yapilandirildi (StorageComponent + ProducerComponent)
- [x] Decryptor yeniden yapilandirildi (ProcessorComponent → DualInputComponent, sol=veri, ust=key)
- [x] ContentType.KEY eklendi (kabloda gorunur Key akisi, renk: #ffaa00, sembol: K)
- [x] Key uretim + dagitim sistemi (Research Lab → kablo → Decryptor ust port)
- [x] Orta kaynaklar: Hastane Terminali, Halk Kutuphanesi, Magaza Sunucusu (.tres)
- [x] Map generator guncellendi (orta kaynaklar ring 1, corporate_server ring 2)
- [x] Tooltip guncellendi (Producer + DualInput bilgileri, Key stok gosterimi)
- [x] Encrypted state isleme (T1 — key_cost=1)

### Faz 4: Crafting + Uretim + Zor Kaynaklar
- [x] Compiler binasi + CompilerComponent (2 farkli Clean → 1 Refined, tarif tabanli)
- [x] Refined malzeme sistemi (RefinedType enum: 5 tip, renk + isim)
- [x] Malzeme ile yapi uretme (material_costs + refined_costs alanlari, Storage'dan kontrol/dusme)
- [x] Kesif = Kilit Acma sistemi (tech_tree_panel → discovery-based otomatik acilma)
- [x] 5 Compiler tarifi (Calibrated Data, Recovery Matrix, Security Core, Trade License, Neural Index)
- [x] Zor kaynaklar: Corporate Server, Biyotek Labi (.tres GDD'ye uygun guncellendi)
- [x] Replicator KALDIRILDI (gereksiz — Splitter zaten 1→2 yapiyor, kaynaklar tukenmez)
- [x] Compiler prosedürel ikonu eklendi
- [x] Tooltip guncellendi (Compiler tarif esleme, Storage refined gosterimi)
- [x] Building panel'de maliyet tooltip'i eklendi

### Faz 5: Harita + Prosedürel Dagitim (Demo Kapsaminda)
- [x] Harita uretimini ring → rastgele dagitima cevir (Factorio modeli)
- [x] Spawn garanti kurallari (en az 2 kolay yakin + 1 orta yakin)
- [x] 25-35 kaynak/harita (kolay %40 + orta %30 + zor %20 + endgame %10)
- [x] Difficulty sistemi (easy/medium/hard/endgame — ring_index kaldirildi)
- [x] Kaynak isimleri Turkcelestirildi (Otomat, ATM, Hastane, Devlet Arsivi vb.)
- [ ] Fog of war (mevcut, test et ve dogrula)

### Faz 6: Polish + Demo Build (AKTIF — Gorsel Polish)
- [x] Tier sistemi (T1-T4 destegi, demo icin T1-T2 aktif)
- [x] Kamera shake: Trauma-based + FastNoiseLite (Squirrel Eiserloh tekniği)
- [x] Bina yerlestirme animasyonu: Scale pop + flash (play_place_animation)
- [x] Bina glow: Working state farki (daha parlak pulse + port glow)
- [x] Kablo glow: 4 katmanli rendering (outer halo + mid glow + core + highlight)
- [x] Kablo partikulleri: Glow halo + inner glow + beyaz karakter overlay
- [x] Grid cell underglow: Bina/kablo hucreleri icin kamera-culled rendering
- [x] Floating text: Scale pop + float up + fade out (Decryptor/Compiler/Quarantine)
- [x] UI panel: Yari saydam + staggered button fade-in + slide-in animasyonu
- [x] Tooltip animasyonu: Fade + slide (acilma/kapanma)
- [x] Shader: Tilt-shift DoF + vignette + glitch sistemi (bloom_vignette + crt)
- [x] Zoom-adaptive rendering: 3 katman (PCB <0.45, Medium 0.45-0.7, Full >0.7)
- [x] Kaynak PCB modu: Zoom-compensated soft glow daireleri (piksel artifact yok)
- [x] Bina PCB modu: Dairesel halo + chip gorunumu
- [x] Kaynak medium modu: Hucre + glow halo + kalin border
- [x] Bina secim highlight: Cyberpunk corner brackets + scan line
- [x] Kablo baglanti flash efekti: Expanding ring + fade
- [x] Minimap: Kablo cizimi + bina glow + cyberpunk cerceve
- [x] Fog of war: Edge softening (kenar chunk'lar yari saydam)
- [x] UI: Top bar speed pulse, upgrade panel fade, tech tree slide animasyonu
- [x] CRT glitch entegrasyonu: Kesif/unlock olaylarinda tetikleme
- [x] Gorsel polish: Bina breathing + processing flash + smooth fill bar + silme animasyonlari + kablo silme flash + chromatic aberration
- [x] Ses sistemi: Prosedürel ses (sine/square/saw sentezi), bina/kablo/kesif/isleme sesleri, ambient drone, SoundManager
- [x] Renk paleti yeniden tasarim: "Dark PCB" Palette C — color theory tabanli, readability-first, fonksiyon grubu bina renkleri
- [x] Kablo baglanti fix: Port exit exempt cells + path truncation + BFS snap (v2.0.3)
- [ ] Demo milestone sistemi (GDD Bolum 17 — 7 milestone)
- [ ] Tutorial akisi
- [ ] Dengeleme testleri
- [ ] Steam Next Fest demo build (4-6 saat icerik)

### Her Fazda Surekli
- Bina bilgi paneli guncellemesi
- Tooltip guncellemesi
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

## Onemli Kurallar
- **OYUN DILI INGILIZCE** — Tum kullaniciya gorunen metinler (yapi isimleri, kaynak isimleri, tooltip'ler, bildirimler, badge'ler, UI label'lari) INGILIZCE olmali. Turkce string YAZMA. Log mesajlari da Ingilizce olmali.
- Kullanici teknik degil — ne ve neden acikla, kod detayi degil
- Her commit kullanici onayi ile yapilir
- Commit ve push birlikte yapilir
- MCP baglantisi yoksa klasik workflow: kod yaz → kullanici test et → hata paylas
- Test: kullanici manuel test eder, Claude log kontrolu yapar
