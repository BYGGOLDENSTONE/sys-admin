# SYS_ADMIN — Game Design Document

**Versiyon:** 4.0
**Son Guncelleme:** 2026-03-15
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
9. [Bilesik State Sistemi](#9-bilesik-state-sistemi)
10. [Yapi Detaylari](#10-yapi-detaylari)
11. [Harita ve Kaynaklar](#11-harita-ve-kaynaklar)
12. [Gig Sistemi](#12-gig-sistemi)
13. [Uc Faz Yapisi](#13-uc-faz-yapisi)
14. [Ilerleme Sistemi](#14-ilerleme-sistemi)
15. [Save Sistemi](#15-save-sistemi)
16. [Kisit ve Zorluk](#16-kisit-ve-zorluk)
17. [Gorsel Tasarim Detaylari](#17-gorsel-tasarim-detaylari)
18. [Referans Oyunlar](#18-referans-oyunlar)
19. [Pazar Stratejisi](#19-pazar-stratejisi)
20. [Kapsam ve Yol Haritasi](#20-kapsam-ve-yol-haritasi)
21. [Kesinlesmis Kararlar](#21-kesinlesmis-kararlar)
22. [Acik Sorular](#22-acik-sorular)

---

## 1. Oyun Ozeti

**SYS_ADMIN**, oyuncunun siberuzayda veri kaynaklarini kesfedip, grid tabanli kablo routing ile parlayan veri pipeline'lari kurdugu 2D top-down chill otomasyon oyunudur. Oyuncunun fabrikasi yukaridan bakildiginda canli bir devre kartina benzer.

### Ters Shapez Modeli

```
Shapez:      Basit parcalar → isle → karmasik urun → teslim
SYS_ADMIN:   Karmasik kaynak → ayikla/coz/onar/temizle → saf veri → teslim
```

Oyuncu insa etmiyor, **aritiyor.** Content = sekil, State = renk. Hacker fantezisi — sifreli, bozuk, enfekte veriyi temizleyip merkeze teslim et.

**Tek Cumle:** "Siberuzayda devre karti gibi veri fabrikalari tasarla — her sozlesme yeni bir muhendislik bulmacasi."

**Temel Fantezi:** Contract Terminal'den bir sozlesme aliyorsun: "Bana sifresi cozulmus Biometric veri getir." Kaynagi buluyorsun, pipeline kuruyorsun, veri akmaya basliyor. Ama sifreyi cozmek icin Key lazim — Key icin Key Forge'a Research verisi beslemen gerek. Iki paralel hat, birbirini besliyor. Zoom out yaptiginda parlayan bir devre karti goruyorsun — ve onu sen tasarladin.

**Tur:** Chill Otomasyon
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner / Siberuzay
**Hedef:** Gig-Driven Sandbox — sozlesmeler yon verir, oyuncu fabrikalasir

### North Star

Oyuncunun amaci haritadaki sunuculari Contract Terminal'e baglayip surekli veri akisi saglayan devasa bir cyber web olusturmak. Gig tamamlama bu hedefe ulasmanin araci. Zoom out yapildiginda harita parlayan kablolarla kapli — "devre karti sehir."

### Ana Referanslar
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
        |                Recoverer (hasari onar — Repair Kit gerekli!)
        |
[SIFRELE]            — Encryptor ile yeniden sifrele (Key gerekli!)
        |
[TESLIM]             — Contract Terminal'e gonder → Gig tamamlandi!
        |
[GENISLE]            — Yeni bina acilir → daha karmasik gig'ler belirir → tekrarla
```

### Shapez Paraleli

```
Shapez:                          SYS_ADMIN:
Hub'dan seviye gelir             Contract Terminal'den gig gelir
Sekil kes/boya/birlestir         Veri ayir/isle/sifrele
Conveyor belt ile Hub'a teslim   Kablo ile Terminal'e teslim
Yeni seviye = daha zor sekil     Yeni gig = daha zor pipeline
Binalar bedava                   Binalar bedava
```

### Temel Gerilim
**"Sozlesme acik — Decrypted Biometric lazim. Ama sifreyi cozmek icin Key lazim. Key icin Key Forge'a Research verisi beslemeliyim. Research ayni kaynakta var ama Corrupted — onu onarmak icin Repair Kit lazim, Repair Lab'a Standard veri beslemeliyim... tek kaynaktan uc paralel hat!"**

### Pozitif Geri Besleme Dongusu (Core Mechanic)
Oyunun kalbindeki mekanik: **farkli kaynaklardan gelen veriler birbirini besler.**

```
Kaynak A (Financial Public + Financial Corrupted + Financial Encrypted)
   |
   ├── Financial Encrypted → Decryptor + Key → Financial Decrypted
   |                                  ↑
   |                    Key ←── Key Forge ←── Research content (Kaynak B)
   |
   └── Financial Corrupted → Recoverer + Repair Kit → Financial Recovered
                                       ↑
                         Repair Kit ←── Repair Lab ←── Standard content (Kaynak C)
```

Her isleme hatti farkli kaynaktan gelen farkli tur veri gerektiriyor. Bu bir fabrika, birden fazla kaynagi birlestiren, kendi kendini besleyen bir sistem.

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
- **Dik acili kablolar serbestce kesisebilir** (Bridge gerekmez)
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

### Simetrik Tasarim: Key Forge + Repair Lab

v4'un en onemli tasarim karari: **Decryptor ve Recoverer artik simetrik calisir.**

```
Encrypted veri → Decryptor + Key        → Decrypted veri
                              ↑
                    Key Forge (Research + tier content)

Corrupted veri → Recoverer + Repair Kit → Recovered veri
                              ↑
                    Repair Lab (Standard + tier content)
```

Her ikisi de:
- Cift girdili bina (veri + tuketilebilir)
- Tuketilebilir uretici bina (Key Forge / Repair Lab)
- Tier arttikca uretici TARIF karmasiklasiyor (daha fazla content turu gerekli)
- Fabrika GENIS buyuyor (farkli kaynaklardan hat cekmek gerekli)

### Bina Listesi (11 Bina)

| Bina | Fiil | Kategori | Benzersiz Mekanik |
|------|------|----------|-------------------|
| **Classifier** | Ayikla | Routing | Binary filtre: secilen content sag, kalan alt |
| **Separator** | Ayir | Routing | Binary filtre: secilen state sag, kalan alt |
| **Splitter** | Bol | Routing | 1 akis → 2 akis (esit dagitim) |
| **Merger** | Birlestir | Routing | 2 akis → 1 akis |
| **Decryptor** | Coz | Isleme | Cift girdi: veri + Key → Decrypted |
| **Recoverer** | Onar | Isleme | Cift girdi: veri + Repair Kit → Recovered |
| **Encryptor** | Sifrele | Donusum | Cift girdi: islenmis veri + Key → Encrypted |
| **Key Forge** | Key uret | Uretim | Research content tuketir → Key uretir (tier tarifli) |
| **Repair Lab** | Kit uret | Uretim | Standard content tuketir → Repair Kit uretir (tier tarifli) |
| **Trash** | Yok et | Altyapi | Istenmeyen veriyi imha eder |
| **Contract Terminal** | Teslim al | Merkez | Gig'leri gosterir + veri teslim noktasi |

**Bina maliyeti YOK — bulmaca zorlugu yeter. Binalar gig ilerlemesiyle acilir. Kaynaklar dogrudan output portlarina sahip.**

---

## 6. Sutun 3: Gorsel Kimlik

### Problem
Dikdortgenler + ince cizgiler + kucuk noktalar $9.99 icin yeterince cekici degil.

### Cozum: Canli Devre Karti Estetigi

**Kablolar → Veri Otoyollari:**
- Grid hucresi boyutunda parlayan kanallar (ince cizgi degil!)
- Ic renk = akan verinin dominant state'i
- Icinden semboller akar: $ @ # ? ! 0/1 +
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

### Content Tipleri (8)

| # | Content | Gorsel Sembol | Gorsel Renk | Aciklama |
|---|---------|---------------|-------------|----------|
| 0 | **Standard** | 0/1 | #7788aa | En yaygin, her yerde bulunur |
| 1 | **Financial** | $ | #ffcc00 | ATM, Corporate kaynaklarinda |
| 2 | **Biometric** | @ | #ff33aa | Hastane, Akilli Kilit kaynaklarinda |
| 3 | **Blueprint** | # | #00ffcc | Corporate, Devlet kaynaklarinda (orta-zor) |
| 4 | **Research** | ? | #9955ff | Biyotek, Kutuphane kaynaklarinda (orta-zor) |
| 5 | **Classified** | ! | #ff3388 | Askeri, Devlet kaynaklarinda (sadece zor) |
| 6 | **Key** | ★ | #ffaa00 | Key Forge tarafindan uretilir (oyuncu yerlestirmez) |
| 7 | **Repair Kit** | + | #ff7744 | Repair Lab tarafindan uretilir (oyuncu yerlestirmez) |

Content 0-5 kaynaklardan gelir. Content 6-7 uretim binalari tarafindan olusturulur.

### Base State'ler

| State | Anlam | Isleyici Bina | Gerekli Tuketilebilir | Gorsel Renk | Tier |
|-------|-------|---------------|-----------------------|-------------|------|
| **Public** | Acik veri, islem gerektirmez | — | — | #00ffaa (yesil) | Yok |
| **Encrypted** | Kilitli veri | Decryptor | Key (Key Forge) | #2288ff (mavi) | T1-T4 |
| **Corrupted** | Hasarli veri | Recoverer | Repair Kit (Repair Lab) | #ffaa00 (turuncu) | T1-T4 |
| **Enc·Cor** | Hem sifreli hem bozuk | Decryptor VEYA Recoverer (sira secimi) | Key veya Repair Kit | Yari mavi, yari sari | T1-T4 |

**Demo:** Public, Encrypted (T1-T2), Corrupted (T1-T2), Enc·Cor
**Full Release:** + Malware state (T1-T4, Malware Cleaner ile temizlenir)

### Islem Etiketleri (Tags — Birikimli)

Her isleme adimi veriye bir etiket ekler. Etiketler BIRIKIR — verinin islem gecmisi korunur.

| Etiket | Bina | Bit |
|--------|------|-----|
| **DECRYPTED** | Decryptor | 1 (0x1) |
| **RECOVERED** | Recoverer | 2 (0x2) |
| **ENCRYPTED** | Encryptor | 4 (0x4) |
| **CLEANED** | Malware Cleaner (release) | 8 (0x8) |

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

### Felsefe: Tier Artisi = Uretici Tarif Karmasikligi

Encrypted ve Corrupted tier'lari ayni prensiple calisir: tier arttikca ilgili uretici binanin (Key Forge / Repair Lab) TARIFI daha fazla content turu gerektirir. Fabrika GENIS buyuyor.

### Encrypted Tier'lari: Key Forge Tarifi Karmasiklasir

Decryptor ayni kaliyor. Degisen sey: Key'in uretim tarifi.

| Tier | Key Forge Girdisi | Bulmaca |
|------|-------------------|---------|
| **T1** | Research | Tek kaynak, tek girdi |
| **T2** | Research + Biometric | Iki farkli content lazim |
| **T3** | Research + Biometric + Financial | Uc farkli content lazim |

**Oyuncu hissi:** "Daha guclu sifre = daha karmasik anahtar fabrikasi." Key uretim hattini buyutuyorsun.
**Fabrika sekli:** GENIS — cok kaynaktan Key Forge'a dogru akan hatlar.

### Corrupted Tier'lari: Repair Lab Tarifi Karmasiklasir

Recoverer ayni kaliyor. Degisen sey: Repair Kit'in uretim tarifi.

| Tier | Repair Lab Girdisi | Bulmaca |
|------|---------------------|---------|
| **T1** | Standard | Tek kaynak, basit |
| **T2** | Standard + Financial | Iki farkli content lazim |
| **T3** | Standard + Financial + Blueprint | Uc farkli content lazim |

**Oyuncu hissi:** "Daha agir hasar = daha karmasik onarim kiti fabrikasi." Repair Kit uretim hattini buyutuyorsun.
**Fabrika sekli:** GENIS — cok kaynaktan Repair Lab'a dogru akan hatlar.

### Encrypted vs Corrupted: Simetrik Ama Farkli

| | Encrypted Tier Artisi | Corrupted Tier Artisi |
|---|---|---|
| **Ne zorlasiyor** | Key TARIFI | Repair Kit TARIFI |
| **Uretici bina** | Key Forge | Repair Lab |
| **Temel content** | Research (nadir) | Standard (yaygin) |
| **Ek content'ler** | +Biometric, +Financial | +Financial, +Blueprint |
| **Kaynak farki** | Research kaynagi bulmak gerekli | Standard her yerde ama ek content'ler farkli |

### Malware: Endgame Boss Puzzle (Full Release)

Malware ne Encrypted ne Corrupted gibi cozulur. Malware Cleaner binasi + Recovered antivirus gerektirir.

---

## 9. Bilesik State Sistemi

### Enc·Cor: Hem Sifreli Hem Bozuk

Bazi kaynaklar tek veri uzerinde birden fazla state tasiyan veri uretir.

**Demo:** Enc·Cor (Encrypted + Corrupted)
**Full Release:** + Enc·Mal, Cor·Mal, Enc·Cor·Mal

### Gorsel Dil

State'ler renk ile temsil edilir. Bilesik state'lerde veri ikonu **yari yariya bolunur:**

| State | Renk |
|-------|------|
| Public | Yesil |
| Encrypted | Mavi |
| Corrupted | Sari |
| Enc·Cor | Yari mavi, yari sari (bolunmus ikon) |

Oyuncu dual state'i sembol + bolunmus renk ile bir bakista okuyor — tipki Shapez'de cok katmanli sekilleri okumak gibi.

### Tier Escalation Kuralı

Bilesik state'li veride bir state'i cozunce **digerinin tier'i +1 artar.**

**Ornek: Financial Enc T1 · Cor T1**

**Yol A — Once Recover:**
```
Recover (T1 Repair Kit = Standard, kolay)
→ Financial Recovered · Encrypted T2(↑)
→ Decrypt (T2 Key = Research + Biometric, daha zor)
→ Financial Recovered · Decrypted
```

**Yol B — Once Decrypt:**
```
Decrypt (T1 Key = Research, basit)
→ Financial Decrypted · Corrupted T2(↑)
→ Recover (T2 Repair Kit = Standard + Financial, daha zor)
→ Financial Decrypted · Recovered
```

### Strateji Kararini Belirleyen Faktorler
- **Cevredeki kaynaklar:** Research kaynagi yakinsa → Decrypt once (Key kolay)
- **Standard bolluğu:** Standard her yerdeyse → Recover once (Repair Kit kolay)
- **Mevcut altyapi:** Key pipeline zaten varsa → Decrypt once
- **Harita seed'i:** Her haritada optimal yol farkli = procedural puzzle

### Kombinasyon Sayisi

| Config | Islem Sirasi Secenekleri |
|--------|------------------------|
| Tekli Encrypted | 1 yol |
| Tekli Corrupted | 1 yol |
| Enc·Cor | 2 yol (once Decrypt veya once Recover) |

Her path × 6 content tipi × tier varyasyonlari = onlarca benzersiz puzzle.

---

## 10. Yapi Detaylari

### CLASSIFIER — "Content Filter"
- **Boyut:** 2×2 | **Giris:** Sol | **Cikis:** Sag (secilen), Alt (kalan)
- Gelen veriyi CONTENT TIPINE gore filtreler (binary filtre)
- Oyuncu Tab ile hangi content'i cikartacagini secer
- Veriyi DEGISTIRMEZ — saf routing

**Ornek — 3 content'li kaynaktan ayiklama:**
```
Karisik (Fin+Bio+Blue) → Classifier "Financial" → Financial (sag)
                                                 → Kalan (sol) → Classifier "Biometric" → Biometric (sag)
                                                                                         → Blueprint (sol)
```

### SEPARATOR — "State Filter"
- **Boyut:** 2×2 | **Giris:** Sol | **Cikis:** Sag (secilen), Alt (kalan)
- Gelen veriyi STATE tipine gore filtreler (binary filtre)
- Tab ile filtre dongusu: Public → Encrypted → Corrupted → Enc·Cor
- Classifier ile ayni mantik, farkli boyut (content yerine state)

**Ornek:**
```
Financial (Public + Corrupted + Encrypted)
    → Separator "Public" → Financial Public (sag)
                         → Kalan (alt) → Separator "Corrupted" → Financial Corrupted (sag)
                                                                → Financial Encrypted (alt)
```

### DECRYPTOR — "Cipher Breaker" (CIFT GIRDI)
- **Boyut:** 2×2 | **Giris:** Sol (veri) + Ust (Key) | **Cikis:** Sag
- Encrypted/Enc·Cor veri + Key → Decrypted veri (DECRYPTED etiketi eklenir)
- Key tier'i veri tier'ina eslesmeli (T1 veri = T1 Key, T2 veri = T2 Key)
- Key yoksa bina DURUR, veri kuyrukta bekler
- Enc·Cor kabul: sifre cozer → Corrupted cikar (Corrupted tier +1)

### RECOVERER — "Data Restorer" (CIFT GIRDI)
- **Boyut:** 2×2 | **Giris:** Sol (veri) + Ust (Repair Kit) | **Cikis:** Sag
- Corrupted/Enc·Cor veri + Repair Kit → Recovered veri (RECOVERED etiketi eklenir)
- Repair Kit tier'i veri tier'ina eslesmeli (T1 veri = T1 Kit, T2 veri = T2 Kit)
- Repair Kit yoksa bina DURUR, veri kuyrukta bekler
- Enc·Cor kabul: bozukluk onarir → Encrypted cikar (Encrypted tier +1)

**Decryptor ile simetrik tasarim:**
```
Decryptor:  Encrypted veri + Key         → Decrypted (Key Forge uretir)
Recoverer:  Corrupted veri + Repair Kit  → Recovered (Repair Lab uretir)
```

### KEY FORGE — "Key Factory"
- **Boyut:** 2×2 | **Giris:** Sol | **Cikis:** Sag
- Research content tuketir → Decryption/Encryption Key uretir
- Tab ile tier secer: T1/T2/T3
- Key'ler kablo ile Decryptor/Encryptor'lara gider

| Tier | Girdi | Cikti |
|------|-------|-------|
| T1 | 5 Research | 6 Key |
| T2 | 5 Research + 2 Biometric | 6 Key |
| T3 | 5 Research + 2 Biometric + 1 Financial | 6 Key |

### REPAIR LAB — "Kit Factory"
- **Boyut:** 2×2 | **Giris:** Sol | **Cikis:** Sag
- Standard content tuketir → Repair Kit uretir
- Tab ile tier secer: T1/T2/T3
- Repair Kit'ler kablo ile Recoverer'a gider

| Tier | Girdi | Cikti |
|------|-------|-------|
| T1 | 5 Standard | 7 Repair Kit |
| T2 | 5 Standard + 1 Financial | 7 Repair Kit |
| T3 | 5 Standard + 1 Financial + 2 Blueprint | 7 Repair Kit |

### ENCRYPTOR — "Cipher Lock" (CIFT GIRDI)
- **Boyut:** 2×2 | **Giris:** Sol (veri) + Ust (Key) | **Cikis:** Sag
- Islenmis veri + Key → yeniden sifrelenmis veri (ENCRYPTED etiketi eklenir)
- Mevcut etiketler korunur: Financial Decrypted → Financial Decrypted·ENCRYPTED
- Decryptor'un tersi — ayni Key'leri tuketir

**Neden onemli:**
- Bazi gig'ler sifrelenmis (islenmis + encrypted) veri istiyor
- Key hem Decryptor'a hem Encryptor'a lazim — Key Forge hattinin onemi artiyor

### SPLITTER — "Flow Divider"
- **Boyut:** 2×2 | **Giris:** Sol | **Cikis:** Sag + Alt (esit dagitim, donusumlu)
- Paralel isleme icin kullanilir

### MERGER — "Flow Combiner"
- **Boyut:** 2×2 | **Giris:** Sol + Ust | **Cikis:** Sag (donusumlu)
- Paralel isleme ciktilarini yeniden birlestirme
- Tutorial'da erken acilir (Gig 2)

### TRASH — "Data Incinerator"
- **Boyut:** 1×1 | **Giris:** Sol | **Cikis:** Yok
- Tum veri tiplerini kabul eder, aninda imha eder
- Gig'ler zorlastikca oyuncu cope daha az atar — her veri lazim olur

### CONTRACT TERMINAL — "Mission Hub"
- **Boyut:** 3×3 | **Giris:** 8 port (her kenarda 2) | **Cikis:** Yok
- Harita merkezinde SABIT (oyuncu yerlestirmez)
- Mevcut gig'leri (sozlesmeleri) gosterir
- Islenmis veriyi teslim alir → gig ilerlemesi sayar
- Gig tamamlaninca yeni bina acilir
- Oyunun kalbi — tum pipeline'lar buraya akar
- Exclusion zone: yakinina bina yerlestirilemez

#### Port Purity Kurali
Contract Terminal **sadece saf (pure) veri akisi kabul eder.** Her input port'un kablosu kumulatif tip kaydı tutar:

- **Kablo baglandiginda:** Kaynak cikislari icin tum olasi veri tipleri aninda kaydedilir
- **Push aninda:** Diger binalardan gelen veri tipleri kabloya kaydedilir ve aninda degerlendirilir
- Port'taki **tum** kayitli tipler aktif bir gig requirement'a eslesiyorsa → **kabul**, veri akar
- Port'ta **tek bir non-matching tip** bile kaydedildiyse → **port kalici olarak bloklanir**
- **Kablo cikarildiginda:** Port kaydi sifirlanir, blok kalkar
- **Gig degistiginde:** Tum portlar yeniden degerlendirilir

**Neden:** Bu kural oyunun puzzle cekirdegini korur. Oyuncu kaynaktan gelen karisik veriyi filtrelemeden CT'ye teslim edemez. Classifier + Separator ZORUNLU hale gelir.

---

## 11. Harita ve Kaynaklar

### Harita Yapisi
- Sonsuz grid, prosedürel uretim (seed-based, her oyunda farkli)
- Sis perdesi (fog of war): kesfedilmemis alanlar gizli
- Yakin bina yerlestirme ile kesif
- Kaynaklar tukenmez (chill otomasyon, stres yok)
- Contract Terminal harita merkezinde sabit
- Zorluk mesafeyle artar (kolay → orta → zor → endgame)

### Tasarim Felsefesi: Factorio/Satisfactory Modeli
Kaynaklar haritaya **rastgele sacilmis.** Zorluk konumdan degil, kaynağin TIPINDEN gelir.

**Neden ring sistemi degil:**
- **Merak:** Yanindaki Askeri Ag'i goruyorsun ama isleyemiyorsun
- **Oyuncu secimi:** Hangi yone gidecegini SEN seciyorsun
- **Replayability:** Her seed genuinely farkli strateji gerektirir
- **Benzersiz fabrikalar:** Herkesin kablo agi farkli gorunur

### Kaynak Tipleri ve Zorluklari

**Kolay Kaynaklar (1-2 content, basit state'ler):**

| Kaynak | Content | State'ler |
|--------|---------|-----------|
| **Otomat** | Standard | %100 Public |
| **ATM** | Financial | %70 Public, %30 Corrupted T1 |
| **Akilli Kilit** | Biometric | %80 Public, %20 Corrupted T1 |
| **Trafik Kamerasi** | Standard + Biometric | Cogu Public |
| **Data Kiosk** | Standard + Financial | %100 Public |

**Orta Kaynaklar (2-3 content, karisik state'ler):**

| Kaynak | Content | State'ler |
|--------|---------|-----------|
| **Hastane Terminali** | Biometric + Research | Public + Encrypted T1 |
| **Bank Terminal** | Financial + Biometric | %70 Public + %30 Corrupted |
| **Halk Kutuphanesi** | Standard + Research | Public + Corrupted T1 |
| **Magaza Sunucusu** | Standard + Financial + Biometric | Public + Corrupted T1-T2 |
| **Biyotek Labi** | Bio + Research + Blueprint + Standard | Corrupted T1-T2 + Encrypted T1 |

**Zor Kaynaklar (3-4 content, agir state'ler, yuksek tier):**

| Kaynak | Content | State'ler |
|--------|---------|-----------|
| **Corporate Server** | Financial + Blueprint + Standard | Encrypted T2 + Corrupted T2 + Enc·Cor |
| **Devlet Arsivi** | Research + Classified + Blueprint + diger | Encrypted T3 + Corrupted T2 + Enc·Cor |

**Endgame Kaynaklar (karmasik content, Malware — full release):**

| Kaynak | Content | State'ler |
|--------|---------|-----------|
| **Askeri Ag** | Classified + Blueprint + Research | Encrypted T3 + Malware |
| **Dark Web Node** | Tum tipler | Tum state'ler, T4 |

### Demo Kaynak Ayarlari
- ~12-18 kaynak/harita (easy 5-8, medium 3-5, hard 2-3, endgame 1-2)
- 5 scripted tutorial spawn (ISP, ATM, Data Kiosk, Bank Terminal, Hospital)
- Sektor garanti: Biyotek Labi
- Zor kaynaklar Enc·Cor bilesik state icerir (demo mekaniği)

### "Gorebilirsin Ama Isleyemezsin" Mekanigi
```
Oyuncu spawn'da basliyor...
  → Yaninda bir Otomat (kolay, Standard Public) — basla
  → 10 kare otede bir Corporate Server! — Blueprint, Encrypted T2
  → "Vay, orada ne var... ama Decryptor'um bile yok..."
  → 3 saat sonra: "SONUNDA o Server'i islemeye hazirim!"
  → Bu his = oyunun bagimlilık dongusu
```

---

## 12. Gig Sistemi

### Genel Bakis
Gig sistemi oyunun KALBI. Opsiyonel degil, ana ilerleme mekanigi. Contract Terminal'den sozlesmeler alir, pipeline kurarsun, teslim edersin. Her gig yeni mekanik ogretiyor ve yeni bina aciyor.

### Nasil Calisir
1. Contract Terminal'de mevcut gig'ler goruntulenir
2. Gig: "X miktar Y veri isle ve teslim et"
3. Oyuncu pipeline kurar: kaynak → islem → Contract Terminal
4. Veri akar → **CT port purity kontrolu** → eslesiyorsa gig ilerleme sayaci artar
5. Gig tamam → yeni bina acilir + yeni gig'ler belirir
6. Veri teslimde TUKETILIR (Shapez modeli — Hub'a giren veri gider)

### Tutorial Gig'ler (6 Gig — Sirali)

| # | Gig Adi | Gereksinim | Acilan Binalar |
|---|---------|-----------|----------------|
| 1 | **First Extraction** | 20× Standard Public | Separator, Classifier |
| 2 | **Clean Data Only** | 10× Financial Public | Merger |
| 3 | **Full Filter Chain** | 8× Financial Public + 8× Biometric Public | Key Forge, Decryptor |
| 4 | **Combined Flow** | 15× Standard Public + 10× Financial Public | Repair Lab, Recoverer |
| 5 | **Data Recovery** | 10× Financial Recovered | Encryptor |
| 6 | **Blueprint Run** | 15× Blueprint Public | — |

Her gig bir veya iki mekanik ogretiyor. Tutorial bittiginde tum binalar acilmis, oyuncu her araci biliyor.

### Procedural Gig Generator (Tutorial Sonrasi)

Tutorial bitince procedural gig generator devreye girer. Her zaman **3 aktif procedural gig** bulunur. Biri tamamlaninca yenisi uretilir.

**Zorluk Skalasi:**

| Ilerleme | Gereken Tag | Bulmaca |
|----------|------------|---------|
| Erken | Public (tag yok) | Sadece ayikla ve teslim et |
| Orta-erken | Decrypted (tag 1) | Key Forge + Decryptor gerekli |
| Orta | Recovered (tag 2) | Repair Lab + Recoverer gerekli |
| Orta-gec | Decrypted·Encrypted (tag 5) | Decrypt + Encrypt zinciri |
| Gec | Recovered·Decrypted (tag 3) | Recover + Decrypt zinciri |

**Content Havuzu:**
- Erken: Standard, Financial, Biometric (kolay kaynaklar)
- Gec: Blueprint, Research (zor kaynaklar — artan olasilikla)

**Miktar:** 8 + (zorluk × 2) MB, ilerlemeyle artar

---

## 13. Uc Faz Yapisi

### Faz 1: One-Shot Delivery (Tutorial)
- **Amac:** Oyuncuya tum araclari ogretmek
- **Gig tipi:** "X MB Y veri teslim et" (tek seferlik)
- **Sonuc:** Tum binalar acilmis, oyuncu her araci biliyor
- **Gig'ler:** 6 hand-crafted tutorial gig, her oyunda ayni sira

### Faz 2: Procedural Gig'ler
- **Amac:** Derin pipeline bulmacalari
- **Gig tipi:** Procedural — tag karmasikligi ve miktar ilerlemeyle artar
- **Ozellik:** 3 simultane aktif gig, biri bitince yenisi uretilir
- **Oyuncu ogreniyor:** Karmasik tag kombinasyonlari, coklu kaynak yonetimi

### Faz 3: Persistent Network (Teaser)
- **Amac:** Haritadaki sunuculari baglayip surekli akisi surdurmek
- **Kritik fark:** Gig tamamlaninca pipeline KALIR ve calismaya devam eder. Ag sadece buyur.
- **Progress:** "NETWORK: X/Y (Z%)" gostergesi — bagli kaynak / toplam kaynak orani
- **Endgame:** Tum veriler ayni anda akiyor, devasa cyber web

### Faz Gecisleri
- Faz 1 → 2: Tum tutorial gig'ler tamamlandiginda
- Faz 2 → 3: Procedural gig'ler ilerlediginde, ag buyumeye baslar
- Faz 3 acik uclu — oyuncu haritayi kaplayana kadar devam eder

---

## 14. Ilerleme Sistemi

### Bina Acilma Siralamasi

Binalar gig tamamlayarak acilir. Bina maliyeti YOK — bulmaca zorlugu yeter.

| Asama | Acilan Binalar | Tetikleyici |
|-------|---------------|-------------|
| **Oyun Basi** | Trash, Splitter | — |
| **Gig 1** | Separator, Classifier | First Extraction |
| **Gig 2** | Merger | Clean Data Only |
| **Gig 3** | Key Forge, Decryptor | Full Filter Chain |
| **Gig 4** | Repair Lab, Recoverer | Combined Flow |
| **Gig 5** | Encryptor | Data Recovery |

### Ilerleme Asamalari

| Asama | Oyuncu Deneyimi | His |
|-------|----------------|-----|
| **Copcu** | Tek kaynak, tek hat, Public veri | "Anladim, basit" |
| **Ayirici** | Classifier + Separator, coklu cikis | "Farkli veriler farkli yonlere!" |
| **Muhendis** | Decryptor + Key Forge, Key zinciri | "Bu gercek bir fabrika" |
| **Tamirci** | Recoverer + Repair Lab, simetrik sistem | "Her sey birbirine bagli" |
| **Mimar** | Coklu kaynak, procedural gig, tam ag | "Devre kartima bak!" |

---

## 15. Save Sistemi

### Coklu Save Dosyasi Destegi
- 5 save slot: slot_1.json — slot_5.json
- Her slot ayrica otomatik kayit: slot_N_auto.json
- "New Game" otomatik bos slot secer
- "Load Game" slot listesi gosterir (tarih + silme butonu)
- Kaydedilen state: binalar, kablolar, gig ilerlemesi, procedural state, kaynak kesfedilmisligi, fog durumu

### Autosave
- 5 dakikada bir otomatik kayit
- Gig tamamlandiginda otomatik kayit
- Autosave rotation: mevcut + yedek

---

## 16. Kisit ve Zorluk

### Felsefe: Shapez Modeli — Saf Otomasyon Bulmacasi
Power, heat, combat, para birimi YOK. Challenge tamamen pipeline tasarimindan gelir.

| Kisit | Nasil Calisir | Oyuncu Karari |
|-------|--------------|---------------|
| **Kablo routing** | Kablolar grid'de yer kaplar | "Bu hatti nereye cekeyim?" |
| **Content cesitliligi** | Zor kaynaklar 3-4+ content | "Kac Classifier zincirlersem?" |
| **State karisikligi** | Kaynaklar karisik state | "Her state icin ayri hat lazim" |
| **Key tedarigi** | Tier arttikca Key Forge tarifi zorlasir | "Key Forge hattim yeterli mi?" |
| **Repair Kit tedarigi** | Tier arttikca Repair Lab tarifi zorlasir | "Repair Lab hattim yeterli mi?" |
| **Bilesik state** | Enc·Cor icin islem sirasi karari | "Once Decrypt mi Recover mi?" |
| **Tier escalation** | Bilesik state'de bir taraf cozulunce diger +1 | "Hangi yol daha ucuz?" |
| **Layout planlamasi** | Yeni kaynak = mevcut fabrikadan hat cekme | "Mevcut kablolarin arasinda yer var mi?" |

### Zorluk Kaynaklari (Uc Eksen)

```
EKSEN 1: GIG KARMASIKLIGI
  Erken: "Public veri teslim et"
  Gec:   "Decrypted·Encrypted veri teslim et" (cok adimli islem)

EKSEN 2: KAYNAK KARMASIKLIGI
  Kolay: 1 content, Public
  Zor:   4 content, T2 Encrypted + T2 Corrupted + Enc·Cor

EKSEN 3: LAYOUT KARMASIKLIGI
  Erken: Tek kaynak, kisa hat
  Gec:   10+ kaynak, yuzlerce kablo, routing bulmacasi
```

---

## 17. Gorsel Tasarim Detaylari

### Sanat Stili: Prosedürel + Shader
Her sey kodla cizilir + shader efektleri. Procedural-first sanat yonu.

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
  Enc·Cor:     Yari mavi, yari sari (bolunmus)
  Malware:     #ff1133 (neon kirmizi) — release

Content Renkleri:
  Standard:    #7788aa
  Financial:   #ffcc00
  Biometric:   #ff33aa
  Blueprint:   #00ffcc
  Research:    #9955ff
  Classified:  #ff3388
  Key:         #ffaa00
  Repair Kit:  #ff7744

Bina Accent Renkleri (12):
  Contract Terminal: Gold (1.0, 0.75, 0.0)
  Classifier:        Teal (0.15, 0.85, 0.63)
  Separator:         Sky Blue (0.33, 0.55, 0.9)
  Decryptor:         Orange (0.95, 0.55, 0.15)
  Encryptor:         Deep Blue (0.2, 0.33, 0.95)
  Recoverer:         Lime (0.67, 0.87, 0.13)
  Key Forge:         Emerald (0.18, 0.83, 0.35)
  Repair Lab:        Orange (0.85, 0.55, 0.25)
  Splitter:          Slate Blue (0.47, 0.6, 0.8)
  Merger:            Sage (0.6, 0.67, 0.47)
  Trash:             Red (0.87, 0.27, 0.2)
```

### Active/Idle Kontrast
- **Idle:** accent.lerp(gray, 0.3), pulse ×0.5 — sonuk, hareketsiz
- **Active:** Tam accent rengi, pulse ×4.0 — parlak, canli

### Shader Efektleri
- **Bloom:** Kablo ve binalarda neon parlama
- **CRT:** Hafif tarama cizgileri + kromatik sapma
- **Vignette:** Ekran kenarlarinda kararma
- **Glow outline:** Bina kenarlarinda renk kodlu titresim

### Ses Tasarimi

**Ambient Katmani:** Dusuk frekanslı dijital hum, aktif kablo sayisina gore yogunluk artar.

**Bina Sesleri (her bina benzersiz):**
- Classifier/Separator: routing "tik-tak"
- Decryptor: dijital "crack" efekti
- Recoverer: tarama/onarma sesi
- Encryptor: sifreleme sesi
- Key Forge: arastirma hum'i
- Repair Lab: uretim sesi
- Trash: imha sesi

**UI Sesleri:**
- Kablo doseme: tatmin edici "snap"
- Bina yerlestirme: sagdam "placement"
- Gig tamamlama: 5-nota basari arpejio
- Yeni bina acilma: kilit acma sesi + shake

---

## 18. Referans Oyunlar

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
- **Satisfactory'den:** Coklu girdili tarifler en iyi lojistik bulmacalari yaratir.

---

## 19. Pazar Stratejisi

### Hedef
- **Fiyat:** $9.99
- **Satis hedefi:** 100K+
- **Platform:** Steam
- **Cikis:** Steam Next Fest demo sonrasi

### Hook + Anchor
- **Hook:** "Siberuzayda parlayan devre kartlari tasarla — veri aritma otomasyon bulmacasi"
- **Anchor:** "Shapez'in kademeli bulmacalari + Factorio'nun grid routing'i"

### Steam Next Fest Stratejisi (Haziran 2026)
- Demo: 6 tutorial gig + procedural gig generator
- ~12-18 kaynak (kolay + orta + zor teaser)
- 4-6 saatlik demo deneyimi
- Screenshot'lar etkileyici olmali (devre karti estetigi = satis noktasi)
- Persistent network teaser (bagli kaynak gostergesi)

---

## 20. Kapsam ve Yol Haritasi

### Demo Kapsami (Next Fest) — 4-6 saat
- Grid kablo routing (dik kesisim serbest)
- 11 bina: Classifier, Separator, Recoverer, Decryptor, Encryptor, Key Forge, Repair Lab, Splitter, Merger, Trash + Contract Terminal
- ~12-18 kaynak (kolay + orta + birkac zor)
- 8 content: Standard, Financial, Biometric, Blueprint, Research, Classified + Key, Repair Kit
- 3+1 state: Public, Corrupted (T1-T2), Encrypted (T1-T2), Enc·Cor
- 6 tutorial gig + procedural gig generator
- Persistent network gostergesi
- Coklu save (5 slot)
- Tam gorsel islem (devre karti estetigi)
- Malware YOK (tam oyuna sakla)

### Tam Oyun Kapsami
- 12 bina (+ Malware Cleaner)
- ~25-35 kaynak/harita
- 4+1 state: + Malware + Enc·Mal, Cor·Mal, Enc·Cor·Mal
- Tam tier sistemi (T1-T4)
- Procedural gig sistemi sinursiz
- Endgame: Malware pipeline bulmacalari

### Lansman Sonrasi Potansiyel
- Yeni content tipleri
- Yeni bina tipleri
- Topluluk challenge'lari
- Trace/hostile AI katmani

---

## 21. Kesinlesmis Kararlar

| Karar | Durum |
|-------|-------|
| "Ters Shapez" oyun kimligi | **Kesin** |
| Compiler kaldirildi | **Kesin** |
| Uplink kaldirildi (kaynaklar direkt output) | **Kesin** |
| Bridge kaldirildi (dik kesisim serbest) | **Kesin** |
| Research Lab → Key Forge yeniden adlandirildi | **Kesin** |
| Repair Lab yeni bina (Repair Kit uretir) | **Kesin** |
| Recoverer: fuel → key mode (Repair Kit) | **Kesin** |
| Decryptor-Recoverer simetrik tasarim | **Kesin** |
| Merger erken acilir (Gig 2) | **Kesin** |
| Bilesik state (Enc·Cor) demo'da var | **Kesin** |
| Tier escalation (cozunce +1) | **Kesin** |
| 3 faz yapisi (Tutorial → Procedural → Network) | **Kesin** |
| Persistent network (pipeline kalir) | **Kesin** |
| Procedural gig generator (tutorial sonrasi) | **Kesin** |
| Malware → sadece full release | **Kesin** |
| Bandwidth mevcut sistem (sinirli) | **Kesin** |
| Coklu save dosyasi (5 slot) | **Kesin** |
| Bina maliyeti YOK | **Kesin** |
| Bina rotasyonu (R tusu, 4 yon) | **Kesin** |
| CT 3×3, 8 port, exclusion zone | **Kesin** |

### Reddedilen Fikirler
- ~~Compiler binasi~~ → Ters Shapez felsefesi, aritiyoruz
- ~~Packet sistemi~~ → Birlestirme modeline uymuyor
- ~~Uplink binasi~~ → Kaynaklar direkt output portlu
- ~~Bridge binasi~~ → Dik kesisim serbest
- ~~Yakit-eslesme Recoverer~~ → Repair Kit simetrik tasarim
- ~~Credits/para birimi~~ → Bina maliyeti yok
- ~~Storage binasi~~ → Veri surekli akar
- ~~Olasiliksal Recoverer~~ → Deterministik
- ~~Quarantine~~ → Trash (basit cop)
- ~~Residue (yan urun)~~ → Yan urun yok
- ~~Tech Tree~~ → Gig ile bina acma
- ~~Power/Heat sistemi~~ → Saf otomasyon
- ~~Ring/halka harita~~ → Rastgele dagitim
- ~~Karisim tipleri (Bond/Fused)~~ → Basit Classifier yeter
- ~~Stabilizer~~ → Gereksiz
- ~~Depolama maliyeti~~ → Tum veriler esit 1x

---

## 22. Acik Sorular

### Tasarlanacak
- [ ] Malware Cleaner bina detaylari (full release)
- [ ] T3-T4 tier tarifleri (endgame)
- [ ] Throughput/sustain gig mekanigi detaylari (Faz 2)
- [ ] Demo denge ince ayari (playtest ile dogrulanacak)
- [ ] Faz gecis tetikleyicileri (tam kriterler)

### Dogrulanmis (Kodda Implement Edilmis)
- [x] Grid kablo routing + dik kesisim serbest
- [x] Gig sistemi = core loop
- [x] Contract Terminal 3×3, 8 port, merkezde sabit
- [x] Bina maliyeti YOK, gig ile acilir
- [x] Key Forge (eski Research Lab) + tier tarifleri
- [x] Repair Lab + tier tarifleri
- [x] Recoverer simetrik key mode (Repair Kit)
- [x] Bilesik state (Enc·Cor) + bolunmus renk gorseli
- [x] Tier escalation (+1 kalan state)
- [x] Procedural gig generator (3 simultane)
- [x] Persistent network gostergesi
- [x] Coklu save (5 slot)
- [x] Bina rotasyonu (R tusu, 4 yon)
- [x] 6 tutorial gig + procedural gecis

---

*Bu dokuman canlidir ve her tasarim oturumunda guncellenecektir.*
*Versiyon 4.0 — v3.0 + v4 tasarim dokumani birlestirmesi. Compiler/Uplink/Bridge kaldirildi, Key Forge + Repair Lab eklendi, simetrik tasarim, bilesik state, procedural gig generator, 3 faz yapisi.*
