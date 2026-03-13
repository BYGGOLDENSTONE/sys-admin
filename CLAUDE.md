# SYS_ADMIN - Proje Durumu ve Demo Release Plani

## Mevcut Asama: v3.0 Faz A-J TAMAMLANDI — Next Fest Sprint basliyor
- **GDD:** `docs/GDD.md` (v3.0) - Tum tasarim kararlari burada
- **Kod durumu:** v3.0 Faz A-J + J-fix tamamlandi, mekanik ve icerik hazir
- **Hedef:** Steam Next Fest Haziran 2026 icin oynanabilir, polished, save/load'lu, onboarding'i guclu demo
- **Ticari hedef:** Tam oyun icin $9.99 fiyat noktasina yakisan kalite ve guven hissi

### Kritik Takvim
| Tarih | Milestone |
|-------|-----------|
| 27 Nisan 2026 | Steam Next Fest kayit sonu |
| 18 Mayis 2026 | Press Preview build |
| 1 Haziran 2026 | Final review teslimi |
| 15-22 Haziran 2026 | Next Fest etkinlik penceresi |

## North Star
SYS_ADMIN, **Shapez'e yakin chill puzzle-factory** yonunde ilerlemelidir:
- Oyun, "basit mekanik + derin kombinasyon + guzel layout" hissi satacak
- Scope, Factorio benzeri genis sistemlere kaydirilmayacak
- Demo, "dar ama asiri polished" olacak
- Gorsel dil, **procedural / abstract / readable cyber-board** estetigine yaslanacak
- Oyuncu ilk 10-15 dakikada dokumansiz oynayabilmeli, ilk 60 dakikada ise oyunun hook'unu tam hissetmeli

---

## Kilitlenmis Tasarim Kararlari
Asagidaki kararlar artik **scope lock** kabul edilir. Claude Code bu kararlarla celisen sistem eklememeli.

### Oyun Yonu
- [x] Tur yonu: **Shapez'e yakin chill puzzle-factory**
- [x] Core loop: Contract al -> uygun kaynak bul -> pipeline kur -> isle -> teslim et -> yeni bina / yeni kontrat
- [x] Bina maliyeti yok
- [x] Combat / power / heat / para birimi yok
- [x] Persistent sandbox save var, run-based yapi yok

### Demo Scope Lock
- [x] Demo, **T1-T2** odakli olacak
- [x] Demo roster: Classifier, Separator, Recoverer, Research Lab, Decryptor, Encryptor, Compiler, Splitter, Merger, Trash, Contract Terminal
- [x] Demo'da **Malware gameplay YOK**
- [x] Malware, sadece **teaser / ileride acilacak sey** olarak var olabilir
- [x] T3-T4 mekanikleri demo'nun zorunlu parcasi olmayacak
- [x] Demo hedefi: 9 tutorial gig + 4 paralel orta + 3 ileri + 1 yan kontrat + 1 finale = 18 gig
- [x] Demo hedefi: 12-15 kaynaklik oynanabilir havuz

### Mekanik Kararlari
- [x] **Packet gercek urun** olacak; Compiler ciktisi iki ayri teslim gibi sayilmayacak
- [x] **Encryptor demo icinde zorunlu** olacak; acilip kullanilmayan bina olmayacak
- [x] Gig 8+, Encryptor'u gercekten kullanacak
- [x] Gig 9+, Compiler'i gercekten kullanacak
- [x] Source bandwidth, sadece tooltip verisi degil, gameplay'de gercek limit olacak
- [x] Recoverer deterministic + fuel tabanli kalacak
- [x] Grid kablo routing oyunun ana layout bulmacasi olmaya devam edecek (dik kesisim serbest, Bridge kaldirildi)
- [x] **Bina rotasyonu** — R tusuyla 4 yone dondurme, portlar da doner
- [x] **Contract Terminal 3x3** — 8 input port (her kenarda 2), merkez etrafinda 10+ cell kaynak exclusion zone
- [x] **CT Port Purity** — CT her port'un kablo tiplerini kumulatif kaydeder. Content bir gig requirement'ina uyuyorsa state da uymali (yoksa port bloklanir). Content hicbir gig'e uymuyorsa veri kabul edilip cope atilir (akis durmaz). Kablo cikarildiginda kayit sifirlanir.
- [x] **Classifier/Separator Back-Pressure** — Her iki cikis portu (match + reject) bagli olmadan calismazlar. Oyuncuyu reject edilen veriyi Trash veya baska binaya yonlendirmeye zorlar.
- [x] **Uplink kaldirildi** — Kaynaklar dogrudan output portlarina sahip, dikdortgen grid_size, oyuncu kaynak portundan kablo ceker.
- [x] **Kaynak boyutlari** — Her kaynak sabit dikdortgen: easy 2x2, medium 2x3/3x2, hard 3x3, endgame 3x4/4x4.

### Art / Audio Kararlari
- [x] Ana sanat yonu: **procedural-first**
- [x] Hand-crafted detayli illustration zorunlu degil
- [x] Gorsel kalite; siluet, ikon, glow, motion, flow feedback, active/idle kontrasti ile kazanilacak
- [x] Harici asset kullanmak zorunlu degil; gerekiyorsa sadece scope'u kurtaran kucuk yardimci UI/audio parcalari dusunulebilir

### Demo'da Yapilmayacaklar
- [x] Malware Processor implementasyonu
- [x] T3/T4 contract zorunlulugu
- [x] Workshop / mod support
- [x] Multiplayer / co-op
- [x] Buyuk hikaye / campaign katmani
- [x] Tech tree / currency / upgrade ekonomisi buyutme
- [x] Yeni bina patlamasi; mevcut roster polish'i once gelecek

---

## Tamamlanan Fazlar (Ozet)

| Faz | Icerik | Durum |
|-----|--------|-------|
| A | Core Loop — Contract Terminal, gig sistemi, bina acma | TAMAMLANDI |
| B | Veri Modeli — Clean→Public, etiket sistemi | TAMAMLANDI |
| C | Bina Mekanikleri — binary filtreler, Encryptor, Recoverer, Compiler, Trash | TAMAMLANDI |
| D | Tier Revizyon — Key tarifleri, fuel islenmisligi | TAMAMLANDI |
| E | Scope Freeze — GDD/kod hizalama, legacy temizlik, bandwidth limit | TAMAMLANDI |
| F | Contract/Gig UI — kalici panel, progress, reward unlock, toast | TAMAMLANDI |
| G | Tutorial/Onboarding — hint sistemi, stall detection, gig aciklamalari | TAMAMLANDI |
| H | Demo Content — source pool curate, 4 paralel gig, spawn garanti, denge | TAMAMLANDI |
| I | Save/Load + Meta UX — autosave, main menu, options, pause, QoL | TAMAMLANDI |
| J | Visual/Audio Polish — renk paleti, active/idle kontrast, ses, feedback | TAMAMLANDI |
| J-fix | Code Review — tutorial race fix, back-pressure, move integrity, GDD uyumu | TAMAMLANDI |

---

## Claude Code Calisma Kurallari
Bu dokuman, Claude Code tarafindan **takip edilecek execution plan** olarak kullanilacak.

### Genel Kurallar
- Sprint maddelerini **sirayla** ilerlet; gate kapanmadan bir sonraki sprint'e gecme
- Her sprint sonunda oyun **playable state**'te kalmali
- GDD ile kod celisirse, once bu dokumandaki kilitlenmis kararlar, sonra GDD referans alinmali
- Scope'u genisletme; polish'i ve clarity'yi one al
- Yeni sistem eklemeden once "demo'da gercekten gerekli mi?" diye kontrol et
- Kullaniciya gorunen tum metinler **Ingilizce** kalmali
- Her biten task sonrasinda bu dokumandaki checkbox'lari guncelle
- Bir sprint bitmeden baska sprint'ten "ufak bir sey" ekleme aliskanligi edinme

### Escalation Kurali
Asagidaki durumlarda dur ve kullaniciya don:
- Scope lock ile celisen yeni ihtiyac cikarsa
- Demo yerine full-game endgame sistemine kayma riski olursa
- Bir mekanigin iki farkli yorumundan biri secilmeden ilerlemek riskliyse

---

## Next Fest Sprint Plani (12 Hafta)

### Sprint 1: Gorsel Kimlik Temeli (Hafta 1-2: 12-25 Mart)
**Amac:** Oyunun screenshot degerini dramatik artirmak — en dusuk eforla en yuksek gorsel etki.

- [x] **A1. PCB arka plan deseni** — Deterministic hash tabanli PCB trace/via/pad deseni. Zoom-adaptive, performans guvenli.
- [x] **A2. Kablo kalinligini artir** — `CABLE_WIDTH` 3→5, `CABLE_GLOW_WIDTH` 8→11, zoom scale tavani 3.5→2.5, halo carpani 2.5→2.0.
- [x] **A3. Bina siluetlerini farklilas** — 8 farkli polygon siluet (Terminal:sekizgen, Classifier:sivri alt, Compiler:altigen, Recoverer:yuvarlak kose, Decryptor:ust centik, Encryptor:alt centik, Research:pentagon). Normal + PCB mode'da aktif.
- [x] **A4. CRT scanline efekti** — Scanline + film grain shader efekti, Options'tan toggle edilebilir. Tilt-shift/DoF kaldirildi.
- [x] **A5. Monospace font** — JetBrains Mono, default theme + world-space draw'lar dahil tum UI'da aktif.

**Definition of Done:**
- [x] Zoom-out screenshot'ta oyun "parlayan devre karti" gibi gorunuyor
- [x] Binalar uzaktan bile birbirinden ayirt edilebiliyor
- [x] UI metinleri terminal/cyber estetiginde

---

### Sprint 2: Ses + Tema Kimligi (Hafta 3-4: 26 Mart - 8 Nisan)
**Amac:** Cyberpunk temasini isim/metin seviyesinden gorsel+ses+atmosfere tasimak.

- [x] **A6. Cyberpunk ambient muzik** — 10sn loop: deep drone + pad sweep + filtered noise + data pulses + high shimmer. Tamamen prosedürel.
- [x] **A7. Kritik SFX iyilestirme** — Gig complete (7-nota, 4 harmonik, reverb tail), unlock fanfare (bass + 5 nota), discovery chime (4 nota + shimmer), cable connect (snap + resonance + sub-bass). Yeni `_gen_rich_chime()` fonksiyonu.
- [x] **A8. Contract'lara client/faction hissi** — 6 client kimlik: FIXER_NULL, BROKER_7, GHOST_SIGNAL, DR_PATCH, CIPHER_QUEEN, ARCHIVE_X. Gig panelde client satiri ayri renkte (CLIENT_CLR).
- [x] **A9. Main menu atmosferi** — Data rain arka plan (duser hex/binary karakterler) + "SYS_ADMIN" basliginda glitch/flicker efekti (rastgele karakter bozulma + renk flash + pozisyon offset).

**Definition of Done:**
- [x] Oyun acildiginda cyberpunk atmosferi hissediliyor
- [x] Gig complete ani "tatmin edici" duyuluyor
- [x] Contract metinleri "hacker dunyasi" hissi veriyor

---

### Sprint 3: Stability + Bug Bash (Hafta 5-6: 9-22 Nisan)
**Amac:** Demo'nun guvenilir, crashsiz, softlocksiz calismasini garanti etmek.

- [x] **A10. Kritik bug bash** — New Game → Gig 7 tamamlama akisi (5 farkli seed). Save → Quit → Load → devam. Uplink source linkleri save/load sonrasi. Undo/redo temel akislar. 50+ bina + 100+ kablo performans.
- [x] **A11. Building-level root cause feedback** — Her bina "neden calismiyor?" gostersin: "Waiting for Key", "Waiting for fuel", "Output blocked", "No source linked".
- [x] **A12. Edge case duzeltme** — Packet delivery counting dogrulama, tier mismatch durumlari, bos connection'lar, orphan kablolar, paralel gig aktivasyonu.
- [ ] **A13. Steam Next Fest kaydini yap** — Steamworks'ten kayit (27 Nisan oncesi). Demo store page olustur, placeholder capsule art + kisa aciklama.

**Definition of Done:**
- [ ] 5 farkli seed'de tutorial 1-7 + paralel gig'ler sorunsuz tamamlaniyor
- [ ] Save/load/autosave guvenilir
- [ ] Oyuncu tikandiginda bina uzerinden sebebi gorebiliyor
- [ ] Steam Next Fest kaydı tamamlanmis

---

### Sprint 3.5: Demo Content Expansion (Hafta 5-6 arasi)
**Amac:** Tutorial sonrasi icerik derinligini artirmak — dalga sistemi + 5 yeni gig.

- [x] **A13b. Wave/prerequisite sistemi** — `gig_definition.gd`'ye `prerequisite_gigs` alani eklendi, `gig_manager.gd`'de dalga aktivasyonu: tutorial sonrasi Wave 1 (10-13+16), Wave 1 bittikten sonra Wave 2 (14,15,17), Wave 2 bittikten sonra Finale (18).
- [x] **A13c. 5 yeni gig** — Gig 14 Data Laundering (derin zincir: Recover→Encrypt), Gig 15 Twin Decryption (paylasimli Key darbogazı, T2 Key ogretimi), Gig 16 Bulk Harvest (hacim + filtreleme yan kontratin), Gig 17 Hybrid Package (iki farkli islem yolu Compiler'da bulusuyor), Gig 18 The Net Heist (3 paralel mega-pipeline finale, tum client'lar).
- [x] **A13d. Demo sonu tetiklemesi** — Gig 18 (finale) tamamlaninca demo complete ekrani gosterilir. Gig 16 opsiyonel yan kontrat.
- [x] **A13e. Stall hint'leri** — Yeni gig'ler icin stall detection hint text'leri eklendi.

**Definition of Done:**
- [x] Dalga yapisi calisiyor: Tutorial (9) → Wave 1 → Wave 2 → Finale
- [x] 18 gig toplam, her dalga farkli problem tipi sunuyor
- [x] Demo sonu finale gig'e bagli, yan kontrat bloklamıyor

---

### Sprint 4: Demo UX Polish (Hafta 7-8: 23 Nisan - 6 Mayis)
**Amac:** Demo'nun ticari amacina hizmet edecek UX katmanini eklemek.

- [x] **A14. Wishlist + Feedback CTA butonlari** — Main menu'ye "Wishlist Full Game" (Steam URL acar), pause menu'ye "Give Feedback" (form/forum URL), demo bitis ekranina her ikisi.
- [x] **A15. Demo bitis deneyimi** — Paralel gig'ler bittikten sonra: haritada gorünen ama islenemeyen ust seviye kaynak teaser olarak parlasın + "Demo Complete — The full network awaits" + Wishlist CTA.
- [x] **A16. Tooltip iyilestirme** — Her binada hover'da: 1 satir "ne yapar" ozeti + su an ne bekliyor (input/fuel/key durumu) + bagli source bilgisi (Uplink icin).
- [x] **A17. Kilitli binalara acilma kosulu** — Building panel'de kilitli bina: "Unlocks after Gig 4: Financial Recovery" gibi tek satir bilgi.

**Definition of Done:**
- [x] Demo bittiginde oyuncu wishlist'e yonlendiriliyor
- [x] Feedback verme yolu acik
- [x] Tooltip'ler "ne yapıyor + ne bekliyor" sorusunu cevaplayabiliyor
- [x] Kilitli binalar merak uyandiriyor, kafa karistirmiyor

---

### Sprint 5: Screenshot + Trailer + Store Page (Hafta 9-10: 7-20 Mayis)
**Amac:** Steam magaza sayfasinin satis materyalini uretmek — store page = ilk izlenim.

- [ ] **A18. 5 Steam screenshot uret** — (1) Zoom-out: buyuk fabrika, parlayan PCB board (2) Close-up: islem zinciri (Decryptor + Research Lab + kablo akisi) (3) Source discovery: yeni kaynak kesif ani + fog acilmasi (4) Contract Terminal: gig panel acik + yogun network (5) Tutorial ani: ilk pipeline kurulumu + hint
- [ ] **A19. 30-60 saniyelik trailer hook** — 5sn: bos board → ilk Uplink → veri akisi. 10sn: fabrika buyuyor, yeni binalar. 10sn: zoom-out → parlayan devre karti. 5sn: logo + "Wishlist Now".
- [ ] **A20. Store page copy yaz** — Kisa aciklama, tag'ler (Automation, Puzzle, Hacking, Cyberpunk, Logic), "shapez clone" algisından kacinarak "hacking board" / "data heist factory" dilini kullan.

**Definition of Done:**
- [ ] 5 screenshot "Steam magaza sayfasinda dikkat ceker" kalitesinde
- [ ] Trailer hook 30 saniyede oyunun ne oldugunu anlatıyor
- [ ] Store copy oyunu 2 cumlede acikliyor

---

### Sprint 6: Final Build + RC (Hafta 11-12: 21 Mayis - 1 Haziran)
**Amac:** Demo'yu teslim edilebilir, guvenilir, polished final build'e donusturmek.

- [x] **A21. Legacy kod temizligi + Demo Upgrade** — `tech_tree_panel.gd` silindi, `upgrade_panel.gd` building panel'e entegre edildi, Classifier/Recoverer/Research Lab'a upgrade eklendi, demo cap (Lv.1), "🔒 More in full game" tease.
- [x] **A22. Version string + crash save** — "Demo v1.0" build identifier. Kapanista otomatik save (`_notification(NOTIFICATION_WM_CLOSE_REQUEST)`).
- [ ] **A23. 5 seed tam demo playthrough** — Her seed'de: tutorial 1-7, paralel gig'ler, save/load, softlock kontrolu, 1 saatlik oturum stabilitesi.
- [ ] **A24. Press Preview build teslimi** — 18 Mayis
- [ ] **A25. Final review build teslimi** — 1 Haziran

**Definition of Done:**
- [x] Version string "Demo v1.0" + crash save mevcut
- [ ] Demo build crashsiz, softlocksiz, 1 saat+ stabil
- [ ] 5 farkli seed'de tam akis calisiyor
- [ ] Build Steam'e yuklenmeye hazir

---

## Demo Ready Cikisi Icin Zorunlu Son Kriterler
Demo "hazir" sayilabilmesi icin su maddelerin hepsi saglanmali:

- [x] 9 tutorial gig tam ve temiz (her konsept ayri gig'de ogretiliyor)
- [x] Dalga sistemi: 4 Wave 1 + 1 yan kontrat + 3 Wave 2 + 1 finale = 18 gig
- [x] Encryptor ve Compiler zorunlu kullanim goruyor
- [x] Packet gercek urun olarak calisiyor
- [x] Malware gameplay demo'da yok
- [x] Save/load/autosave var
- [x] Contract UI var
- [x] Goal clarity guclu
- [x] Demo source havuzu curate edilmis
- [x] Gorsel kimlik — PCB arka plan, bina siluetleri, kablo kalinligi, CRT efekti
- [x] Ses kimligi — ambient muzik, iyilestirilmis SFX
- [x] Cyberpunk tema — client/faction hissi, monospace font, menu atmosferi
- [x] Temel bug bash tamam
- [x] Building-level root cause feedback var
- [x] Demo bitis deneyimi + Wishlist CTA var
- [ ] Screenshot/trailer capture icin gorsel kalite yeterli
- [ ] Store page copy + capsule art hazir
- [ ] 5 seed'de tam playthrough sorunsuz

---

## Bilinen Sorunlar / Backlog

### Aktif Buglar
_(Tum aktif buglar cozuldu — Sprint 3 kapsaminda)_

### Cozulen Buglar
1. ~~**Bina mirroring eksik**~~ — T tusu ile yatay aynalama eklendi. Placement, idle, undo/redo, save/load destekli.
2. ~~**Contract panel mouse wheel zoom sorunu**~~ — Panel seviyesinde `_gui_input` + `accept_event()` ile wheel yakalaniyor. Panel collapse/expand toggle eklendi (baslik tiklama veya G tusu). Collapsed'da seffaf arka plan, expanded'da koyu panel.
3. ~~**Gig requirement okunurlugu zayif**~~ — RichTextLabel + BBCode ile renk kodlu content ikonu (`[$]`, `[@]`, `[#]`), state/tags renkleri eklendi. Packet'ler iki bilesenli renk kodlu.
4. ~~**Save v1 uyumsuzlugu**~~ — Eski v1 save dosyalari artik migrate ediliyor (Uplink/Bridge temizligi, eksik alanlar ekleniyor).

### Full Game Backlog (Phase 2-3)
5. **Bandwidth authoritative yapma** — `bandwidth` alani suan sadece tooltip'te gorunuyor, gameplay'de `generation_rate` kullaniliyor. Ileride bandwidth'i sim'de authoritative yapip generation_rate'i ona baglamak gerekebilir.
6. **PCB pattern'i GPU shader'a tasima** — Su an CPU'da per-cell hash + draw_line/draw_circle. Fragment shader'a tasinirsa CPU maliyeti sifir olur, sonsuz haritada bile bedava. Oncelik: orta (performans darbogazina duserse yukselt).

---

## Transit-Based Data Flow Sistemi (Aktif Gelistirme)

**Amac:** Veri aninda hedefe ulasmak yerine kablo uzerinde gercekten hareket etsin. Parcacigin hedefe varisi = verinin teslimi. "Gordugun = olan" prensibi.

### Tasarim Kararlari
- Veri kabloya girer (t=0), kablo boyunca ilerler, hedefe varinca (t>=1.0) teslim edilir
- Parcaciklar kozmetik degil, gercek veriyi temsil eder
- Back-pressure: hedef dolu → on item teslim edilemez → arkadakiler durur → kablo stalled → kaynak gondermeyi keser
- Hiz: `TRANSIT_GRIDS_PER_SEC = 3.0` (ayarlanabilir), game speed ile orantili
- Kablo silindiginde / undo-redo'da ucustaki veri kaybolur (Shapez modeli, individual data onemli degil)
- Save/load'da transit kaydedilmez, kablolar bos baslar
- Port Purity kontrolu veri kabloya girerken yapilir (anlik feedback)

### Faz 1: Transit Altyapisi + Push Refactor (simulation_manager.gd)
- [x] Transit veri yapisi: conn["transit"] Array (her item: {key, content, state, tier, tags, amount, t})
- [x] `_push_data_from()` refactor: direkt stored_data yerine transit kuyruğuna t=0'da ekle
- [x] `_push_packet_from()` refactor: ayni sekilde transit'e ekle
- [x] `_advance_transit(delta)`: her frame cagirilir, t ilerletir (smooth hareket)
- [x] `_deliver_arrived()`: her tick, t>=1.0 olan verileri hedef binaya teslim et (partial delivery destekli)
- [x] Back-pressure: kabloda bekleyen item varsa (_is_transit_stalled) yeni veri girmesin
- [x] `connection_flow_data` / `connection_last_flow` → transit'ten turet (gecis uyumu icin)
- [x] Tick sirasi: deliver_arrived → rebuild_flow → generate → forward → process → status → stall → display

### Faz 2: connection_layer.gd Refactor — TAMAMLANDI
- [x] Kozmetik parcacik sistemi kaldirildi (`_conn_particles`, `_conn_spawn_accum`, spawn/drain/pick logic)
- [x] Transit verisini dogrudan render et (her transit item = 1 parcacik, `_draw_transit_items()`)
- [x] Stalled kablo gorselligi (transit stalled → parcaciklar donuk, kablo STALLED rengi)
- [x] Eski flow data bagimliliklari temizlendi (`connection_flow_data`, `connection_last_flow`, `_rebuild_flow_data_from_transit` kaldirildi)
- [x] Cable state → transit durumundan turetiliyor (conn["transit"] non-empty → FLOWING)

### Faz 2.5: Pass-Through + Gorsel Tutarlilik — TAMAMLANDI
- [x] Routing binalari (Separator, Classifier, Splitter, Merger) icin gercek zamanli pass-through
- [x] Item kimligi korunuyor: giren key/content/state/tier/tags ile ayni item cikiyor
- [x] Minimum spacing (1.5 grid cell) — itemlar kablo uzerinde ust uste binmiyor
- [x] Kaynak portunda yigilma yok — t < 1_grid_cell olan itemlar render edilmiyor
- [x] "No input" yanip sonmesi fix — incoming transit varsa status bos kaliyor
- [x] Kablo rengi stabil — kaynak binaya veri geliyorsa cikis kablolari aktif kaliyor
- [x] Her frame delivery — _deliver_arrived() _process()'te de calisiyor (tick'e bagimli degil)
- [x] Dual-input kapasite rezervasyonu — primary veri %75 cap, %25 Key/fuel icin ayrilir

### Faz 3: Storageless Inline Processing — TAMAMLANDI
**Amac:** Processing binalari veri depolamaz. Veri her zaman kablo uzerindedir — ya hareket eder ya da bekler.
Oyuncu her parcacigi kaynaktan CT'ye kadar takip edebilir. "Gordugun = olan" tam anlamiyla gerceklesir.

#### Implementasyon Ozeti
- **Inline isleyiciler (Decryptor/Encryptor/Recoverer):** Veri storage'a yazilmiyor, kablo ucunda (t=1.0) bekliyor. `_process_inline_rendezvous()` her frame calisir, primary+secondary ikisi hazirsa tuketir ve output kablosuna koyar.
- **Trash:** `_deliver_arrived()` icerisinde t=1.0'da aninda imha — storage gecisi yok.
- **Routing binalari (Separator/Classifier/Splitter/Merger):** Pass-through basarisiz olursa iki katmanli back-pressure: (1) Hedef port bagli degilse hard stall — veri kabloda kalir. (2) Port bagli ama gecici stall varsa storage buffer'a duser, tick-based isleme FIFO bloklama olmadan yonlendirir. Downstream storage (ornegin Research Lab 30MB) basinci kademeli emer — normal fabrika oyunu davranisi.
- **Accumulator binalar (Research Lab/Compiler):** Mevcut storage + tick-based model korunuyor.
- **Status reasons:** Transit-aware — "No input", "Waiting for Key/fuel", "Output blocked" kablo durumundan turetiliyor.

#### Basari Kriterleri
- [x] Decryptor/Encryptor/Recoverer storage kullanmiyor
- [x] Randevu mantigi calisiyor: ikisi hazir → isle, biri eksik → ikisi de bekle
- [x] Stall durumunda itemlar kablo uzerinde spacing ile duruyor (yigilma yok)
- [x] Research Lab ve Compiler accumulator modelde calismaya devam ediyor
- [x] Trash aninda yok ediyor (storage gecisi yok)
- [x] Deadlock imkansiz — storage dolup Key/fuel'i bloklamak yok
- [x] Routing binalari pass-through fail → kabloda stall (storage fallback yok)
- [x] Routing buffer: port bagli ama gecici stall → storage fallback ile FIFO bloklama onlenir

---

## Performans Optimizasyon Plani (Aktif Gelistirme)

**Amac:** Demo'da 50+ kablo + 200+ transit item ile 60 FPS garanti. Full release'de 200+ kablo destegi.
**Strateji:**Once algoritmik fix'ler (GDScript), sonra hot path'leri GDExtension C++'a tasima.

### Tespit Edilen Ana Darbogazlar
1. **simulation_manager.gd** — O(n²) connection lookup'lar, frame basina 15+ `get_connections()` kopyasi, `_has_output_connection()` her cagride tum baglantilari tariyor
2. **connection_layer.gd** — Polyline frame basina 2x rebuild, segment lengths her frame yeniden hesaplaniyor, O(n) point-along-path
3. **building.gd** — Her bina her frame `queue_redraw()`, polygon/port/rotation her frame yeniden hesaplaniyor, dirty flag yok
4. **grid_system.gd** — PCB + kablo underglow her frame, viewport culling eksik
5. **bloom_vignette.gdshader** — Piksel basina 25 texture okuma (5x5 bloom)

### Faz 1: Algoritmik Optimizasyonlar (GDScript)
- [x] **P1.1. Connection lookup cache** — `_conn_from`, `_conn_to`, `_output_ports` Dictionary'leri, frame/tick basinda 1 kez olustur. `_has_output_connection()` O(n) → O(1).
- [x] **P1.2. Frame-level get_connections() caching** — `_cached_conns` frame basinda 1 kez alinir. `_advance_transit`, `_deliver_arrived`, `_push_data_from`, `_update_generation`, `_update_stall_tracking`, `_inline_input_status`, `_try_rendezvous` hepsi cache kullanir.
- [x] **P1.3. Polyline + segment length caching** — Connection dict'e `_cached_polyline`, `_cached_seg_lengths`, `_cached_total_length` kaydedildi. Cable length grids da cached. Frame basina 2x rebuild → 0.
- [x] **P1.4. Building polygon caching** — `_cached_base_poly` ve `_cached_closed_poly`, direction/mirror degismedikce yeniden hesaplanmaz. PCB mode dahil.
- [x] **P1.5. Stall tracking tek gecis** — `_conn_from`/`_conn_to` adjacency cache ile O(n²) × 3 → O(E) × 3.
- [x] **P1.6. Bloom shader 5x5 → 3x3** — 25 texture sample → 9. GPU yuku ~%60 azalir.
- [x] **P1.7. Point-along-path binary search** — Cumulative distance array + binary search, O(n) → O(log n). C++ PolylineHelper ile birlikte yapildi.

**Faz 1 Beklenen Etki:** %50-70 CPU + %30 GPU iyilesmesi. Demo icin yeterli olmali.

### Faz 2: GDExtension C++ (Hot Path Migration) — TAMAMLANDI
- [x] **P2.1. TransitSimulator** — `_advance_transit()` C++'a tasindi. Her frame cagrilan transit ilerleme dongusu native.
- [x] **P2.2. StallPropagator** — Back-pressure yayilimi (Pass 2-4) C++'a tasindi. Pass 1 GDScript'te (Godot node method cagrilari gerekli).
- [x] **P2.3. PolylineHelper** — Binary search + batch pozisyon hesaplama C++'a tasindi. `batch_transit_positions()` ile tek C++ cagrisinda tum item pozisyonlari hesaplaniyor.
- [x] **GDScript fallback** — DLL yuklenemezse `ClassDB.class_exists()` kontrolu ile otomatik GDScript'e duser.

**Faz 2 Dosya Yapisi:**
```
gdextension/
  src/                         # C++ kaynak dosyalari
    register_types.cpp/h       # Extension entry point
    transit_simulator.cpp/h    # _advance_transit() native
    polyline_helper.cpp/h      # Binary search + batch positions
    stall_propagator.cpp/h     # Back-pressure propagation
  godot-cpp/                   # Git submodule (master branch)
  SConstruct                   # SCons build dosyasi
  .gdignore                    # Godot'un C++ dosyalarini taramamasi icin
bin/
  sysadmin.gdextension         # DLL tanimlari
  sysadmin.windows.*.dll       # Build ciktisi (.gitignore'da)
```

**Build komutu:** `cd gdextension && scons platform=windows target=template_debug -j4`

**Faz 2 Beklenen Etki:** 200+ kablo + 1000+ transit item ile 60 FPS. Full release icin gerekli.

### Basari Kriterleri
- [x] 50 kablo + 100 transit item'da 60 FPS (Faz 1 sonrasi)
- [ ] 200 kablo + 500 transit item'da 60 FPS (Faz 2 sonrasi — benchmark bekliyor)
- [x] Save/load ve gameplay davranisi degismemis (regresyon yok)

---

## Late-Game Optimizasyon Plani (Aktif — Sonraki Sprint)

**Hedef:** 2000+ kablo, 20000+ parcacik, 800+ bina, sonsuz harita — 60 FPS
**Mimari:** GDScript UI/UX + C++ simulasyon kerneli + GPU shader render + streaming/LOD

### Mimari Karar (Kilitli)
- **GDScript kalacak:** UI, menu/panel, tutorial/gig akisi, save/load orkestrasyonu, placement UX
- **C++ GDExtension:** Simulasyon kerneli (veri modeli, delivery, routing, processing, graph state)
- **GPU Shader:** PCB/grid background, kablo render, parcacik instancing
- **Streaming/LOD:** Chunk unload, viewport culling, zoom-based detay azaltma
- **Kural:** Sadece C++ yetmez — batching + LOD + streaming + packed data model birlikte sart

### Faz 0: Olcum Altyapisi — TAMAMLANDI
- [x] Godot Profiler custom monitor'leri kur (frame time breakdown: sim tick, render, draw calls) — `perf_monitor.gd` (14 custom monitor), `simulation_manager.gd`, `connection_layer.gd`, `grid_system.gd`, `building.gd` instrumented
- [x] Benchmark sahnesi: 200 kablo + 500 item test — `benchmark_runner.gd` (F7 veya `--benchmark` CLI), 20 chain × 10 building = 200 bina + ~180 kablo + ~591 transit item
- [x] Release DLL build dogrulama (`scons target=template_release`) — `bin/sysadmin.windows.template_release.x86_64.dll` build basarili

**Baseline Olcum (200 bina + 180 kablo + 591 transit, RTX 3070):**
| Katman | Süre (us) | Frame % |
|--------|-----------|---------|
| Building draw | 36,689 | 62% |
| Cable draw | 14,151 | 24% |
| Grid draw | 6,837 | 12% |
| Simulation | 1,425 | 2% |
| **TOPLAM** | **~59,100** | **~17 FPS** |

Demo (20-50 bina) sorunsuz calisir. Late-game (800+ bina) icin Faz 1+ gerekli.
Oncelik sirasi: Building draw > Cable draw > Grid draw > Simulation.

### Faz 1: Hizli GDScript Kazanimlari
**Beklenen kazanc: %20-30 CPU, %40-60 draw call**
- [ ] **O1. Dirty connection cache** — `_rebuild_conn_cache()` event-based (baglanti ekleme/silme signal'i ile)
- [ ] **O2. Building list cache** — `get_children()` yerine runtime registry, bina ekleme/silme event'inde guncelle
- [ ] **O3. Viewport frustum culling** — connection_layer.gd'de kamera sinirlari disindaki kablo/parcaciklari atla
- [ ] **O4. Zoom-based LOD** — zoom<0.25: metin yok, zoom<0.5: basit daire, zoom>0.5: tam detay
- [ ] **O5. Port spatial grid** — `_find_port_at()` O(n)→O(1), grid hucresine gore port index
- [ ] **O6. Status reason dirty flag** — polling degil, event-based (durum degistiginde guncelle)
- [ ] **O7. queue_redraw() dirty flag** — bina/source sadece durum degistiginde yeniden cizilsin

### Faz 2: GPU Shader Migration
**Beklenen kazanc: %15-20 CPU, %30-40 draw call**
- [ ] **O8. PCB pattern → fragment shader** — `pcb_background.gdshader`, camera pos+zoom uniform, CPU maliyeti sifir
- [ ] **O9. Grid cizgileri → ayni shader** — PCB shader'a dahil
- [ ] **O10. Kablo underglow → shader** — background layer'da GPU ile

### Faz 3: C++ Simulasyon Kernel
**Beklenen kazanc: %30-40 CPU**
- [ ] **O11. `_deliver_arrived()` → C++** — remove_at(0) O(m)→deque/ring buffer, nested condition native
- [ ] **O12. `_try_passthrough()` → C++** — routing mantigi per-item native
- [ ] **O13. Veri modeli refactoru** — Dictionary/String key→packed int/enum struct (transit item, stored_data)
- [ ] **O14. Generation/processing/storage forward → C++** — tick-based islemler native
- [ ] **O15. Graph state management → C++** — baglanti grafi, adjacency, stall state

### Faz 4: Buyuk Render Overhaul
**Beklenen kazanc: %80-90 draw call**
- [ ] **O16. Parcacik instanced rendering** — 50K draw call→1-2, glyph texture atlas, shader ile renk/glow
- [ ] **O17. Kablo mesh-based rendering** — 4-5 polyline/kablo→1 mesh strip + shader
- [ ] **O18. Building batch rendering** — MultiMesh, 44 unique polygon, 500 bina→44 draw call

### Faz 5: Streaming + Memory
**Late-game surdurulebilirlik**
- [ ] **O19. Chunk unloading** — kameradan uzak chunk'lari serbest birak, kaynak node'lari da unload
- [ ] **O20. Far-object virtualization** — ekran disi binalari lightweight placeholder'a donustur
- [ ] **O21. Node count yonetimi** — object pool (bina, kablo, parcacik), uzun oturum node birikimi onleme

### Bilinen Riskler
- Release DLL: `scons target=template_release` build sart, yoksa export'ta C++ devre disi kalir
- Veri modeli refactoru save/load format degistirir — migration layer gerekli
- Shader uyumluluk: eski GPU'larda instanced rendering icin GDScript fallback sart
- Her faz sonrasi benchmark ile dogrulama — tahminler kesin olcum degil

### Draw Call Hedef Tablosu
| Katman | Demo (simdi) | Late-Game (raw) | Hedef (optimized) |
|--------|-------------|-----------------|-------------------|
| PCB + Grid | 100 | 100 | 0 (shader) |
| Kablo underglow | 50 | 1,000 | 0 (shader) |
| Kablo polyline | 200 | 5,000 | 1,000 (mesh) |
| Parcaciklar | 600 | 50,000 | 1-2 (instanced) |
| Binalar | 375 | 7,500 | 2,000 (dirty+batch) |
| UI + Minimap | 100 | 100 | 50 (lazy) |
| **TOPLAM** | **~1,400** | **~63,700** | **~3,050** |

---

## Altyapi

### GDExtension C++ Modulu
- **Yol:** `gdextension/` — godot-cpp submodule + src/ klasoru
- **Build:** `cd gdextension && scons platform=windows target=template_debug -j4`
- **Cikti:** `bin/sysadmin.windows.template_debug.x86_64.dll`
- **Siniflar:** `TransitSimulator`, `PolylineHelper`, `StallPropagator`
- **Fallback:** DLL yoksa GDScript otomatik devreye girer (`ClassDB.class_exists()` kontrolu)
- **Ilk build** godot-cpp'yi derler (~5-10dk), sonraki build'ler sadece src/ degisikliklerini derler (~5sn)

### Performans-Kritik Kod Kurali
Hot path'lerde (her frame veya her tick cagrilan donguler) performans sorunu yasanirsa:
1. **Once** GDScript'te algoritmik optimizasyon dene (cache, O(n²)→O(n), lazy eval)
2. **Yetmezse** ilgili fonksiyonu GDExtension C++'a tasi (`gdextension/src/` altina)
3. C++ sinifi `RefCounted` extend etmeli, `ClassDB::register_class<>()` ile kaydedilmeli
4. GDScript tarafinda **her zaman fallback** olmali — DLL olmadan oyun calismali
5. C++ tarafinda Godot node method'lari (is_active, can_accept_data vs.) **cagirma** — bu logic GDScript'te kalmali

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
- Tamamlanan isler commit mesajinda belirt, bu dokumandaki ilgili checkbox'i guncelle

---

## Son Not
Bu planin ana ilkesi:
**Scope buyutme degil, clarity + polish + guvenilirlik.**

Eger bir karar "daha fazla sistem" ile "daha iyi demo hissi" arasinda secim gerektiriyorsa,
**her zaman daha iyi demo hissini sec.**
