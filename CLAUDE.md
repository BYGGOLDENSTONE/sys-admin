# SYS_ADMIN - Proje Durumu ve v4 Demo Implementasyon Plani

## Mevcut Asama: v4 Implementasyon — Demo hazirligi
- **GDD:** `docs/GDD.md` (v3.0) + `docs/v4_design.md` (v4 tasarim kararlari)
- **Kod durumu:** Faz A-J + Sprint 1-4 + Transit + Optimizasyon tamamlandi, v4 degisiklikleri basliyor
- **Hedef:** Steam Next Fest Haziran 2026 icin oynanabilir, polished, v4 mekanikli demo
- **Ticari hedef:** Tam oyun icin $9.99 fiyat noktasina yakisan kalite ve guven hissi

### Kritik Takvim
| Tarih | Milestone |
|-------|-----------|
| 27 Nisan 2026 | Steam Next Fest kayit sonu |
| 18 Mayis 2026 | Press Preview build |
| 1 Haziran 2026 | Final review teslimi |
| 15-22 Haziran 2026 | Next Fest etkinlik penceresi |

## North Star — Ters Shapez
SYS_ADMIN, **Ters Shapez** modelidir:
```
Shapez:      Basit parcalar → isle → karmasik urun → teslim
SYS_ADMIN:   Karmasik kaynak → ayikla/coz/onar/temizle → saf veri → teslim
```
- Oyuncu insa etmiyor, **aritiyor.** Content = sekil, State = renk.
- "Basit mekanik + derin kombinasyon + guzel layout" hissi satacak
- Gorsel dil: **procedural / abstract / readable cyber-board** estetigi
- Oyuncu ilk 10-15 dakikada dokumansiz oynayabilmeli
- Reddit toplulugu gorselleri ve ters-Shapez mantigi begendi

---

## Kilitlenmis Tasarim Kararlari (v4)
Asagidaki kararlar **scope lock** kabul edilir. Claude Code bu kararlarla celisen sistem eklememeli.

### Oyun Yonu
- Tur: **Ters Shapez — chill puzzle-factory**
- Core loop: Contract al → kaynak bul → pipeline kur → aritstir → teslim et → yeni bina / kontrat
- Bina maliyeti yok | Combat / power / heat / para birimi yok
- Persistent sandbox save, run-based yapi yok
- **Compiler KALDIRILDI** — biz birlestirmiyoruz, aritiyoruz

### Demo Scope Lock (v4)
- Demo **T1-T2** odakli
- Roster: Classifier, Separator, Recoverer, Research Lab, Decryptor, Encryptor, Splitter, Merger, Trash, Contract Terminal (10 bina)
- **Malware gameplay YOK** — sadece full release'de
- Bilesik state: **Enc·Cor** demo'da var
- Tier escalation: bilesik state'de bir state cozulunce digeri +1 tier
- 3 faz yapisi: One-shot Tutorial → Sustain + Throughput → Persistent Network (teaser)
- Tutorial sonrasi procedural gig generator
- Coklu save dosyasi destegi

### Mekanik Kararlari
- Source bandwidth gameplay'de gercek limit (mevcut sistem)
- Recoverer deterministic + fuel tabanli
- Grid kablo routing = ana layout bulmacasi (dik kesisim serbest)
- Bina rotasyonu (R tusu, 4 yon) | CT 3x3, 8 port, exclusion zone
- CT Port Purity | Classifier/Separator Back-Pressure
- Kaynaklar dogrudan output portlu (Uplink kaldirildi)
- Merger tutorial'da erken acilir
- Gig tamamlaninca pipeline KALIR (persistent network)

### Bilesik State Gorsel Dili
- Public = Yesil, Encrypted = Mavi, Corrupted = Sari
- Enc·Cor = Yari mavi, yari sari (bolunmus renk)
- Oyuncu dual state'i sembol + bolunmus renk ile bir bakista okuyor

### Art / Audio
- Procedural-first sanat yonu
- Gorsel kalite: siluet, ikon, glow, motion, flow feedback, active/idle kontrasti
- Harici asset zorunlu degil

### Demo'da Yapilmayacaklar
- Compiler, Packet sistemi, Malware Cleaner
- T3/T4 zorunlu kontrat, Workshop/mod, Multiplayer
- Buyuk hikaye/campaign, Tech tree/currency/upgrade buyutme

---

## v4 Implementasyon Plani

### Faz 1: Compiler Temizligi ✓ TAMAMLANDI
- [x] `compiler.tres` kaldirildi
- [x] `simulation_manager.gd` — `_process_compiler()` + `_push_packet_from()` silindi
- [x] `data_enums.gd` — packet fonksiyonlari silindi (is_packed_packet guard kaldi — eski save uyumu)
- [x] `gig_manager.gd` — packet delivery silindi
- [x] `gig_09.tres` (packet gig) kaldirildi
- [x] `gig_13.tres`, `gig_17.tres`, `gig_18.tres` (packet gig'ler) devre disi birakildi (Faz 4'te yeniden tasarlanacak)
- [x] Tutorial hint'lerden Compiler referanslari silindi
- [x] `compiler_component.gd`, `compiler_recipe.gd` kaldirildi
- [x] building.gd, building_icon.gd, building_tooltip.gd, building_panel.gd — Compiler gorselleri/UI temizlendi
- [x] connection_layer.gd — packet render kodu temizlendi
- [x] sound_manager.gd — compiler ses efekti kaldirildi
- [x] building_definition.gd — compiler property + accepts_data silindi
- [x] gig_requirement.gd — packet_key alani kaldirildi
- [x] shop_server.tres — Compiler referansi guncellendi

### Faz 2: Bilesik State (Enc·Cor) — Ana Mekanik
- [ ] `data_enums.gd` — compound state destegi ekle
- [ ] Kaynak tanimlarinda bilesik state weight'leri
- [ ] `simulation_manager.gd` — bilesik state isleme: bir state cozulunce diger +1 tier
- [ ] Decryptor/Recoverer bilesik state veriyi kabul etmeli
- [ ] Separator bilesik state filtreleme destegi
- **Risk:** Orta, veri modeli degisikligi — dikkatli test gerekir

### Faz 3: Bilesik State Gorselleri
- [ ] Transit item'da yari-yariya bolunmus renk
- [ ] Building tooltip'te bilesik state gosterimi
- [ ] Gig panel'de bilesik state label'lari
- **Risk:** Dusuk, sadece gorsel

### Faz 4: Gig Sistemi Yeniden Tasarimi
- [ ] Tutorial gig'leri yeniden sirala (Merger erken, Compiler yok)
- [ ] Throughput gig mekanigi (timer bazli sustain)
- [ ] Basit procedural gig generator
- [ ] 3 faz yapisi (One-shot → Sustain → Persistent Network)
- **Risk:** Orta, gig sistemi cekirdegi degisiyor

### Faz 5: Persistent Network
- [ ] Gig tamamlaninca pipeline kalir, calismaya devam eder
- [ ] "Sehir Kontrolu" progress gostergesi
- **Risk:** Dusuk, mevcut sistemde zaten binalar/kablolar kalici

### Faz 6: Coklu Save + Polish + GDD Guncelleme
- [ ] Save slot sistemi (birden fazla save dosyasi)
- [ ] Load ekraninda slot listesi
- [ ] Son dokunuslar
- [ ] **Recoverer yakit sistemi yeniden degerlendir** — Recoverer'in yakit olarak ne kullandigini gozden gecir, v4 mekanikleriyle uyumlu mu kontrol et
- [ ] **GDD.md guncelle** — Tum fazlar bittikten sonra, leftover kod kalmasin diye en son GDD v4.0 olarak yazilacak

### Siralama
Faz 1 → 2 → 3 → 4 → 5 → 6. Her faz sonunda oyun playable state'te kalmali.

---

## Tamamlanan Calismalar (Ozet)
Detaylar git gecmisinde. `git log --oneline` ile gorulebilir.

| Alan | Icerik |
|------|--------|
| Faz A-J + J-fix | Core loop, veri modeli, bina mekanikleri, tier, scope freeze, UI, tutorial, content, save/load, visual/audio polish |
| Sprint 1 | PCB arka plan, kablo kalinligi, bina siluetleri, CRT efekti, monospace font |
| Sprint 2 | Cyberpunk ambient, SFX, client/faction, menu atmosferi |
| Sprint 3 | Bug bash, root cause feedback, edge case fix |
| Sprint 3.5 | Wave/prerequisite sistemi, 5 yeni gig (toplam 18) |
| Sprint 4 | Wishlist CTA, demo bitis, tooltip, kilitli bina bilgisi |
| Sprint 6 kismi | Legacy temizlik, upgrade sistemi, version string, crash save |
| Transit sistemi | Kablo uzerinde gercek veri hareketi, back-pressure, storageless inline, routing buffer |
| Performans | Algoritmik cache'ler, C++ GDExtension (TransitSimulator, PolylineHelper, StallPropagator, DeliveryEngine, SimKernel) |
| GPU render | PCB/grid shader, underglow shader, MultiMesh transit, kablo LOD, building CPU opt |

---

## Daha Sonra Yapilacaklar

### Sprint: Screenshot + Trailer + Store Page
- [ ] 5 Steam screenshot uret
- [ ] 30-60sn trailer hook
- [ ] Store page copy yaz
- [ ] Steam Next Fest kaydini yap (27 Nisan oncesi)

### Final Build + RC
- [ ] 5 seed tam demo playthrough
- [ ] Press Preview build teslimi (18 Mayis)
- [ ] Final review build teslimi (1 Haziran)

### Full Game Backlog
- Malware Cleaner binasi + Malware state (release)
- Triple bilesik state: Enc·Cor·Mal (release)
- T3 tier (release)
- Building batch rendering, chunk unloading, far-object virtualization
- Bandwidth authoritative yapma

---

## Altyapi

### GDExtension C++ Modulu
- **Yol:** `gdextension/` — godot-cpp submodule + src/
- **Build:** `cd gdextension && scons platform=windows target=template_debug -j4`
- **Release:** `cd gdextension && scons platform=windows target=template_release -j4`
- **Siniflar:** TransitSimulator, PolylineHelper, StallPropagator, DeliveryEngine, SimKernel
- **Fallback:** DLL yoksa `ClassDB.class_exists()` kontrolu ile GDScript'e duser

### Performans-Kritik Kod Kurali
1. **Once** GDScript'te algoritmik optimizasyon (cache, O(n²)→O(n), lazy eval)
2. **Yetmezse** GDExtension C++'a tasi (`gdextension/src/`)
3. C++ sinifi `RefCounted` extend, `ClassDB::register_class<>()` ile kayit
4. GDScript'te **her zaman fallback** olmali
5. C++'ta Godot node method'lari **cagirma** — logic GDScript'te kalmali

### MCP: tomyud1/godot-mcp (32 arac)
WebSocket port 6505 | Godot editorde "MCP Connected" (yesil) olmali

### Godot
- **Yol:** `D:\godot\Godot_v4.6-stable_win64_console.exe`
- Acmadan once: `taskkill /F /IM Godot_v4.6-stable_win64_console.exe` + dogrula
- Editor: `"D:/godot/Godot_v4.6-stable_win64_console.exe" --editor --path "D:/godotproject/sys-admin"`
- Calistir: `"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin"`

### Loglama
- Event-based logla, tick-based log BASMA
- Format: `[SistemAdi] Olay — deger`

### Kurallar
- **OYUN DILI INGILIZCE** - Tum user-facing text Ingilizce. Turkce string YAZMA.
- Kullanici teknik degil - ne/neden acikla, kod detayi verme
- Commit + push birlikte, kullanici onayi ile
- Tamamlanan isler commit mesajinda belirt

---

## Claude Code Calisma Kurallari

### Genel Kurallar
- v4 fazlarini **sirayla** ilerlet; faz bitmeden sonrakine gecme
- Her faz sonunda oyun **playable state**'te kalmali
- `docs/v4_design.md` tasarim kararlari icin referans dokuman
- Scope'u genisletme; polish'i ve clarity'yi one al
- Yeni sistem eklemeden once "demo'da gercekten gerekli mi?" kontrol et
- Kullaniciya gorunen tum metinler **Ingilizce** kalmali

### Escalation Kurali
Dur ve kullaniciya don:
- Scope lock ile celisen yeni ihtiyac cikarsa
- Demo yerine full-game endgame sistemine kayma riski olursa
- Mekanigin iki farkli yorumundan biri secilmeden ilerlemek riskliyse

---

## Son Not
**Ters Shapez: aritstir, birlestirme.**
"Daha fazla sistem" vs "daha iyi demo hissi" → **her zaman daha iyi demo hissini sec.**
