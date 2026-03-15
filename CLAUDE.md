# SYS_ADMIN - Proje Durumu ve v4 Demo Implementasyon Plani

## Mevcut Asama: v4 Implementasyon — Demo hazirligi
- **GDD:** `docs/GDD.md` (v3.0) + `docs/v4_design.md` (v4 tasarim kararlari)
- **Kod durumu:** Faz A-J + Sprint 1-4 + Transit + Optimizasyon + Level sistemi tamamlandi
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
- **Level-based ilerleme:** 9 level, CT 2x2→10x10, harita 100→800→sonsuz
- **Compiler KALDIRILDI** — biz birlestirmiyoruz, aritiyoruz

### Demo Scope Lock (v4)
- Demo **T1-T2** odakli
- Roster: Classifier, Separator, Recoverer, Research Lab, Decryptor, Encryptor, Splitter, Merger, Trash, Contract Terminal (10 bina)
- **Malware gameplay YOK** — sadece full release'de
- Bilesik state: **Enc·Cor** demo'da var
- Tier escalation: bilesik state'de bir state cozulunce digeri +1 tier
- Demo = Level 1: 2x2 CT, 100x100 harita, tutorial + %100 network hedefi
- Kazanma kosulu: tum kaynaklari CT'ye bagla (%100 network)
- Level 2+: tum binalar acik, procedural gig, daha buyuk harita
- Level 9: sonsuz harita, endless mode
- Coklu save dosyasi destegi + level ilerleme kaydi

### Mekanik Kararlari
- Source bandwidth gameplay'de gercek limit (mevcut sistem)
- Recoverer deterministic + fuel tabanli
- Grid kablo routing = ana layout bulmacasi (dik kesisim serbest)
- Bina rotasyonu (R tusu, 4 yon) | CT dinamik boyut (2x2→10x10), port formulu: 4*(size-1)
- CT Port Purity | Classifier/Separator Back-Pressure
- Kaynaklar dogrudan output portlu (Uplink kaldirildi)
- Merger tutorial'da erken acilir
- Gig tamamlaninca pipeline KALIR (persistent network)
- Kazanma kosulu: %100 network (tum kaynaklar bagli) → level complete
- Sinirli harita (levels 1-8): bolge-grid tabanli esit kaynak dagitimi
- Harita siniri gorunur (teal border + dis alan karartma + kamera siniri)

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
- Level 2-9 ilerleme (demo = sadece Level 1, LevelConfig.IS_DEMO=true)

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

### Faz 2: Bilesik State (Enc·Cor) — Ana Mekanik ✓ TAMAMLANDI
- [x] `data_enums.gd` — ENC_COR=4 state, compound tier helpers (make/enc/cor), state_name/color/label
- [x] Kaynak tanimlarinda bilesik state weight'leri (Corporate %20, Govt %30, Military %35, DarkWeb %40)
- [x] `simulation_manager.gd` — _roll_tier ENC_COR destegi, tier escalation (+1 kalan state)
- [x] Decryptor: ENC_COR kabul, sifre cozer → Corrupted cikar (cor_tier+1)
- [x] Recoverer: ENC_COR kabul, bozukluk onarir → Encrypted cikar (enc_tier+1)
- [x] Separator: Tab dongusu PUBLIC→ENCRYPTED→CORRUPTED→ENC_COR (MALWARE atlandi)
- [x] decryptor.tres / recoverer.tres — primary_input_states'e ENC_COR(4) eklendi
- [x] building_tooltip.gd — Enc·Cor kabul gosterimi

### Faz 3: Bilesik State Gorselleri ✓ TAMAMLANDI
- [x] Transit shader: compound flag (v_custom.y), UV.x bazli split renk (mavi/sari)
- [x] CPU draw path: ENC_COR icin split glow (sol=Encrypted mavi, sag=Corrupted sari)
- [x] Building tooltip: stored data'da split renk label, source state dagiliminda split renk
- [x] Gig panel: ENC_COR requirement icin "[Enc]·[Cor]" split renk gosterimi
- [x] Decryptor/Recoverer tooltip: Enc·Cor kabul bilgisi

### Faz 4: Gig Sistemi Yeniden Tasarimi ✓ TAMAMLANDI
- [x] Tutorial 8 gig → 6 gig'e indirildi (1:Extraction, 2:Separator, 3:FilterChain, 4:Merger, 5:Recovery, 6:Blueprint)
- [x] Bina unlock sirasi: Gig1→Sep+Class, Gig2→Merger, Gig3→ResLab+Decryptor, Gig4→Recoverer, Gig5→Encryptor
- [x] Eski post-tutorial gigler silindi (gig_08-16), yerlerine procedural gig generator
- [x] Procedural gig generator: zorluk kademeli (Public→Decrypted→Recovered→Dec·Enc→Rec·Dec)
- [x] 3 procedural gig ayni anda aktif, biri bitince yenisi uretilir
- [x] Save/load procedural state destegi (tutorials_complete, procedural_count, next_order_index)
- [x] Tutorial/stall hint'ler ve building_panel unlock mapping guncellendi
- [x] Throughput gig mekanigi → Faz 4.5'te eklenebilir (simdilik one-shot delivery)

### Faz 5: Persistent Network ✓ TAMAMLANDI
- [x] Pipeline'lar zaten kalici — binalar/kablolar gig tamamlaninca silinmiyor (mevcut davranis)
- [x] "NETWORK: X/Y (Z%)" progress gostergesi top_bar'a eklendi
- [x] Bagli kaynak / toplam kaynak orani, renk mavi→yesile kayiyor
- [x] Kablo ekleme/cikarma'da otomatik guncelleniyor

### Faz 6: Coklu Save + Polish + GDD Guncelleme (DEVAM EDIYOR)
- [x] **Research Lab → Key Forge** yeniden adlandirildi (T1:Research, T2:+Biometric, T3:+Financial)
- [x] **Repair Lab** yeni bina eklendi — Repair Kit uretir (T1:Standard, T2:+Financial, T3:+Blueprint)
- [x] **Recoverer** fuel mode → key mode (Repair Kit kullanir, Decryptor ile simetrik)
- [x] **REPAIR_KIT** content type eklendi (char:"R", color:#ff7744)
- [x] Tum UI/tooltip/hint referanslari guncellendi
- [x] Ard arda undo yapilinca engine crash — zombie node korumasi + is_instance_valid guard
- [x] Save slot sistemi — 5 slot, slot_N.json + slot_N_auto.json
- [x] Ana menu: New Game (oto bos slot) + Load Game (slot listesi + silme) + Give Feedback
- [x] Tarih formati okunabilir: "Mar 15, 2026 — 6:34 AM"
- [x] Kaynak yogunluk azaltma — MIN_SOURCE_DISTANCE 5→8, ayni tip arasi 18, endgame dist 10→9
- [x] Ayni tip kaynak yan yana engeli (MIN_SAME_TYPE_DISTANCE=18)
- [x] Per-instance state weight varyasyonu — content sabit, state oranlari seed-based rastgele
- [x] CT (Contract Terminal) korumasi — silinemez, kopyalanamaz, tasinamaz
- [x] "Combined Flow" gig → "Research Collection" (Research data toplama ogretiyor)
- [x] Pause menüye "Wishlist Full Game" butonu eklendi
- [x] Renk paleti tutarli gruplara ayrildi (Filtering=cyan, Routing=steel, Support=green, Crypto=orange/blue)
- [x] Producer tooltip dinamik (Key Forge + Repair Lab dogru gosterim)
- [x] Recoverer tooltip output_tag ile dogru ayirt ediliyor (Repair Kit gosterimi)
- [x] **GDD.md guncelle** — v4.0 olarak yeniden yazildi (Compiler/Uplink/Bridge kaldirildi, Key Forge + Repair Lab eklendi, bilesik state, procedural gig, 3 faz yapisi)
- [x] **Bina gorsel yenileme** — tum binalar 2x2 (Splitter/Merger/Trash 1x1→2x2), ayirt edici polygon sekilleri, ikon merkez fix (rotate/mirror), output port oklari (disari uzayan ucgen), input port daireler, key/fuel port elmas sembol ("K"/"R"), Decryptor acik kilit / Encryptor kapali kilit, Repair Lab ikonu, Separator/Classifier buyutulmus ikon
- [x] **Merger port layout** — iki input sol kenarda koselerde (left_0/left_1), ikon guncellendi
- [x] **Splitter port layout** — iki output sag kenarda koselerde (right_0/right_1), ikon guncellendi
- [x] **Kablo renk solma kaldirildi** — tum kablolar her zaman tam parlaklikta, _get_cable_state/CABLE_INACTIVE sistemi temizlendi
- [x] **Kablo sabit renk** — tum kablolar notral gumus-beyaz (#aabbcc, alpha 0.7), bina renginden bagimsiz
- [x] **Kaynak dominant content rengi** — her kaynak en yuksek agirlikli content type'in rengini kullaniyor (orn. Hospital=%55 Biometric → pembe)
- [x] **Minimap renk uyumu** — kablolar gumus, kaynaklar dominant content rengi
- [x] **Save silme onay paneli** — Load Game'de silme butonuna basinca cyberpunk stilinde onay penceresi (teal border, kirmizi Delete butonu)
- [x] **CT exclusion zone** — Manhattan→Chebyshev distance (kare bolge, her yonde 5 kare)
- [x] **Harita cesitliligi** — pool gecisleri erkene alindi (hard dist 4+, endgame dist 6+), spawn yogunlugu artirildi
- [x] **Easy kaynaklara T1 Encrypted** — Bank Terminal %15, Smart Lock %10, Shop Server %10 sifreleme eklendi
- [x] **Endgame kaynak temasi** — Military: agir encrypted, Dark Web: agir corrupted, public veri sifir
- [x] **Hard kaynak temasi** — Corporate/Govt Archive'den public ve temel content kaldirildi (oyuncuyu yan kaynaklara yonlendirir)
- [x] **Kaynak renk sistemi yenilendi** — easy/medium: dominant content rengini kullanir (sari=Financial, pembe=Biometric, mor=Research), hard/endgame: kaynagin kendi rengi (turuncu/kirmizi/amber)
- [x] **Hard/endgame glow guclendirme** — hard 1.6x, endgame 2.2x glow boyutu+parlaklik (zoom out'ta gorunurluk)
- [x] **Biometric content rengi** — #ff33aa→#ff88cc (acik pembe, endgame kirmizilariyla karismiyor)
- [x] **Berabere content dagilimi duzeltme** — Data Kiosk→Financial, Traffic Cam→Biometric, Public DB→Research, her kaynak net dominant renge sahip
- [x] **Tooltip boyut fix** — reset_size() ile panel icerige tam oturuyor, altta bosluk kalmiyor

### Faz 7: Level Sistemi ✓ TAMAMLANDI
- [x] `level_config.gd` — 9 level tanimi (CT 2x2→10x10, harita 100→800→sonsuz)
- [x] `level_manager.gd` — level takibi, %100 network win condition, save/load
- [x] CT dinamik boyut — .tres 2x2 varsayilan, runtime'da level'a gore override (.duplicate())
- [x] Sinirli harita uretimi — bolge-grid tabanli esit dagitim (chunk-based degil)
- [x] Kaynak pozisyonlari map center offset olarak (sabit degil)
- [x] Pool filtreleme — level'in izin verdigi zorluk havuzlari (ic=easy, orta=medium, dis=hard)
- [x] Camera bounds — sinirli haritalarda kamera siniri ortalar
- [x] Harita siniri gorseli — teal border, kose aksanlari, dis alan karartma (z_index=5)
- [x] %100 network → "Level Complete" bildirimi + level gecis ekrani
- [x] Demo modda "Demo Complete" + Wishlist ekrani
- [x] Top bar: "LEVEL X [NxN]" etiketi
- [x] GigManager: Level 2+ tum binalar acik, sadece procedural gig
- [x] Save v5 — level_state kayit/yukleme, v4→v5 migration
- [x] Load Game: slot'larda "LVL X" gosterimi
- [x] Level paneli — 3x3 grid, 9 level karti (kilitli/acik/tamamlandi)
- [x] Main menu: "Level Select" butonu (ilerleme varsa gorunur)
- [x] IS_DEMO flag — demo=true ise sadece Level 1
- [x] Gig content level uyumu — Level 1'de Blueprint istenmez, level-aware content pool
- [x] Tutorial gig 6: Blueprint Run → Network Expansion (Research Public)

### Siralama
Faz 1 → 2 → 3 → 4 → 5 → 6 → 7. Her faz sonunda oyun playable state'te kalmali.

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
| Level sistemi | 9 level (CT 2x2→10x10), sinirli harita, %100 network win, level panel, demo blocker |
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

### UI Guncelleme Kurali
- **_process() icinde UI guncelleme YAPMA** — sinyal/event tabanli guncelle
- Tooltip, panel, stats gibi UI'lar `tick_completed` veya ozel sinyal ile refresh edilmeli
- Minimap gibi surekli cizim gereken UI'larda throttle kullan (ornegin 10 FPS)
- Her frame string olusturma, RichTextLabel.text atama gibi islemler YASAK

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
