# SYS_ADMIN - Proje Durumu

## Mevcut Asama: v4 Implementasyon — Demo hazirligi
- **GDD:** `docs/GDD.md` (v3.0) + `docs/v4_design.md` (v4 tasarim kararlari)
- **Kod durumu:** Faz A-J + Sprint 1-4 + Transit + Optimizasyon + v4 Faz 1-7 TAMAMLANDI
- **Hedef:** Steam Next Fest Haziran 2026 icin oynanabilir, polished, v4 mekanikli demo
- **Ticari hedef:** $9.99 fiyat noktasina yakisan kalite ve guven hissi

### Kritik Takvim
| Tarih | Milestone |
|-------|-----------|
| 27 Nisan 2026 | Steam Next Fest kayit sonu |
| 18 Mayis 2026 | Press Preview build |
| 1 Haziran 2026 | Final review teslimi |
| 15-22 Haziran 2026 | Next Fest etkinlik penceresi |

---

## North Star — Ters Shapez
```
Shapez:      Basit parcalar → isle → karmasik urun → teslim
SYS_ADMIN:   Karmasik kaynak → ayikla/coz/onar/temizle → saf veri → teslim
```
- Oyuncu insa etmiyor, **aritiyor.** Content = sekil, State = renk.
- "Basit mekanik + derin kombinasyon + guzel layout" hissi satacak
- Gorsel dil: **procedural / abstract / readable cyber-board** estetigi
- Oyuncu ilk 10-15 dakikada dokumansiz oynayabilmeli

---

## Kilitlenmis Tasarim Kararlari (v4) — Scope Lock

### Oyun Yonu
- Tur: **Ters Shapez — chill puzzle-factory**
- Core loop: Contract al → kaynak bul → pipeline kur → aritstir → teslim et → yeni bina / kontrat
- Bina maliyeti yok | Combat / power / heat / para birimi yok
- **Level-based ilerleme:** 9 level, CT 2x2→10x10, harita 100→800→sonsuz
- **Compiler KALDIRILDI** — biz birlestirmiyoruz, aritiyoruz

### Demo Scope Lock
- Demo **T1-T2** odakli, Level 1 only (2x2 CT, 100x100 harita)
- Roster: Classifier, Separator, Recoverer, Key Forge, Repair Lab, Decryptor, Encryptor, Splitter, Merger, Trash, Contract Terminal
- **Malware gameplay YOK** — sadece full release'de
- Bilesik state: **Enc·Cor** demo'da var (tier escalation: cozulen state'in digeri +1 tier)
- Kazanma kosulu: %100 network (tum kaynaklar CT'ye bagli) → level complete
- Coklu save (5 slot) + level ilerleme kaydi

### Mekanik Kararlari
- Source bandwidth = gercek limit | Grid kablo routing = ana bulmaca (dik kesisim serbest)
- Bina rotasyonu (R, 4 yon) | CT dinamik boyut, port formulu: 4*(size-1)
- CT Port Purity | Classifier/Separator Back-Pressure | Kaynaklar dogrudan output portlu
- Gig tamamlaninca pipeline KALIR (persistent network)
- Sinirli harita (levels 1-8): bolge-grid tabanli esit kaynak dagitimi + gorunur sinir

### Gorsel Dil
- Public=Yesil, Encrypted=Mavi, Corrupted=Sari, Enc·Cor=Bolunmus mavi/sari
- Procedural-first sanat, siluet/ikon/glow/motion/flow feedback

### Demo'da Yapilmayacaklar
- Compiler, Packet, Malware Cleaner, T3/T4, Workshop/mod, Multiplayer
- Buyuk hikaye/campaign, Tech tree/currency/upgrade, Level 2-9 ilerleme

---

## Yapilacaklar

### Screenshot + Trailer + Store Page
- [ ] 5 Steam screenshot uret
- [ ] 30-60sn trailer hook
- [ ] Store page copy yaz
- [ ] Steam Next Fest kaydini yap (27 Nisan oncesi)

### Final Build + RC
- [ ] 5 seed tam demo playthrough
- [ ] Press Preview build teslimi (18 Mayis)
- [ ] Final review build teslimi (1 Haziran)

### Full Game Backlog
- Malware Cleaner + Malware state | Triple bilesik state: Enc·Cor·Mal | T3 tier
- Building batch rendering, chunk unloading, far-object virtualization
- Bandwidth authoritative yapma

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
- Scope'u genisletme; polish ve clarity one al
- Yeni sistem eklemeden once "demo'da gercekten gerekli mi?" kontrol et
- Her degisiklik sonunda oyun **playable state**'te kalmali
- `docs/v4_design.md` tasarim kararlari icin referans dokuman
- Kullanici teknik degil — ne/neden acikla, kod detayi verme
- Commit + push birlikte, kullanici onayi ile

### Escalation Kurali
Dur ve kullaniciya don:
- Scope lock ile celisen yeni ihtiyac cikarsa
- Demo yerine full-game endgame sistemine kayma riski olursa
- Mekanigin iki farkli yorumundan biri secilmeden ilerlemek riskliyse

---

**Ters Shapez: aritstir, birlestirme.**
"Daha fazla sistem" vs "daha iyi demo hissi" → **her zaman daha iyi demo hissini sec.**
