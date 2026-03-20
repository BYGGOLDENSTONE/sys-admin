# NetFactory // BREACH — Game Design Document

**Versiyon:** 5.1
**Son Guncelleme:** 2026-03-19
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
8. [Sifreleme ve Glitch Sistemleri](#8-sifreleme-ve-glitch-sistemleri)
9. [Bilesik State Sistemi](#9-bilesik-state-sistemi)
10. [Yapi Detaylari](#10-yapi-detaylari)
11. [FIRE Sistemi](#11-fire-sistemi)
12. [Throughput Sistemi](#12-throughput-sistemi)
13. [Upgrade Sistemi](#13-upgrade-sistemi)
14. [Harita ve Kaynaklar](#14-harita-ve-kaynaklar)
15. [Gig Sistemi](#15-gig-sistemi)
16. [Uc Faz Yapisi](#16-uc-faz-yapisi)
17. [Ilerleme Sistemi](#17-ilerleme-sistemi)
18. [Save Sistemi](#18-save-sistemi)
19. [Kisit ve Zorluk](#19-kisit-ve-zorluk)
20. [Gorsel Tasarim Detaylari](#20-gorsel-tasarim-detaylari)
21. [Referans Oyunlar](#21-referans-oyunlar)
22. [Pazar Stratejisi](#22-pazar-stratejisi)
23. [Kapsam ve Yol Haritasi](#23-kapsam-ve-yol-haritasi)
24. [Kesinlesmis Kararlar](#24-kesinlesmis-kararlar)
25. [Acik Sorular](#25-acik-sorular)

---

## 1. Oyun Ozeti

**NetFactory // BREACH**, oyuncunun siberuzayda veri kaynaklarini kesfedip, guvenlik duvarlarini asip, grid tabanli kablo routing ile parlayan veri pipeline'lari kurdugu 2D top-down chill otomasyon oyunudur. Oyuncunun fabrikasi yukaridan bakildiginda canli bir devre kartina benzer.

### Ters Shapez Modeli

```
Shapez:      Basit parcalar → isle → karmasik urun → teslim
BREACH:   Karmasik kaynak → guvenlik as → ayikla/coz/onar → saf veri → teslim
```

Oyuncu insa etmiyor, **aritiyor.** Content = sekil, State = renk. Hacker fantezisi — sifreli, bozuk, korunmali veriyi temizleyip merkeze teslim et.

**Tek Cumle:** "Siberuzayda devre karti gibi veri fabrikalari tasarla — her kaynak yeni bir hack bulmacasi."

**Temel Fantezi:** Haritada bir Hospital Archive goruyorsun ama FIRE korumasinda. Onun Retina Scan verisine erismek icin yakinlardaki Medical Clinic'i hackleyip Retina Scan verisini Hospital'a beslemelisin. FIRE kalkinca sifreli Biometric veri akiyor — ama 16-bit sifreleme! Key Forge'a Lab Reports + Fingerprint besleyip Key uretmelisin, ustelik 16-bit Key yavaş uretiyor, paralel Key Forge hatlari lazim. Zoom out yaptiginda her kaynak baska bir kaynagi besleyen devasa bir cyber web goruyorsun — ve onu sen tasarladin.

**Tur:** Chill Otomasyon
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner / Siberuzay
**Hedef:** Sandbox Hacking — kaynaklar yon verir, oyuncu fabrikalasir

### North Star

Oyuncunun amaci haritadaki sunuculari birbirine baglayip Contract Terminal'e surekli veri akisi saglayan devasa bir cyber web olusturmak. Her kaynak hem kendi verisini uretir hem baska kaynaklarin FIRE duvarlarini kirmak icin kullanilir. Zoom out yapildiginda harita parlayan kablolarla kapli — "devre karti sehir."

### Ana Referanslar
- **Shapez:** Kademeli bulmaca karmasikligi, chill otomasyon, merkez hub teslimat, bina maliyeti yok, throughput challenge
- **Factorio:** Grid routing, mekansal bulmacalar, paralel uretim hatlari
- **Satisfactory:** Kaynak → isleme → uretim dongusu, coklu girdili binalar

---

## 2. Tasarim Sutunlari

### Sutun 1: Fabrikan Bir Devre Karti
Oyuncunun yaratimi yukaridan bakildiginda guzel, canli bir devre karti gibi gorunmeli. Parlayan kanallar, titreyen binalar, akan veri nehirleri. Screenshot'lar "bu ne guzel sey?" dedirtmeli.

### Sutun 2: Basit Ogren, Derin Ustalan
Her mekanik sezgisel ("sifreli dosya icin anahtar lazim" — herkes anlar). Karmasiklik bireysel mekanikten degil, KOMBINASYONDAN gelir. Shapez modeli: islemlerin kendisi basit, birlesimleri zor.

### Sutun 3: Her Kaynak Yeni Bir Bulmaca
Her kaynak farkli FIRE gereksinimleri, farkli sub-type'lar, farkli state'ler tasiyor. Her yeni kaynak genuinely farkli pipeline tasarimi gerektirir. Yakinlardaki kolay kaynaklarin verisini kullanarak zor kaynaklarin guvenligini asarsin.

### Sutun 4: Layout = Oyun
Kablolar grid uzerinde fiziksel yer kaplar, serbestce kesilemez. Yerlesim planlamak hangi binayi kullanacagin kadar onemli. Paralel hatlar, feedback loop'lar, FIRE besleme kablolari — hepsi alan tuketir.

---

## 3. Cekirdek Dongu

### Ana Akis: Source Hacking Pipeline

```
[KESFET]             — Haritada yeni kaynak bul
        |
[FIRE AS]            — Kaynağın FIRE duvarını kır:
        |                Yakın kaynaklardan doğru sub-type'ı besle
        |                Medium: sabit eşik (50 MB) → FIRE kalkar
        |                Hard: regenerating → sürekli throughput koru
        |
[CEK]                — Kaynak açıldı! Kablo çek, veri çekmeye başla
        |
[AYIKLA]             — Classifier ile content ayır, Scanner ile sub-type ayır
        |
[AYIR]               — Separator ile state ayır (Public / Encrypted / Glitched)
        |
[ISLE]               — Duruma göre işle:
        |                Encrypted → Decryptor + Key (paralel Key Forge)
        |                Glitched → Recoverer feedback loop (Separator ile döngü)
        |
[SIFRELE]            — Encryptor ile yeniden şifrele (Key gerekli!)
        |
[TESLIM]             — Contract Terminal'e gönder → ilerleme!
        |
[GENISLE]            — Yeni kaynak aç → FIRE kır → daha karmaşık pipeline → tekrarla
```

### Shapez Paraleli

```
Shapez:                          BREACH:
Hub'dan seviye gelir             Haritadaki kaynaklar yönlendirir
Şekil kes/boya/birleştir         Veri ayır/işle/şifrele
Conveyor belt ile Hub'a teslim   Kablo ile Terminal'e teslim
Throughput challenge (geç oyun)  FIRE regen throughput (geç oyun)
Binalar bedava                   Binalar bedava
```

### Temel Gerilim
**"Hospital Archive'dan Decrypted Biometric lazım. Ama FIRE korumasında — Retina Scan beslemem gerek. Retina Scan Medical Clinic'ten geliyor ama o da FIRE'lı — önce Fingerprint beslemeliyim. Fingerprint Smart Lock'tan. Ve şifre 16-bit — paralel Key Forge lazım, Lab Reports + Fingerprint tarifi. Tek kaynaktan beş paralel hat!"**

### Pozitif Geri Besleme Dongusu (Core Mechanic)
Oyunun kalbindeki mekanik: **kaynaklar birbirini besler.**

```
Smart Lock (Fingerprint Public)
   └── Fingerprint → Medical Clinic'in FIRE'ını kır
                        └── Retina Scan → Hospital Archive'ın FIRE'ını kır
                                            └── Biometric Encrypted → işle → teslim
ATM (Transaction Records + Fingerprint)
   └── Transaction Records → Bank Terminal'in FIRE'ını kır
   └── Fingerprint → Key Forge'a (16-bit Key tarifi)
```

Her kaynak hem kendi verisini üretir hem başka kaynakların kilidini açar. Bu bir fabrika değil, birbirine bağlı bir **hack ağı.**

---

## 4. Sutun 1: Grid Kablo Routing

### Problem
Kablolar noktadan noktaya çizgi olursa, yerleşim önemsizleşir. Oyun "akış şeması çizimine" döner.

### Cozum: Kablolar Grid Uzerinde Fiziksel Yer Kaplar

**Kurallar:**
- Kablolar kare kare dösenilir (Factorio bantları gibi)
- Her kablo segmenti bir grid hücresi kaplar
- 4 yön: yukarı, aşağı, sol, sağ + köşeler
- **İKİ KABLO AYNI HÜCREYİ PAYLAŞAMAZ**
- **Dik açılı kablolar serbestçe kesişebilir** (Bridge gerekmez)
- Binaların port pozisyonları sabit (giriş sol, çıkış sağ vb.)
- Veri kablo boyunca akar (anında değil, görülebilir şekilde)
- Veri sürekli akar, depolanmaz (Shapez conveyor modeli)

### Kablo Yerlestirme UX

Kablo döşemek oyunun en sık yapılan eylemi. Akıcı ve tatmin edici olmalı.

**Temel İnteraksiyon:**
- Tıkla-sürükle ile kablo döser (Factorio belt modeli)
- Sürükleme yönü otomatik yön belirler
- Köşeler otomatik oluşur (L-şeklinde sürükle = otomatik köşe)
- Başlangıç/bitiş noktası bina portlarına snap'lenir
- Ghost önizleme: döşenmeden önce rota yeşil/kırmızı gösterilir (geçerli/geçersiz)

**Hızlı Düzenleme:**
- Sağ tıkla kablo segmentini siler
- Ctrl+Z undo desteği

### Neden Bu Her Seyi Degistirir
- Yerleşim planlaması = ana bulmaca
- Alan = kaynak — kompakt tasarımlar verimli ama routing zor
- Paralel hatlar + feedback loop'lar = devasa alan tüketimi
- FIRE besleme kabloları = ek routing karmaşıklığı
- Zoom-out görünümü = parlayan devre kartı = "factory porn"

---

## 5. Sutun 2: Mekanik Seti

### Felsefe: Basit Islemler, Derin Kombinasyonlar

Her bina tek bir basit iş yapar. Zorluk bireysel binalardan değil, birleşimlerin yarattığı pipeline bulmacalarından gelir. Shapez'deki kes/boya/birleştir gibi — tek başına basit, birlikte derin.

### Asimetrik Tasarim: Encrypted vs Glitched

v5'in en önemli tasarım kararı: **Encrypted ve Glitched FARKLI bulmaca tipleri yaratır.**

```
ENCRYPTED = GENİŞLİK BULMACASI (paralel hatlar)
  Encrypted veri → Decryptor + Key → Decrypted veri
                                ↑
                     Key Forge (bit-depth'e göre tarif)

  4-bit:  1 Key Forge, hızlı → basit
  16-bit: 2+ paralel Key Forge, yavaş → geniş fabrika
  32-bit: 3+ paralel Key Forge → devasa yayılma

GLITCHED = DERİNLİK BULMACASI (feedback loop)
  Glitched veri → Recoverer + Repair Kit → Separator
                                              ↓         ↓
                                        Recovered    hâlâ Glitched
                                          (çıkış)      (loop başına döner)

  Minor:    %70-80 recovery oranı → küçük loop
  Major:    %40-50 recovery oranı → çok döngü
  Critical: %20-30 recovery oranı → paralel loop'lar gerekli
```

**Neden asimetrik:**
- Encrypted fabrikalar YAN YANA büyür (paralel Key Forge hatları)
- Glitch fabrikalar DÖNGÜSEL büyür (feedback loop'lar)
- Zoom-out'da tamamen farklı görsel doku yaratırlar
- Enc·Glitch bileşik state'te ikisi birleşir → en karmaşık fabrika

### Bina Listesi (12 Bina)

| Bina | Fiil | Kategori | Benzersiz Mekanik |
|------|------|----------|-------------------|
| **Classifier** | Ayıkla | Routing | Binary filtre: seçilen content sağ, kalan alt |
| **Separator** | Ayır | Routing | Binary filtre: seçilen state sağ, kalan alt |
| **Scanner** | Tara | Routing | Binary filtre: seçilen sub-type sağ, kalan alt (YENİ) |
| **Splitter** | Böl | Routing | 1 akış → 2 akış (eşit dağıtım) |
| **Merger** | Birleştir | Routing | 2 akış → 1 akış |
| **Decryptor** | Çöz | İşleme | Çift girdi: veri + Key → Decrypted |
| **Recoverer** | Onar | İşleme | Çift girdi: veri + Repair Kit → kısmi recovery (feedback loop) |
| **Encryptor** | Şifrele | Dönüşüm | Çift girdi: işlenmiş veri + Key → Encrypted |
| **Key Forge** | Key üret | Üretim | Content tüketir → Key üretir (bit-depth tarifli, yüksek bit = yavaş) |
| **Repair Lab** | Kit üret | Üretim | Content tüketir → Repair Kit üretir (tier tarifli) |
| **Trash** | Yok et | Altyapı | İstenmeyen veriyi imha eder |
| **Contract Terminal** | Teslim al | Merkez | Gig'leri gösterir + veri teslim noktası |

**Bina maliyeti YOK — bulmaca zorluğu yeter. Binalar ilerleyerek açılır. Kaynaklar doğrudan output portlarına sahip ama FIRE koruması olabilir.**

### Üç Katmanlı Filtre Sistemi

```
Separator  → STATE filtresi    (Public / Encrypted / Glitched / Enc·Glitch)
Classifier → CONTENT filtresi  (Financial / Biometric / Standard / ...)
Scanner    → SUB-TYPE filtresi (Account Data / Credit History / ...)
```

Üç bina, üç seviye, her biri binary filtre (seçilen → sağ, kalan → alt). Aynı tasarım dili, artan detay seviyesi.

---

## 6. Sutun 3: Gorsel Kimlik

### Problem
Dikdörtgenler + ince çizgiler + küçük noktalar $9.99 için yeterince çekici değil.

### Cozum: Canli Devre Karti Estetigi

**Kablolar → Veri Otoyolları:**
- Grid hücresi boyutunda parlayan kanallar (ince çizgi değil!)
- Sabit nötral gümüş-beyaz renk — tüm kablolar aynı ton, veriler kendi rengini taşıyor
- İçinden semboller akar: $ @ # ? ! 1 K R
- Köşeler ve kavşaklar yumuşak geçişli

**Binalar → Canlı Makineler:**
- Çalışırken animasyonlu (dönen elementler, yanıp sönen ekranlar, port flash'ları)
- Boştayken sonuk ve hareketsiz (kontrast = anlam)
- Her binanın benzersiz silueti (zoom-out'da bile tanınabilir)

**Zoom Seviyeleri:**
- **Uzak:** Parlayan devre kartı manzarası — STEAM SCREENSHOT SEVİYESİ
- **Orta:** Binalar, kanallar, veri akışı görünür
- **Yakın:** Bireysel paketler, bina detayları, port aktivitesi

**Hedef:** Oyuncunun fabrikası ekran görüntüsü olarak Reddit'e atıldığında "bu ne güzel şey, ne oyunu bu?" dedirtmeli.

---

## 7. Veri Modeli

### Temel Prensip
Her veri paketi üç boyuta sahip:
- **Content (İçerik):** Verinin NE olduğu → ana veri tipi
- **Sub-Type (Alt Tip):** Content'in SPESİFİK türü → FIRE gereksinimleri ve kaynak kimliği
- **State (Durum):** Verinin NE HALDE olduğu → işleme yolunu belirler

Ek olarak, işlem etiketleri birikir ve verinin geçmişini korur.

### Content Tipleri (8) ve Sub-Type'lar

Her content tipi 4 sub-type'a sahiptir. Sub-type'lar kaynağa bağlıdır — her kaynak spesifik sub-type'lar üretir.

#### Standard (Her yerde, temel altyapı verisi) — Sembol: 1 — Renk: #7788aa

| Sub-Type | Bulunduğu Kaynaklar |
|----------|-------------------|
| Log Files | ISP Backbone, Traffic Camera |
| Config Data | Smart Lock, Shop Server |
| Cache Data | ATM, Public Library |
| Metadata | Data Kiosk, Hospital |

#### Financial (Para ve işlem verisi) — Sembol: $ — Renk: #ffcc00

| Sub-Type | Bulunduğu Kaynaklar |
|----------|-------------------|
| Transaction Records | ATM, Shop Server |
| Account Data | Bank Terminal, Corporate |
| Credit History | Bank Terminal, Data Kiosk |
| Tax Records | Government Archive, Corporate |

#### Biometric (Biyolojik kimlik verisi) — Sembol: @ — Renk: #ff88cc

| Sub-Type | Bulunduğu Kaynaklar |
|----------|-------------------|
| Facial Recognition | Traffic Camera, Smart Lock |
| Fingerprint | ATM, Smart Lock |
| Retina Scan | Hospital, Military Network |
| Voice Pattern | Corporate, Government Archive |

#### Blueprint (Teknik tasarım verisi) — Sembol: # — Renk: #00ffcc

| Sub-Type | Bulunduğu Kaynaklar |
|----------|-------------------|
| Schematics | Biotech Lab, Corporate |
| Architecture | Government Archive, Corporate |
| Network Maps | ISP Backbone, Military Network |
| Source Code | Shop Server, Biotech Lab |

#### Research (Bilimsel/deneysel veri) — Sembol: ? — Renk: #9955ff

| Sub-Type | Bulunduğu Kaynaklar |
|----------|-------------------|
| Lab Reports | Biotech Lab, Hospital |
| Test Data | Biotech Lab, Public Library |
| Analysis | Public Library, Data Kiosk |
| Clinical Trials | Hospital, Biotech Lab |

#### Classified (Gizli/kısıtlı veri) — Sembol: ! — Renk: #ff3388

| Sub-Type | Bulunduğu Kaynaklar |
|----------|-------------------|
| Intelligence | Military Network, Government Archive |
| Military Ops | Military Network |
| State Secrets | Government Archive |
| Diplomatic Cables | Government Archive, Corporate |

#### Üretim Content'leri (oyuncu yerleştirmez)

| # | Content | Sembol | Renk | Üreten Bina |
|---|---------|--------|------|-------------|
| 6 | **Key** | K | #ffaa00 | Key Forge |
| 7 | **Repair Kit** | R | #ff7744 | Repair Lab |

Content 0-5 kaynaklardan gelir. Content 6-7 üretim binaları tarafından oluşturulur. Key ve Repair Kit sub-type'a sahip değildir.

### Sub-Type Relevance: Hibrit Yaklaşım

| Oyun Aşaması | Sub-Type Önemi |
|-------------|---------------|
| **Erken oyun** | Fark etmez — Key Forge "herhangi Research" kabul eder |
| **Geç oyun** | Spesifik — FIRE gereksinimleri ve yüksek bit-depth Key tarifleri belirli sub-type ister |

Bu kademeli geçiş oyuncunun aşırı bilgi yüküyle karşılaşmasını engeller.

### Sub-Type Nerede Önemli?

| Sistem | Sub-type önemli mi? | Neden |
|--------|-------------------|-------|
| **FIRE gereksinimleri** | EVET | "50 MB Fingerprint" — spesifik sub-type |
| **Kaynak kimliği** | EVET | Smart Lock → Fingerprint üretir |
| **Scanner filtresi** | EVET | Aynı content'in farklı sub-type'larını ayırır |
| **Key Forge tarifi (erken)** | HAYIR | "Research gerekli" — herhangi sub-type olur |
| **Key Forge tarifi (geç)** | EVET | "Lab Reports gerekli" — spesifik sub-type |
| **Repair Lab tarifi** | Benzer şekilde hibrit | Erken duyarsız, geç duyarlı |
| **Decryptor/Recoverer** | HAYIR | İşlem tipi değişmez |
| **Encryptor** | HAYIR | İşlem tipi değişmez |

### Base State'ler

| State | Anlam | İşleyici Bina | Gerekli Tüketilebilir | Görsel Renk | Zorluk Skalası |
|-------|-------|---------------|-----------------------|-------------|----------------|
| **Public** | Açık veri, işlem gerektirmez | — | — | #00ffaa (yeşil) | Yok |
| **Encrypted** | Şifreli veri | Decryptor | Key (Key Forge) | #2288ff (mavi) | 4-bit / 16-bit / 32-bit |
| **Glitched** | Hasarlı/bozuk veri | Recoverer (feedback loop) | Repair Kit (Repair Lab) | #ffaa00 (turuncu) | Minor / Major / Critical |
| **Enc·Glitch** | Hem şifreli hem bozuk | Decryptor VEYA Recoverer (sıra seçimi) | Key veya Repair Kit | Yarı mavi, yarı turuncu | Birleşik |

**Demo:** Public, Encrypted (4-bit, 16-bit), Glitched (Minor, Major), Enc·Glitch
**Full Release:** + Malware state (Malware Cleaner ile temizlenir)

### Islem Etiketleri (Tags — Birikimli)

Her işleme adımı veriye bir etiket ekler. Etiketler BİRİKİR — verinin işlem geçmişi korunur.

| Etiket | Bina | Bit |
|--------|------|-----|
| **DECRYPTED** | Decryptor | 1 (0x1) |
| **RECOVERED** | Recoverer | 2 (0x2) |
| **ENCRYPTED** | Encryptor | 4 (0x4) |
| **CLEANED** | Malware Cleaner (release) | 8 (0x8) |

**Etiket Birikmesi Örnekleri:**
```
Financial Encrypted          → Decryptor → Financial DECRYPTED
Financial Decrypted          → Encryptor → Financial DECRYPTED·ENCRYPTED
Biometric Glitched           → Recoverer → Biometric RECOVERED
Biometric Recovered          → Encryptor → Biometric RECOVERED·ENCRYPTED
```

**Kritik:** "Financial Encrypted" (kaynaktan ham) ≠ "Financial Decrypted·Encrypted" (işlenmiş + paketlenmiş). Aynı content, aynı state adı ama FARKLI ürünler.

### Neden Bu Sistem Çalışır
- Okuma kolaylığı: "Financial: Transaction Records — Decrypted·Encrypted" — ne olduğunu okuyarak anlarsın
- Sub-type zenginliği: her kaynak benzersiz veri üretir
- Combinatorial derinlik: az sayıda işlemle çok sayıda ürün
- FIRE bulmacası: doğru sub-type'ı doğru kaynaktan bulmak
- Shapez paraleli: kes+boya+birleştir gibi basit işlemler, derin kombinasyonlar

---

## 8. Sifreleme ve Glitch Sistemleri

### Felsefe: Asimetrik Zorluk Artışı

Encrypted ve Glitched **FARKLI** bulmaca tipleri yaratır. Encrypted paralel hatlar (genişlik), Glitched feedback loop'lar (döngü) gerektirir. Zoom-out'da fabrikalar tamamen farklı görsel doku yaratır.

### Encrypted: Bit-Depth → Genişlik Bulmacası

Yüksek bit-depth iki şekilde zorlaştırır:
1. **Key Forge yavaşlar** (karmaşık tarif = uzun üretim)
2. **Key başarı oranı düşer** (her Key şifreyi çözemez, başarısız Key tüketilir)

| Bit-Depth | Key Forge Girdisi | Üretim Hızı | Key Başarı Oranı | Ort. Key/Veri |
|-----------|-------------------|-------------|-----------------|---------------|
| **4-bit** | Research | Hızlı | ~%80 | ~1.25 |
| **16-bit** | Research + Biometric | Yavaş | ~%40 | ~2.5 |
| **32-bit** | Research + Biometric + Financial | Çok yavaş | ~%20 | ~5 |

**Çifte bottleneck:** Key Forge hem YAVAŞ üretiyor hem ürettiği Key'ler her zaman çalışmıyor. Başarısız olunca Key tüketilir, veri Decryptor'da bekler, yeni Key bekler. Feedback loop yok — Decryptor sadece daha fazla Key istiyor.

**Encrypted vs Glitched mekanik farkı:**
```
ENCRYPTED: Veri Decryptor'da BEKLİYOR, Key'ler akıp gidiyor (tüketiliyor)
GLITCHED:  Veri DÖNGÜDE hareket ediyor, Kit'ler tüketiliyor
```

```
16-bit Encrypted veri akışı:

Research ──→ [Key Forge A] ──→ [Merger] ──→ [Merger] ──→ [Decryptor] ──→ Decrypted
Biometric ──→ [Key Forge A]       ↑              ↑
Research ──→ [Key Forge B] ──→────┘              |
Biometric ──→ [Key Forge B]                      |
Research ──→ [Key Forge C] ──→────────────────────┘
Biometric ──→ [Key Forge C]

Fabrika şekli: ═══ yan yana hatlar ═══ (GENİŞ)
```

**Oyuncu hissi:** "Daha güçlü şifre = daha geniş Key fabrikası. Paralel hatlarım nereye sığacak?"

**Geç oyun sub-type spesifik:** 16-bit Key tarifi "Lab Reports (Research) + Fingerprint (Biometric)" gibi spesifik sub-type isteyebilir.

### Glitched: Severity → Derinlik Bulmacası (Feedback Loop)

Recoverer %100 recover yapamaz. Her geçişte bir ORAN kadar recover eder, kalanı hâlâ Glitched çıkar. Oyuncu Separator ile feedback loop kurar.

| Severity | Recovery Oranı/Geçiş | Sonuç |
|----------|---------------------|-------|
| **Minor Glitch** | ~%70-80 | Küçük loop, hızlı temizlenir |
| **Major Glitch** | ~%40-50 | Veri döngüde daha çok kalır, throughput düşer |
| **Critical Glitch** | ~%20-30 | Çok fazla recirculation, paralel loop'lar gerekli |

**Repair Kit tüketimi:** Her recovery DENEMESİ Kit tüketir (başarılı veya başarısız). Bu Repair Lab throughput'unu kritik yapar.

```
Feedback Loop:

                    ┌────────────────────────────────┐
                    ↓                                |
[Kaynak] → Glitched → [Recoverer] + Kit → [Separator "Recovered"]
                                              |             |
                                         Recovered    hâlâ Glitched
                                              ↓          (loop başına döner)
                                         (devam eder)

Fabrika şekli: ↻ döngüsel devre (DERİN)
```

**Critical Glitch'te paralel loop'lar:**
```
                    ┌→ [Recoverer A] → [Separator A] → loop A ─┐
[Splitter] ─────────┤                                          ↓
                    └→ [Recoverer B] → [Separator B] → loop B ─┤
                                                                ↓
                                                         [Merger] → çıkış
```

**Oyuncu hissi:** "Daha derin hasar = daha karmaşık döngü. Loop'larım yeterli throughput üretiyor mu?"

### Repair Lab Tarifi (Glitch Tier'a Paralel)

| Glitch Tier | Repair Lab Girdisi | Bulmaca |
|-------------|---------------------|---------|
| **Minor** | Standard | Tek kaynak, basit |
| **Major** | Standard + Financial | İki farklı content lazım |
| **Critical** | Standard + Financial + Blueprint | Üç farklı content lazım |

Repair Lab recipe karmaşıklığı + feedback loop Kit tüketimi = çifte throughput challenge.

### Encrypted vs Glitched: Asimetrik Karşılaştırma

| | Encrypted (Genişlik) | Glitched (Derinlik) |
|---|---|---|
| **Zorluk artışı** | Bit-depth (4/16/32) | Severity (Minor/Major/Critical) |
| **Temel mekanik** | Paralel Key Forge hatları | Recoverer feedback loop |
| **Bottleneck** | Key üretim throughput'u (yavaş üretim) | Recovery oranı + Kit tüketimi |
| **Alan kullanımı** | Yana yayılma (paralel hatlar) | Döngüsel routing (loop'lar) |
| **Fabrika şekli** | Geniş ve kısa | Döngüsel ve kompakt |
| **Oyuncu kararı** | "Kaç paralel Key Forge?" | "Kaç paralel loop?" |
| **Üretici bina** | Key Forge (bit-depth'e göre yavaşlar) | Repair Lab (Kit tüketimi artar) |

### Malware: Endgame Boss Puzzle (Full Release)

Malware ne Encrypted ne Glitched gibi çözülür. Malware Cleaner binası + Recovered antivirus gerektirir.

---

## 9. Bilesik State Sistemi

### Enc·Glitch: Hem Şifreli Hem Bozuk

Bazı kaynaklar tek veri üzerinde birden fazla state taşıyan veri üretir.

**Demo:** Enc·Glitch (Encrypted + Glitched)
**Full Release:** + Enc·Mal, Glitch·Mal, Enc·Glitch·Mal

### Görsel Dil

State'ler renk ile temsil edilir. Bileşik state'lerde veri ikonu **yarı yarıya bölünür:**

| State | Renk |
|-------|------|
| Public | Yeşil |
| Encrypted | Mavi |
| Glitched | Turuncu |
| Enc·Glitch | Yarı mavi, yarı turuncu (bölünmüş ikon) |

Oyuncu dual state'i sembol + bölünmüş renk ile bir bakışta okuyor — tıpkı Shapez'de çok katmanlı şekilleri okumak gibi.

### Tier Escalation Kuralı

Bileşik state'li veride bir state'i çözünce **diğerinin zorluğu +1 artar.**

**Örnek: Financial Enc 4-bit · Minor Glitch**

**Yol A — Önce Recover (loop):**
```
Recover loop (Minor = %70-80, Kit = Standard, kolay)
→ Financial Recovered · Encrypted 16-bit(↑)
→ Decrypt (16-bit Key = Research + Biometric, paralel Key Forge lazım)
→ Financial Recovered · Decrypted
```

**Yol B — Önce Decrypt:**
```
Decrypt (4-bit Key = Research, basit, tek Key Forge yeter)
→ Financial Decrypted · Major Glitch(↑)
→ Recover loop (Major = %40-50, Kit = Standard + Financial, daha çok loop)
→ Financial Decrypted · Recovered
```

### Strateji Kararını Belirleyen Faktörler
- **Çevredeki kaynaklar:** Research kaynağı yakınsa → Decrypt önce (Key kolay)
- **Standard bolluğu:** Standard her yerdeyse → Recover önce (Kit kolay ama loop daha uzun)
- **Mevcut altyapı:** Key pipeline zaten varsa → Decrypt önce
- **Alan durumu:** Loop alan tuketiyor, paralel hat da → hangisi sığar?
- **Harita seed'i:** Her haritada optimal yol farklı = procedural puzzle

### Yol Seçimi = Farklı Fabrika Şekli

| | Yol A (önce Recover) | Yol B (önce Decrypt) |
|---|---|---|
| **İlk adım** | Feedback loop (döngüsel) | Paralel Key Forge (geniş) |
| **İkinci adım** | Paralel 16-bit Key Forge (geniş) | Major Glitch loop (daha büyük döngü) |
| **Fabrika şekli** | Loop + geniş hat | Geniş hat + büyük loop |

Her yol × 6 content tipi × severity/bit-depth varyasyonları = onlarca benzersiz puzzle.

---

## 10. Yapi Detaylari

### CLASSIFIER — "Content Filter"
- **Boyut:** 2×2 | **Giriş:** Sol | **Çıkış:** Sağ (seçilen), Alt (kalan)
- Gelen veriyi CONTENT TİPİNE göre filtreler (binary filtre)
- Oyuncu Tab ile hangi content'i çıkartacağını seçer
- Veriyi DEĞİŞTİRMEZ — saf routing

**Örnek — 3 content'li kaynaktan ayıklama:**
```
Karışık (Fin+Bio+Blue) → Classifier "Financial" → Financial (sağ)
                                                 → Kalan (alt) → Classifier "Biometric" → Biometric (sağ)
                                                                                         → Blueprint (alt)
```

### SEPARATOR — "State Filter"
- **Boyut:** 2×2 | **Giriş:** Sol | **Çıkış:** Sağ (seçilen), Alt (kalan)
- Gelen veriyi STATE tipine göre filtreler (binary filtre)
- Tab ile filtre döngüsü: Public → Encrypted → Glitched → Enc·Glitch
- Classifier ile aynı mantık, farklı kriter (content yerine state)
- **Recoverer feedback loop'ta kritik rol:** Recovered vs hâlâ Glitched ayırımı

**Örnek:**
```
Financial (Public + Glitched + Encrypted)
    → Separator "Public" → Financial Public (sağ)
                         → Kalan (alt) → Separator "Glitched" → Financial Glitched (sağ)
                                                                → Financial Encrypted (alt)
```

### SCANNER — "Sub-Type Filter" (YENİ)
- **Boyut:** 2×2 | **Giriş:** Sol | **Çıkış:** Sağ (seçilen), Alt (kalan)
- Gelen veriyi SUB-TYPE'a göre filtreler (binary filtre)
- **Akıllı Tab:** Sadece gelen content'in sub-type'larını gösterir
- Aynı content'in farklı sub-type'larını ayırmak için kullanılır
- Geç oyunda açılır (erken oyunda sub-type fark etmez)

**Örnek — Bank Terminal'den gelen iki Financial sub-type:**
```
Bank Terminal: Account Data (Financial) + Credit History (Financial)
    → Classifier "Financial" → ikisi de Financial, ikisi de çıkar
    → Scanner "Account Data" → Account Data (sağ)
                              → Credit History (alt)
```

**Filtre Bina Ailesi:**

| Bina | Ne Filtreler | Tab Döngüsü | Ne Zaman Lazım |
|------|-------------|-------------|----------------|
| **Separator** | State | Public → Encrypted → Glitched → Enc·Glitch | Her zaman |
| **Classifier** | Content | Standard → Financial → Biometric → ... | Çoğu zaman |
| **Scanner** | Sub-Type | Gelen content'e göre değişir | Geç oyun, spesifik FIRE/tarif |

### DECRYPTOR — "Cipher Breaker" (ÇİFT GİRDİ)
- **Boyut:** 2×2 | **Giriş:** Sol (veri) + Üst (Key) | **Çıkış:** Sağ
- Encrypted/Enc·Glitch veri + Key → **OLASİLİKSAL** decryption (DECRYPTED etiketi eklenir)
- Key bit-depth'i veri bit-depth'ine eşleşmeli (4-bit veri = 4-bit Key)
- **Key başarı oranı:** 4-bit %80, 16-bit %40, 32-bit %20
- Başarısız: Key tüketilir, veri Decryptor'da kalır, yeni Key bekler
- Key yoksa bina DURUR, veri kuyrukta bekler
- İşlem hızı bit-depth'e göre yavaşlar (16-bit → paralel Decryptor gerekli)
- Enc·Glitch kabul: şifre çözer → Glitched çıkar (Glitch severity +1)

### RECOVERER — "Data Restorer" (ÇİFT GİRDİ — FEEDBACK LOOP)
- **Boyut:** 2×2 | **Giriş:** Sol (veri) + Üst (Repair Kit) | **Çıkış:** Sağ
- Glitched/Enc·Glitch veri + Repair Kit → **KISMİ** recovery
- Her denemede Repair Kit tüketilir (başarılı veya başarısız)
- Recovery oranı Glitch severity'ye bağlı (Minor %70-80, Major %40-50, Critical %20-30)
- Çıkış: karışık (Recovered + hâlâ Glitched) → Separator ile ayır → Glitched'ı loop'a döndür
- Enc·Glitch kabul: bozukluğu onarır → Encrypted çıkar (Encrypted bit-depth +1)

**Feedback Loop Kurulumu:**
```
[Kaynak] → Glitched → [Recoverer] + Kit → [Separator "Recovered"]
                ↑                              |             |
                |                         Recovered    hâlâ Glitched
                |                              ↓             |
                |                         (devam eder)       |
                └────────────────────────────────────────────┘
```

**Kit throughput zayıfsa loop tıkanır** — bu otomasyon bulmacasının kendisi.

### KEY FORGE — "Key Factory"
- **Boyut:** 2×2 | **Giriş:** Sol | **Çıkış:** Sağ
- Content tüketir → Decryption/Encryption Key üretir
- Tab ile bit-depth seçer: 4-bit / 16-bit / 32-bit
- **Yüksek bit-depth = yavaş üretim** → paralel Key Forge zorunluluğu yaratır
- Key'ler kablo ile Decryptor/Encryptor'lara gider

| Bit-Depth | Girdi | Üretim Hızı |
|-----------|-------|-------------|
| 4-bit | Research | Hızlı |
| 16-bit | Research + Biometric | Yavaş (2+ paralel gerekli) |
| 32-bit | Research + Biometric + Financial | Çok yavaş (3+ paralel gerekli) |

**Not:** Girdi miktarları ve üretim hızları throughput tartışmasından sonra kesinleşecek.

### REPAIR LAB — "Kit Factory"
- **Boyut:** 2×2 | **Giriş:** Sol | **Çıkış:** Sağ
- Content tüketir → Repair Kit üretir
- Tab ile tier seçer (Glitch severity'ye eşleşir)
- Repair Kit'ler kablo ile Recoverer'a gider

| Glitch Tier | Girdi |
|-------------|-------|
| Minor | Standard |
| Major | Standard + Financial |
| Critical | Standard + Financial + Blueprint |

**Not:** Feedback loop'ta her deneme Kit tükettiğinden, Major/Critical Glitch çok fazla Kit tüketir → Repair Lab throughput'u kritik.

### ENCRYPTOR — "Cipher Lock" (ÇİFT GİRDİ)
- **Boyut:** 2×2 | **Giriş:** Sol (veri) + Üst (Key) | **Çıkış:** Sağ
- İşlenmiş veri + Key → yeniden şifrelenmiş veri (ENCRYPTED etiketi eklenir)
- Mevcut etiketler korunur: Financial Decrypted → Financial Decrypted·ENCRYPTED
- Decryptor'un tersi — aynı Key'leri tüketir

**Neden önemli:**
- Bazı gig'ler şifrelenmiş (işlenmiş + encrypted) veri istiyor
- Key hem Decryptor'a hem Encryptor'a lazım — Key Forge throughput'u daha kritik

### SPLITTER — "Flow Divider"
- **Boyut:** 2×2 | **Giriş:** Sol | **Çıkış:** Sağ + Alt (eşit dağıtım, dönüşümlü)
- Paralel işleme ve paralel feedback loop'lar için kullanılır

### MERGER — "Flow Combiner"
- **Boyut:** 2×2 | **Giriş:** Sol + Üst | **Çıkış:** Sağ (dönüşümlü)
- Paralel Key Forge çıktılarını veya paralel loop çıktılarını birleştirir
- Bir giriş boşsa diğerinden alır (tıkanma önleme)
- Zincirleme Merger = routing bulmacası (3+ hattı birleştirmek için)

### TRASH — "Data Incinerator"
- **Boyut:** 1×1 | **Giriş:** Sol | **Çıkış:** Yok
- Tüm veri tiplerini kabul eder, anında imha eder
- İstenmeyen sub-type'ları veya yan akışları temizlemek için

### CONTRACT TERMINAL — "Mission Hub"
- **Boyut:** Level'a göre değişir (Level 1: 2×2, Level 2+: büyür, max 10×10)
- **Port sayısı:** 4 × (size - 1) formülü (Level 1: 4 port, Level 2: 8 port, vb.)
- Harita merkezinde SABİT (oyuncu yerleştirmez)
- Mevcut gig'leri (sözleşmeleri) gösterir
- İşlenmiş veriyi teslim alır → ilerleme sayar
- Oyunun kalbi — tüm pipeline'lar buraya akar
- Exclusion zone: yakınına bina yerleştirilemez

#### Port Purity Kuralı
Contract Terminal **sadece saf (pure) veri akışı kabul eder.** Her input port'un kablosu kümülatif tip kaydı tutar:

- **Kablo bağlandığında:** Kaynak çıkışları için tüm olası veri tipleri anında kaydedilir
- **Push anında:** Diğer binalardan gelen veri tipleri kabloya kaydedilir ve anında değerlendirilir
- Port'taki **tüm** kayıtlı tipler aktif bir gig requirement'a eşleşiyorsa → **kabul**, veri akar
- Port'ta **tek bir non-matching tip** bile kaydedildiyse → **port kalıcı olarak bloklanır**
- **Kablo çıkarıldığında:** Port kaydı sıfırlanır, blok kalkar
- **Gig değiştiğinde:** Tüm portlar yeniden değerlendirilir

**Neden:** Bu kural oyunun puzzle çekirdeğini korur. Oyuncu kaynaktan gelen karışık veriyi filtrelemeden CT'ye teslim edemez.

---

## 11. FIRE Sistemi

### FIRE — Forced Isolation & Restriction Enforcer

FIRE, medium ve üstü kaynakların güvenlik duvarıdır. Oyuncu FIRE'ı kırmadan kaynaktan veri çekemez.

### Temel Mekanik

Kaynak bağımlılık zinciri ve güvenlik duvarı **tek bir birleşik mekanik** olarak çalışır:

1. **Easy kaynaklar:** FIRE yok, direkt bağlan ve veri çek
2. **Medium kaynaklar:** FIRE var, sabit eşik → yakın kaynaklardan doğru sub-type besle → eşik dolunca FIRE kalkar
3. **Hard kaynaklar:** FIRE var, regenerating → sürekli throughput koru yoksa FIRE kapanır, veri kesilir

### Nasıl Çalışır

```
Hospital Archive — 🔥 FIRE Active
  Biometric: Retina Scan — 0/50 MB

  "Feed Retina Scan (Public) to bypass FIRE protection."
```

1. Oyuncu FIRE gereksinimini okur: "50 MB Retina Scan lazım"
2. Retina Scan üreten yakın kaynağı bulur: Medical Clinic
3. Medical Clinic'ten kablo çekip Hospital Archive'ın FIRE input port'una bağlar
4. Retina Scan akmaya başlar → FIRE sayacı dolar
5. **Medium:** 50 MB dolunca FIRE kalkar, artık Hospital'dan veri çekebilir. FIRE bir daha kapanmaz.
6. **Hard:** FIRE regenerating — throughput düşerse FIRE kapanır, veri **anında** kesilir

### Kaynak Bağımlılık Zinciri

FIRE gereksinimleri doğal bir bağımlılık ağacı yaratır:

```
[Easy: Smart Lock] ──Fingerprint──→ [Medium: Hospital Terminal] FIRE kırılır
                                          |
                                    Biometric Encrypted
                                          ↓
                                        işle → CT

[Easy: ATM] ──Transaction Records──→ [Medium: Shop Server] FIRE kırılır
                                          |
[Easy: Bank Terminal] ──Account Data──→ [Hard: Corporate Server] FIRE kırılır (regen)
                                          |
                                    Financial Encrypted → işle → CT
```

**Easy → Medium → Hard** zinciri otomatik olarak oluşur. Oyuncu kolay kaynaklardan başlar, onların verisini kullanarak orta kaynaklara erişir, orta kaynaklarla zor kaynaklara ulaşır.

### FIRE Zorluk Seviyeleri

| Kaynak Zorluğu | FIRE Tipi | Davranış | Oyuncu Aksiyonu |
|----------------|-----------|----------|----------------|
| **Easy** | FIRE yok | Direkt erişim | Kablo çek, veri çek |
| **Medium** | Sabit eşik | X MB doğru sub-type → FIRE kalıcı olarak kalkar | Bir kere besle, bitsin |
| **Hard** | Regenerating | Sürekli throughput gerekli, düşerse FIRE kapanır | Kalıcı besleme hattı kur |

### FIRE ve Throughput

Hard kaynaklarda FIRE regenerating olduğundan, oyuncunun **sürekli akış** koruması gerekir. Bu Shapez'in geç-oyun throughput challenge'ının BREACH karşılığıdır:

```
Shapez geç oyun:   "Bu şekli saniyede 10 adet sürdür"
BREACH:         "Bu kaynağın FIRE'ını sürekli besle yoksa kapanır"
```

FIRE kapandığında veri akışı **anında** kesilir. Stresli değil çünkü doğru kurulduktan sonra FIRE değişmez — bu sadece throughput testi.

### Görsel Gösterim

- Kaynak üzerinde FIRE durumu sembol ile gösterilir (Shapez hub göstergesi gibi)
- "FIRE: Retina Scan — 32/50 MB" progress bar
- FIRE Active = kırmızı kalkan ikonu
- FIRE Breached = yeşil kilit-açık ikonu
- Hard kaynakta FIRE regen göstergesi (throughput bar)
- Bilgi panelinde: "FIRE — Forced Isolation & Restriction Enforcer" açıklaması

---

## 12. Throughput Sistemi

### Temel Prensip

Oyunda throughput dört kaynaktan kontrol edilir:

| Kaynak | Nasıl Çalışır |
|--------|-------------|
| **Filtre binaları** | Girdi çeşitliliği arttıkça yavaşlar |
| **İşleme binaları** | Bit-depth/severity arttıkça hem yavaşlar hem başarı oranı düşer |
| **Üretim binaları** | Tarif karmaşıklığı arttıkça yavaşlar |
| **Routing binaları** | Anlık — gecikme yok, akışı doğal böler/birleştirir |

### Filtre Binaları — Çeşitlilik = Yavaşlık

Separator, Classifier ve Scanner'ın işlem hızı girdideki **benzersiz tip sayısına** bağlıdır:

```
throughput = base_speed / input_variety_count
```

| Bina | Variety ne ile sayılır | Örnek |
|------|----------------------|-------|
| **Separator** | Girdideki farklı state sayısı | 2 state → base/2, 4 state → base/4 |
| **Classifier** | Girdideki farklı content sayısı | 2 content → base/2, 4 content → base/4 |
| **Scanner** | Girdideki farklı sub-type sayısı | 2 sub-type → base/2, 8 sub-type → base/8 |

**Neden bu önemli:** Scanner'ı ham veriye (8+ sub-type) bağlayan oyuncu ~base/8 hız alır. Önce Separator → Classifier → Scanner sırasıyla filtreleyen oyuncu her adımda base/2-3 hız alır — çok daha verimli. Oyuncu optimal filtre sırasını kurallarla değil, **verimlilik farkını görerek** öğrenir.

### İşleme Binaları — Karmaşıklık = Yavaşlık + Başarı Oranı

| Bina | Hız Belirleyicisi | Başarı Oranı | Başarısızlıkta |
|------|-------------------|-------------|----------------|
| **Decryptor** | Bit-depth'e göre yavaşlar | 4-bit %80, 16-bit %40, 32-bit %20 | Key tüketilir, veri bekler |
| **Recoverer** | Severity'ye göre yavaşlar | Minor %70-80, Major %40-50, Critical %20-30 | Kit tüketilir, veri loop'a döner |
| **Encryptor** | Key bit-depth'e göre yavaşlar | Key başarı oranına tabi | Key tüketilir, veri bekler |

**Paralel çözüm:** Yüksek bit-depth/severity → paralel Decryptor/Recoverer kurarak toplam throughput'u artır.

### Üretim Binaları — Tarif = Yavaşlık

| Bina | Hız Belirleyicisi |
|------|-------------------|
| **Key Forge (4-bit)** | Hızlı (1 content) |
| **Key Forge (16-bit)** | Yavaş (2 content) → 2+ paralel gerekli |
| **Key Forge (32-bit)** | Çok yavaş (3 content) → 3+ paralel gerekli |
| **Repair Lab (Minor)** | Hızlı (1 content) |
| **Repair Lab (Major)** | Orta (2 content) |
| **Repair Lab (Critical)** | Yavaş (3 content) |

### Routing Binaları — Anlık, Doğal Akış Etkisi

Splitter ve Merger kendi işlem hızına sahip DEĞİL. Akışı doğal olarak böler/birleştirir:

```
Splitter:  10 MB/s → 5 MB/s + 5 MB/s (her zaman 50/50)
Merger:    10 MB/s + 15 MB/s → kablo kapasitesine tabi
Trash:     Anlık imha, tıkanma yok
```

### Kablo Kapasitesi

Kablolar sınırsız veri taşıyamaz. Her kablonun bir **maksimum throughput** kapasitesi vardır:

```
Merger: 10 MB/s + 15 MB/s = 25 MB/s isteniyor
Kablo kapasitesi: 20 MB/s
Sonuç: 20 MB/s çıkış, kalan birikir → backpressure
```

**Çözüm:** Paralel kablolar. Ama iki kablo aynı grid hücresini paylaşamaz → alan tüketiyor → routing bulmacası. Geç oyunda ana hatlar "kablo otoyollarına" dönüşür → devre kartı estetiği güçlenir.

Kablo kapasitesi Bandwidth upgrade ile ölçeklenir (bkz. Upgrade Sistemi).

### Veri Çekme Hızı — Global, Kaynak Bazlı Değil

Tüm kaynaklar aynı taban hızda veri üretir. Hız kaynağa değil, **oyuncunun altyapısına** bağlıdır.

- **Taban hız:** 5 MB/s (tüm kaynaklar, tüm portlar eşit)
- **Bandwidth upgrade ile ölçeklenir** (Upgrade Sistemi)
- **Port sayısı** kaynak zorluğuna göre değişir — daha fazla port = daha fazla paralel kablo çekebilirsin = daha fazla toplam veri

| Kaynak Zorluğu | Output Port Sayısı | Tier 1 Toplam | Tier 5 Toplam |
|----------------|-------------------|---------------|---------------|
| **Easy** | 1-2 port | 5-10 MB/s | 500 MB - 1 GB/s |
| **Medium** | 3-4 port | 15-20 MB/s | 1.5-2 GB/s |
| **Hard** | 5-6 port | 25-30 MB/s | 2.5-3 GB/s |
| **Endgame** | 7-8 port | 35-40 MB/s | 3.5-4 GB/s |

**Not:** Kesin port sayıları ve taban hız playtest ile doğrulanacak. Terabyte+ ölçeğine ulaşmak için upgrade çarpanları agresif olacak.

### FIRE Regen Hızı — Output'tan Bağımsız

FIRE regen hızı kaynağın output hızından ve Bandwidth upgrade'den **bağımsızdır.** Sabit, tuned değerlerdir:

| Kaynak | FIRE Regen Hızı | Min. Tier (yaklaşık) |
|--------|----------------|---------------------|
| Medium | Sabit eşik (regen yok) | Tier 1 yeter |
| Hard (Corporate) | ~50 MB/s | ~Tier 3 |
| Hard (Gov Archive) | ~150 MB/s | ~Tier 4 |
| Endgame (Military) | ~500 MB/s | ~Tier 5-6 |

Bu doğal ilerleme kapısı yaratır: "Corporate'ı hacklemek için önce Bandwidth'imi yükseltmeliyim."

---

## 13. Upgrade Sistemi

### Temel Prensip: Shapez Modeli

Contract Terminal'e teslim ettiğin veri **iki iş birden** yapar:
1. Gig/ilerleme tamamlama (mevcut)
2. Upgrade ilerlemesi (yeni)

**Ayrı currency yok, ayrı üretim hattı yok.** Zaten yaptığın iş seni güçlendiriyor.

### 4 Upgrade Kategorisi

| Kategori | Ne İyileşir | Hangi Veri Yükseltir | Tematik Mantık |
|----------|-----------|---------------------|----------------|
| **Routing** | Separator, Classifier, Scanner işlem hızı | Public data teslimi | Daha çok sıraladıkça hızlanırsın |
| **Decryption** | Key başarı oranı + Decryptor/Encryptor/Key Forge hızı | Decrypted veya Encrypted data teslimi | Daha çok kırdıkça ustalaşırsın |
| **Recovery** | Recovery oranı + Recoverer/Repair Lab hızı | Recovered data teslimi | Daha çok onardıkça iyileşirsin |
| **Bandwidth** | Kaynak çekme hızı + kablo kapasitesi | Herhangi data teslimi | Ağ büyüdükçe altyapı güçlenir |

### Hız Ölçekleme Tablosu

| Tier | Çarpan | Kümülatif Teslim Gereksinimi |
|------|--------|------------------------------|
| 1 | 1x (base) | — |
| 2 | 3x | 100 MB |
| 3 | 10x | 500 MB |
| 4 | 30x | 2 GB |
| 5 | 100x | 10 GB |
| 6 | 300x | 50 GB |
| 7 | 1,000x | 250 GB |
| 8 | 3,000x | 1 TB |

**Not:** Kesin çarpanlar ve maliyetler playtest ile doğrulanacak. Terabyte+ ölçeğe ulaşmak için agresif ölçekleme gerekli. Full release'de Tier 8+ sınırsız devam edebilir.

### Başarı Oranı Upgrade'leri

Sadece hız değil, **başarı oranları** da iyileşir — bu qualitative bir değişim:

**Decryption Upgrade → Key Başarı Oranı:**

| Bit-Depth | Tier 1 | Tier 4 | Tier 8 |
|-----------|--------|--------|--------|
| 4-bit | %80 | %90 | %98 |
| 16-bit | %40 | %60 | %85 |
| 32-bit | %20 | %35 | %60 |

**Recovery Upgrade → Recovery Oranı:**

| Severity | Tier 1 | Tier 4 | Tier 8 |
|----------|--------|--------|--------|
| Minor | %70 | %85 | %97 |
| Major | %40 | %55 | %80 |
| Critical | %20 | %35 | %55 |

**Neden bu önemli:** Erken oyunda Critical Glitch neredeyse imkansız (%20 recovery), ama upgrade'lerle yönetilebilir hale gelir (%55). Sadece "daha hızlı" değil, "daha verimli" — Shapez/Factorio'dan daha derin bir upgrade deneyimi.

### Bandwidth Upgrade Detayları

Bandwidth upgrade **üç şeyi birden** etkiler:

| Tier | Kaynak Çekme Hızı (port başı) | Kablo Kapasitesi |
|------|-------------------------------|-----------------|
| 1 | 5 MB/s | 20 MB/s |
| 2 | 15 MB/s | 60 MB/s |
| 3 | 50 MB/s | 200 MB/s |
| 4 | 150 MB/s | 600 MB/s |
| 5 | 500 MB/s | 2 GB/s |
| 6 | 1.5 GB/s | 6 GB/s |
| 7 | 5 GB/s | 20 GB/s |
| 8 | 15 GB/s | 60 GB/s |

Kablo kapasitesi her zaman port hızının ~4x'i — tek kaynağın verisi tek kabloya sığar, ama merger sonrası veya çok portlu kaynaklar için paralel kablo gerekebilir.

### Oyuncu Deneyim Eğrisi

```
İlk 10 dk:    ATM (1 port) → 5 MB/s                "Başladık"
30 dk:        3 kaynak bağlı → 30 MB/s toplam       "Güzel akıyor"
1 saat:       Tier 2, Hospital (3 port) → 45 MB/s    "Ciddi veri!"
2 saat:       Tier 3, 8 kaynak → 1 GB/s toplam       "GİGABYTE!"
3 saat:       Tier 4, Corporate (6 port) → 900 MB/s  "Bu tek kaynak!"
4 saat:       Tier 5 → toplam 20 GB/s                "Devasa ağ"
Endgame:      Tier 7-8 → 100+ GB/s → TB bölgesi      "TERABYTE!"
```

**Network Throughput göstergesi:** CT'ye giren toplam akış = oyuncunun gurur metriği.

### UI — Contract Terminal Upgrade Paneli

```
┌─ CONTRACT TERMINAL ──────────────────────┐
│                                          │
│  [Gigs]  [Upgrades]  [Network]           │
│                                          │
│  ⚡ ROUTING          Tier 4 (30x)        │
│  ████████░░░░░░  1.2 GB / 2 GB           │
│  "Deliver Public data to improve"        │
│                                          │
│  🔓 DECRYPTION       Tier 3 (10x)        │
│  ██████░░░░░░░░  320 MB / 500 MB         │
│  "Deliver Decrypted data to improve"     │
│                                          │
│  🔧 RECOVERY         Tier 2 (3x)         │
│  ████░░░░░░░░░░  80 MB / 100 MB          │
│  "Deliver Recovered data to improve"     │
│                                          │
│  📡 BANDWIDTH        Tier 3 (10x)        │
│  ██████░░░░░░░░  350 MB / 500 MB         │
│  "Deliver any data to improve"           │
│                                          │
└──────────────────────────────────────────┘
```

---

## 14. Harita ve Kaynaklar

### Harita Yapısı
- **Level-based:** 9 level, Level 1-8 sınırlı harita (100-800 hücre), Level 9 sonsuz
- Demo sadece Level 1 (2×2 CT, 100×100 harita)
- Bölge-grid tabanlı eşit kaynak dağıtımı + görünür sınır (Level 1-8)
- Level 9: chunk-based sonsuz üretim
- Sis perdesi (fog of war): keşfedilmemiş alanlar gizli
- Yakın bina yerleştirme ile keşif
- Kaynaklar tükenmez (chill otomasyon, stres yok)
- Contract Terminal harita merkezinde sabit
- Seed-based prosedürel — her oyunda farklı

### Kaynak Tipleri ve Zorlukları

Kaynaklar 3 zorluk kategorisinde (+ endgame):

| Zorluk | Content Çeşitliliği | State Profili | FIRE | Port | Örnek Kaynaklar |
|--------|--------------------|--------------|----|------|-----------------|
| **Easy** | 1-2 content, 1-2 sub-type | Çoğu Public, az Minor Glitch | Yok | 1-2 port | ISP Backbone, ATM, Data Kiosk, Smart Lock, Traffic Camera |
| **Medium** | 2-3 content, 2-3 sub-type | Public + Encrypted 4-bit + Minor Glitch | Sabit eşik | 3-4 port | Hospital, Bank Terminal, Public Library, Shop Server, Biotech Lab, Medical Clinic |
| **Hard** | 3-4 content, 3-4 sub-type | Encrypted 16-bit + Major Glitch + Enc·Glitch | Regenerating | 5-6 port | Corporate Server, Government Archive |
| **Endgame** | 3-4 content | Encrypted 32-bit + Malware (release) | Regenerating+ | 7-8 port | Military Network, Blackwall Fragment |

### Kaynak → Sub-Type Eşleştirmeleri

Her kaynak spesifik sub-type'lar üretir. Bu eşleştirmeler tematik tutarlılık sağlar:

| Kaynak | Zorluk | Ürettiği Sub-Type'lar |
|--------|--------|----------------------|
| **ISP Backbone** | Easy | Log Files (Standard), Network Maps (Blueprint) |
| **ATM** | Easy | Transaction Records (Financial), Fingerprint (Biometric), Cache Data (Standard) |
| **Data Kiosk** | Easy | Metadata (Standard), Credit History (Financial), Analysis (Research) |
| **Smart Lock** | Easy | Config Data (Standard), Fingerprint (Biometric), Facial Recognition (Biometric) |
| **Traffic Camera** | Easy | Log Files (Standard), Facial Recognition (Biometric) |
| **Medical Clinic** | Medium | Retina Scan (Biometric), Clinical Trials (Research), Metadata (Standard) |
| **Hospital** | Medium | Retina Scan (Biometric), Lab Reports (Research), Metadata (Standard) |
| **Bank Terminal** | Medium | Account Data (Financial), Credit History (Financial), Fingerprint (Biometric) |
| **Public Library** | Medium | Test Data (Research), Analysis (Research), Cache Data (Standard) |
| **Shop Server** | Medium | Transaction Records (Financial), Config Data (Standard), Source Code (Blueprint) |
| **Biotech Lab** | Medium | Lab Reports (Research), Test Data (Research), Schematics (Blueprint), Source Code (Blueprint) |
| **Corporate Server** | Hard | Account Data (Financial), Tax Records (Financial), Schematics (Blueprint), Voice Pattern (Biometric) |
| **Government Archive** | Hard | Architecture (Blueprint), State Secrets (Classified), Voice Pattern (Biometric), Tax Records (Financial), Diplomatic Cables (Classified) |
| **Military Network** | Endgame | Intelligence (Classified), Military Ops (Classified), Network Maps (Blueprint), Retina Scan (Biometric) |

**Not:** Kaynak sub-type eşleştirmeleri ve state dağılımları aktif dengeleme altında.

### FIRE Gereksinimleri

**Medium (Threshold — sabit eşik, bir kere besle, kalıcı olarak kalkar):**

| Kaynak | FIRE Gereksinimi | Miktar | Besleme Kaynağı |
|--------|-----------------|--------|-----------------|
| Hospital Terminal | Fingerprint (Biometric) | 30 MB | Smart Lock, ATM |
| Shop Server | Transaction Records (Financial) | 40 MB | ATM |
| Biotech Lab | Log Files (Standard) | 50 MB | ISP Backbone, Traffic Camera |
| Public Library | Test Data (Research) | 30 MB | Public Database |

**Hard (Regenerating — sürekli throughput koru, düşerse FIRE kapanır):**

| Kaynak | FIRE Gereksinimi | Regen Hızı | Besleme Kaynağı |
|--------|-----------------|-----------|-----------------|
| Corporate Server | Account Data (Financial) | ~50 MB/s | Bank Terminal |
| Government Archive | Voice Pattern (Biometric) | ~150 MB/s | Data Kiosk, Corporate Server |

**Endgame (Regenerating — çok yüksek regen):**

| Kaynak | FIRE Gereksinimi | Regen Hızı | Besleme Kaynağı |
|--------|-----------------|-----------|-----------------|
| Military Network | State Secrets (Classified) | ~500 MB/s | Government Archive |
| Blackwall Fragment | Intelligence (Classified) | ~500 MB/s | Military Network |
| Dark Web Node | Military Ops (Classified) | ~500 MB/s | Military Network |

**FIRE Input Port Yerleşimi:** CT'den ters yöndeki kenarda. Çalışma zamanında CT konumuna göre hesaplanır.

**Not:** FIRE miktarları ve regen hızları playtest ile doğrulanacak.

### Tasarım Felsefesi

**Neden kaynak bağımlılık zinciri:**
- **Doğal ilerleme:** Easy → Medium → Hard otomatik yol haritası
- **Her kaynak değerli:** Bir kaynak hem kendi verisi hem başka kaynağın FIRE'ı için kullanılır
- **Hack fantezisi:** "Kamerayı hackle → hastaneyi hackle → arşive eriş" = hacker deneyimi
- **Devre kartı:** Zoom-out'da her kaynak birbirine bağlı bir ağ — tam bir devre kartı

**"Görebilirsin Ama Erişemezsin" Mekanigi:**
```
Oyuncu spawn'da başlıyor...
  → Yanında bir ISP Backbone (easy, FIRE yok) — başla
  → 10 kare ötede Corporate Server! — FIRE Active, 16-bit Encrypted
  → "FIRE'ı kırmak için Account Data lazım... Bank Terminal'den gelir ama o da FIRE'lı..."
  → 3 saat sonra: "SONUNDA Corporate'a ulaştım!"
  → Bu his = oyunun bağımlılık döngüsü
```

---

## 15. Gig Sistemi

### Genel Bakış
Gig sistemi oyuncuya yön veren soft-guide mekanizmasıdır. Contract Terminal'den sözleşmeler alır, pipeline kurarsın, teslim edersin.

**Not:** Gig sisteminin soft-guide olarak yeniden tasarlanması tartışılmaktadır. Mevcut yapı referans olarak korunuyor, sonraki tasarım oturumunda kesinleşecek.

### Mevcut Yapı (Yeniden Değerlendirilecek)

1. Contract Terminal'de mevcut gig'ler görüntülenir
2. Gig: "X miktar Y veri isle ve teslim et"
3. Oyuncu pipeline kurar: kaynak → işlem → Contract Terminal
4. Veri akar → **CT port purity kontrolü** → eşleşiyorsa ilerleme sayacı artar
5. Gig tamam → yeni bina açılır + yeni gig'ler belirir
6. Veri teslimde TÜKETİLİR (Shapez modeli — Hub'a giren veri gider)

### Tutorial Gig'ler (Yeniden Tasarlanacak)

Tutorial sistemi 9 gig ile tüm mekanikleri öğretir. Her gig tek bir konsept, miktarlar pipeline gözlemlemeye yetecek kadar büyük:

| # | Gig | Mekanik | Miktar | Unlock |
|---|-----|---------|--------|--------|
| 1 | First Connection | Kablo çekme | 50 MB | Separator |
| 2 | Clean Stream | State filtre (Separator) | 100 MB | Classifier |
| 3 | Content Split | Content filtre + Merger | 80+80 MB | Merger, Scanner |
| 4 | Deep Scan | Scanner sub-type filtre | 100 MB | — |
| 5 | Break the Firewall | F.I.R.E. sistemi | 120 MB | Repair Lab, Recoverer |
| 6 | Data Recovery | Recoverer + Repair Lab | 150 MB | Key Forge, Decryptor |
| 7 | Crack the Code | Key Forge + Decryptor | 150 MB | Encryptor |
| 8 | Secure Transfer | Encryptor + tag stacking | 120 MB | — |
| 9 | Master Pipeline | Throughput + Upgrade + Capstone | 200+150+100 MB | — |

Tutorial sonrası hedef: Network Bar %100 (tüm kaynakların tüm content'leri aktif kullanımda).

### Procedural Gig Generator (Tutorial Sonrası)

Tutorial bitince procedural gig generator devreye girer. Her zaman **3 aktif procedural gig** bulunur. Biri tamamlanınca yenisi üretilir.

**Zorluk Skalası:**

| İlerleme | Gereken Tag | Bulmaca |
|----------|------------|---------|
| Erken | Public (tag yok) | Sadece ayıkla ve teslim et |
| Orta-erken | Decrypted (tag 1) | Key Forge + Decryptor gerekli |
| Orta | Recovered (tag 2) | Repair Lab + Recoverer loop gerekli |
| Orta-geç | Decrypted·Encrypted (tag 5) | Decrypt + Encrypt zinciri |
| Geç | Recovered·Decrypted (tag 3) | Recover loop + Decrypt zinciri |

---

## 16. Uc Faz Yapisi

### Faz 1: Keşif ve Öğrenme (Tutorial)
- **Amaç:** Oyuncuya tüm araçları ve FIRE sistemini öğretmek
- **Gig tipi:** "X MB Y veri teslim et" (tek seferlik)
- **Sonuç:** Tüm binalar açılmış, oyuncu her aracı ve FIRE'ı biliyor

### Faz 2: Ağ Genişletme
- **Amaç:** Derin pipeline bulmacaları, kaynak bağımlılık zincirleri
- **Gig tipi:** Procedural — tag karmaşıklığı ve miktar ilerle artar
- **Özellik:** 3 simultane aktif gig, biri bitince yenisi üretilir
- **Oyuncu öğreniyor:** FIRE zincirleri, paralel Key Forge, feedback loop'lar, sub-type routing

### Faz 3: Persistent Network
- **Amaç:** Haritadaki sunucuları bağlayıp sürekli akışı sürdürmek
- **Kritik fark:** Gig tamamlanınca pipeline KALIR ve çalışmaya devam eder. Ağ sadece büyür.
- **Progress:** "NETWORK: X/Y (Z%)" göstergesi — bağlı kaynak / toplam kaynak oranı
- **Bağlı sayılma kuralı:** Bir kaynak "connected" sayılır ancak TÜM content tipleri ağda aktif kullanıldığında. Aktif kullanım = CT'ye teslim, F.I.R.E. besleme, Key/Kit üretiminde tüketim, veya Decryptor/Recoverer/Encryptor'da işleme. Trash'e yönlendirmek SAYMAZ.
- **F.I.R.E. regen:** Hard kaynaklarda sürekli throughput koruma = daimi mühendislik
- **Endgame:** Tüm veriler aynı anda akıyor, devasa cyber web

### Faz Geçişleri
- Faz 1 → 2: Tüm tutorial gig'ler tamamlandığında
- Faz 2 → 3: Procedural gig'ler ilerledğinde, ağ büyümeye başlar
- Faz 3 açık uçlu — oyuncu haritayı kaplayana kadar devam eder

---

## 17. Ilerleme Sistemi

### Bina Açılma Sıralaması

Binalar ilerlemeyle açılır. Bina maliyeti YOK — bulmaca zorluğu yeter.

**Not:** Açılma tetikleyicileri gig sisteminin yeniden tasarımıyla birlikte güncellenecek. Tahmini sıralama:

| Aşama | Açılan Binalar | Tetikleyici |
|-------|---------------|-------------|
| **Oyun Başı** | Trash, Splitter | — |
| **Erken** | Separator, Classifier | İlk extraction tamamlama |
| **Erken-Orta** | Merger | İlk filtreleme tamamlama |
| **Orta** | Repair Lab, Recoverer | İlk Glitched veri ile karşılaşma |
| **Orta** | Key Forge, Decryptor | İlk Encrypted veri ile karşılaşma |
| **Orta-Geç** | Encryptor | İlk re-encryption gereksinimiyle karşılaşma |
| **Geç** | Scanner | İlk sub-type spesifik FIRE gereksinimiyle karşılaşma |

### İlerleme Aşamaları

| Aşama | Oyuncu Deneyimi | His |
|-------|----------------|-----|
| **Çöpçü** | Easy kaynak, tek hat, Public veri | "Anladım, basit" |
| **Hacker** | İlk FIRE kırma, medium kaynağa erişim | "Hackledim!" |
| **Mühendis** | Decryptor + Key Forge, paralel Key hattı | "Bu gerçek bir fabrika" |
| **Tamirci** | Recoverer feedback loop, döngüsel devre | "Loop kurdum, veri temizleniyor!" |
| **Mimar** | Çoklu kaynak, FIRE zincirleri, tam ağ | "Devre kartıma bak!" |

---

## 18. Save Sistemi

### Çoklu Save Dosyası Desteği
- 5 save slot: slot_1.json — slot_5.json
- Her slot ayrıca otomatik kayıt: slot_N_auto.json
- "New Game" otomatik boş slot seçer
- "Load Game" slot listesi gösterir (tarih + silme butonu)
- Kaydedilen state: binalar, kablolar, gig ilerlemesi, procedural state, kaynak keşfedilmişliği, fog durumu, FIRE durumları

### Autosave
- 5 dakikada bir otomatik kayıt
- Gig tamamlandığında otomatik kayıt
- Autosave rotation: mevcut + yedek

---

## 19. Kisit ve Zorluk

### Felsefe: Shapez Modeli — Saf Otomasyon Bulmacası
Power, heat, combat, para birimi YOK. Challenge tamamen pipeline tasarımından gelir.

| Kısıt | Nasıl Çalışır | Oyuncu Kararı |
|-------|--------------|---------------|
| **Kablo routing** | Kablolar grid'de yer kaplar | "Bu hattı nereye çekeyim?" |
| **FIRE güvenliği** | Medium+ kaynaklar korumalı | "Hangi kaynağı önce hacklemeliyim?" |
| **Content çeşitliliği** | Zor kaynaklar 3-4+ content | "Kaç Classifier zincirlersem?" |
| **Sub-type spesifisitesi** | FIRE ve geç oyun tarifleri spesifik sub-type ister | "Bu sub-type hangi kaynakta?" |
| **Bit-depth** | Yüksek bit-depth = yavaş Key üretimi | "Kaç paralel Key Forge lazım?" |
| **Glitch severity** | Düşük recovery oranı = çok döngü | "Loop'um yeterli throughput üretiyor mu?" |
| **Kit tüketimi** | Her recovery denemesi Kit yer | "Repair Lab hattım yeterli mi?" |
| **Bileşik state** | Enc·Glitch için işlem sırası kararı | "Önce Decrypt mi Recover mi?" |
| **Tier escalation** | Bileşik state'de bir taraf çözülünce diğer +1 | "Hangi yol daha verimli?" |
| **Layout planlaması** | Paralel hatlar + loop'lar = alan tüketimi | "Fabrikam haritaya sığıyor mu?" |
| **FIRE regen throughput** | Hard kaynaklarda sürekli besleme | "Throughput'm yeterli mi?" |

### Zorluk Kaynakları (Dört Eksen)

```
EKSEN 1: FIRE KARMAŞIKLIĞI
  Erken: FIRE yok — direkt bağlan
  Geç:   3-katmanlı bağımlılık zinciri + regenerating FIRE

EKSEN 2: KAYNAK KARMAŞIKLIĞI
  Easy:  1 content, Public, FIRE yok
  Hard:  4 content, 16-bit Encrypted + Major Glitch + Enc·Glitch, regenerating FIRE

EKSEN 3: İŞLEME KARMAŞIKLIĞI
  Erken: "Public veri teslim et"
  Geç:   Paralel Key Forge + feedback loop + re-encryption zinciri

EKSEN 4: LAYOUT KARMAŞIKLIĞI
  Erken: Tek kaynak, kısa hat
  Geç:   10+ kaynak, FIRE besleme hatları, paralel fabrikalar, loop'lar
```

---

## 20. Gorsel Tasarim Detaylari

### Sanat Stili: Prosedürel + Shader
Her şey kodla çizilir + shader efektleri. Procedural-first sanat yönü.

### Renk Paleti ("Dark PCB")

```
Arka plan:     #060a10 (koyu siyah)
Grid:          Neon cyberpunk red (PCB estetiği)
Bina gövde:    #0a0d14
Kablo:         #aabbcc (gümüş-beyaz, nötral)
UI Accent:     #00bbee (teal-cyan)

State Renkleri:
  Public:      #00ffaa (neon yeşil)
  Encrypted:   #2288ff (neon mavi)
  Glitched:    #ffaa00 (neon turuncu)
  Enc·Glitch:  Yarı mavi, yarı turuncu (bölünmüş)
  Malware:     #ff1133 (neon kırmızı) — release

Content Renkleri:
  Standard:    #7788aa
  Financial:   #ffcc00
  Biometric:   #ff88cc
  Blueprint:   #00ffcc
  Research:    #9955ff
  Classified:  #ff3388
  Key:         #ffaa00
  Repair Kit:  #ff7744

Bina Accent Renkleri (12):
  Contract Terminal: Gold (1.0, 0.75, 0.0)
  Classifier:        Cyan (0.0, 0.82, 0.82)
  Separator:         Sky Blue (0.3, 0.65, 0.9)
  Scanner:           Violet (0.65, 0.4, 0.85)
  Decryptor:         Orange (0.95, 0.55, 0.15)
  Encryptor:         Deep Blue (0.2, 0.33, 0.95)
  Recoverer:         Yellow-Green (0.55, 0.85, 0.25)
  Key Forge:         Emerald (0.18, 0.83, 0.35)
  Repair Lab:        Teal (0.25, 0.78, 0.6)
  Splitter:          Slate Blue (0.5, 0.58, 0.72)
  Merger:            Steel Blue (0.58, 0.63, 0.7)
  Trash:             Red (0.87, 0.27, 0.2)
```

### Active/Idle Kontrast
- **Idle:** accent.lerp(gray, 0.3), pulse ×0.5 — sonuk, hareketsiz
- **Active:** Tam accent rengi, pulse ×4.0 — parlak, canlı

### Shader Efektleri
- **Bloom:** Kablo ve binalarda neon parlama
- **CRT:** Hafif tarama çizgileri + kromatik sapma
- **Vignette:** Ekran kenarlarında kararma
- **Glow outline:** Bina kenarlarında renk kodlu titreşim

### Ses Tasarımı

**Ambient Katmanı:** Düşük frekanslı dijital hum, aktif kablo sayısına göre yoğunluk artar.

**Bina Sesleri (her bina benzersiz):**
- Classifier/Separator/Scanner: routing "tik-tak"
- Decryptor: dijital "crack" efekti
- Recoverer: tarama/onarma döngüsel sesi (loop hissi)
- Encryptor: şifreleme sesi
- Key Forge: araştırma hum'ı
- Repair Lab: üretim sesi
- Trash: imha sesi

**UI Sesleri:**
- Kablo döşeme: tatmin edici "snap"
- Bina yerleştirme: sağlam "placement"
- Gig tamamlama: 5-nota başarı arpejio
- Yeni bina açılma: kilit açma sesi + shake
- FIRE breach: güvenlik duvarı kırılma sesi

---

## 21. Referans Oyunlar

| Oyun | Ne Alıyoruz | Ne Almıyoruz |
|------|------------|-------------|
| **Shapez** | Hub teslimat, bedava binalar, kademeli bulmaca, chill, throughput challenge | Şekil-spesifik mekanikler |
| **Factorio** | Grid routing, mekansal bulmaca, paralel üretim hatları | Savaş, kirlilik, devasa kapsam |
| **Satisfactory** | Çoklu girdili binalar, kaynak→işleme döngüsü | 3D, büyük kapsam |
| **Mindustry** | Harita kaynaklar, çıkarım | Kule savunma |
| **Hacknet** | Cyberpunk estetik, terminal hissi | Tekrarcı oynayış |

### Kritik Dersler
- **Shapez'den:** Bina maliyeti yok, bulmaca yeter. Hub merkezi teslimat. Operasyonlar basit, kombinasyonlar zor. Throughput challenge = geç oyun derinliği.
- **Factorio'dan:** Grid routing = oyun. Layout planlaması ana bulmaca. Paralel hatlar = doğal ölçekleme.
- **Satisfactory'den:** Çoklu girdili tarifler en iyi lojistik bulmacaları yaratır.
- **Kontrol Sistemleri'nden:** Feedback loop = benzersiz mekanik. Hiçbir otomasyon oyununda yok.

---

## 22. Pazar Stratejisi

### Hedef
- **Fiyat:** $9.99
- **Satış hedefi:** 100K+
- **Platform:** Steam
- **Çıkış:** Steam Next Fest demo sonrası

### Hook + Anchor
- **Hook:** "Siberuzayda güvenlik duvarlarını kır, parlayan devre kartı fabrikaları tasarla"
- **Anchor:** "Shapez'in chill bulmacaları + Factorio'nun grid routing'i + cyberpunk hacking fantezisi"

### Benzersiz Satış Noktaları
- **FIRE sistemi:** Kaynakları hackleyerek erişim kazanma — hiçbir otomasyon oyununda yok
- **Feedback loop recovery:** Kontrol sistemlerinden esinlenen döngüsel veri onarımı — benzersiz
- **Ters Shapez:** Karmaşık → basit arıtma (herkes basit → karmaşık yapıyor)
- **Devre kartı estetiği:** Screenshot-worthy görsel kimlik

### Steam Next Fest Stratejisi (Haziran 2026)
- Demo: Tutorial + procedural gig generator
- Easy + Medium + Hard kaynaklar (FIRE sistemini gösterir)
- 4-6 saatlik demo deneyimi
- Screenshot'lar etkileyici olmalı (devre kartı estetiği = satış noktası)
- Persistent network teaser (bağlı kaynak göstergesi)

---

## 23. Kapsam ve Yol Haritasi

### Demo Kapsamı (Next Fest) — 4-6 saat
- Grid kablo routing (dik kesişim serbest) + kablo kapasitesi limiti
- 12 bina: Classifier, Separator, Scanner, Recoverer, Decryptor, Encryptor, Key Forge, Repair Lab, Splitter, Merger, Trash + Contract Terminal
- Easy (1-2 port) + Medium (3-4 port) + Hard (5-6 port) kaynaklar
- 6 content × 4 sub-type = 24 sub-type
- 3+1 state: Public, Encrypted (4-bit, 16-bit), Glitched (Minor, Major), Enc·Glitch
- FIRE sistemi (sabit eşik + regenerating)
- Feedback loop recovery + Key başarı oranı
- Throughput sistemi (filtre variety, işleme hızı/olasılık, üretim hızı)
- 4 upgrade kategorisi (Routing, Decryption, Recovery, Bandwidth)
- Tutorial + procedural gig generator
- Persistent network göstergesi + network throughput metriği
- Çoklu save (5 slot)
- Tam görsel işlem (devre kartı estetiği)
- Malware YOK (tam oyuna sakla)

### Tam Oyun Kapsamı
- 13 bina (+ Malware Cleaner)
- ~25-35 kaynak/harita
- Ek zorluk kademeleri: Hard+, Hard++ veya Medium+ gibi ara seviyeler eklenebilir
- 4+1 state: + Malware + Enc·Mal, Glitch·Mal, Enc·Glitch·Mal
- Tam bit-depth sistemi (4/16/32-bit)
- Tam glitch severity (Minor/Major/Critical)
- Upgrade Tier 8+ sınırsız devam (TB+ ölçek)
- Procedural gig sistemi sınırsız
- Endgame: Malware pipeline bulmacaları + 32-bit + Critical Glitch

### Lansman Sonrası Potansiyel
- Yeni content tipleri ve sub-type'lar
- Yeni bina tipleri
- Topluluk challenge'ları
- Trace/hostile AI katmanı

---

## 24. Kesinlesmis Kararlar

| Karar | Durum |
|-------|-------|
| "Ters Shapez" oyun kimliği | **Kesin** |
| Compiler kaldırıldı | **Kesin** |
| Uplink kaldırıldı (kaynaklar direkt output) | **Kesin** |
| Bridge kaldırıldı (dik kesişim serbest) | **Kesin** |
| Research Lab → Key Forge yeniden adlandırıldı | **Kesin** |
| Repair Lab binası (Repair Kit üretir) | **Kesin** |
| Scanner binası (sub-type binary filtre) | **Kesin** |
| Corrupted → Glitched yeniden adlandırıldı | **Kesin** |
| Encrypted tier → bit-depth (4-bit/16-bit/32-bit) | **Kesin** |
| Glitched severity (Minor/Major/Critical) | **Kesin** |
| Encrypted = genişlik bulmacası (paralel Key Forge) | **Kesin** |
| Glitched = derinlik bulmacası (feedback loop) | **Kesin** |
| Recoverer: kısmi recovery + feedback loop | **Kesin** |
| Repair Kit: her deneme tüketir (başarılı/başarısız) | **Kesin** |
| FIRE sistemi (Forced Isolation & Restriction Enforcer) | **Kesin** |
| FIRE: Easy=yok, Medium=sabit eşik, Hard=regenerating | **Kesin** |
| FIRE kapandığında veri akışı anında kesilir | **Kesin** |
| Kaynak bağımlılık zinciri (Easy→Medium→Hard) FIRE ile birleşik | **Kesin** |
| Content sub-type'ları (6 content × 4 sub-type) | **Kesin** |
| Sub-type hibrit relevance (erken duyarsız, geç duyarlı) | **Kesin** |
| Üç katmanlı filtre (Separator/Classifier/Scanner) | **Kesin** |
| Bileşik state: Enc·Glitch (demo'da var) | **Kesin** |
| Tier escalation (çözünce +1) | **Kesin** |
| 3 faz yapısı (Tutorial → Procedural → Network) | **Kesin** |
| Persistent network (pipeline kalır) | **Kesin** |
| Procedural gig generator (tutorial sonrası) | **Kesin** |
| Malware → sadece full release | **Kesin** |
| Çoklu save dosyası (5 slot) | **Kesin** |
| Bina maliyeti YOK | **Kesin** |
| Bina rotasyonu (R tuşu, 4 yön) | **Kesin** |
| CT dinamik boyut (Level 1: 2×2 → Level 9: 10×10), port = 4×(size-1) | **Kesin** |
| Throughput: filtre hızı = base/variety | **Kesin** |
| Throughput: işleme hızı bit-depth/severity'ye göre yavaşlar | **Kesin** |
| Throughput: Key başarı oranı (4-bit %80, 16-bit %40, 32-bit %20) | **Kesin** |
| Throughput: Splitter/Merger anlık, kendi hızı yok | **Kesin** |
| Kablo kapasitesi limiti (Bandwidth upgrade ile ölçeklenir) | **Kesin** |
| Veri çekme hızı global, kaynak bazlı değil (tüm portlar eşit) | **Kesin** |
| Kaynak port sayısı zorluğa göre (Easy 1-2, Medium 3-4, Hard 5-6, Endgame 7-8) | **Kesin** |
| FIRE regen hızı output/upgrade'den bağımsız, sabit tuned değer | **Kesin** |
| 4 upgrade kategorisi (Routing, Decryption, Recovery, Bandwidth) | **Kesin** |
| Upgrade kaynağı = CT'ye teslim edilen veri (Shapez modeli, ayrı currency yok) | **Kesin** |
| Upgrade başarı oranlarını da iyileştirir (qualitative değişim) | **Kesin** |

### Reddedilen Fikirler
- ~~Compiler binası~~ → Ters Shapez felsefesi, arıtıyoruz
- ~~Packet sistemi~~ → Birleştirme modeline uymuyor
- ~~Uplink binası~~ → Kaynaklar direkt output portlu
- ~~Bridge binası~~ → Dik kesişim serbest
- ~~Yakıt-eşleşme Recoverer~~ → Feedback loop + Repair Kit
- ~~Deterministik Recoverer~~ → Kısmi recovery + feedback loop (daha ilginç)
- ~~Credits/para birimi~~ → Bina maliyeti yok
- ~~Storage binası~~ → Veri sürekli akar
- ~~Quarantine~~ → Trash (basit çöp)
- ~~Residue (yan ürün)~~ → Yan ürün yok
- ~~Tech Tree~~ → İlerleme ile bina açma
- ~~Power/Heat sistemi~~ → Saf otomasyon
- ~~Ring/halka harita~~ → FIRE bağımlılık zinciri ile doğal ilerleme
- ~~Karışım tipleri (Bond/Fused)~~ → Basit Classifier yeter
- ~~Stabilizer~~ → Gereksiz
- ~~Depolama maliyeti~~ → Tüm veriler eşit 1x
- ~~ICE terimi~~ → FIRE (Forced Isolation & Restriction Enforcer) — özgün terim
- ~~Per-bina upgrade~~ → Global upgrade kategorileri (Shapez modeli)
- ~~Kaynak bazlı farklı hızlar~~ → Global çekme hızı, port sayısı ile fark
- ~~Sınırsız kablo kapasitesi~~ → Kablo bandwidth limiti + paralel kablo çözümü
- ~~Deterministik Decryptor~~ → Olasılıksal Key başarı oranı

---

## 25. Acik Sorular

### Tasarlanacak
- [ ] **Gig sistemi yeniden tasarımı:** Soft-guide yaklaşımı, sandbox'ı kısıtlamayan yönlendirme
- [ ] **Tutorial gig'leri yeniden yazma:** FIRE, Scanner, feedback loop, upgrade öğretim sırası
- [ ] **Bina açılma tetikleyicileri:** Gig-based mi, ilerleme-based mi?
- [ ] **Throughput kesin değerleri:** base_speed, upgrade çarpanları, Key/Recovery oranları (playtest)
- [ ] **Kablo kapasitesi kesin değerleri** (playtest)
- [ ] **FIRE regen kesin değerleri** (playtest)
- [ ] Malware Cleaner bina detayları (full release)
- [ ] Full release zorluk kademeleri (Hard+, Medium+ gibi ara seviyeler)
- [ ] Demo denge ince ayarı (playtest ile doğrulanacak)
- [ ] Faz geçiş tetikleyicileri (tam kriterler)

### Doğrulanmış (Kodda Implement Edilmiş — v4 bazlı, v5 güncellemesi bekliyor)
- [x] Grid kablo routing + dik kesişim serbest
- [x] Gig sistemi = core loop (yeniden tasarlanacak)
- [x] Contract Terminal dinamik boyut (level'a göre), merkezde sabit
- [x] Bina maliyeti YOK
- [x] Key Forge (eski Research Lab) + tier tarifleri (→ bit-depth'e güncellenecek)
- [x] Repair Lab + tier tarifleri
- [x] Recoverer (→ feedback loop'a güncellenecek)
- [x] Bileşik state (Enc·Cor → Enc·Glitch'e güncellenecek)
- [x] Tier escalation (+1 kalan state)
- [x] Procedural gig generator (3 simultane)
- [x] Persistent network göstergesi
- [x] Çoklu save (5 slot)
- [x] Bina rotasyonu (R tuşu, 4 yön)

### Yeni Implement Edilecekler (v5)
- [ ] FIRE sistemi (kaynak güvenlik duvarı + bağımlılık zinciri)
- [ ] Scanner binası (sub-type filtre)
- [ ] Content sub-type'ları (6×4 = 24)
- [ ] Recoverer feedback loop (kısmi recovery + Separator döngü)
- [ ] Encrypted bit-depth (4/16/32-bit) + Key Forge hız farkı + Key başarı oranı
- [ ] Glitched severity (Minor/Major/Critical) + recovery oranları
- [ ] Corrupted → Glitched yeniden adlandırma (tüm kodda)
- [ ] FIRE görsel gösterimi (kaynak üzerinde durum göstergesi)
- [ ] Throughput sistemi (filtre variety, işleme hızı, kablo kapasitesi)
- [ ] Upgrade sistemi (4 kategori, CT'ye teslim = upgrade kaynağı)
- [ ] Kaynak port sayıları (zorluk bazlı)
- [ ] Upgrade UI (CT paneli)

---

*Bu doküman canlıdır ve her tasarım oturumunda güncellenecektir.*
*Versiyon 5.1 — Throughput + Upgrade sistemi eklendi: filtre variety hızı, işleme olasılık sistemi (Key başarı oranı + Recovery oranı), kablo kapasitesi limiti, global veri çekme hızı (port bazlı), 4 upgrade kategorisi (Routing/Decryption/Recovery/Bandwidth), Shapez modeli upgrade (CT'ye teslim = kaynak). Full release için ara zorluk kademeleri notu eklendi.*
