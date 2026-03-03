# SYS_ADMIN - Game Design Document
**Versiyon:** 0.5 (Tasarım Aşaması)
**Son Güncelleme:** 2026-03-03
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
| **Trace** | Kötü birikim (yerel) | Malware tutan Storage'dan zone-based yayılır. Etraftaki yapıları bozar |
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
Daha çok Uplink       → Daha çok veri AMA daha çok Power + Heat
Override kullan        → Daha hızlı AMA daha çok Heat
Decrypt/Recover        → Değerli çıktı AMA işleme kapasitesi harcanır
Malware filtrele       → Güvenli AMA Quarantine kapasitesi harcanır
Malware depolanırsa    → Storage etrafında Trace yayılır → yapılar bozulur
```

### İki Kötü Kaynak: Heat ve Trace
- **Heat** = Fiziksel tehdit → Çok birikirse yapılar yavaşlar → hasar alır → bozulur
- **Trace** = Dijital kirlilik (yerel) → Malware tutan Storage'dan yayılır → etraftaki yapıları bozar

### Trace Sistemi (Zone-Based Dijital Kirlilik)
Trace global bir sayaç değil, **yerel bir zone etkisi.** Malware verisi tutan Storage yapıları etraflarına Trace yayar:
```
Storage'da malware var  → Trace zone aktif (Power Cell gibi ama kötü etki)
Trace düşük:             Uyarı yok, güvenli
Trace orta:              Görsel uyarı (mor titreme efekti)
Trace yüksek:            Etraftaki yapılarda bozulma ihtimali başlar
Trace kritik:            Bozulma hızlanır, acil müdahale gerekir
```

**Trace nasıl yükselir:**
- Storage'da depolanan malware miktarına orantılı (daha çok malware = daha güçlü Trace)
- Malware boyutu arttıkça Trace zone'u genişler ve şiddeti artar

**Trace nasıl düşer:**
- Quarantine ile malware bertaraf edilir → Storage'daki malware azalır → Trace düşer
- Malware Storage'dan temizlenirse Trace sıfırlanır

**Bozulma mekaniği:**
- Trace zone içindeki yapılar belli bir ihtimalle "bozuk" duruma düşer
- Bozuk yapı çalışmayı durdurur, onarım gerektirir (Patch Data ile)
- Bozulmadan önce uyarı verilir (oyuncu tepki verebilir)

**Gelecek güncelleme:** Trace azaltıcı özel yapılar (Trace zone'unu küçülten/zayıflatan yapı tipi)

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
Malware storage'da birikti → etrafta Trace yayılıyor!
  → Yakındaki yapılar bozulmaya başlıyor!
  → Quarantine kurup malware'ı bertaraf et → Trace düşer
  → Malware'ı hızlıca temizlemeyen oyuncu yapı kaybeder
```
- Oyuncu anlar: "Malware'ı depolamak tehlikeli, hızlıca bertaraf etmeliyim"
- Motivasyon: Quarantine hattı kurmak, malware akışını optimize etmek

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

### Faz 7: Gig Sistemi ve Scale
```
Tüm veri tipleri açık, tüm process hatları kurulu
  → Gig panosu açılır — sözleşmeler farklı zorluk/ödül sunar
  → Her gig farklı veri kompozisyonu + farklı talep
  → Tier atlama → üstel büyüme
  → Oyuncu evrensel bir fabrika kurmaya doğru ilerler
```

### Gig (Sözleşme) Sistemi
Uplink kaynak seçimi yerine **Gig panosu** sistemi. Her gig tek seferlik bir sözleşme:
- Gig kabul edilir → Uplink belirli miktarda veriyi indirir (ör: 1 GB) → Gig biter
- Her gig'in kendine özgü veri kompozisyonu var (ör: %50 encrypted, %30 clean, %20 malware)
- Bazı gig'ler özel çıktı ister (ör: "şifreyi çöz, tekrar şifrele, premium olarak sat")
- Birden fazla Uplink = birden fazla eşzamanlı gig
- Gig panosu her zaman seçenek sunar — oyuncu hiç boş kalmaz

**Gig Kategorileri:**
| Kategori | Zorluk | İçerik | Ödül |
|----------|--------|--------|------|
| **Web Traffic** | Kolay | %80 clean, düşük hacim | Düşük Credits |
| **Deep Web** | Orta | Çok encrypted/corrupted, orta hacim | Orta Credits + Research |
| **Corporate** | Zor | Ağır encrypted, yüksek hacim, çok malware | Yüksek Credits |
| **Military** | Çok Zor | Encrypted + malware, çok yüksek hacim | Çok yüksek Credits |
| **Blackwall** | Endgame | Hibrit kombolar (corrupted+encrypted), devasa hacim | Premium ödüller |

**Gig boyut ölçeklemesi:**
```
Erken oyun:  500 MB — küçük, öğretici, tek hat yeterli
Orta oyun:   50 GB — birkaç paralel hat lazım
Geç oyun:    10 TB — devasa sistem gerektirir
Endgame:     100 TB+ — sonsuz döngüde artan zorluk
```

**Endgame gig döngüsü:** Oyun asla bitmez. Endgame gig'leri sonsuz döngüde gelir, her seferinde biraz daha büyük/karmaşık. Shapez'in sonsuz hub talepleri gibi.

**Neden gig sistemi (Uplink kaynak seçimi yerine):**
- Her gig = farklı challenge (Shapez'in hub talepleri gibi)
- Doğal ilerleme: kolay → zor → endgame
- Evrensel fabrika hedefi: oyuncu sonunda her gig'i çözebilen genel bir sistem kurar
- Tek seferlik yapı: eski hatlar yıkılmaz, yanına yeni hatlar eklenir (fabrika büyür)

### Geç Oyun: Özel Gig Talepleri
Bazı gig'ler sadece veri indirip işlemek değil, **özel çıktı** ister:
```
Gig: "256-bit şifreli temiz veri paketi hazırla"

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
- Farklı gig'ler farklı işleme adımları ister
- "Veri madencisi"nden "veri broker'ı"na geçiş

### Geç Oyun: Karışık Veri Paketleri
İleri gig'lerde veriler tek tip değil, **karışım** olarak geliyor:
```
Erken gig:  Veri ya Clean ya Encrypted → tek process yeterli
Geç gig:    "Corrupted-Encrypted paketi"
  → Önce corruption düzelt → sonra şifreyi çöz
  → Tek veri paketi birden fazla process hattından geçmek zorunda
```

### Tasarım Prensibi: Katmanlı Büyüme
```
BAŞLANGIÇ          → ORTA OYUN              → GEÇ OYUN
Kolay gig'ler,     → Zor gig'ler,          → Özel talepler,
tek hat              paralel hatlar           evrensel fabrika

Yapılar basit      → Yapılar büyüyor        → Yapılar birleşiyor
1 iş = 1 bina       1 iş = N bina (tier)      N sistem = 1 yeni sistem

500 MB gig'ler     → 50 GB gig'ler          → 10 TB+ gig'ler
```

---

## 8. Yapı/Bileşen Listesi

### Yapı Listesi (13 Yapı + 1 Geç Oyun)

**Çıkarım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Uplink** | "Ağa bağlanıp veri indirir" | Gig panosundan seçilen sözleşmeyi indirir. Her gig farklı veri kompozisyonu getirir |

**Uplink ve Gig Sistemi:**
Uplink = indirme makinesi. Gig panosu'ndan seçilen sözleşme Uplink'e atanır, Uplink gig boyutunca veri indirir:
- Her Uplink'e 1 gig atanabilir (birden fazla Uplink = birden fazla eşzamanlı gig)
- Gig bitince Uplink boşta kalır, yeni gig atanabilir
- Uplink hızı upgrade ile artar (başlangıç 10 MB/s → endgame 1 TB/s)

**Gig Kategorileri (Bkz. Bölüm 7 — Gig Sistemi):**
| Kategori | İçerik | Özel Mekanik |
|----------|--------|-------------|
| Web Traffic | Çoğu clean, düşük hacim | Güvenli, öğretici |
| Deep Web | Çok encrypted/corrupted, orta hacim | Düzensiz akış |
| Corporate | Ağır encrypted, yüksek hacim | Çok malware, Trace riski |
| Military | Encrypted + malware, çok yüksek hacim | Encryptor gerektirir |
| Blackwall | Hibrit kombinasyonlar, devasa hacim | Yapılara hasar (hostile veri) |

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

### Trace: Zone-Based Dijital Kirlilik
- Trace bölgesel (zone-based), global değil
- **Kaynak:** Malware verisi tutan Storage yapıları etraflarına Trace yayar
- **Etki:** Trace zone içindeki yapılar bozulma riski taşır
- **Çözüm:** Quarantine ile malware'ı hızlıca bertaraf et → Trace düşer
- Bkz. Bölüm 5: Trace Sistemi (Zone-Based Dijital Kirlilik)

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

**2. Gig Sistemi (ana ilerleme motoru):**
Her gig farklı pipeline gerektirir. Gig'ler büyüdükçe sistem büyümek zorunda:
```
Web Traffic gig:   500 MB, %80 clean — tek hat yeterli
Deep Web gig:      5 GB, çok encrypted — Decryptor hattı kur
Corporate gig:     50 GB, ağır encrypted + malware — paralel hatlar + Quarantine
Military gig:      500 GB, yoğun malware — devasa altyapı
Blackwall gig:     10 TB+, hibrit kombolar — evrensel fabrika
```
Endgame gig'leri sonsuz döngüde gelir (Shapez hub talepleri gibi).

**3. Astronomik Veri Ölçeklemesi:**
Uplink hızı ve gig boyutları oyun ilerledikçe astronomik olarak büyür:
```
Uplink hızı:   10 MB/s → 100 MB/s → 1 GB/s → 100 GB/s → 1 TB/s+
Gig boyutu:    500 MB → 50 GB → 10 TB → 100 TB+
```
Upgrade sistemi (Patch Data) bu ölçeklemeyi sağlar. Oyuncu her aşamada "ne kadar büyüdüm" hisseder.

**4. Trace Doğal Scale:**
- Daha büyük gig = daha çok malware = daha çok Trace riski
- Malware'ı hızlı işleyemeyen oyuncu yapı kaybeder → sistemi optimize etmeli
- Oyuncuyu dengede tutar

**5. Özel Gig Talepleri (geç oyun):**
- Bazı gig'ler belirli formatta çıktı ister (ör: "şifrele ve sat")
- Daha uzun pipeline = daha fazla kazanç
- Yeniden şifreleme sistemi (Encryptor)

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
- [ ] Gig sistemi temel implementasyonu

### İleride Tasarlanacak
- [ ] Ekonomi dengeleme (credits, fiyatlar, verimlilik oranları)
- [ ] Teknoloji ağacı yapısı
- [ ] Veri kombinasyonları tam listesi ve process sıraları
- [ ] Gig panosu UI tasarımı
- [ ] Gig zorluk/ödül dengeleme
- [ ] Trace zone parametreleri (radius, bozulma ihtimali, eşikler)
- [ ] Trace azaltıcı yapı tasarımı (post-release)
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
- [x] **Gig sistemi** (Uplink kaynak seçimi yerine tek seferlik sözleşme sistemi)
- [x] **Sonsuz endgame gig döngüsü** (Shapez hub talepleri gibi)
- [x] **Astronomik veri ölçeklemesi** (10 MB/s → 1 TB/s, 500 MB gig → 100 TB+ gig)
- [x] 5 gig kategorisi: Web Traffic, Deep Web, Corporate, Military, Blackwall
- [x] Oyuncu ilerleme fazları (Çöpçü → Madenci → Mühendis → Sistem Mimarı)
- [x] Karışık veri paketleri geç oyunda
- [x] Tier çeşitleri farklı process yolları gerektirir
- [x] **Trace = zone-based dijital kirlilik** (malware Storage'dan yayılır, etraftaki yapıları bozar)
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
*Versiyon 0.5 — Trace zone-based yeniden tasarım, Gig sistemi, astronomik ölçekleme kararları.*
