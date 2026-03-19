# SYS_ADMIN - Proje Durumu

## Mevcut Asama: v5 Tasarim Revizyonu — Implementasyon oncesi
- **GDD:** `docs/GDD.md` (v5.0 — buyuk tasarim revizyonu)
- **Kod durumu:** v4 Faz 1-7 TAMAMLANDI, v5 Faz 1-9 TAMAMLANDI + UI polish — playtest asamasinda
- **Hedef:** Steam Next Fest icin oynanabilir, polished, v5 mekanikli demo
- **Ticari hedef:** $9.99 fiyat noktasina yakisan kalite ve guven hissi

---

## North Star — Ters Shapez
```
Shapez:      Basit parcalar → isle → karmasik urun → teslim
SYS_ADMIN:   Karmasik kaynak → guvenlik as → ayikla/coz/onar → saf veri → teslim
```
- Oyuncu insa etmiyor, **aritiyor.** Content = sekil, State = renk.
- Kaynaklar birbirini besler: Easy → Medium → Hard bagimlilik zinciri
- "Basit mekanik + derin kombinasyon + guzel layout" hissi satacak
- Gorsel dil: **procedural / abstract / readable cyber-board** estetigi

---

## Kilitlenmis Tasarim Kararlari (v5) — Scope Lock

### Oyun Yonu
- Tur: **Ters Shapez — chill puzzle-factory**
- Core loop: Kaynak bul → FIRE kir → pipeline kur → aritstir → teslim et
- Bina maliyeti yok | Combat / power / heat / para birimi yok
- **Level-based ilerleme:** 9 level, CT 2x2→10x10, harita 100→800→sonsuz

### v5 Yeni Sistemler
- **FIRE (Forced Isolation & Restriction Enforcer):** Medium+ kaynak guvenligi, Easy→Medium→Hard bagimlilik zinciri
- **Content Sub-Types:** 6 content × 4 sub-type = 24 spesifik veri tipi
- **Scanner binasi:** Sub-type binary filtre (uc katmanli filtre: Separator/Classifier/Scanner)
- **Encrypted tier'lari:** 4-bit, 16-bit (demo) | 32-bit (full release). Paralel Key Forge = genislik bulmacasi
- **Corrupted tier'lari:** Minor-Glitched, Major-Glitched (demo) | Critical-Glitched (full release). Recoverer feedback loop = derinlik bulmacasi
- **Recoverer feedback loop:** Kismi recovery + Separator dongusu, her deneme Kit tuketir
- **Network Bar:** Kaynak "connected" = TUM content tipleri agda aktif kullaniliyor (CT teslim, F.I.R.E. besleme, Key/Kit uretimi, Decryptor/Recoverer isleme). Trash saymaz. Bar = connected / total
- **Throughput:** Maks 1.5s islem suresi. Paralel bina = cozum. Degerler placeholder, playtest ile ayarlanacak

### Demo Scope Lock
- Demo Level 1 only (2x2 CT, 100x100 harita)
- Roster: Classifier, Separator, Scanner, Recoverer, Key Forge, Repair Lab, Decryptor, Encryptor, Splitter, Merger, Trash, Contract Terminal (12 bina)
- State: Public, Encrypted (4-bit, 16-bit), Corrupted (Minor-Glitched, Major-Glitched)
- CT kabul: Public, Decrypted, Recovered, Dec·Enc, Rec·Enc
- Enc·Cor (birlesik state): demo'da YOK — sadece full release
- FIRE: Easy (yok) + Medium (sabit esik) + Hard (regenerating)
- **Malware gameplay YOK** — sadece full release'de
- Coklu save (5 slot) + level ilerleme kaydi
- **Dev Mode:** Tum binalar acik, gig'ler devre disi — hizli test icin

### Mekanik Kararlari
- Grid kablo routing = ana bulmaca (dik kesisim serbest)
- Bina rotasyonu (R, 4 yon) | CT dinamik boyut, port formulu: 4*(size-1)
- CT Port Purity | Kaynaklar dogrudan output portlu (FIRE korumasina tabi)
- Gig tamamlaninca pipeline KALIR (persistent network)
- Sinirli harita (levels 1-8): bolge-grid tabanli esit kaynak dagitimi + gorunur sinir
- Encrypted = genislik (paralel Key Forge), Corrupted = derinlik (feedback loop)
- FIRE kapaninca veri akisi aninda kesilir
- **Network Bar:** Kaynak bagli = tum content tipleri CT'ye aktif akiyor. Bar = bagli kaynak / toplam kaynak
- **CT Istatistik Paneli:** CT'ye tiklayinca tum zamanlar kumulatif veri dokumu (content + state bazli, gercek zamanli)

### Gorsel Dil
- Public=Yesil, Encrypted=Mavi, Corrupted=Turuncu
- Sub-type gorseli: kablo/haritada sadece parent content sembolu ($ @ # ? ! 1). Sub-type detayi sadece bina panellerinde (hover/info)
- Procedural-first sanat, siluet/ikon/glow/motion/flow feedback

### Demo'da Yapilmayacaklar
- Malware Cleaner, 32-bit Encrypted, Critical-Glitched, Enc·Cor birlesik state
- Workshop/mod, Multiplayer
- Buyuk hikaye/campaign, Tech tree/currency/upgrade, Level 2-9 ilerleme

---

## Yapilacaklar

### v5.1 Implementasyon Plani (9 Faz)

Her faz sonunda oyun **playable state**'te kalmali. Fazlar sirayla yapilir, bagimliliklar asagida belirtilmistir.

---

#### FAZ 1: Veri Modeli Tier Sistemi + State Duzeltmesi ✓ TAMAMLANDI
**Amac:** Encrypted/Corrupted tier isimlendirmesi, ENC_COR kaldir (demo'da yok), islenmis state'ler ekle
**Bagimlilik:** Yok (ilk yapilmali)

**Degisiklikler:**
- State'ler: Public, Encrypted, Corrupted (3 ana state — Corrupted KALIR, rename YOK)
- Encrypted tier: BIT_4, BIT_16 (demo) | BIT_32 (full)
- Corrupted tier: MINOR_GLITCHED, MAJOR_GLITCHED (demo) | CRITICAL_GLITCHED (full)
- Islenmis state'ler: DECRYPTED, RECOVERED, DEC_ENC, REC_ENC
- ENC_COR: demo'dan KALDIR, full release notu olarak birak

**Dosyalar:**
- `scripts/data_enums.gd` — ENC_COR kaldir. Tier sabitleri ekle (BIT_4/BIT_16, MINOR_GLITCHED/MAJOR_GLITCHED). Islenmis state enum'lari (DECRYPTED, RECOVERED, DEC_ENC, REC_ENC). Gorsel isim mapleri guncelle.
- `resources/buildings/*.tres` — state referanslarini guncelle (ENC_COR kaldir)
- `resources/sources/*.tres` — state_weights: ENC_COR key'lerini kaldir
- `resources/gigs/*.tres` — GigRequirement state alanlari guncelle
- `scripts/building.gd` — separator_mode etiketleri (Public/Encrypted/Corrupted), renk mapleri
- `scripts/simulation_manager.gd` — State karsilastirma, delivery logic, tier kontrolleri
- `scripts/gig_manager.gd` — process_deliveries state kontrolleri
- `scripts/ui/building_panel.gd` — Separator filtre etiketleri (Public/Encrypted/Corrupted)
- `scripts/ui/gig_panel.gd` — Gig label'lari
- `scripts/save_manager.gd` — Eski save uyumlulugu: ENC_COR migration
- `scripts/connection_layer.gd` — State renk mapleri (Corrupted=Turuncu kalir)

**Test:** Mevcut save yuklenebilmeli, yeni oyun baslatilabilmeli, tum gig'ler tamamlanabilmeli.

---

#### FAZ 2: Content Sub-Type Sistemi ✓ TAMAMLANDI
**Amac:** 6 content × 4 sub-type = 24 spesifik veri tipi
**Bagimlilik:** Faz 1

**Dosyalar:**
- `scripts/data_enums.gd` — Yeni SubType enum (0-23). Content→SubType mapleme. Sub-type gorsel isimleri (Log Files, Fingerprint vs). `make_key()` ve `parse_key()` fonksiyonlarina sub_type alani ekle (packed int formatinda yeni bitler). Sub-type sembol/renk mapleri (parent content rengini kullanir).
- `scripts/data_source.gd` — Yeni `sub_type_weights: Dictionary` alani. Kaynak her urettigi veri icin content+sub_type belirler.
- `resources/sources/data_source_definition.gd` — Yeni `sub_type_pool: Array[Dictionary]` alani. Her kaynak hangi sub-type'lari uretir tanimla. Ornek: ATM → [{content:FINANCIAL, sub_type:TRANSACTION_RECORDS}, {content:BIOMETRIC, sub_type:FINGERPRINT}]
- `resources/sources/*.tres` — 15 kaynak dosyasina sub_type_pool ekle (GDD'deki tabloya gore)
- `scripts/simulation_manager.gd` — Veri uretiminde sub_type atama
- `scripts/building.gd` — stored_data key formatinda sub_type destegi, gorsel render'da sub_type ismi
- `scripts/ui/building_tooltip.gd` — Sub-type bilgisi gosterimi
- `scripts/save_manager.gd` — Sub-type alani save/load

**Not:** Bu fazda Scanner binasi HENUZ eklenmez, sub-type sadece veri modeline eklenir. Classifier content bazli filtrelemeye devam eder.

**Test:** Kaynaklar sub-type'li veri uretmeli, tooltip'lerde sub-type gozukmeli, save/load calismali.

---

#### FAZ 3: Scanner Binasi ✓ TAMAMLANDI
**Amac:** Sub-type binary filtre binasi
**Bagimlilik:** Faz 2

**Dosyalar:**
- `resources/components/scanner_component.gd` — Yeni component. ClassifierComponent benzeri ama sub_type bazli. `selected_sub_type: int`, `throughput_rate: float`. Akilli Tab: gelen content'in sub-type'larini detect et, sadece onlari goster.
- `resources/buildings/scanner.tres` — Yeni bina tanimi. 2x2, sol giris, sag+alt cikis. Renk: Violet (0.65, 0.4, 0.85). Kategori: routing.
- `resources/buildings/building_definition.gd` — `scanner: ScannerComponent` alani ekle
- `scripts/building.gd` — Scanner render, Tab dongusu (sub-type), scanner_filter_sub_type state
- `scripts/building_manager.gd` — Scanner Tab dongusu input handler
- `scripts/simulation_manager.gd` — Scanner processing logic (DeliveryEngine'e yeni target type ekle: 8=Scanner). conn_target_types/filters guncelle.
- `scripts/ui/building_panel.gd` — Scanner ikonu, BUILDING_ORDER'a ekle, unlock gig tanimla
- `scripts/ui/building_tooltip.gd` — Scanner tooltip (secili sub-type goster)
- `scripts/gig_manager.gd` — Scanner unlock tetikleyicisi

**Test:** Scanner yerlestirilebilmeli, Tab ile sub-type secilebilmeli, dogru sub-type sag, kalan alt porttan cikmali.

---

#### FAZ 4: FIRE Sistemi ✓ TAMAMLANDI
**Amac:** Kaynak guvenlik duvari + bagimlilik zinciri
**Bagimlilik:** Faz 2 (sub-type'lar FIRE gereksinimi icin lazim)

**Dosyalar:**
- `resources/sources/data_source_definition.gd` — Yeni alanlar: `fire_enabled: bool`, `fire_type: String` ("none"/"threshold"/"regen"), `fire_requirements: Array[Dictionary]` (her biri {sub_type: int, amount: int}), `fire_regen_rate: float` (MB/s, regen tipi icin), `fire_input_ports: Array[String]` (FIRE besleme portlari)
- `resources/sources/*.tres` — Medium kaynaklara threshold FIRE, hard kaynaklara regen FIRE ekle. FIRE gereksinim sub-type'lari GDD'ye gore.
- `scripts/data_source.gd` — Yeni alanlar: `fire_active: bool` (baslangic true), `fire_progress: Dictionary` ({sub_type → current_amount}), `fire_regen_accumulator: float`. Yeni methodlar: `feed_fire(sub_type, amount)`, `_process_fire_regen(delta)`, `is_fire_breached()`. FIRE breached olunca output portlari aktif, degilse bloklu. Input portlari FIRE beslemesi icin ayri (output portlarindan farkli).
- `scripts/simulation_manager.gd` — FIRE besleme logic: kaynagin FIRE input portlarina gelen veriyi `feed_fire()` ile isle. FIRE durumuna gore kaynak output'unu ac/kapa. Regen tick logic.
- `scripts/building_manager.gd` — Kaynak FIRE input portlarina kablo baglama destegi
- `scripts/connection_manager.gd` — Source FIRE portlarina baglanti destegi
- `scripts/grid_system.gd` — Source FIRE portlarinin fiziksel konumlari
- `scripts/building.gd` veya `scripts/data_source.gd` — FIRE gorsel gosterimi: ikon (kalkan/kilit), progress bar, regen hiz gostergesi
- `scripts/ui/building_tooltip.gd` — FIRE durumu tooltip'te gosterimi
- `scripts/save_manager.gd` — FIRE state save/load (fire_progress, fire_active)
- `scripts/sound_manager.gd` — FIRE breach sesi

**Test:** Medium kaynaga dogru sub-type besle → threshold dol → FIRE kalk → veri akmaya basla. Hard kaynakta throughput kes → FIRE kapansin → veri kesilsin.

---

#### FAZ 5: Throughput Sistemi ✓ TAMAMLANDI
**Amac:** Filtre hizi (variety), isleme hizi (bit-depth/severity), kablo kapasitesi
**Bagimlilik:** Faz 1 (isim degisiklikleri)

**Dosyalar:**
- `scripts/simulation_manager.gd` — ANA DEGISIKLIK. Filtre binalari icin variety hesapla: gelen verinin benzersiz state/content/sub-type sayisini say → `throughput = base / variety`. Isleme binalari icin bit-depth/severity hiz carpani. Uretim binalari icin tarif karmasikligi hiz carpani.
- `resources/components/classifier_component.gd` — `base_throughput: float` (variety ile bolunecek)
- `resources/components/processor_component.gd` — Separator icin `base_throughput: float`
- `resources/components/scanner_component.gd` — `base_throughput: float`
- `resources/components/dual_input_component.gd` — `speed_by_tier: Array[float]` (bit-depth/severity bazli hiz carpanlari)
- `resources/components/producer_component.gd` — `speed_by_tier: Array[float]`
- `resources/components/splitter_component.gd` — throughput_rate KALDIR, anlik yap
- `resources/components/merger_component.gd` — throughput_rate KALDIR, anlik yap. Bos giris atla davranisi ekle.
- `scripts/connection_manager.gd` veya `scripts/grid_system.gd` — Kablo kapasitesi: `cable_bandwidth_limit: float`. Exceed edilirse backpressure. Global Bandwidth upgrade carpani.
- `scripts/building.gd` — Throughput gostergeleri (fill bar, islem hizi)

**Test:** Scanner'i ham veriye bagla → cok yavas. Once Classifier sonra Scanner → hizli. 16-bit Decryptor → yavas, paralel Decryptor → hizli. Merger sonrasi kablo tasmasi → backpressure.

---

#### FAZ 6: Olasiliksal Isleme (Key Basari Orani + Recovery Loop) ✓ TAMAMLANDI
**Amac:** Decryptor Key basari orani, Recoverer kismi recovery
**Bagimlilik:** Faz 5 (throughput sistemi)

**Dosyalar:**
- `resources/components/dual_input_component.gd` — Yeni: `success_rate_by_tier: Array[float]`. Decryptor: [0.8, 0.4] (4-bit/16-bit, demo). Recoverer: [0.75, 0.45] (Minor-Glitched/Major-Glitched, demo). `consumes_on_fail: bool` (her iki bina icin true).
- `scripts/simulation_manager.gd` — DualInput isleme logic degisiklik: basari oranina gore Random kontrol. Basarisiz: tuketilebilir harcanir, Decryptor'da veri kalir / Recoverer'da veri cikisa gider ama CORRUPTED state korunur.
- `resources/buildings/decryptor.tres` — success_rate_by_tier = [0.8, 0.4] (demo)
- `resources/buildings/recoverer.tres` — success_rate_by_tier = [0.75, 0.45] (demo). Cikis artik KARISIK: bir kisim RECOVERED, bir kisim hala CORRUPTED. Oyuncu Separator ile ayirir.
- `scripts/building.gd` — Basari/basarisizlik gorsel feedback (flash rengi)

**Not:** Recoverer feedback loop fiziksel kablo + Separator ile oyuncunun kendisinin kurmasi gereken bir yapi. Kod degisikligi minimal — sadece Recoverer cikisinda veriyi kismi olarak donustur.

**Test:** 4-bit Key → %80 basari, cogu calisiyor. 16-bit Key → %40, cok key harcanir. Recoverer Minor-Glitched → cogu recover, Major-Glitched → yari recover + yari corrupted cikis. Separator loop kurulabilmeli.

---

#### FAZ 7: Upgrade Sistemi ✓ TAMAMLANDI
**Amac:** 4 kategori, CT'ye teslim = upgrade kaynagi
**Bagimlilik:** Faz 5+6 (throughput + olasilik gerekli)

**Dosyalar:**
- `scripts/upgrade_manager.gd` — YENI DOSYA. Singleton/autoload. 4 kategori state: {tier, cumulative_data, multiplier}. Tier tablosu (8 tier, maliyet + carpan). `add_data(content, state, tags, amount)` — CT tesliminde cagirilir, ilgili kategoriye ekler. `get_multiplier(category)` → float. `get_success_bonus(category)` → float. Save/load destegi.
- `scripts/gig_manager.gd` veya `scripts/simulation_manager.gd` — CT teslimi sirasinda `upgrade_manager.add_data()` cagir. Teslim edilen verinin state/tags'ine gore kategori belirle: Public → Routing, Decrypted/Encrypted tag → Decryption, Recovered tag → Recovery, hepsi → Bandwidth.
- `scripts/simulation_manager.gd` — Upgrade carpanlarini throughput hesabina uygula. `upgrade_manager.get_multiplier("routing")` → filtre base_speed'e carpan. Ayni sekilde processing, production, bandwidth.
- `resources/components/dual_input_component.gd` — success_rate'e upgrade bonusu ekle
- `scripts/data_source.gd` — Bandwidth upgrade → kaynak cekme hizi carpani. Kablo kapasitesi carpani.
- `scripts/ui/upgrade_panel.gd` — YENI DOSYA. CT upgrade tab'i. 4 kategori progress bar, tier gostergesi, aciklama metni. CT secildiginde gig panel yerine/yaninda gosterilir.
- `scripts/ui/building_panel.gd` veya `scripts/main.gd` — CT tiklandiginda upgrade paneli toggle
- `scripts/save_manager.gd` — Upgrade state save/load
- `scripts/sound_manager.gd` — Tier-up sesi

**Test:** Public veri teslim et → Routing tier artsin → filtre hizlansin. Decrypted teslim et → Key basari orani yukselsin. Bandwidth tier artsin → kaynak hizi + kablo kapasitesi artsin.

---

#### FAZ 8: Kaynak Port Yapilandirmasi ✓ TAMAMLANDI
**Amac:** Kaynak zorluguna gore port sayisi (Easy 1-2, Medium 3-4, Hard 5-6, Endgame 7-8)
**Bagimlilik:** Faz 4 (FIRE portlari ayri olmali)

**Dosyalar:**
- `resources/sources/data_source_definition.gd` — `output_port_count: int` alani (mevcut grid_size tabanli output yerine)
- `resources/sources/*.tres` — Her kaynaga output_port_count ata: ISP=2, ATM=1, Smart Lock=1, Traffic Camera=2, Data Kiosk=1, Hospital=3, Bank Terminal=4, Biotech Lab=3, Corporate=6, Gov Archive=5, Military=8
- `scripts/data_source.gd` — Port uretimini output_port_count'a gore yap (grid_size yerine). FIRE input portlari ayri (faz 4'te eklendi).
- `scripts/grid_system.gd` — Kaynak port pozisyonlari (cok portlu buyuk kaynaklarda kenar dagilimi)

**Test:** ATM 1 port, Corporate 6 port gorunmeli. Her port ayni global hizda veri cikarmali.

---

#### FAZ 9: Gorsel + UI + Ses Guncellemeleri ✓ TAMAMLANDI
**Amac:** FIRE gorselleri, throughput gostergeleri, upgrade UI polish, network throughput metrigi
**Bagimlilik:** Faz 4-8 tamamlanmis olmali

**Dosyalar:**
- `scripts/data_source.gd` — FIRE ikon render: kalkan (active), kilit-acik (breached), progress bar, regen hizi gostergesi
- `scripts/building.gd` — Throughput gostergesi: islem hizi bar, backpressure gorseli
- `scripts/connection_layer.gd` — Kablo kapasite gorseli: doluluk orani renk degisimi (yesil→sari→kirmizi)
- `scripts/ui/top_bar.gd` — Network throughput metrigi: "NETWORK: 1.2 GB/s" gostergesi
- `scripts/ui/upgrade_panel.gd` — Polish: animasyonlar, tier-up efekti
- `scripts/sound_manager.gd` — FIRE breach sesi, tier-up sesi, backpressure uyari
- `scripts/tutorial_manager.gd` — Yeni hint'ler: FIRE, Scanner, feedback loop, upgrade

---

#### GORSEL TASARIM NOTLARI (Faz 9 oncesi konusulacak)
- **Renk paleti:** Cyberpunk neon — kirmizi, cyan/teal, sari ana renkler. Cok fazla farkli renk KULLANMA. Mevcut 12 bina rengi fazla olabilir, 3-4 ana neon renge sadellestir.
- **Sub-type gosterimi:** KARARLASTI — kablo/haritada sadece parent content sembolu. Sub-type detayi sadece bina info panellerinde gosterilir.

#### KAYNAK HARITA NOTU (Faz 8 sirasinda konusulacak)
- Kaynaklarin haritadaki dizilimi (Easy→Medium→Hard zonlama, FIRE bagimlilik zinciriyle uyumlu komsuluk)
- Port sayilari tekrar elden gecirilmeli (grid_size ile uyum, buyuk kaynaklarda port yerlesimi)
- FIRE input portlari vs output portlari fiziksel konum planlama
- Tutorial scripted kaynak koordinatlari v5 sistemine uyarlanmali

#### v5.1 Sonrasi UI Degisiklikleri (Faz 9+) — TAMAMLANDI
- [x] Yapi/kaynak tiklama → sol panelde (Contracts) detayli bilgi gosterimi
- [x] CT tiklama → upgrade butonlari (claim sistemi) + stored data
- [x] Filtre binalari dropdown menu ile filtre secimi (Classifier/Separator/Scanner/Producer)
- [x] Giren/cikan veri akisi gosterimi (INPUT/OUTPUT, content renkleriyle)
- [x] Upgrade sistemi: sadece islenmis veri (Decrypted/Recovered) sayilir, Public = 0
- [x] Upgrade mapping: Standard/Financial→Routing, Blueprint/Classified→Decryption, Biometric/Research→Recovery, tumu %25→Bandwidth
- [x] Upgrade claim: otomatik degil, oyuncu CT'den tiklar

#### ERTELENMIS (Sonraki Tasarim Oturumu)
- [x] ~~Gig sistemi detaylari~~ TAMAMLANDI — 9 tutorial gig, tum mekanikler ogretiliyor (F.I.R.E., Scanner, Upgrade dahil)
- [x] ~~Tutorial gig'leri FIRE/Scanner/loop/upgrade icin yeniden yazma~~ TAMAMLANDI
- [ ] Bina acilma tetikleyicileri (gig-based kalacak, dev mode ile bypass)
- [x] ~~**Network Bar hesabi:**~~ YENIDEN YAZILDI — Content-bazli aktif kullanim kontrolu. Kaynak "connected" = tum content tipleri CT/F.I.R.E./Producer/Processor tarafindan tuketiliyor. Trash saymaz.
- [x] ~~**CT Port Purity bug:**~~ DUZELTILDI — type_key encoding'e tags eklendi (content<<8|state<<4|tags). Raw Encrypted/Corrupted (tags=0) artik CT'ye giremez, purity checker tags-aware.
- [x] ~~**Dev Mode release'de acik:**~~ DUZELTILDI — OS.is_debug_build() kontrolu eklendi, release build'de F10 devre disi.

### Full Game Backlog
- Malware Cleaner + Malware state | Triple bilesik state: Enc·Cor·Mal
- 32-bit Encrypted + Critical-Glitched + Enc·Cor birlesik state (tam oyun)
- Ara zorluk kademeleri: Hard+, Hard++, Medium+ (full release)
- Building batch rendering, chunk unloading, far-object virtualization
- Upgrade Tier 8+ sinirsiz (endgame)

---

## Altyapi

### GDExtension C++
- **Yol:** `gdextension/` — godot-cpp submodule + src/
- **Build:** `cd gdextension && scons platform=windows target=template_debug -j4`
- **Release:** `cd gdextension && scons platform=windows target=template_release -j4`
- **Siniflar:** TransitSimulator, PolylineHelper, StallPropagator, DeliveryEngine, SimKernel
- **Fallback:** DLL yoksa `ClassDB.class_exists()` ile GDScript'e duser

### Performans-Kritik Kod Kurali
1. Once GDScript'te algoritmik optimizasyon (cache, O(n²)→O(n), lazy eval)
2. Yetmezse GDExtension C++'a tasi — `RefCounted` extend, `ClassDB::register_class<>()`
3. GDScript'te **her zaman fallback** olmali | C++'ta Godot node method'lari **cagirma**

### MCP: tomyud1/godot-mcp (32 arac)
WebSocket port 6505 | Godot editorde "MCP Connected" (yesil) olmali

### Godot
- **Yol:** `D:\godot\Godot_v4.6-stable_win64_console.exe`
- Acmadan once: `taskkill /F /IM Godot_v4.6-stable_win64_console.exe` + dogrula
- Editor: `"D:/godot/Godot_v4.6-stable_win64_console.exe" --editor --path "D:/godotproject/sys-admin"`
- Calistir: `"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin"`

---

## Kurallar

### Kod Kurallari
- **OYUN DILI INGILIZCE** — Tum user-facing text Ingilizce. Turkce string YAZMA.
- **_process() icinde UI guncelleme YAPMA** — sinyal/event tabanli guncelle, throttle kullan
- Event-based logla, tick-based log BASMA — Format: `[SistemAdi] Olay — deger`

### Calisma Kurallari
- Her degisiklik sonunda oyun **playable state**'te kalmali
- `docs/GDD.md` (v5.0) tasarim kararlari icin referans dokuman
- Kullanici teknik degil — ne/neden acikla, kod detayi verme
- Commit + push birlikte, kullanici onayi ile

### Escalation Kurali
Dur ve kullaniciya don:
- Scope lock ile celisen yeni ihtiyac cikarsa
- Demo yerine full-game endgame sistemine kayma riski olursa
- Mekanigin iki farkli yorumundan biri secilmeden ilerlemek riskliyse

---

**Ters Shapez: aritstir, birlestirme.**
