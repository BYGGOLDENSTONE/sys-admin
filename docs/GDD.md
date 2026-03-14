# SYS_ADMIN — Game Design Document

**Versiyon:** 3.0
**Son Guncelleme:** 2026-03-10
**Motor:** Godot 4.6
**Hedef:** $9.99, 100K+ satis, Steam Next Fest Haziran 2026

---

## ICINDEKILER

1. [Oyun Ozeti](#1-oyun-ozeti)
2. [Tasarim Sutunlari](#2-tasarim-sutunlari)
3. [Cekirdek Dongu](#3-cekirdek-dongu)
4. [Sutun 1: Grid Kablo Routing](#4-sutun-1-grid-kablo-routing)
5. [Sutun 2: Mekanik Seti](#5-sutun-2-mekanik-seti)
6. [Sutun 3: Gorsel Kimlik](#6-sutun-3-gorsel-kimlik)
7. [Veri Modeli](#7-veri-modeli)
8. [Tier Sistemi](#8-tier-sistemi)
9. [Yapi Detaylari](#9-yapi-detaylari)
10. [Harita ve Kaynaklar](#10-harita-ve-kaynaklar)
11. [Gig Sistemi (Core Loop)](#11-gig-sistemi-core-loop)
12. [Ilerleme Sistemi](#12-ilerleme-sistemi)
13. [Kisit ve Zorluk](#13-kisit-ve-zorluk)
14. [Gorsel Tasarim Detaylari](#14-gorsel-tasarim-detaylari)
15. [Referans Oyunlar](#15-referans-oyunlar)
16. [Pazar Stratejisi](#16-pazar-stratejisi)
17. [Kapsam ve Yol Haritasi](#17-kapsam-ve-yol-haritasi)
18. [Acik Sorular](#18-acik-sorular)

---

## 1. Oyun Ozeti

**SYS_ADMIN**, oyuncunun siberuzayda veri kaynaklarini kesfedip, grid tabanli kablo routing ile parlayan veri pipeline'lari kurdugu 2D top-down chill otomasyon oyunudur. Oyuncunun fabrikasi yukaridan bakildiginda canli bir devre kartina benzer.

**Tek Cumle:** "Siberuzayda devre karti gibi veri fabrikalari tasarla — her sozlesme yeni bir muhendislik bulmacasi."

**Temel Fantezi:** Contract Terminal'den bir sozlesme aliyorsun: "Bana sifresi cozulmus Biometric veri getir." Kaynagi buluyorsun, pipeline kuruyorsun, veri akmaya basliyor. Ama sifreyi cozmek icin Key lazim — Key icin ayni kaynaktan Research verisi cekmen gerek. Iki paralel hat, birbirini besliyor. Zoom out yaptiginda parlayan bir devre karti goruyorsun — ve onu sen tasarladin.

**Tur:** Chill Otomasyon
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner / Siberuzay
**Hedef:** Gig-Driven Sandbox — sozlesmeler yon verir, oyuncu fabrikalasir

**Ana Referanslar:**
- **Shapez:** Kademeli bulmaca karmasikligi, chill otomasyon, merkez hub teslimat, bina maliyeti yok
- **Factorio:** Grid routing, mekansal bulmacalar, bant yonetimi
- **Satisfactory:** Kaynak → isleme → uretim dongusu, coklu girdili binalar

---

## 2. Tasarim Sutunlari

### Sutun 1: Fabrikan Bir Devre Karti
Oyuncunun yaratimi yukaridan bakildiginda guzel, canli bir devre karti gibi gorunmeli. Parlayan kanallar, titreyen binalar, akan veri nehirleri. Screenshot'lar "bu ne guzel sey?" dedirtmeli.

### Sutun 2: Basit Ogren, Derin Ustalan
Her mekanik sezgisel ("sifreli dosya icin anahtar lazim" — herkes anlar). Karmasiklik bireysel mekanikten degil, KOMBINASYONDAN gelir. Shapez modeli: islemlerin kendisi basit, birlesimleri zor.

### Sutun 3: Her Kaynak Yeni Bir Bulmaca
Yakin kaynaklar basit (tek veri tipi, kolay durum). Uzak kaynaklar karmasik (coklu tip, zor durumlar, yuksek tier). Her yeni kaynak genuinely farkli pipeline tasarimi gerektirir.

### Sutun 4: Layout = Oyun
Kablolar grid uzerinde fiziksel yer kaplar, serbestce kesilemez. Yerlesim planlamak hangi binayi kullanacagin kadar onemli.

---

## 3. Cekirdek Dongu

### Ana Akis: Gig-Driven Pipeline Building

```
[CONTRACT TERMINAL]  — Sozlesme al: "X veriyi Y sekilde isle ve teslim et"
        |
[KESFET]             — Uygun kaynagi haritada bul
        |
[CEK]                — Kaynaga kablo cek, veri cekmeye basla
        |
[AYIKLA]             — Classifier ile istedigin content'i ayir
        |
[AYIR]               — Separator ile istedigin state'i ayir
        |
[ISLE]               — Duruma gore isle:
        |                Decryptor (sifreyi coz — Key gerekli!)
        |                Recoverer (hasari onar — ayni kaynaktan yakit gerekli!)
        |
[PAKETLE]            — Encryptor ile sifrele / Compiler ile birlestir
        |
[TESLIM]             — Contract Terminal'e gonder → Gig tamamlandi!
        |
[GENISLE]            — Yeni bina acilir → daha karmasik gig'ler belirir → tekrarla
```

### Shapez Paraleli

```
Shapez:                          SYS_ADMIN:
Hub'dan seviye gelir             Contract Terminal'den gig gelir
Sekil kes/boya/birlestir         Veri ayir/isle/paketle
Conveyor belt ile Hub'a teslim   Kablo ile Terminal'e teslim
Yeni seviye = daha zor sekil     Yeni gig = daha zor pipeline
Binalar bedava                   Binalar bedava
```

### Temel Gerilim
**"Sozlesme acik — Decrypted Biometric lazim. Ama sifreyi cozmek icin Key uretmem gerek. Key icin Research verisi lazim. Research ayni kaynakta var ama Corrupted — onu onarmak icin de ayni kaynaktan Public veri lazim yakit olarak... tek kaynaktan uc paralel hat!"**

### Pozitif Geri Besleme Dongusu (Core Mechanic)
Oyunun kalbindeki mekanik: **ayni kaynaktan gelen farkli veriler birbirini besler.**

```
Kaynak (Financial Public + Financial Corrupted + Research Encrypted)
   |
   ├── Financial Public ──→ Recoverer'a YAKIT (corrupted'i onarmak icin)
   |
   ├── Financial Corrupted ──→ Recoverer + yakit ──→ Financial Recovered
   |
   └── Research Encrypted ──→ Decryptor + Key ──→ Research Decrypted
                                     ↑
                              Key ←── Research Lab ←── (baska kaynaktan Research)
```

Oyuncu tek kaynak icin birden fazla paralel hat kuruyor. Her hat baska bir hatti besliyor. Bu bir fabrika, kendi kendini besleyen bir sistem.

---

## 4. Sutun 1: Grid Kablo Routing

### Problem
Kablolar noktadan noktaya cizgi olursa, yerlesim onemsizlesir. Oyun "akis semasi cizimine" doner.

### Cozum: Kablolar Grid Uzerinde Fiziksel Yer Kaplar

**Kurallar:**
- Kablolar kare kare dosenilir (Factorio bantlari gibi)
- Her kablo segmenti bir grid hucresi kaplar
- 4 yon: yukari, asagi, sol, sag + koseler
- **IKI KABLO AYNI HUCREYI PAYLASAMAZ**
- Dik acili kablolar serbestce kesisebilir
- Binalarin port pozisyonlari sabit (giris sol, cikis sag vb.)
- Veri kablo boyunca akar (aninda degil, gorulebilir sekilde)
- Veri surekli akar, depolanmaz (Shapez conveyor modeli)

### Kablo Yerlestirme UX

Kablo dosemek oyunun en sik yapilan eylemi. Akici ve tatmin edici olmali.

**Temel Interaksiyon:**
- Tikla-surukle ile kablo doser (Factorio belt modeli)
- Surukleme yonu otomatik yon belirler
- Koseler otomatik olusur (L-seklinde surukle = otomatik kose)
- Baslangic/bitis noktasi bina portlarina snap'lenir
- Ghost onizleme: dosenmeden once rota yesil/kirmizi gosterilir (gecerli/gecersiz)

**Hizli Duzenleme:**
- Sag tikla kablo segmentini siler
- Ctrl+Z undo destegi

### Neden Bu Her Seyi Degistirir
- Yerlesim planlamasi = ana bulmaca
- Alan = kaynak — kompakt tasarimlar verimli ama routing zor
- Yeni kaynak ekleme = mevcut kablo aginin icinden yeni rota bulma
- Zoom-out gorunumu = parlayan devre karti = "factory porn"

---

## 5. Sutun 2: Mekanik Seti

### Felsefe: Basit Islemler, Derin Kombinasyonlar

Her bina tek bir basit is yapar. Zorluk bireysel binalardan degil, birlesimlerin yarattigi pipeline bulmacalarindan gelir. Shapez'deki kes/boya/birlestir gibi — tek basina basit, birlikte derin.

### Bina Listesi

| Bina | Fiil | Kategori | Benzersiz Mekanik |
|------|------|----------|-------------------|
| **Classifier** | Ayikla | Routing | Binary filtre: secilen content sag, kalan sol |
| **Separator** | Ayir | Routing | Binary filtre: secilen state sag, kalan sol |
| **Decryptor** | Coz | Isleme | Cift girdi: veri + Key → Decrypted |
| **Recoverer** | Onar | Isleme | Cift girdi: veri + ayni tur Public yakit → Recovered |
| **Research Lab** | Key uret | Uretim | Research content tuketir → Key uretir |
| **Encryptor** | Sifrele | Donusum | Cift girdi: islenmis veri + Key → Encrypted |
| **Compiler** | Paketle | Donusum | Cift girdi: A + B → Paket [A·B] |
| **Splitter** | Bol | Routing | 1 akis → 2 akis (esit dagitim) |
| **Merger** | Birlestir | Routing | 2 akis → 1 akis |
| **Trash** | Yok et | Altyapi | Istenmeyen veriyi imha eder |
| **Contract Terminal** | Teslim al | Merkez | Gig'leri gosterir + veri teslim noktasi |

**11 bina. Bina maliyeti YOK — bulmaca zorlugu yeter. Binalar gig ilerlemesiyle acilir. Kaynaklar dogrudan output portlarina sahip (Uplink kaldirildi).**

---

## 6. Sutun 3: Gorsel Kimlik

### Problem
Dikdortgenler + ince cizgiler + kucuk noktalar $9.99 icin yeterince cekici degil.

### Cozum: Canli Devre Karti Estetigi

**Kablolar → Veri Otoyollari:**
- Grid hucresi boyutunda parlayan kanallar (ince cizgi degil!)
- Ic renk = akan verinin dominant state'i
- Icinden semboller akar: $ @ # ? ! 0/1
- Yogun trafik = parlak, bos = sonuk
- Koseler ve kavsaklar yumusak gecisli

**Binalar → Canli Makineler:**
- Calisirken animasyonlu (donen elementler, yanip sonen ekranlar, port flash'lari)
- Bostayken sonuk ve hareketsiz (kontrast = anlam)
- Her binanin benzersiz silueti (zoom-out'da bile taninabilir)

**Zoom Seviyeleri:**
- **Uzak:** Parlayan devre karti manzarasi — STEAM SCREENSHOT SEVIYESI
- **Orta:** Binalar, kanallar, veri akisi gorunur
- **Yakin:** Bireysel paketler, bina detaylari, port aktivitesi

**Hedef:** Oyuncunun fabrikasi ekran goruntusu olarak Reddit'e atildiginda "bu ne guzel sey, ne oyunu bu?" dedirtmeli.

---

## 7. Veri Modeli

### Temel Prensip
Her veri paketi iki temel boyuta sahip:
- **Content (Icerik):** Verinin NE oldugu → hangi gig icin kullanilacagini belirler
- **State (Durum):** Verinin NE HALDE oldugu → isleme yolunu belirler

Ek olarak, islem etiketleri birikir ve verinin gecmisini korur.

### Content Tipleri (6)

| Content | Gorsel Sembol | Gorsel Renk | Kolay Kaynak | Zor Kaynak |
|---------|---------------|-------------|-------------|------------|
| **Standard** | 0/1 | #7788aa | Otomat | Her yerde |
| **Financial** | $ | #ffcc00 | ATM | Corporate Server |
| **Biometric** | @ | #ff33aa | Akilli Kilit | Hastane, Askeri Ag |
| **Blueprint** | # | #00ffcc | — | Corporate, Devlet |
| **Research** | ? | #9955ff | — | Biyotek, Devlet |
| **Classified** | ! | #ff3388 | — | Askeri Ag, Blackwall |

### Base State'ler (Kaynaktan Gelen)

| State | Anlam | Isleyici Bina | Gorsel Renk | Tier Var Mi |
|-------|-------|---------------|-------------|-------------|
| **Public** | Acik veri, islem gerektirmez | — | #00ffaa (yesil) | Hayir |
| **Encrypted** | Kilitli veri | Decryptor (Key gerekli) | #2288ff (mavi) | Evet (T1-T4) |
| **Corrupted** | Hasarli veri | Recoverer (yakit gerekli) | #ffaa00 (turuncu) | Evet (T1-T4) |
| **Malware** | Endgame — coklu kaynak cozumu gerektirir | Ozel pipeline | #ff1133 (kirmizi) | Evet (T1-T4) |

**Public'in tier'i YOK.** Public veri direkt kullanilabilir veya baska islemlere yakit olur.

### Islem Etiketleri

Her isleme adimi veriye bir etiket ekler. Etiketler BIRIKIR — verinin islem gecmisi korunur.

| Etiket | Nasil Eklenir | Bina |
|--------|--------------|------|
| **Decrypted** | Encrypted verinin sifresi cozuldu | Decryptor |
| **Recovered** | Corrupted verinin hasari onarildi | Recoverer |
| **Encrypted** | Veri yeniden sifrelendi | Encryptor |

**Etiket Birikmesi Ornekleri:**

```
Financial Encrypted          → Decryptor → Financial DECRYPTED
Financial Decrypted          → Encryptor → Financial DECRYPTED·ENCRYPTED
Biometric Corrupted          → Recoverer → Biometric RECOVERED
Biometric Recovered          → Encryptor → Biometric RECOVERED·ENCRYPTED
```

**Kritik:** "Financial Encrypted" (kaynaktan ham) ≠ "Financial Decrypted·Encrypted" (islenmis + paketlenmis). Ayni content, ayni state adi ama FARKLI urunler. Gig'ler spesifik etiket kombinasyonlari ister.

### Neden Bu Sistem Calisir
- Okuma kolayligi: "Financial Decrypted·Encrypted" — ne oldugunu okuyarak anlarsin
- Combinatorial derinlik: az sayida islemle cok sayida urun
- Gig cesitliligi: her gig farkli etiket kombinasyonu isteyebilir
- Shapez paraleli: kes+boya+birlestir gibi basit islemler, derin kombinasyonlar

---

## 8. Tier Sistemi

### Felsefe: Tier Artisi = Workflow Seklini Degistir, Boyutunu Degil

"Daha fazla bina koy" degil, "farkli dusun" olmali. Encrypted ve Corrupted tier'lari FARKLI sekilde zorlasiyor.

### Encrypted Tier'lari: KEY TARIFI Karmasiklasir

Decryptor ayni kaliyor. Degisen sey: Key'in uretim tarifi.

**T1 (4-bit Encryption):**
```
Research Lab: Research content → Key
Basit: tek kaynak, tek girdi.
```

**T2 (16-bit Encryption):**
```
Research Lab: Research + Financial → Strong Key
Iki farkli content lazim. Iki kaynaktan hat cek.
```

**T3 (256-bit Encryption):**
```
Research Lab: Research + Financial + Biometric → Master Key
Uc farkli content. Uc kaynak. Key fabrikasi buyuyor.
```

**T4 (Quantum Encryption):**
```
Endgame. Key tarifi 4+ content + islenms veri gerektirir.
```

**Oyuncu hissi:** "Daha guclu sifre = daha karmasik anahtar fabrikasi." Decryptor'u cogaltmiyorsun, Key uretim hattini buyutuyorsun.

**Fabrika sekli:** GENIS — cok kaynaktan tek Key fabrikasina dogru akan hatlar.

### Corrupted Tier'lari: YAKIT Zorlasiyor (Pozitif Geri Besleme)

Recoverer ayni kaliyor. Degisen sey: gereken YAKITIN islem seviyesi.

**T1 (Hafif Hasar):**
```
Recoverer: Corrupted veri + [ayni content] PUBLIC yakit → Recovered

Ornek: Financial Corrupted T1 + Financial Public → Financial Recovered
Basit: ayni kaynaktan Public halini ayir, yakit olarak kullan.
```

**T2 (Orta Hasar):**
```
Recoverer: Corrupted veri + [ayni content] DECRYPTED yakit → Recovered

Ornek: Financial Corrupted T2 + Financial DECRYPTED → Financial Recovered
Zor: once Encrypted Financial'i bul → Decryptor'dan gecir → Decrypted Financial'i yakit yap
Yakit KENDISI islem gerektiriyor! Pipeline icinde pipeline.
```

**T3 (Agir Hasar):**
```
Recoverer: Corrupted veri + [ayni content] DECRYPTED·ENCRYPTED yakit → Recovered

Ornek: Financial Corrupted T3 + Financial DECRYPTED·ENCRYPTED → Financial Recovered
Cok zor: Encrypted bul → Decrypt → tekrar Encrypt → bu islenmis veriyi yakit yap.
Uc adimli yakit uretim hatti.
```

**T4 (Kritik Hasar):**
```
Endgame. Yakit = farkli content'lerden olusturulmus paket (Compiler gerekli).
```

**Oyuncu hissi:** "Bu hasar cok agir — onarmak icin kullandigim yakit bile islem gormesi gereken bir sey." Her tier'da yakit hatti bir kademe daha derinlesiyor.

**Fabrika sekli:** DERIN — tek hattan uzun islem zinciri, her adim yakiti daha cok isliyor.

### Encrypted vs Corrupted: Neden Farkli Hissettiriyor

| | Encrypted Tier Artisi | Corrupted Tier Artisi |
|---|---|---|
| **Ne zorlasiyor** | Key'in TARIFI | Yakitin ISLEM SEVIYESI |
| **Ne buyuyor** | Key uretim fabrikasi (yan hat) | Yakit isleme hatti (ayni kaynak icinde) |
| **Daha fazla ne lazim** | FARKLI kaynaklardan content | AYNI kaynaktan daha islenmis veri |
| **Dusunme tarzi** | "Bu kilide hangi malzemelerden anahtar yapmaliyim?" | "Bu yakiti nasil daha fazla islerim?" |
| **Fabrika sekli** | Genis (cok kaynak → Key fabrikasi) | Derin (uzun islem zinciri, geri besleme) |

### Malware: Endgame Boss Puzzle

Malware ne Encrypted ne Corrupted gibi cozulur. **Tek kaynak yetmez.**

Malware temizlemek icin birden fazla kaynak icin kurulmus pipeline'lardan gelen islenmis urunlerin birlestirilmesi gerekir.

```
Ornek: Askeri Ag'dan Classified Malware verisini temizle

  ATM pipeline'i ────── Financial Decrypted ─────────┐
  Hastane pipeline'i ── Biometric Recovered ──────────┼→ Malware Processor → Cleaned
  Kutuphane pipeline'i  Standard Public ──────────────┘

  Askeri Ag ── Classified Malware ────────────────────┘
```

**Oyuncu daha once AYRI kurulan pipeline'lari tek noktada bulusturmali.** Devasa "cyber fabrika" ani — tum hatlar birbirine baglanarak Malware'i cozer. Layout bulmacasinin zirvesi.

**Detaylar henuz tasarlanmadi** — Malware Processor'un kac girdi alacagi, hangi islenmis verilerin gerekecegi dengeleme asamasinda belirlenecek.

---

## 9. Yapi Detaylari

### UPLINK — "Data Extractor"
- Haritadaki kaynak node'unun yanina yerlestirilir
- Kaynaktan veri ceker (kaynağin bandwidth hizinda)
- Cikti: kaynağin content+state dagilimina gore karisik paketler
- Tek cikis portu (sag)
- Her pipeline'in baslangic noktasi

### CLASSIFIER — "Content Filter"
- Gelen veriyi CONTENT TIPINE gore filtreler (binary filtre)
- Oyuncu hangi content'i cikartacagini secer
- 2 cikis portu: Sag = secilen content, Sol = geri kalan her sey
- N content'li kaynaktan spesifik content cikarma = Classifier zinciri gerekli
- Veriyi DEGISTIRMEZ — saf routing

**Ornek — 3 content'li kaynaktan ayiklama:**
```
Karisik (Fin+Bio+Blue) → Classifier "Financial" → Financial (sag)
                                                 → Kalan (sol) → Classifier "Biometric" → Biometric (sag)
                                                                                         → Blueprint (sol)
```

### SEPARATOR — "State Filter"
- Gelen veriyi STATE tipine gore filtreler (binary filtre)
- Oyuncu hangi state'i filtreleyecegini secer
- 2 cikis portu: Sag = secilen state, Sol = geri kalan
- Classifier ile ayni mantik, farkli boyut (content yerine state)

**Ornek:**
```
Financial (Public + Corrupted + Encrypted)
    → Separator "Public" → Financial Public (sag)
                         → Kalan (sol) → Separator "Corrupted" → Financial Corrupted (sag)
                                                                → Financial Encrypted (sol)
```

### DECRYPTOR — "Cipher Breaker" (CIFT GIRDI)
- IKI giris portu: Veri (sol) + Key (ust)
- Encrypted veri + Key → Decrypted veri (DECRYPTED etiketi eklenir)
- Key tuketimi tier'a bagli (T1=1, T2=1, T3=1 Key ama KEY'IN KENDISI farkli)
- Key yoksa bina DURUR, veri kuyrukta bekler
- Content tipi korunur, state etiketi degisir

**Ornek:**
```
Research Lab (Key uretir) ═══╗
                              ╠══ Decryptor ══ Financial DECRYPTED
Financial Encrypted ═════════╝
```

### RECOVERER — "Data Restorer" (CIFT GIRDI — Pozitif Geri Besleme)
- IKI giris portu: Corrupted veri (sol) + Yakit (ust)
- Yakit = AYNI CONTENT turunden veri (islenmislik seviyesi tier'a bagli)
- Yakit varsa %100 calisir, yoksa DURUR
- Cikti: Recovered veri (RECOVERED etiketi eklenir)

**Yakit Kuralları:**
```
T1 yakit: [ayni content] Public         → Financial Corrupted T1 + Financial Public
T2 yakit: [ayni content] Decrypted      → Financial Corrupted T2 + Financial Decrypted
T3 yakit: [ayni content] Decrypted·Encrypted → Financial Corrupted T3 + Financial Decrypted·Encrypted
```

**Neden bu guclu:** Ayni kaynaktan gelen "iyi" veri, "kotu" veriyi onarmak icin yakit oluyor. Oyuncu tek kaynaktan paralel hatlar cekiyor — biri isleme icin, biri yakit icin. Tier arttikca yakitin KENDISI de islem gerektiriyor.

**Ornek — T2 Corrupted recovery pipeline:**
```
Kaynak (Financial Public + Financial Corrupted T2 + Financial Encrypted)
  |
  ├── Financial Public → direkt kullanimlar icin
  |
  ├── Financial Encrypted → Decryptor + Key → Financial Decrypted ──→ Recoverer'a YAKIT
  |                                                                        |
  └── Financial Corrupted T2 ──────────────────────────────────────→ Recoverer → Financial Recovered
```
Yakitin kendisi islem gormeli! Pipeline icinde pipeline.

### RESEARCH LAB — "Key Forge"
- Research content tuketir → Decryption/Encryption Key uretir
- Key tarifi tier'a bagli (Bolum 8'e bak)
- T1: sadece Research, T2: Research + Financial, T3: Research + Financial + Biometric
- Key'ler kablo ile Decryptor/Encryptor'lara gider

### ENCRYPTOR — "Cipher Lock" (CIFT GIRDI — Geri Besleme Dongusu)
- IKI giris portu: Veri (sol) + Key (ust)
- Islenmis veri + Key → yeniden sifrelenmis veri (ENCRYPTED etiketi eklenir)
- Mevcut etiketler korunur: Financial Decrypted → Financial Decrypted·ENCRYPTED
- Decryptor'un tersi — ayni Key'leri tuketir

**Neden onemli:**
- Bazi gig'ler "paketlenmis" (sifrelenmis) veri istiyor
- Key hem Decryptor'a hem Encryptor'a lazim — Key uretim hattinin onemi artiyor
- Ayni kaynaktan: bir content Decryptor'a gider (cozme), baska content Encryptor'a (paketleme)
- Geri besleme dongusu: cikti → isleme → tekrar girdi

### COMPILER — "Data Packager" (CIFT GIRDI)
- IKI giris portu: Veri A (sol) + Veri B (ust)
- Iki farkli islenmis veriyi tek pakete birlestirir
- Cikti: Paket [A·B] (her iki verinin etiketleri korunur)
- Gig'ler spesifik kombinasyon paketleri isteyebilir

**Ornek:**
```
Financial Decrypted ═══════╗
                            ╠══ Compiler ══ Paket [Financial Decrypted · Biometric Recovered]
Biometric Recovered ═══════╝
```

### SPLITTER — "Flow Divider"
- 1 giris → 2 cikis (esit dagitim, donusumlu)
- Paralel isleme icin kullanilir (or: 4x Decryptor setup)

### MERGER — "Flow Combiner"
- 2 giris → 1 cikis (donusumlu)
- Paralel isleme ciktilarini yeniden birlestirme

### BRIDGE — "Cable Junction"
- Iki kablonun kesismesi gereken yere konur
- Isleme yapmaz — saf altyapi
- Bir kablo yatay, digeri dikey gecer

### TRASH — "Data Incinerator"
- Istenmeyen veriyi yok eder
- Gig'ler zorlastikca oyuncu cöpe daha az atar — her veri lazim olur
- Shapez'deki cop kutusu mantigi

### CONTRACT TERMINAL — "Mission Hub"
- Harita merkezinde SABIT (oyuncu yerlestirmez)
- Mevcut gig'leri (sozlesmeleri) gosterir
- Islenmis veriyi teslim alir → gig ilerlemesi sayar
- Gig tamamlaninca yeni bina acilir
- Oyunun kalbi — tum pipeline'lar buraya akar

#### Port Purity Kurali (Kablo Tipi Dogrulama)
Contract Terminal **sadece saf (pure) veri akisi kabul eder.** Her input port'un kablosu kumulatif tip kaydı tutar:

- **Kablo baglandiginda:** Kaynak cikislari icin tum olasi veri tipleri (content × state) aninda kaydedilir — ilk tick'ten once kontrol yapilir
- **Push aninda:** Diger binalardan gelen veri tipleri kabloya kaydedilir ve aninda degerlendirilir
- Port'taki **tum** kayitli tipler aktif bir gig requirement'a eslesiyorsa → **kabul**, veri akar
- Port'ta **tek bir non-matching tip** bile kaydedildiyse → **port kalici olarak bloklanir**, hicbir veri gecmez
- **Kablo cikarildiginda:** Port kaydi sifirlanir, blok kalkar
- **Gig degistiginde:** Tum portlar yeniden degerlendirilir (yeni requirement'lar farkli tipleri kabul edebilir)

**Ornek:** Gig "20 MB Financial Public" istiyor.
- Port'a sadece Financial Public geliyorsa → kabul ✓
- Port'a Financial Public + Biometric Public geliyorsa (ikisi de aktif gig'e uyuyor) → kabul ✓
- ATM kaynagi (70% Financial Public + 30% Financial Corrupted) direkt baglanirsa → **kablo aninda bloklanir** ✗

**Neden:** Bu kural oyunun puzzle cekirdegini korur. Oyuncu kaynaktan gelen karisik veriyi (content + state) filtrelemeden CT'ye teslim edemez. Classifier ile content ayirma, Separator ile state ayirma ZORUNLU hale gelir. Temiz hatlar Merger ile birlestirilebilir.

**Kaynak tasarimi ile uyum:** Tum kaynaklar (tutorial Otomat haric) karisik state icerir (Public + Corrupted/Encrypted). Bu, direkt Kaynak → CT baglantisinin hicbir zaman calismayacagini dogal olarak garanti eder.

---

## 10. Harita ve Kaynaklar

### Harita Yapisi
- 512x512 grid
- Prosedürel uretim (seed-based, her oyunda farkli)
- **Rastgele dagitim** — ring/bolge sistemi YOK
- Sis perdesi (fog of war): kesfedilmemis alanlar gizli
- Yakin bina yerlestirme ile kesif
- Kaynaklar tukenmez (chill otomasyon, stres yok)
- Contract Terminal harita merkezinde sabit

### Tasarim Felsefesi: Factorio/Satisfactory Modeli
Kaynaklar haritaya **rastgele sacilmis.** Zorluk konumdan degil, kaynağin TIPINDEN gelir.

**Neden ring sistemi degil:**
- **Merak:** Yanindaki Askeri Ag'i goruyorsun ama isleyemiyorsun
- **Oyuncu secimi:** Hangi yone gidecegini SEN seciyorsun
- **Replayability:** Her seed genuinely farkli strateji gerektirir
- **Benzersiz fabrikalar:** Herkesin kablo agi farkli gorunur

### Kaynak Tipleri ve Zorluklari

**Kolay Kaynaklar (1-2 content, basit state'ler):**

| Kaynak | Content | State'ler | Bulmaca |
|--------|---------|-----------|---------|
| **Otomat** | Standard | %100 Public | En basit — bagla ve teslim et |
| **ATM** | Financial | %70 Public, %30 Corrupted T1 | Ayirma + ilk recovery ogren |
| **Akilli Kilit** | Biometric | %80 Public, %20 Corrupted T1 | Tek tip, basit recovery |
| **Trafik Kamerasi** | Standard + Biometric | Cogu Public | 2 content — Classifier ogren |
| **Acik Veritabani** | Standard + Bio + Research | Cogu Public, az Corrupted | 3 content, basit state |

**Orta Kaynaklar (2-3 content, karisik state'ler):**

| Kaynak | Content | State'ler | Bulmaca |
|--------|---------|-----------|---------|
| **Hastane Terminali** | Biometric + Research | Public + Encrypted T1 | Ilk encryption — Key lazim |
| **Halk Kutuphanesi** | Standard + Research | Public + Corrupted T1 | Recovery + Research kaynak |
| **Magaza Sunucusu** | Standard + Financial + Biometric | Public + Corrupted T1-T2 | 3 content + T2 yakit bulmacasi |
| **Biyotek Labi** | Bio + Research + Blueprint + Standard | Corrupted T1-T2 + Encrypted T1 | Karisik isleme |

**Zor Kaynaklar (3-4 content, agir state'ler, yuksek tier):**

| Kaynak | Content | State'ler | Bulmaca |
|--------|---------|-----------|---------|
| **Corporate Server** | Financial + Blueprint + Standard | Encrypted T2 + Corrupted T2 | Cift isleme + karmasik Key |
| **Devlet Arsivi** | Research + Classified + Blueprint + diger | Encrypted T3 + Corrupted T2 | Master Key + derin yakit zinciri |

**Endgame Kaynaklar (karmasik content, Malware):**

| Kaynak | Content | State'ler | Bulmaca |
|--------|---------|-----------|---------|
| **Askeri Ag** | Classified + Blueprint + Research | Encrypted T3 + Malware | Coklu kaynak birlestirme |
| **Dark Web Node** | Tum tipler | Tum state'ler, T4 | Evrensel fabrika |
| **Blackwall Parcasi** | Classified + Research + Blueprint | T4 + agir Malware | Nihai bulmaca |

### Kaynak Ozellikleri
Her kaynak su bilgilere sahip:
- **Isim:** Somut, akilda kalici (ATM, Hastane, Askeri Ag)
- **Zorluk seviyesi:** Kolay / Orta / Zor / Endgame
- **Content dagilimi:** Hangi content tipleri, hangi oranlarda
- **State dagilimi:** Her content icin hangi state'ler, hangi oranlarda
- **Maks tier:** Encrypted/Corrupted icin tier limiti
- **Bant genisligi:** Maks cikis hizi (MB/s)
- **Tukenmez:** Kaynaklar bitmez (chill otomasyon)

### Spawn Garanti Kurallari
- **Spawn yaninda:** En az 2 kolay kaynak
- **Yakin cevre:** En az 1 orta kaynak
- **Harita genelinde:** Her content tipinden en az 1 kaynak
- **Dagilim:** Kolay ~%40, Orta ~%30, Zor ~%20, Endgame ~%10
- **Toplam:** ~25-35 kaynak/harita
- **Zor kaynak spawn yaninda olabilir** — gorebilirsin ama isleyemezsin (merak!)

### "Gorebilirsin Ama Isleyemezsin" Mekanigi
```
Oyuncu spawn'da basliyor...
  → Yaninda bir Otomat (kolay, Standard Public) — basla
  → 10 kare otede bir Askeri Ag! — Classified Data, Malware
  → "Vay, orada ne var... ama Decryptor'um bile yok..."
  → 3 saat sonra: "SONUNDA o Askeri Ag'i islemeye hazirim!"
  → Bu his = oyunun bagimlilık dongusu
```

---

## 11. Gig Sistemi (Core Loop)

### Genel Bakis
Gig sistemi oyunun KALBI. Opsiyonel degil, ana ilerleme mekanigi. Contract Terminal'den sozlesmeler alir, pipeline kurarsun, teslim edersin. Her gig yeni mekanik ogretiyor ve yeni bina aciyor.

### Nasil Calisir
1. Contract Terminal'de mevcut gig'ler goruntulenir
2. Gig: "X miktar Y veri isle ve teslim et"
3. Oyuncu pipeline kurar: kaynak → islem → Contract Terminal
4. Veri akar → **CT port purity kontrolu** → eslesiyorsa gig ilerleme sayaci artar
5. Gig tamam → yeni bina acilir + yeni gig'ler belirir
6. Veri teslimde TUKETILIR (Shapez modeli — Hub'a giren veri gider)

> **Port Purity Kurali:** CT, her input port'una bagli kablonun tasidigi veri tiplerini kumulatif olarak kaydeder. Kaynaklar icin kompozisyon kablo baglandiginda aninda yazilir (ilk tick'ten once blok). Diger binalar icin push aninda kaydedilir — paketler dahil. Port'taki TUM kayitli tipler aktif bir gig requirement'a eslesiyorsa veri kabul edilir. Tek bir non-matching tip bile kaydedildiyse port kalici olarak bloklanir. Kablo cikarildiginda kayit sifirlanir. Gig degistiginde tum portlar yeniden degerlendirilir. Detay icin "CONTRACT TERMINAL — Mission Hub" bolumune bak.

### Gig Ilerleme Zinciri

Ilk gig'ler SIRALI (tutorial islevi gorur). Sonra PARALEL acilir.

**Erken Oyun (Sirali — Tutorial):**

| # | Gig | Ne Ogretiyor | Acilan Bina |
|---|-----|-------------|-------------|
| 1 | "20 Standard Public teslim et" | Kaynak + kablo + teslim | Trash, Splitter (baslangic) |
| 2 | "Biometric ve Financial'i AYRI teslim et" | Classifier (binary filtre) | Classifier |
| 3 | "15 Financial Public teslim et" (kaynakta Corrupted var) | Separator (state ayirma) | Separator |
| 4 | "10 Financial Recovered teslim et" | Recovery + pozitif geri besleme | Recoverer |
| 5 | "10 Research Decrypted teslim et" | Key uretimi + decryption | Research Lab, Decryptor |
| 6 | "10 Biometric Decrypted·Encrypted teslim et" | Encryptor + geri besleme dongusu | Encryptor |
| 7 | "5 [Bio + Financial] paket teslim et" | Paketleme | Compiler |

**Orta Oyun (Paralel — Birden Fazla Aktif Gig):**

| Gig Ornegi | Zorluk | Pipeline Gereksinimi |
|-----------|--------|---------------------|
| "20 Blueprint Decrypted teslim et" | Orta | Corporate → Classify → Separate → Decrypt (T2 Key!) |
| "15 Financial Recovered teslim et" (T2) | Orta | ATM → Separate → Decrypt yakiti hazirla → Recover |
| "10 [Research Decrypted · Biometric Recovered] paket" | Zor | 2 kaynak + isleme + paketleme |
| "5 Classified Decrypted·Encrypted" | Zor | Devlet Arsivi → T3 Key + Decrypt + Encrypt |

**Gec Oyun (Karmasik Paralel Gig'ler):**

| Gig Ornegi | Zorluk | Pipeline Gereksinimi |
|-----------|--------|---------------------|
| "Askeri Ag Malware temizle" | Endgame | Coklu kaynak birlestirme |
| "Blackwall verisini isle" | Endgame | T4 Key + T3 yakit + Malware pipeline |

### Gig Odul Sistemi
- Her gig yeni bina acar (ilerleme)
- Ileri gig'ler mevcut binalarin verimlilgini artirabilir
- Detayli odul dengeleme henuz tasarlanmadi

---

## 12. Ilerleme Sistemi

### Bina Acilma Siralamasi

Binalar gig tamamlayarak acilir. Bina maliyeti YOK — bulmaca zorlugu yeter.

| Asama | Acilan Binalar | Tetikleyici |
|-------|---------------|-------------|
| **Oyun Basi** | Trash, Splitter | — |
| **Gig 2** | Classifier | Ilk content ayirma gig'i |
| **Gig 3** | Separator | Ilk state ayirma gig'i |
| **Gig 4** | Recoverer | Ilk recovery gig'i |
| **Gig 5** | Research Lab, Decryptor | Ilk decryption gig'i |
| **Gig 6** | Encryptor | Ilk sifreleme gig'i |
| **Gig 7** | Compiler | Ilk paketleme gig'i |
| **Gec Oyun** | Malware Processor | Malware gig'i |

### Ilerleme Asamalari

| Asama | Oyuncu Deneyimi | His |
|-------|----------------|-----|
| **Copcu** | Tek kaynak, tek hat, Public veri | "Anladim, basit" |
| **Ayirici** | Classifier + Separator, coklu cikis | "Farkli veriler farkli yonlere!" |
| **Muhendis** | Decryptor + Research Lab, Key zinciri | "Bu gercek bir fabrika" |
| **Mimar** | Coklu kaynak, paralel gig, geri besleme | "Devre kartima bak!" |
| **Netrunner** | Malware, T3-T4, tum mekanikler birlikte | "Sisteme hakim oldum" |

---

## 13. Kisit ve Zorluk

### Felsefe: Shapez Modeli — Saf Otomasyon Bulmacasi
Power, heat, combat, para birimi YOK. Challenge tamamen pipeline tasarimindan gelir.

| Kisit | Nasil Calisir | Oyuncu Karari |
|-------|--------------|---------------|
| **Kablo routing** | Kablolar grid'de yer kaplar | "Bu hatti nereye cekeyim?" |
| **Content cesitliligi** | Zor kaynaklar 3-4+ content | "Kac Classifier zincirlersem?" |
| **State karisikligi** | Kaynaklar karisik state | "Her state icin ayri hat lazim" |
| **Key tedarigi** | Tier arttikca Key tarifi zorlasir | "Key fabrikam yeterli mi?" |
| **Yakit dongusu** | Corrupted tier arttikca yakit islenmeli | "Yakitim icin ayri pipeline mi?" |
| **Geri besleme** | Encryptor/Recoverer ayni kaynaktan yakit | "Bu kaynaktan kac paralel hat?" |
| **Layout planlamasi** | Yeni kaynak = mevcut fabrikadan hat cekme | "Mevcut kablolarin arasinda yer var mi?" |
| **Gig karmasikligi** | Gec gig'ler karmasik urun istiyor | "Bu urunu uretmek icin kac kaynak lazim?" |

### Zorluk Kaynaklari (Uc Eksen)

```
EKSEN 1: GIG KARMASIKLIGI
  Erken: "Public veri teslim et"
  Gec:   "Decrypted·Encrypted paket teslim et" (cok adimli islem)

EKSEN 2: KAYNAK KARMASIKLIGI
  Kolay: 1 content, Public
  Zor:   4 content, T3 Encrypted + T3 Corrupted (istenen veriyi ayikla + isle)

EKSEN 3: LAYOUT KARMASIKLIGI
  Erken: Tek kaynak, kisa hat
  Gec:   10+ kaynak, yuzlerce kablo, routing bulmacasi
```

Uc eksen birlikte: ayni gig farkli kaynaklardan farkli zorlukta cozulebilir. Oyuncu stratejik olarak **hangi kaynaktan cekmenin daha verimli olduguna** karar verir.

---

## 14. Gorsel Tasarim Detaylari

### Sanat Stili: Prosedürel + Shader (Sifir Harici Asset)
Her sey kodla cizilir + shader efektleri. Sprite yok, satin alinan asset yok.

### Renk Paleti ("Dark PCB")

```
Arka plan:     #060a10 (koyu siyah)
Grid:          #0f1520
Bina govde:    #0a0d14
UI Accent:     #00bbee (teal-cyan)

State Renkleri:
  Public:      #00ffaa (neon yesil)
  Encrypted:   #2288ff (neon mavi)
  Corrupted:   #ffaa00 (neon turuncu)
  Malware:     #ff1133 (neon kirmizi)

Content Renkleri:
  Standard:    #7788aa
  Financial:   #ffcc00
  Biometric:   #ff33aa
  Blueprint:   #00ffcc
  Research:    #9955ff
  Classified:  #ff3388
  Key:         #ffaa00
```

### Shader Efektleri
- **Bloom:** Kablo ve binalarda neon parlama
- **CRT:** Hafif tarama cizgileri + kromatik sapma
- **Vignette:** Ekran kenarlarinda kararma
- **Glow outline:** Bina kenarlarinda renk kodlu titresim

### Ses Tasarimi

**Ambient Katmani:**
- Temel: dusuk frekanslı dijital hum
- Aktif kablo sayisina gore yogunluk artar
- Zoom seviyesine gore ses degisir

**Bina Sesleri (her bina benzersiz):**
- Kaynak baglanti: veri cekme/indirme pulse
- Classifier/Separator: routing "tik-tak"
- Decryptor: dijital "crack" efekti
- Recoverer: tarama/onarma sesi
- Encryptor: sifreleme/paketleme sesi
- Compiler: sentez sesi
- Research Lab: arastirma hum'i
- Trash: imha sesi

**UI Sesleri:**
- Kablo doseme: tatmin edici "snap"
- Bina yerlestirme: sagdam "placement"
- Gig tamamlama: basari jingle
- Yeni bina acilma: kilit acma sesi

---

## 15. Referans Oyunlar

| Oyun | Ne Aliyoruz | Ne Almiyoruz |
|------|------------|-------------|
| **Shapez** | Hub teslimat, bedava binalar, kademeli bulmaca, chill | Sekil-spesifik mekanikler |
| **Factorio** | Grid routing, mekansal bulmaca, bant yonetimi | Savas, kirlilik, devasa kapsam |
| **Satisfactory** | Coklu girdili binalar, kaynak→isleme dongusu | 3D, buyuk kapsam |
| **Mindustry** | Harita kaynaklar, cikarim | Kule savunma |
| **Hacknet** | Cyberpunk estetik, terminal hissi | Tekrarci oynanis |

### Kritik Dersler
- **Shapez'den:** Bina maliyeti yok, bulmaca yeter. Hub merkezi teslimat. Operasyonlar basit, kombinasyonlar zor.
- **Factorio'dan:** Grid routing = oyun. Layout planlamasi ana bulmaca.
- **Satisfactory'den:** Coklu girdili tarifler en iyi lojistik bulmacalari yaratir. Surekli tuketim fabrikalari canli tutar.

---

## 16. Pazar Stratejisi

### Hedef
- **Fiyat:** $9.99
- **Satis hedefi:** 100K+
- **Platform:** Steam
- **Cikis:** Steam Next Fest demo sonrasi

### Hook + Anchor
- **Hook:** "Siberuzayda parlayan devre kartlari tasarla — veri madenciligi otomasyon bulmacasi"
- **Anchor:** "Shapez'in kademeli bulmacalari + Factorio'nun grid routing'i"

### Steam Next Fest Stratejisi
- Demo: Gig 1-7 + birkac paralel gig
- ~12-15 kaynak (kolay + orta + gec oyun gorsel teaser)
- 4-6 saatlik demo deneyimi
- Screenshot'lar etkileyici olmali (devre karti estetigi = satis noktasi)

---

## 17. Kapsam ve Yol Haritasi

### Demo Kapsami (Next Fest) — 4-6 saat
- Grid kablo routing (dik kesisim serbest)
- 10 bina: Classifier, Separator, Recoverer, Decryptor, Research Lab, Encryptor, Compiler, Splitter, Merger, Trash
- Contract Terminal (sabit, harita merkezinde)
- ~12-15 kaynak (kolay + orta + birkac zor teaser)
- 5 content: Standard, Financial, Biometric, Research, Blueprint
- 3 state: Public, Corrupted (T1-T2), Encrypted (T1-T2)
- 7 sirali tutorial gig + 3-5 paralel orta gig
- Tam gorsel islem (devre karti estetigi)
- Malware YOK (tam oyuna sakla)

### Tam Oyun Kapsami
- 13 binanin tamami (+ Malware Processor)
- ~25-35 kaynak/harita
- 6 content tipinin tamami
- 3 state + Malware + tam tier sistemi (T1-T4)
- Paralel gig sistemi, onlarca gig
- Endgame: Malware pipeline bulmacalari

### Lansman Sonrasi Potansiyel
- Yeni content tipleri
- Yeni bina tipleri
- Topluluk challenge'lari
- Trace/hostile AI katmani (aktif tehdit mekanigi)

---

## 18. Acik Sorular

### Tasarlanacak
- [ ] Bina isleme hizlari ve dengeleme
- [ ] Gig zorluk skalasi ve odul detaylari
- [ ] Gig sayisi ve cesitliligi (toplam kac gig?)
- [ ] Malware Processor detaylari (kac girdi, nasil calisir?)
- [ ] Kaynak spawn dagilim algoritmasi ve dengeleme
- [ ] Bina boyutlari (hepsi 2x2 mi, bazi 1x1 mi?)
- [ ] Bina ic buffer boyutu (Shapez modeli — kucuk ama ne kadar?)
- [ ] Key tuketim orani ve dengeleme
- [ ] Recoverer yakit tuketim orani
- [ ] T4 Key ve yakit tarifleri (endgame)
- [ ] Ses asset'leri (prosedürel vs free library)

### Dogrulanmis Kararlar
- [x] Grid kablo routing (Factorio modeli)
- [x] Gig sistemi = core loop (Shapez hub modeli)
- [x] Contract Terminal harita merkezinde sabit
- [x] Bina maliyeti YOK — gig ile acilir (Shapez modeli)
- [x] Storage binasi YOK — veri surekli akar
- [x] Public (eski "Clean") state ismi
- [x] Islem etiketleri birikir (Decrypted, Recovered, Encrypted)
- [x] Classifier = binary filtre (sag: secilen, sol: kalan)
- [x] Separator = binary filtre (state icin)
- [x] Recoverer = deterministik + yakit tabanli (olasilik YOK)
- [x] Recoverer yakiti = ayni content'in islenmis hali (pozitif geri besleme)
- [x] Corrupted tier = yakit islenmisligi artar (pipeline icinde pipeline)
- [x] Encrypted tier = Key tarifi karmasiklasir (farkli content'ler)
- [x] Encryptor binasi (Decryptor'un tersi, geri besleme dongusu)
- [x] Compiler = paketleyici (iki veriyi birlestir)
- [x] Trash = basit cop (Shapez modeli)
- [x] Malware = endgame boss puzzle (coklu kaynak birlestirme)
- [x] Chill otomasyon (savas, power, heat YOK)
- [x] Devre karti gorsel kimligi
- [x] Rastgele dagitimli harita, somut kaynak isimleri
- [x] $9.99 fiyat hedefi

### Reddedilen Fikirler
- ~~Credits/para birimi~~ → Bina maliyeti yok, gig ile acilir
- ~~Storage binasi~~ → Veri surekli akar (Shapez modeli)
- ~~Refined malzeme sistemi~~ → Compiler = paketleyici
- ~~Olasiliksal Recoverer~~ → Deterministik + yakit tabanli
- ~~Quarantine (doluluk/flush)~~ → Trash (basit cop)
- ~~Residue (yan urun)~~ → Recoverer deterministik, yan urun yok
- ~~Tech Tree~~ → Gig ilerlemesi ile bina acma
- ~~Power/Heat sistemi~~ → Saf otomasyon
- ~~Noktadan noktaya kablolar~~ → Grid routing
- ~~Ayni mekanikli isleyiciler~~ → Her bina benzersiz fiil
- ~~Ring/halka sistemi~~ → Rastgele dagitim
- ~~Research Points~~ → Research Lab direkt Key uretir
- ~~Compressor~~ → Scope disinda
- ~~Replicator~~ → Gereksiz
- ~~Duplicator~~ → Oyunu kirar
- ~~Validator~~ → Gereksiz karmasiklik
- ~~Karisim tipleri (Bond/Fused/Obfuscated)~~ → Basit Classifier zinciri yeter
- ~~Stabilizer binasi~~ → Yakit tier sistemi ile gereksiz
- ~~Tier = daha fazla bina koy~~ → Tier = workflow seklini degistir

---

*Bu dokuman canlidir ve her tasarim oturumunda guncellenecektir.*
*Versiyon 3.0 — Tamamen yeniden yazildi. Gig-driven core loop, Shapez ekonomi modeli, pozitif geri besleme mekanigi, etiket sistemi.*
