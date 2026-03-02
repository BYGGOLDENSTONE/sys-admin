# SYS_ADMIN - Game Design Document
**Versiyon:** 0.4 (Tasarım Aşaması)
**Son Güncelleme:** 2026-03-02
**Motor:** Godot 4.6 (Forward Plus, Jolt Physics, D3D12)
**Durum:** Tasarım tamamlanıyor, vertical slice planlanıyor

---

## İÇİNDEKİLER
1. [Oyun Özeti](#1-oyun-özeti)
2. [Tasarım Sütunları](#2-tasarım-sütunları)
3. [Teknik Kararlar](#3-teknik-kararlar)
4. [Çekirdek Döngü](#4-çekirdek-döngü)
5. [Kaynak Sistemi](#5-kaynak-sistemi)
6. [Veri Tipleri ve Tier Sistemi](#6-veri-tipleri-ve-tier-sistemi)
7. [Veri İşleme Zinciri](#7-veri-i̇şleme-zinciri)
8. [Yapı/Bileşen Listesi](#8-yapıbileşen-listesi)
9. [Bağlantı Sistemi](#9-bağlantı-sistemi)
10. [Power ve Heat Sistemi](#10-power-ve-heat-sistemi)
11. [İlerleme ve Scale](#11-i̇lerleme-ve-scale)
12. [Görsel Tasarım](#12-görsel-tasarım)
13. [Pazar Araştırması](#13-pazar-araştırması)
14. [Referans Oyunlar](#14-referans-oyunlar)
15. [Gelecek Güncellemeler](#15-gelecek-güncellemeler)
16. [Açık Sorular ve Yapılacaklar](#16-açık-sorular-ve-yapılacaklar)

---

## 1. Oyun Özeti

**SYS_ADMIN**, oyuncunun bir **netrunner** olarak dijital bir sistemi yönettiği 2D top-down chill otomasyon/management oyunudur.

**Temel Konsept:**
- Oyuncu bir netrunner'ın rig'ini kurar ve yönetir
- Ağdan veri çeker, işler, dönüştürür ve satar
- Sistemin ısınmasını, enerji ihtiyacını ve iz bırakma riskini dengeler
- Verimli pipeline'lar kurarak giderek daha değerli veriler işler

**Tür:** Chill Otomasyon/Management
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner
**Hedef:** Rehberli Sandbox - kazanma koşulu yok, oyuncu sürekli yönetir ve optimize eder

**Tek Cümle:** "Bir netrunner olarak dijital sisteminizi kurun, veri akışlarını yönetin ve en verimli pipeline'ı tasarlayın."

---

## 2. Tasarım Sütunları

### Sütun 1: Oyuncunun Kendini Akıllı ve Yetkin Hissetmesi
- Oyuncu kararlarının sonuçlarını görmeli
- Verimli bir sistem kurmak tatmin edici hissetmeli
- Override gibi risk/ödül mekanikleri ile "akıllı hamle" anları yaratılmalı
- Erken oyunda "çöp" olan kaynakların ilerledikçe değerli hale gelmesi eureka anları yaratır

### Sütun 2: Sandbox - Kendi Çözümlerini Optimize Etsin
- Tek doğru çözüm yok, oyuncu kendi pipeline'ını tasarlıyor
- Aynı soruna farklı yaklaşımlar mümkün
- "Rehberli sandbox" - teknoloji ağacı/açılma sistemi yön verir ama oyuncuyu zorlamaz
- Factorio'nun "The Factory Must Grow" → bizde "The System Must Scale"

### Sütun 3: Sistemsel Baskı (Savaş Değil, Denge)
- Artan veri hacmi mevcut sistemi yetersiz bırakır
- Heat birikimi yapılara hasar verir
- Trace birikimi kaynak erişimini kısıtlar
- Tier atlama anlarında pipeline yeniden tasarlanmalı
- Oyuncu kendi sistemine karşı mücadele eder, düşmana karşı değil

### Sütun 4: Diegetic Aesthetic (Dünya İle Bütünleşik Estetik)
- Her görsel eleman oyun dünyasına ait hissettirmeli
- Basit şekiller + shader efektleri ile "pahalı" görünüm
- CRT shader, bloom, glitch efektleri dünyayı güçlendirir
- Zukowski: "Grafikleriniz son teknoloji olmak zorunda değil ama niyetiniz net olmalı"

---

## 3. Teknik Kararlar

| Karar | Seçim | Gerekçe |
|-------|-------|---------|
| **Perspektif** | 2D Top-Down | Solo geliştirici için hız, otomasyon türünde kanıtlanmış (Factorio %97, Shapez %96) |
| **Asset Pipeline** | Prosedürel şekiller + shader efektleri | Minimum asset ihtiyacı, kod ile üretim |
| **Zaman Mekaniği** | Real-time with pause | Otomasyon kurma = düşünme zamanı. Hız kontrolü: 1x, 2x, 3x + duraklat |
| **İlerleme** | Rehberli Sandbox | Teknoloji ağacı yön verir ama oyuncuyu zorlamaz. Kazanma yok, sadece yönet |
| **İsimlendirme** | Cyberpunk terimleri | Uplink, Decryptor gibi tematik isimler. Tooltip ile gerçek karşılığı açıklanır |
| **Motor** | Godot 4.6 | Forward Plus renderer, Jolt Physics, D3D12 |

---

## 4. Çekirdek Döngü

### Ana Metafor: "Tabak Çevirme" (Plate Spinning)
Oyuncu aynı anda birden fazla sistemi dengede tutuyor. Bir şeyi düzeltmek başka bir ihtiyacı ortaya çıkarıyor.

### Dakika Dakika Akış
```
[VERİ GELİR] → Uplink ile ağdan veri çekilir
      ↓
[AYIR] → Separator ile veri tiplerine ayrılır
      ↓
[DEPOLA] → Storage'da tamponlanır
      ↓
[İŞLE] → Her veri tipi kendi process hattından geçer
      ↓
[SONUÇ] → Credits, Research, Patch Data veya Malware bertarafı
      ↓
[GENİŞLE] → Yeni yapılar al, sistemi büyüt
      ↓
[BASKI] → Heat yükseldi, Trace arttı, Storage doldu
      ↓
[OPTİMİZE] → Pipeline'ı iyileştir, dengeyi kur
      ↓
[TEKRAR] → ...döngü, artan karmaşıklıkla
```

### Temel Gerilim
**"Büyümek ZORUNDASIN ama büyümek yeni sorunlar yaratır."**
- Daha fazla veri = daha fazla gelir AMA daha fazla Power/Heat/Trace
- Daha büyük sistem = daha fazla kapasite AMA daha fazla ısı yönetimi
- Daha hızlı işleme = daha verimli AMA daha fazla ısı ve iz

### Oyun Temposu
Chill otomasyon oyunu — oyuncu kendi hızında ilerler. Baskı düşmandan değil, sistemin kendi dinamiklerinden gelir:
- Storage doluyor → pipeline tıkanır
- Heat birikir → yapılar yavaşlar/hasar alır
- Trace yükselir → kaynak erişimi kısıtlanır
- Power yetmiyor → yapılar durur

Bunlar acil krizler değil, yavaş yavaş biriken ve çözüm gerektiren durumlar.

### "Bir Şey Daha" Faktörü (Bağımlılık Döngüsü)
> "Storage dolmak üzere, bir tane daha koyayım... ama Power yetmiyor, Power Cell ekleyeyim... hmm Heat çok yükseldi, Coolant lazım... oh Trace yüksek, kaynak değiştireyim... tamam şimdi Storage'a döneyim..."

---

## 5. Kaynak Sistemi

### Temel Kaynaklar

| Kaynak | Tipi | Rol |
|--------|------|-----|
| **Clean Data** | Ana kaynak | **Ana gelir kaynağı.** Ne kadar saf, o kadar değerli. Credits'e dönüşür |
| **Corrupted Data** | Dönüştürülebilir | Başta waste (???). Recover edilince **Patch Data** → mevcut yapıları geliştirme kaynağı |
| **Encrypted Data** | Dönüştürülebilir | Başta waste (???). Decrypt edilince **Research** → yeni yapı tipi açma kaynağı |
| **Malware Data** | Tehlike | En son keşfedilen (???). Filtrelenmezse yapılara hasar verir. Karantina ile bertaraf |
| **Power** | Altyapı | Her yapı tüketir. Override ile artırılabilir (risk/ödül). Yetersizse sistem durur |
| **Heat** | Kötü birikim | Her çalışan yapı üretir. Soğutulmazsa yapılar yavaşlar → hasar alır → bozulur |
| **Trace** | Kötü birikim | Uplink, decrypt, recover artırır. Yükselince kaynak erişimi kısıtlanır |
| **Credits** | Para birimi | Clean Data satışından kazanılır. Yeni yapı satın almak için kullanılır |

### Her Veri Tipinin Kendine Özgü Amacı

| Veri Tipi | Çıktı | Oyundaki Rolü |
|-----------|-------|---------------|
| **Clean Data** | Credits | Yeni yapı **satın al** (ana gelir) |
| **Encrypted Data** | Research | Yeni yapı tipi **aç** |
| **Corrupted Data** | Patch Data | Mevcut yapıları **geliştir** (upgrade kaynağı) |
| **Malware** | — | Bertaraf et (yoksa sisteme hasar verir) |

**Kritik tasarım:** Her veri tipinin gideceği yer belli. Oyuncu "hangisini satsam" ikileminde kalmıyor. Clean = para, Encrypted = araştırma, Corrupted = upgrade, Malware = tehlike.

### Kaynak Etkileşimleri
```
Daha çok Uplink       → Daha çok veri AMA daha çok Power + Heat + Trace
Override kullan        → Daha hızlı AMA daha çok Heat
Decrypt/Recover        → Değerli çıktı AMA Trace ↑↑
Malware filtrele       → Güvenli AMA işleme kapasitesi harcanır
Trace yükselirse       → Kaynak erişimi kısıtlanır / kesilir
```

### İki Kötü Kaynak: Heat ve Trace
- **Heat** = Fiziksel tehdit → Çok birikirse yapılar yavaşlar → hasar alır → bozulur
- **Trace** = Tespit riski → Çok birikirse kaynak erişimi kısıtlanır → kesilir

### Trace Tespit Sistemi
Trace saldırı dalgası tetiklemez (savunma yok). Bunun yerine **kaynak erişimini etkiler:**
```
Trace düşük:     Tüm kaynaklara rahat erişim
Trace orta:      Yüksek tier kaynaklar fark etti → bağlantı yavaşlar
Trace yüksek:    Corporate/Military erişim kesildi → düşük kaynaklara geçmek zorunlu
Trace kritik:    Tüm kaynaklar kilitlendi → Trace düşene kadar bekle
```
Trace zamanla doğal olarak düşer, ama aktif işlem yapıldıkça artar.

### Power Override Mekaniği
Oyuncu her yapıya ne kadar güç vereceğini seçebilir:
```
Düşük güç ──── Normal ──── Override
Yavaş          Standart     Hızlı
Az heat        Normal heat  Çok heat
Verimli        Dengeli      Riskli
```

---

## 6. Veri Tipleri ve Tier Sistemi

### 4 Temel Veri Tipi
1. **Clean Data** (Temiz Veri) - Yeşil — Ana gelir kaynağı (Credits)
2. **Corrupted Data** (Bozuk Veri) - Sarı — Upgrade kaynağı (Patch Data)
3. **Encrypted Data** (Şifreli Veri) - Mor — Araştırma kaynağı (Research)
4. **Malware Data** (Zararlı Veri) - Kırmızı — Tehlike, bertaraf edilmeli

### Bilinmeyen Veri Tipleri (Keşif Sistemi)
Oyuncu başta sadece Clean data'yı tanıyor. Diğerleri "???" olarak görünür:
```
ERKEN OYUN:                    ORTA OYUN:                    GEÇ OYUN:
  Clean:     30%                 Clean:     30%                Clean:     30%
  ???:       25%                 Encrypted: 25%  ← keşfedildi Encrypted: 25%
  ???:       25%                 Corrupted: 25%  ← keşfedildi Corrupted: 25%
  ???:       20%                 ???:       20%                Malware:   20%  ← keşfedildi
```
Her yeni process yapısı bir veri tipini keşfettirir. "Meğer bu da varmış!" eureka anları yaratır.

### Tier Çeşitleri (Content Derinliği)
Her veri tipinin tier'ı sadece "daha fazla bina koy" değil, **farklı process yolu** da gerektirebilir:

**Encrypted Tier Çeşitleri:**
```
4-bit şifreleme   → 1 Decryptor, standart yöntem
16-bit şifreleme  → 4 Decryptor paralel (Splitter → Merger)
256-bit şifreleme → 16 Decryptor + farklı çözme algoritması (yeni yapı?)
Kuantum şifreleme → Tamamen farklı process hattı
```

**Corrupted Tier Çeşitleri:**
```
%10 bozuk  → 1 Recoverer, hızlı düzeltme
%30 bozuk  → Birden fazla Recoverer, birden fazla geçiş
%60 bozuk  → Önce parçala, sonra ayrı ayrı kurtar, sonra birleştir
%90 bozuk  → Neredeyse tamamen yeniden yapılandır (özel yapı?)
```

**Malware Tier Çeşitleri:**
```
Worm       → Hızlı karantina lazım, yayılır
Trojan     → Gizlenir, önce tespit lazım
Ransomware → Verileri kilitler, acil müdahale
Rootkit    → Sisteme gömülür, katmanlı temizlik
```

### Veri Kombinasyonları (Geç Oyun Content)
Geç oyunda veriler tek tip değil, **karışım** olarak gelir. Her kombinasyon farklı process sırası gerektirir:
```
"16-bit Encrypted + %30 Corrupted":
  Yol A: Decrypt → Recover (hızlı ama verimlilik düşük ~%70)
  Yol B: Recover → Decrypt (yavaş ama verimlilik yüksek ~%90)
```
**Process sıralaması = optimizasyon puzzle'ı.** Oyuncu her karışım için en verimli sırayı bulmaya çalışır.

4 veri tipi × 4 tier × kombinasyonlar = çok geniş content havuzu.

### Saflık / Verimlilik Sistemi
Separator mükemmel ayırmaz. Başta ~%60 verimlilik:
```
100 GB ham veri (gerçek: 30 Clean + 70 diğer)
  → Separator (%60 verimlilik)
  → Çıktı: ~18 GB saf clean + ~12 GB hâlâ karışık
```
Oyuncu saflığı artırmak için:
- Aynı veriyi **birden fazla kez** separator'dan geçirir (zaman + enerji maliyeti)
- Veya separator'ı Patch Data ile geliştirir (upgrade)
- **Karar:** "Tekrar mı işleyeyim yoksa upgrade mı yapayım?"

### Sıkıştırma (Compression) Sistemi
Storage'a koymadan önce veri sıkıştırılır:
```
100 GB ham veri → [Compressor T1] → 75 GB (başlangıç)
100 GB ham veri → [Compressor T2] → 50 GB (orta oyun)
100 GB ham veri → [Compressor T3] → 30 GB (geç oyun)
```
- Sıkıştırılmış veri daha az güç + ısı tüketir storage'da
- Kötü sıkıştırma değerli veriyi de kaybettirir
- Veri hacmi oyun ilerledikçe 100GB'den TB/PB'lara çıkar, sıkıştırma zorunlu hale gelir

### Tier Sistemi: Yeni Bina Değil, Daha Fazla Bina
Factorio mantığı: "Tier 2 fırın" yok, daha fazla fırın koyarsın. Bizde de:
```
Tier 1 (4-bit şifreleme):
  → 1 Decryptor yeterli
  → Düşük Trace

Tier 2 (16-bit şifreleme):
  → 4 Decryptor paralel çalışır
  → Splitter ile veri dağıtılır, Merger ile birleştirilir
  → 4x Power, 4x Heat

Tier 3 (256-bit şifreleme):
  → 16 Decryptor + karmaşık routing
  → 16x Power, 16x Heat

Tier 4 (Kuantum şifreleme):
  → 64 Decryptor + yeni özel yapı gerektirebilir
  → Devasa altyapı
```

---

## 7. Veri İşleme Zinciri ve Oyuncu İlerlemesi

### Tasarım Prensibi
Oyuncu başta "çöpçü" gibi, ilerledikçe "sistem mimarı" oluyor. Aynı ham maddeden giderek daha fazla değer çıkarıyor. Her yeni process katmanı bir karar noktası ekliyor.

**İlerleme modeli:**
| Aşama | Oyuncu Ne Yapıyor | His |
|-------|-------------------|-----|
| Çöpçü | Ham veri toptan sat | "Çöpçüyüm" |
| Filtreleme | Veri tiplerini ayırmayı öğrenir | "Madenciyim" |
| Çok aşamalı işleme | Her tip kendi hattına | "Mühendisim" |
| Hat birleştirme | Karışık verileri çözer, özel siparişler | "Sistem mimarıyım" |

### Faz 1: Çöpçü (Başlangıç)
```
Uplink → 100GB ham veri
  → [Compressor T1] → 75GB (kötü sıkıştırma, veri kaybı var)
  → Storage (75 birim güç + ısı)
  → Toptan sat → ~30 Credits (sadece içindeki clean data değerli)
```
Oyuncu sadece veri çekip depoluyor ve toptan satıyor. Basit, öğretici.

### Faz 2: İlk Filtreleme (Corrupted Keşfi)
```
Separator açılır → Corrupted veri keşfedilir!
  Ham veri → [Separator %60] → ~18GB saf clean + karışık
  Clean → [Compressor] → Storage → Sat (daha verimli!)
  Corrupted → Storage'da bekler (henüz işe yaramıyor, Trace yayar)
```
- Corrupted ayıklanıyor ama henüz waste
- Temiz satış daha çok credits kazandırıyor
- **Oyuncu öğrenir:** Birden fazla separator geçişi = daha fazla verim ama daha fazla enerji
- İşlenemeyen veri storage'da Trace yayıyor

### Faz 3: Encrypted Keşfi (Araştırma Başlangıcı)
```
Decryptor açılır → Encrypted veri keşfedilir!
  Separator artık encrypted'ı da ayırır (%60 verimlilikle)
  → Decryptor → çözülmüş veri → Research Lab → Yeni yapı tipleri açılır!
```
- Research ile yeni yapılar açılmaya başlar
- **Eureka:** "Meğer bu verinin içinde bu kadar bilgi varmış!"

### Faz 3.5: İlk Tier Atlama
```
16-bit encrypted gelmeye başlar
  → 1 Decryptor yetmez → 4 tane paralel kur
  → Splitter → 4x Decryptor → Merger
```
- Oyuncu ilk kez birden fazla yapıyı birleştirerek bir sorunu çözer
- 4x Power, 4x Heat → Coolant ve Power yatırımı gerekir
- **His:** "Zordu ama çözdüm, zekiyim"

### Faz 4: Trace Baskısı
```
İşlenemeyen veri storage'da Trace yayıyor!
  → Trace birikim ████████ → Kaynak erişimi kısıtlanıyor!
  → Corporate bağlantısı kesildi → daha düşük kaynaklara geçmek zorunda
  → Trace düşürmenin yolu: işlenemeyen veriyi azaltmak
```
- Oyuncu anlar: "Bu birikmiş veriler sorun yaratıyor"
- Motivasyon: işlenemeyen veriyi çözmek için yeni yapılar araştır

### Faz 5: Corrupted Data Kurtarma (Upgrade Başlangıcı)
```
Research ile Recoverer açılır
  Storage'daki Corrupted → [Recoverer] → Patch Data
  Patch Data ile mevcut yapıları geliştir:
    → Separator %60 → %70 verimlilik
    → Decryptor hız artışı
    → Power Cell kapsama genişlemesi
```
- **Eureka:** "O çöp sandığım veri aslında yapılarımı geliştirmemi sağlıyormuş!"
- Trace düşer çünkü artık corrupted işlenebiliyor

### Faz 6: Malware Keşfi (En Son, En Tehlikeli)
```
Son "???" ortaya çıkar: MALWARE!
  → Oyuncu fark eder: "Bu ŞİMDİYE KADAR tüm verimde vardı
    ve ben bilmiyordum! O yüzden yapılarım sürekli hasar alıyordu!"
  → Quarantine ile güvenle bertaraf edilebilir
  → Diğer hatlar malware'den arınmış → verimlilik artar
```
- Geçmişteki rastgele hasar/yavaşlamaların sebebi açıklanıyor
- **Eureka anı:** Oyunun en büyük "aha!" momenti

### Faz 7: Scale ve Optimizasyon
```
Tüm veri tipleri açık, tüm process hatları kurulu
  → Daha yüksek tier kaynaklar (Deep Web, Corporate, Military)
  → Her kaynak farklı pipeline gerektirir
  → Tier atlama → üstel büyüme
```

### Geç Oyun: Yeniden Şifreleme Siparişleri
```
Müşteri siparişi: "256-bit şifreli temiz veri istiyorum"

Uplink → Separator → Clean → Compressor → Storage
                                             ↓
                                     [Encryptor] ← (yeni yapı, Decryptor'ın tersi)
                                             ↓
                                   "Encrypted Clean Package"
                                             ↓
                                        Data Broker → $$$$$ Premium Credits
```
- Mevcut pipeline'ı kullanıyor (yeni yapı sadece Encryptor)
- Daha uzun zincir = daha fazla ödül
- Farklı müşteriler farklı şifreleme seviyeleri ister
- "Veri madencisi"nden "veri broker'ı"na geçiş

### Geç Oyun: Karışık Veri Paketleri
İleri oyunda veriler tek tip değil, **karışım** olarak geliyor:
```
Erken oyun: Veri ya Clean ya Encrypted → tek process yeterli
Geç oyun:   "Corrupted-Encrypted paketi"
  → Önce corruption düzelt → sonra şifreyi çöz
  → Tek veri paketi birden fazla process hattından geçmek zorunda
```

### Tasarım Prensibi: Katmanlı Büyüme
```
BAŞLANGIÇ          → ORTA OYUN              → GEÇ OYUN
Tek hat, toptan    → Paralel hatlar,        → Hatlar birleşiyor,
sat                  tier büyümesi             özel siparişler

Yapılar basit      → Yapılar büyüyor        → Yapılar birleşiyor
1 iş = 1 bina       1 iş = N bina (tier)      N sistem = 1 yeni sistem

1 kaynak           → 3 kaynak               → 5 kaynak + siparişler
```

---

## 8. Yapı/Bileşen Listesi

### Yapı Listesi (13 Yapı + 1 Geç Oyun)

**Çıkarım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Uplink** | "Ağa bağlanıp veri indirir" | Ham veri çeker. Üzerinden kaynak seçilir (Web, Deep Web, Corporate, Military, Blackwall) |

**Uplink Veri Kaynakları:**
Uplink = makine, kaynak = ayar. Aynı yapı, farklı kaynağa bağlanır:
| Kaynak | İçerik | Özel Mekanik |
|--------|--------|-------------|
| Web Traffic | Çoğu clean, düşük tier, düşük hacim | Yok — güvenli, öğretici |
| Deep Web | Çok encrypted/corrupted, orta tier | Dalga halinde gelir (düzensiz akış) |
| Corporate Network | Ağır encrypted, yüksek tier | İzlenebilir — Trace hızlı artar |
| Military Channel | Encrypted + malware, çok yüksek tier | Yeniden şifreleme gerekir (Encryptor lazım) |
| Blackwall | Hibrit (corrupted+encrypted kombinasyonları) | Yapılara hasar verir (hostile veri) |

**Ayırma & Depolama:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Separator** | "Veriyi tiplerine ayırır" | Ham veriyi tanınan tiplere ayırır. Verimlilik %60 başlar, Patch Data ile geliştirilebilir |
| **Compressor** | "Veriyi sıkıştırır" | Storage'a koymadan önce boyutu küçültür → daha az güç/ısı. Tier'lı |
| **Storage** | "Veri depolar" | Her türlü veriyi depolar. İşlenemeyen veri Trace yayar. Dolarsa pipeline tıkanır |

**İşleme:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Decryptor** | "Şifreli veriyi çözer" | Encrypted data → Research. Çok Power, çok Heat, Trace ↑ |
| **Recoverer** | "Bozuk veriyi kurtarır" | Corrupted data → Patch Data (upgrade kaynağı). Çok güç + ısı |
| **Quarantine** | "Zararlı veriyi bertaraf eder" | Malware → güvenli imha. Malware bertaraf edilmezse yapılara hasar verir |

**Çıktı:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Data Broker** | "Temiz veriyi satar" | Clean Data → Credits. Ne kadar saf veri, o kadar çok kazanç |
| **Research Lab** | "Yeni teknoloji araştırır" | Research puanı (Encrypted'dan) → yeni yapı tipi açma |

**Altyapı:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Power Cell** | "Enerji üretir" | Bölgesindeki yapılara Power sağlar (zone-based) |
| **Coolant Rig** | "Isıyı düşürür" | Bölgesindeki yapıların Heat'ini azaltır (zone-based) |

**Dağıtım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Splitter** | "Akışı böler" | Tek hattı birden fazla hatta ayırır (1→N). Tier işleme için |
| **Merger** | "Akışları birleştirir" | Birden fazla hattı tek hatta toplar (N→1) |

**Geç Oyun:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Encryptor** | "Veriyi şifreler" | Clean Data → Encrypted paket. Premium sipariş sistemi için. Decryptor'ın tersi |

**Toplam: 13 temel + 1 geç oyun = 14 yapı**

### Güncellenmiş Akış Haritası
```
                    ┌──→ Compressor → Storage → Data Broker ────→ Credits
                    │                              (ana gelir)
                    │
Uplink → Separator ─┼──→ Storage → Decryptor ──→ Research Lab ──→ Unlock (yeni yapılar)
                    │
                    ├──→ Storage → Recoverer ──→ Patch Data (yapı geliştirme kaynağı)
                    │
                    └──→ Storage → Quarantine ──→ Güvenli imha
                            ↑
                        (Trace yayar!)

GEÇ OYUN:
Clean Data → ... → [Encryptor] → Premium paket → Data Broker → Premium Credits
```

### Patch Data Upgrade Sistemi
Patch Data ayrı bir yapıda harcanmaz. Doğrudan yapı üzerinde kullanılır:
- Oyuncu bir yapıyı seçer → "Geliştir" butonu → Patch Data harcanır
- Her yapının geliştirilebilir özellikleri var:
  - Separator: verimlilik %60 → %70 → %80 → %90
  - Decryptor: işleme hızı artışı
  - Compressor: sıkıştırma oranı artışı
  - Power Cell: kapsama alanı genişlemesi
  - Coolant Rig: soğutma etkinliği artışı
  - Storage: kapasite artışı
  - vs.

### Yapı Okunabilirliği (Görsel Ayırt Etme)
**3 Katmanlı sistem:**
1. **Siluet (uzaktan):** Her yapının grid boyutu ve oranı farklı
2. **Renk (orta mesafe):** Her kategori sabit renk
3. **Detay (yakından):** İkon, isim etiketi, durum barları

**Durum ile renk değişimi:**
```
Normal:  Standart renk, sakin animasyon
Yüklü:  Sarıya kayar, hızlı animasyon
Kritik:  Kırmızı, yanıp sönme
Bozuk:   Koyu gri, durgun
```

**Overlay/Heatmap modları:**
- [H] Isı haritası
- [E] Enerji haritası

---

## 9. Bağlantı Sistemi

### Doğrudan Link (Kablo) Sistemi
Factorio'nun konveyör bantları çok karmaşık, otomatik bağlantı çok basit. Biz ortasını kullanıyoruz:

**Nasıl çalışır:**
- Yapılar grid üzerine yerleştirilir
- Bir yapının çıkış portunu başka yapının giriş portuna bağlarsın (kablo çekersin)
- Veri bağlantı üzerinden anında akar (konveyör hızı yok)
- Tıkanıklık yapının işleme hızından kaynaklanır, kablodan değil
- Görsel: kablolar üzerinde renkli veri parçacıkları akar (0/1'ler)

**Neden bu sistem:**
- Konveyör bantları (Factorio) → çok karmaşık, başlı başına bir oyun
- Otomatik bağlantı → çok basit, lojistik kararı yok
- Doğrudan link → "neyi nereye bağlayayım" kararı var ama "bant hızı hesaplama" yok

**Splitter/Merger bu sistemde:**
```
Separator ──→ [Splitter] ──→ Decryptor 1 ──→ [Merger] ──→ Research Lab
                  ├──→ Decryptor 2 ──────────→ ↑
                  ├──→ Decryptor 3 ──────────→ ↑
                  └──→ Decryptor 4 ──────────→ ↑
```

---

## 10. Power ve Heat Sistemi

### Power: Bölgesel (Zone-Based)
```
Power Cell kapsama alanı:
    ┌─────────────┐
    │  ○ ○ ○ ○ ○  │
    │  ○ ○ ■ ○ ○  │  ■ = Power Cell
    │  ○ ○ ○ ○ ○  │  ○ = Kapsama alanı
    │  ○ ○ ○ ○ ○  │
    └─────────────┘
```
- Her Power Cell belirli bir alan besler (ör. 5x5 tile)
- O alandaki yapılar otomatik güç alır
- Power Cell'in kapasitesi var — çok yapı bağlarsan yetmez
- Aşırı yüklenme = ekstra Heat
- **Oyuncu kararı:** Yapıları nereye koyayım ki Power Cell kapsasın? Sıkıştırayım mı (ısı riski), dağıtayım mı (daha çok Power Cell)?

### Heat: Yapı Bazlı + Bölgesel Yayılma
- Her çalışan yapı Heat üretir (Override'da daha çok)
- Yakın yapılar birbirinin ısısını artırır (kümelenme riski)
- Coolant Rig belirli bir alanı soğutur (Power Cell gibi zone)
- Çok ısınan yapı: yavaşlar → hasar alır → bozulur
- **Oyuncu kararı:** Sıkıştırıp alan kazanmak mı, dağıtıp ısıyı kontrol etmek mi?

### Trace: Global Sayaç
- Trace bölgesel değil, global bir sayaç
- Artıran: Uplink çekimi, Decrypt/Recover işlemleri, Storage'daki işlenemeyen veri
- Zamanla doğal olarak düşer
- Eşiklere ulaşınca kaynak erişimi kısıtlanır (bkz. Bölüm 5: Trace Tespit Sistemi)

---

## 11. İlerleme ve Scale

### Rehberli Sandbox Modeli
- Shapez/Factorio referansı: oyunun kendisi sandbox, ama teknoloji ağacı yön veriyor
- Oyuncu kendi hızında ilerliyor ama hep bir "sonraki hedef" var
- Kazanma koşulu yok - sistem büyüdükçe talepler de büyüyor

### Scale Mekanikleri

**1. Veri Tier'ları (ana scale kaynağı):**
- Her tier öncekinin ~4 katı yapı gerektiriyor
- Tier 1 → Tier 4 arası üstel büyüme
- Oyun doğal olarak devasa base'ler yaratıyor

**2. Veri Kaynakları (Uplink Kaynakları):**
```
Web Traffic:      Düşük hacim, çoğu clean, güvenli
Deep Web:         Orta hacim, daha fazla encrypted/corrupted, dalga halinde
Corporate:        Yüksek hacim, ağır encrypted, Trace hızlı artar
Military:         Çok yüksek tier, encrypted + malware, Encryptor gerektirir
Blackwall:        Hibrit veri (kombinasyonlar), hostile, yapılara hasar verir
```
Her yeni kaynak farklı pipeline gerektirir.

**3. Trace Doğal Scale:**
- Büyüme → Trace ↑ → Kaynak erişimi kısıtlanır → Optimize et veya yavaşla
- Oyuncuyu dengede tutar

**4. Premium Siparişler (geç oyun):**
- Müşteriler belirli formatta veri ister
- Daha uzun pipeline = daha fazla kazanç
- Yeniden şifreleme sistemi

### Devasa Base Vizyonu (Geç Oyun)
```
┌──────────────────────────────────────────────────────┐
│ [UPLINK ÇİFTLİĞİ]                                    │
│  ■■■■■■■■■■■■                                        │
│     ↓                                                │
│ [SEPARATOR DİZİSİ]                                   │
│  ▣▣▣▣▣▣▣▣                                           │
│  ↓    ↓    ↓    ↓                                    │
│ [DEPO] [DEPO] [DEPO] [DEPO]                          │
│  ↓     ↓      ↓       ↓                             │
│ [DECRYPT DİZİSİ]  [RECOVER DİZİSİ]  [QUARANTINE]    │
│  ◆◆◆◆◆◆◆◆◆◆◆◆◆◆   ◇◇◇◇◇◇◇◇◇◇     ⬡⬡⬡⬡⬡⬡       │
│     ↓                  ↓                             │
│ [ÇIKTILAR]                                           │
│  Research Lab  ←── Decrypted Data                     │
│  Data Broker   ←── Clean Data                         │
│  Patch Data    ←── Recovered Data (yapılara harcanır) │
│                                                      │
│ [POWER GRID]  ████████████████  [COOLING] ◎◎◎◎◎◎◎◎◎ │
└──────────────────────────────────────────────────────┘
```

---

## 12. Görsel Tasarım

### Sanat Stili: Tamamen Prosedürel (Kod ile Üretim)
**Perspektif:** 2D Top-Down (izometrik değil)
**Yaklaşım:** Sıfır harici art asset. Her şey kod ile çizilir + shader efektleri.

**Neden bu yaklaşım:**
- Solo geliştirici, sanat yeteneği gerektirmiyor
- Cyberpunk/hacker estetiği zaten koyu arka plan + neon + minimal geometri
- Shader efektleri basit şekilleri profesyonel gösteriyor
- Görsel tutarlılık otomatik garanti (her şey aynı sistemle üretiliyor)
- Shapez referansı: renkli geometrik şekiller, sıfır geleneksel art, %96 Steam puanı

### Yapılar: Geometrik Şekiller + Glow
```
┌─────────┐
│ UPLINK  │  ← Koyu gri dikdörtgen, neon kenar parlaması
│  ◉───   │  ← İçinde basit ikon (kod ile çizilen çizgiler/şekiller)
│ ▓▓▓▓▓▓  │  ← Durum barı (doluluk, ısı vs.)
└─────────┘
   ↕ neon glow (cyan kenar parlaması)
```

### Geometrik Fonksiyonellik (Şekillerin Dili)
Her şekle bir görev vererek oyuncunun ekranı bir bakışta "okumasını" sağla.
- **Daireler (Nodes):** Giriş ve çıkış noktaları. Verinin doğduğu ve bittiği yerler
- **Kareler (Logic):** Verinin manipüle edildiği yerler (filtreleme, şifreleme, ayrıştırma)
- **Üçgenler (Gates):** Verinin hangi yöne gideceğine karar veren switch noktaları (Splitter/Merger)

### Veri Temsili: Hareketli 0/1 Parçacıkları
Bağlantılar üzerinde akan küçük 0 ve 1'ler:
- **Yeşil 0/1:** Temiz veri (Clean)
- **Sarı 0/1:** Bozuk veri (Corrupted)
- **Mor 0/1:** Şifreli veri (Encrypted)
- **Kırmızı 0/1:** Zararlı veri (Malware)

### Bağlantılar: Parlayan Kablolar
- Yapılar arası bağlantılar neon renkli çizgiler
- Üzerinde veri parçacıkları akar
- Aktif bağlantı parlar, boş bağlantı soluk

### Arka Plan: Grid Sistemi
- Koyu gri/lacivert tonlarında hafif ızgara
- "Buraya bir şey koyabilirim" hissi verir
- Cyberpunk devre kartı estetiği

### Shader Efektleri (İşin Büyüğünü Yapan Kısım)
- **Bloom:** Neon parlamaları — basit şekilleri "pahalı" gösterir
- **CRT Shader:** Tarama çizgileri, hafif kenar bükülmesi — terminal hissi
- **Vignette:** Ekran kenarlarında kararma — odak yaratır
- **Glow outline:** Yapı kenarlarında renk kodlu parlama

### Renk Paleti
```
Arka plan:    Koyu gri / lacivert (#0a0e14, #1a1e2e)
Grid:         Hafif açık çizgiler (#2a2e3e)
Yapılar:      Koyu gri gövde + renkli neon kenar
Clean veri:   Neon yeşil (#00ff88)
Corrupted:    Neon sarı (#ffcc00)
Encrypted:    Neon mor (#cc44ff)
Malware:      Neon kırmızı (#ff2244)
Enerji:       Cyan (#00ccff)
Isı:          Turuncu → Kırmızı (#ff8800 → #ff2200)
UI:           Neon cyan + beyaz
```

### Durum Göstergeleri
```
Normal:  Standart renk, sakin animasyon
Yüklü:  Sarıya kayar, hızlı animasyon
Kritik:  Kırmızı, yanıp sönme
Bozuk:   Koyu gri, durgun, kırık efekt
```

### Overlay Modları
- [H] Isı haritası — yapıların ısı durumunu gösterir
- [E] Enerji haritası — Power Cell kapsama alanlarını gösterir

---

## 13. Pazar Araştırması

### Zukowski (howtomarketagame.com) Bulguları

**Tür Uygunluğu:**
- "Crafty-Buildy-Simulation-Strategy" Steam'in yıllardır tutarlı en başarılı indie türü
- Solo/küçük ekipler için ideal alan
- Sistem tabanlı oyunlar az içerikle çok oyun süresi yaratır

**Görsel Kalite:**
- "Programcı sanatı hemen fark edilir" - minimum görsel eşik aşılmalı
- Aydinlatma, shader, parçacık efektleri basit görselleri profesyonel gösterir
- Görsel TUTARLILIK, görsel KALİTEDEN daha önemli

**Hook + Anchor Formülü:**
- Hook (kanca): "Netrunner olarak dijital sistemi yönet" (benzersiz)
- Anchor (çapa): "Factorio/Shapez benzeri otomasyon" (tanıdık)
- İkisi birlikte oyuncuyu çeker

**Pazarlama Stratejisi:**
- Kapsül görseli #1 yatırım - profesyonel çizdirilmeli
- Demo + Steam Next Fest stratejisi şart
- Steam sayfası mümkün olan en erken açılmalı
- Ekran görüntülerinde gerçek oyun içi gösterilmeli, UI dahil

**Wishlist Verileri:**
- İyi dönüşüm oranı: %20, %15 bile başarılı
- Wishlist'ler bayatlamaz
- Lansman öncesi en az 7.000+ wishlist hedeflenmeli

---

## 14. Referans Oyunlar

### Ana Referanslar

| Oyun | Steam Puanı | Neden Referans | Alınacak Ders |
|------|-------------|----------------|---------------|
| **Factorio** | %97 (224K+ yorum) | Otomasyon türünün kralı | İç içe geçen döngüler, "The Factory Must Grow", teknoloji ağacı |
| **Shapez** | %96 (14K+ yorum) | Minimalist chill otomasyon | Az yapı tipiyle derin oynanış, başlangıçta 2 yapı ile yumuşak giriş |
| **Hacknet** | %94 (7.5K+ yorum) | Hacking estetiği | Terminal estetiği çalışıyor AMA tekrarcılık öldürücü |

### İkincil Referanslar
| Oyun | Alınacak Ders |
|------|---------------|
| **Zachtronics (TIS-100, EXAPUNKS)** | Optimizasyon metrikleri, tekrar oynama motivasyonu |
| **Bitburner** | Meta-otomasyon, prestige sistemi |
| **while True: learn()** | Veri akışı görselleştirmesi, pipe-and-filter mekaniği |
| **Oxygen Not Included** | Çoklu kaynak dengeleme, kademeli açılma, heatmap overlay'ler |

### Kritik Uyarılar

**Hacknet uyarısı:** Tekrarcılık öldürücü - her görev gerçekten farklı hissetmeli.

**Zachtronics uyarısı:** Gerçek programlama gerektirmek kitleyi daraltır. Oyun "programlama hissi" vermeli ama gerçek kod yazdırmamalı.

**Shapez uyarısı:** Tüm mekanikler açıldıktan sonra motivasyon düşebilir - endgame derinliği şart (bizde: premium siparişler, karışık veri paketleri, tier 4).

---

## 15. Gelecek Güncellemeler

### Savunma Sistemi (Potansiyel Büyük Güncelleme / DLC)
Oyun chill otomasyon olarak çıkar. Savunma sistemi başarılı olursa sonradan eklenebilir:

**Planlanan konseptler (henüz tasarlanmadı):**
- Dijital katman (TAB geçişi) — savunma yapıları için ayrı katman
- Trace → saldırı dalgası tetikleme (mevcut: kaynak kısıtlama)
- Virüs yayılımı mekaniği (Creeper World referansı)
- Malware → Defense Intel dönüşümü (mevcut: sadece bertaraf)
- Savunma yapıları: ICE, Black ICE, Daemon, Honeypot vs.

**Neden şimdi değil:**
- Solo geliştirici olarak kapsam kontrolü
- İki sistemi dengelemek (otomasyon + savunma) çok karmaşık
- Chill otomasyon kendi başına yeterli pazar potansiyeline sahip (Shapez referansı)
- Altyapı zaten savunma eklemeye uygun (Trace sistemi, Malware tipi, grid yapısı)

---

## 16. Açık Sorular ve Yapılacaklar

### Öncelikli (Vertical Slice İçin)
- [ ] Sanat stili finalizasyonu
- [ ] 5 temel yapı ile çalışan prototip (Uplink, Storage, Data Broker, Power Cell, Coolant Rig)
- [ ] Grid yerleştirme sistemi
- [ ] Temel veri akış görselleştirmesi
- [ ] Steam sayfası için ekran görüntüleri

### Sonraki Adımlar (Prototip Sonrası)
- [ ] Separator eklenmesi (Faz 2 deneyimi)
- [ ] Decryptor + Research Lab (Faz 3)
- [ ] Recoverer + Patch Data upgrade sistemi (Faz 5)
- [ ] Quarantine + Malware bertaraf (Faz 6)
- [ ] Veri kaynakları özel mekanikleri (Deep Web, Corporate, Military, Blackwall)

### İleride Tasarlanacak
- [ ] Ekonomi dengeleme (credits, fiyatlar, verimlilik oranları)
- [ ] Teknoloji ağacı yapısı
- [ ] Veri kombinasyonları tam listesi ve process sıraları
- [ ] Premium sipariş sistemi detayları
- [ ] Encryptor geç oyun mekaniği
- [ ] Savunma sistemi (büyük güncelleme / DLC)

### Kesinleşmiş Kararlar ✅
- [x] 2D Top-Down perspektif
- [x] Godot 4.6 motoru
- [x] **Chill otomasyon** (savunma yok, gelecek güncelleme olarak planlandı)
- [x] Real-time with pause zaman mekaniği
- [x] Rehberli sandbox ilerleme
- [x] Cyberpunk/Netrunner teması
- [x] Cyberpunk isimlendirme + tooltip açıklama
- [x] 4 temel veri tipi: Clean, Corrupted, Encrypted, Malware
- [x] **Her veri tipinin kendine özgü amacı:** Clean→Credits, Encrypted→Research, Corrupted→Patch Data, Malware→bertaraf
- [x] 3 altyapı kaynağı: Power, Heat (kötü), Trace (kötü)
- [x] Credits para birimi (sadece Clean Data'dan)
- [x] **Patch Data upgrade sistemi** (Corrupted → yapı geliştirme)
- [x] Tier sistemi: yeni bina değil, daha fazla bina (üstel büyüme)
- [x] Veri renk kodlaması: Yeşil, Sarı, Mor, Kırmızı
- [x] Power Override mekaniği
- [x] Diegetic aesthetic tasarım sütunu
- [x] Prosedürel asset'ler + shader efektleri
- [x] Bilinmeyen veri tipleri keşif sistemi (??? → keşfet)
- [x] Saflık/verimlilik sistemi (separator %60 başlar, Patch Data ile gelişir)
- [x] Sıkıştırma (Compression) process'i — tier'lı
- [x] Uplink = makine, kaynak = ayar (aynı yapı, farklı kaynağa bağlanır)
- [x] 5 veri kaynağı: Web, Deep Web, Corporate, Military, Blackwall
- [x] Oyuncu ilerleme fazları (Çöpçü → Madenci → Mühendis → Sistem Mimarı)
- [x] Karışık veri paketleri geç oyunda
- [x] Tier çeşitleri farklı process yolları gerektirir
- [x] **Trace = tespit sistemi** (kaynak erişimi kısıtlama, saldırı dalgası değil)
- [x] **Doğrudan link (kablo) bağlantı sistemi** (konveyör değil)
- [x] **Power: zone-based** (Power Cell kapsama alanı)
- [x] **Heat: yapı bazlı + bölgesel yayılma** (Coolant Rig zone)
- [x] **13 temel + 1 geç oyun yapı** (savunma yapıları gelecek güncellemeye ertelendi)
- [x] **Geç oyun: Encryptor + premium sipariş sistemi**
- [x] **Yapı adı: Uplink** (eski: Data Siphon)
- [x] Malware tier çeşitleri: Worm, Trojan, Ransomware, Rootkit
- [x] **Sanat stili: Tamamen prosedürel** (kod ile üretim, sıfır harici art asset)
- [x] **2D Top-Down** (izometrik/2.5D değil)
- [x] Shader efektleri: Bloom, CRT, Vignette, Glow outline

---

*Bu döküman canlıdır ve her tasarım session'ında güncellenecektir.*
*Versiyon 0.4 — Chill otomasyon kararı, yapı listesi finalize, bağlantı ve altyapı sistemleri tanımlandı.*
