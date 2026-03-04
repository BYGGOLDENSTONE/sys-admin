# SYS_ADMIN - Game Design Document
**Versiyon:** 0.7 (Saf Otomasyon — Power/Heat kaldırıldı)
**Son Güncelleme:** 2026-03-04
**Motor:** Godot 4.6 (Forward Plus, Jolt Physics, D3D12)
**Durum:** Demo Faz 5 tamamlandı, büyük tasarım pivotu — harita sistemi + veri modeli + saf otomasyon

---

## İÇİNDEKİLER
1. [Oyun Özeti](#1-oyun-özeti)
2. [Tasarım Sütunları](#2-tasarım-sütunları)
3. [Teknik Kararlar](#3-teknik-kararlar)
4. [Çekirdek Döngü](#4-çekirdek-döngü)
5. [Harita Sistemi](#5-harita-sistemi)
6. [Veri Modeli: Content + State](#6-veri-modeli-content--state)
7. [Kaynak Sistemi](#7-kaynak-sistemi)
8. [Veri İşleme Zinciri](#8-veri-i̇şleme-zinciri)
9. [Yapı/Bileşen Listesi](#9-yapıbileşen-listesi)
10. [Bağlantı Sistemi](#10-bağlantı-sistemi)
11. [Kısıt Sistemi](#11-kısıt-sistemi)
12. [İlerleme ve Scale](#12-i̇lerleme-ve-scale)
13. [Görsel Tasarım](#13-görsel-tasarım)
14. [Pazar Araştırması](#14-pazar-araştırması)
15. [Referans Oyunlar](#15-referans-oyunlar)
16. [Gelecek Güncellemeler](#16-gelecek-güncellemeler)
17. [Açık Sorular ve Yapılacaklar](#17-açık-sorular-ve-yapılacaklar)

---

## 1. Oyun Özeti

**SYS_ADMIN**, oyuncunun bir **netrunner** olarak dijital dünyada dolaşıp, haritaya yayılmış veri kaynaklarından veri çekerek otomasyon hatları kurduğu 2D top-down chill otomasyon/management oyunudur.

**Temel Konsept:**
- Oyuncu dijital dünyada (siberuzay) bir netrunner olarak hareket eder
- Haritada dağılmış veri kaynakları (corpo sunucuları, askeri ağlar, dark web node'ları) bulur
- Kaynağın yanına Uplink kurarak veri çeker
- Çekilen veriyi otomasyon hatlarıyla işler, dönüştürür ve satar
- Farklı kaynaklar farklı **içerik tipleri** ve **veri durumları** içerir → her kaynak benzersiz bir otomasyon challenge'ı sunar
- Saf otomasyon: zorluk fiziksel kısıtlardan değil, veri karmaşıklığı ve routing'den gelir

**Tür:** Chill Otomasyon/Management
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner — Siberuzay (Dijital Gerçeklik)
**Hedef:** Rehberli Sandbox - kazanma koşulu yok, oyuncu sürekli yönetir ve optimize eder

**Tek Cümle:** "Siberuzayda veri kaynaklarını keşfet, otomasyon hatları kur ve en verimli pipeline'ı tasarla."

---

## 2. Tasarım Sütunları

### Sütun 1: Oyuncunun Kendini Akıllı ve Yetkin Hissetmesi
- Oyuncu kararlarının sonuçlarını görmeli
- Verimli bir sistem kurmak tatmin edici hissetmeli
- Yeni bir kaynak keşfedince "bu farklı bir challenge, nasıl çözeceğim?" düşüncesi
- Karmaşık bir kaynağı verimli pipeline ile çözmek → "zekiyim" hissi

### Sütun 2: Sandbox - Kendi Çözümlerini Optimize Etsin
- Tek doğru çözüm yok, oyuncu kendi pipeline'ını tasarlıyor
- Aynı soruna farklı yaklaşımlar mümkün
- "Rehberli sandbox" - teknoloji ağacı/açılma sistemi yön verir ama oyuncuyu zorlamaz
- Harita keşfi doğal yönlendirme sağlar

### Sütun 3: Karmaşıklık Baskısı (Shapez Modeli)
- Zorluk fiziksel kısıtlardan değil, **veri karmaşıklığından** gelir
- Uzak kaynaklar daha karışık content + daha zor state'ler → daha karmaşık routing
- Throughput darboğazları: yapıların işleme hızı sınırlı
- Storage dolulukları: buffer dolarsa pipeline tıkanır
- Ekonomik baskı: yapılar Credits'e mal olur, önceliklendirme kararı
- Oyuncu kendi pipeline'ına karşı mücadele eder, düşmana karşı değil

### Sütun 4: Diegetic Aesthetic (Dünya İle Bütünleşik Estetik)
- Her görsel eleman siberuzaya ait hissettirmeli
- Harita = dijital dünya, kaynaklar = ağ node'ları
- Basit şekiller + shader efektleri ile "pahalı" görünüm
- CRT shader, bloom, glitch efektleri dünyayı güçlendirir

---

## 3. Teknik Kararlar

| Karar | Seçim | Gerekçe |
|-------|-------|---------|
| **Perspektif** | 2D Top-Down | Solo geliştirici için hız, otomasyon türünde kanıtlanmış (Factorio %97, Shapez %96) |
| **Asset Pipeline** | Prosedürel şekiller + shader efektleri | Minimum asset ihtiyacı, kod ile üretim |
| **Zaman Mekaniği** | Real-time with pause | Otomasyon kurma = düşünme zamanı. Hız kontrolü: 1x, 2x, 3x + duraklat |
| **İlerleme** | Rehberli Sandbox | Teknoloji ağacı + harita keşfi yön verir ama oyuncuyu zorlamaz |
| **İsimlendirme** | Cyberpunk terimleri | Uplink, Decryptor gibi tematik isimler. Tooltip ile gerçek karşılığı açıklanır |
| **Motor** | Godot 4.6 | Forward Plus renderer, Jolt Physics, D3D12 |
| **Harita** | Prosedürel dijital dünya | Kaynak dağılımı rastgele, her oyunda farklı deneyim |
| **Kısıt Modeli** | Saf otomasyon (Shapez modeli) | Power/Heat yok, zorluk veri karmaşıklığı + throughput + ekonomiden gelir |

---

## 4. Çekirdek Döngü

### Ana Metafor: "Keşfet, Kur, Optimize Et"
Oyuncu siberuzayı keşfeder, kaynakları bulur, otomasyon kurar ve optimize eder. Yeni bölgeler yeni zorluklar getirir.

### Dakika Dakika Akış
```
[KEŞFET] → Haritada yeni veri kaynağı bul
      ↓
[ÇEK] → Kaynağın yanına Uplink kur, veri çekmeye başla
      ↓
[AYIR] → Separator ile içerik tiplerini ve durumları ayır
      ↓
[İŞLE] → Duruma göre: Decrypt / Recover / Quarantine
      ↓
[KULLAN] → İçerik tipine göre: Sat (Credits) / Araştır (Research) / Geliştir (Patch Data)
      ↓
[GENİŞLE] → Yeni yapılar al, yeni bölgelere git, sistemi büyüt
      ↓
[DARBOĞAZ] → Storage doldu, throughput yetersiz, routing karmaşık
      ↓
[OPTİMİZE] → Pipeline'ı iyileştir, paralel hatlar kur, dengeyi bul
      ↓
[TEKRAR] → Daha uzak, daha karmaşık kaynaklara doğru...
```

### Temel Gerilim
**"Daha uzak kaynaklar daha değerli AMA daha karmaşık."**
- Yakın kaynaklar basit içerik, tek durum → kolay pipeline
- Uzak kaynaklar karışık içerik, birden fazla durum + yüksek tier → karmaşık pipeline
- Daha büyük sistem = daha fazla kapasite AMA daha karmaşık routing

### "Bir Şey Daha" Faktörü (Bağımlılık Döngüsü)
> "Şu corpo sunucusundaki Financial Data çok değerli, oraya hat çekeyim... ama Encrypted T2, daha çok Decryptor lazım... Splitter ile dağıtayım... hmm Storage doluyor, daha fazla Storage ekleyeyim... oh şurada bir Biotech lab var, Research Data içeriyor, oraya da hat çekeyim..."

---

## 5. Harita Sistemi

### Temel Konsept
Siberuzay = oyuncunun dolaştığı dijital dünya haritası. Haritada çeşitli **veri kaynakları** dağılmış durumda. Her kaynak farklı içerik tipleri ve durumları barındırır.

### Kaynak Yapısı
Her veri kaynağı şu bilgilere sahip:
- **Konum:** Haritadaki pozisyon (merkeze yakınlık = zorluk)
- **İçerik dağılımı:** Hangi Content type'ları içeriyor (ör: %40 Financial, %30 Biometric, %30 Standard)
- **Durum dağılımı:** İçeriklerin hangi State'lerde olduğu (ör: %50 Clean, %30 Encrypted T1, %20 Corrupted)
- **Kapasite:** Kaynaktan çekilebilecek toplam veri miktarı (tükenebilir veya tükenmez — TBD)
- **Bant genişliği:** Kaynağın saniyedeki maksimum çıkış hızı

### Kaynak Bölgeleri

| Bölge | Uzaklık | İçerik | Durumlar | Zorluk |
|-------|---------|--------|----------|--------|
| **ISP Backbone** | Yakın | Çoğu Standard, az Biometric | Çoğu Clean, az Corrupted | Kolay — gelir başlangıcı |
| **Public Database** | Yakın | Standard + Biometric T1 | Clean + az Corrupted | Kolay-Orta |
| **Corporate Server** | Orta | Financial + Blueprint + Standard | Encrypted T1-T2 + Clean + az Malware | Orta |
| **Biotech Lab** | Orta | Biometric T2 + Research | Encrypted T1 + Corrupted + Clean | Orta |
| **Dark Web Node** | Orta-Uzak | Karışık her şey | Çok Corrupted + Malware + Encrypted T2 | Orta-Zor |
| **Government Archive** | Uzak | Research + Blueprint | Ağır Encrypted T2-T3 | Zor |
| **Military Network** | Uzak | Blueprint T3 + Research | Encrypted T3 + Malware | Çok Zor |
| **Blackwall Fragment** | Çok Uzak | Nadir/özel içerikler | Her şey yüksek tier, çok Malware | Endgame |

### Oyuncu ve Kaynak Etkileşimi
1. Oyuncu haritada dolaşır, kaynağı bulur
2. Kaynağın yanına Uplink yerleştirir
3. Uplink kaynaktan veri çekmeye başlar (kaynağın composition'ına göre)
4. Çekilen veri otomasyon hattına girer
5. Oyuncu pipeline'ını kaynağın içeriğine göre tasarlar

### Harita Özellikleri
- **Prosedürel üretim** (her oyunda farklı kaynak dağılımı — replayability)
- **Merkez → dış:** Zorluk ve değer artar
- **Keşif mekaniği:** Uzak kaynaklar başta görünmez, keşfedilmeli
- **Lojistik:** Uzak kaynaktan veriyi ana üsse taşımak bir challenge (uzun kablo veya relay sistemi — TBD)

### Shapez/Mindustry Paralelleri
- **Shapez:** Sonsuz harita, kaynak yatakları dağılmış, extractor ile çıkar → kemer ile taşı → işle
- **Mindustry:** Haritada cevherler, drill ile çıkar → konveyör ile taşı → rafine et
- **SYS_ADMIN:** Siberuzayda veri kaynakları, Uplink ile çek → kablo ile taşı → işle

---

## 6. Veri Modeli: Content + State

### Temel Prensip
Her veri paketi **iki boyutlu:**
- **Content (İçerik):** Verinin **ne** olduğu → hedefi ve değeri belirler
- **State (Durum):** Verinin **ne halde** olduğu → işleme yolunu belirler

```
Bir veri paketi = Content + State
Örnek: Financial Data (Encrypted T2) = "Finansal veri, 16-bit şifreli"
```

Bu iki katmanlı sistem **çarpımsal çeşitlilik** sağlar:
- 6 içerik x 4 durum = 24 temel kombinasyon
- Durumların tier'ları dahil: yüzlerce varyant
- Yeni içerik eklemek = anında 4+ yeni kombinasyon

### Neden Bu Model?
Eski model: `Veri = Tip (Clean, Encrypted, Corrupted, Malware)`
- Clean Data = tier'sız, çeşitlilik yok
- 4 tiple sınırlı
- Her kaynak "aynı" hissediyor

Yeni model: `Veri = İçerik (ne) + Durum (nasıl)`
- Shapez paraleli: Şekil (daire, kare) + Renk (kırmızı, mavi) = sonsuz kombinasyon
- SYS_ADMIN: İçerik (Financial, Biometric) + Durum (Clean, Encrypted) = sonsuz kombinasyon
- Her kaynak gerçekten **unique** hissediyor

### Content (İçerik) Katmanı — "Bu veri ne?"

İçerik tipi verinin **ne olduğunu** belirler. Her içerik tipinin kendine özgü **amacı** ve **değeri** vardır.

**İçerik Tipleri (Kesinleştirilecek — Öneriler):**

| İçerik Tipi | Cyberpunk Karşılığı | Oyundaki Amacı | Değer |
|-------------|---------------------|----------------|-------|
| **Standard Data** | Genel ağ trafiği, web verisi | Temel gelir kaynağı → Credits | Düşük |
| **Financial Data** | Banka, kripto, şirket hesapları | Premium gelir → Credits | Yüksek |
| **Biometric Data** | Parmak izi, retina, neural imprint | Gelir → Credits | Orta-Yüksek |
| **Blueprint Data** | Teknik şemalar, firmware, silah planları | Yapı geliştirme → Patch Data | Özel |
| **Research Data** | Bilimsel deneyler, AI eğitim verisi | Yeni yapı açma → Research Points | Özel |
| **Classified Data** | Devlet/askeri sırlar | Premium gelir → Credits (çok yüksek değer) | Çok Yüksek |

**İçerik katmanı sonsuz genişletilebilir** — yeni bir içerik tipi eklemek, tüm State varyantlarını otomatik olarak yaratır.

**NOT:** İçerik tipleri henüz kesinleşmedi. Yukarıdaki liste öneri niteliğindedir. Minimum 6 içerik tipi hedefleniyor.

### State (Durum) Katmanı — "Bu veri ne halde?"

Durum, verinin **işlenmeden önceki halini** belirler. Her durum farklı bir **işleme yapısı** gerektirir.

| Durum | İşleyici Yapı | Çıktı | Tier Sistemi |
|-------|---------------|-------|-------------|
| **Clean** | Yok (direkt kullanılabilir) | İçerik tipine göre son kullanım | Tier yok — temiz veri |
| **Encrypted** | Decryptor | Clean halindeki aynı içerik | Tier: 4-bit → 16-bit → 256-bit → Kuantum |
| **Corrupted** | Recoverer | Clean halindeki aynı içerik | Tier: %10 → %30 → %60 → %90 bozulma |
| **Malware-infected** | Quarantine | İmha (veri kurtarılamaz) | Tier: Worm → Trojan → Ransomware → Rootkit |

**Durum işleme mantığı:**
```
Financial Data (Encrypted T2) → Decryptor → Financial Data (Clean) → Data Broker → Credits
Biometric Data (Corrupted %30) → Recoverer → Biometric Data (Clean) → Data Broker → Credits
Blueprint Data (Malware-infected) → Quarantine → İmha (veri kaybolur)
Research Data (Clean) → Research Lab → Research Points
```

### State Tier Detayları

**Encrypted Tier'ları (Şifreleme Yöntemi):**
```
T1: 4-bit şifreleme    → 1 Decryptor, hızlı çözme
T2: 16-bit şifreleme   → 4 Decryptor paralel (Splitter → Merger)
T3: 256-bit şifreleme  → 16 Decryptor + karmaşık routing
T4: Kuantum şifreleme  → Özel yapı gerektirebilir (geç oyun)
```

**Corrupted Tier'ları (Bozulma Oranı):**
```
T1: %10 bozuk   → 1 Recoverer, hızlı düzeltme
T2: %30 bozuk   → Birden fazla Recoverer, birden fazla geçiş
T3: %60 bozuk   → Önce parçala, ayrı ayrı kurtar, birleştir
T4: %90 bozuk   → Neredeyse tamamen yeniden yapılandır
```

**Malware Tier'ları (Zararlı Türü):**
```
T1: Worm         → Standart karantina
T2: Trojan       → Gizlenir, önce tespit lazım
T3: Ransomware   → Verileri kilitler, acil müdahale
T4: Rootkit      → Sisteme gömülür, katmanlı temizlik
```

**NOT:** Düşük tier corrupted veriye ağır Recoverer hattı kurmak vakit kaybettirir. Oyuncu doğru tier'a doğru miktarda kaynak ayırmalı → optimizasyon kararı.

### Combinatorial Örnek

Aynı kaynak (Corporate Server):
```
Financial Data (Encrypted T2)  → Decrypt → Clean Financial → Sat → Yüksek Credits
Blueprint Data (Clean)          → Direkt → Patch Data → Yapı upgrade
Standard Data (Corrupted %30)   → Recover → Clean Standard → Sat → Düşük Credits
Standard Data (Malware-Worm)    → Quarantine → İmha
```

4 farklı veri, 3 farklı işleme yolu, 3 farklı çıktı — tek bir kaynaktan.

### Gelecek: 3. Katman — Protocol (Protokol)

> **NOT: 3. katman şu an planlanmıyor.** Gelecek güncelleme için not düşülmüştür.

**Konsept:** Verinin iletişim protokolü — "bunu hangi sistemle okuyabilirim?"
- Her bölge farklı protokol kullanır (CorpNet, MilSpec, DarkNet, Legacy...)
- Her protokolü okumak için farklı Decoder yapısı gerekir
- Content + State + Protocol = üç boyutlu kombinasyon

**Cyberpunk uyumu çok güçlü** — CorpNet, MilSpec, DarkNet protokolleri harita bölgeleriyle doğal eşleşir. Gelecekte değerlendirilecek.

---

## 7. Kaynak Sistemi

### İşlenmiş Kaynaklar (Çıktılar)

| Kaynak | Nasıl Elde Edilir | Oyundaki Rolü |
|--------|-------------------|---------------|
| **Credits** | Content'i Clean state'te Data Broker'a sat | Yapı satın alma (ana para birimi) |
| **Research Points** | Research Data (Clean) → Research Lab | Yeni yapı tipi açma |
| **Patch Data** | Blueprint Data (Clean) → doğrudan veya işleme | Mevcut yapıları upgrade etme |

### Content → Çıktı Eşlemesi

Oyuncu kararı **"hangi içerik tipini işleyeyim"** üzerinde:

| Content Type | Clean State'te Ne Olur | Strateji |
|--------------|------------------------|----------|
| Standard Data | Data Broker → düşük Credits | Kolay gelir, erken oyun |
| Financial Data | Data Broker → yüksek Credits | Yüksek gelir ama genelde Encrypted |
| Biometric Data | Data Broker → orta Credits | Dengeli gelir |
| Blueprint Data | → Patch Data (upgrade kaynağı) | Yapı geliştirmek için |
| Research Data | Research Lab → Research Points | Yeni yapı tipi açmak için |
| Classified Data | Data Broker → çok yüksek Credits | En değerli, genelde zor State'lerde |

### Kaynak Etkileşimleri
```
Uzak kaynak      → Değerli içerik AMA zor State'ler + lojistik zorluk
Encrypted veri   → İçeriği çöz → değerli AMA Decryptor kapasitesi gerekir
Corrupted veri   → Kurtarılınca faydalı AMA düşük tier'ı işlemek israf
Malware veri     → İmha et → veri kaybı (content ne olursa olsun kaybolur)
Karışık kaynak   → Her tip ayrı hat ister → karmaşık ama verimli
```

---

## 8. Veri İşleme Zinciri ve Oyuncu İlerlemesi

### Tasarım Prensibi
Oyuncu başta yakın, basit kaynakları işler. İlerledikçe uzak, karmaşık kaynakları keşfeder. Her yeni bölge yeni bir otomasyon challenge'ı sunar.

**İlerleme modeli:**
| Aşama | Oyuncu Ne Yapıyor | His |
|-------|-------------------|-----|
| Çöpçü (Scavenger) | Yakın ISP'den Standard Data topla, sat | "İlk adımlar" |
| Filtreleme (Filter) | Karışık kaynakları ayırmayı öğrenir | "Farklı veriler varmış!" |
| Mühendis (Engineer) | Her content+state için ayrı hat kurar | "Her şeyin yeri var" |
| Sistem Mimarı (Architect) | Uzak karmaşık kaynakları verimli işler | "Evrensel fabrika!" |

### Faz 1: Çöpçü (Başlangıç — Yakın Kaynaklar)
```
ISP Backbone kaynağı: çoğu Standard Data (Clean)
  → Uplink → Standard Data (Clean) → Data Broker → Credits
```
Basit, tek hat. Oyuncu temel mekanikleri öğreniyor.

### Faz 2: İlk Karışıklık (Corrupted Keşfi)
```
Public Database kaynağı: Standard + Biometric, bazıları Corrupted
  → Uplink → Separator → Content tiplerini ayır
  → Clean olanlar → direkt sat
  → Corrupted olanlar → ??? (henüz Recoverer yok, depolansın)
```
Oyuncu öğrenir: "Tüm veriler aynı değil, bazıları bozuk!"

### Faz 3: Encrypted Keşfi (Değerli Veriler)
```
Corporate Server kaynağı: Financial (Encrypted T1) + Blueprint (Clean)
  → Uplink → Separator → Content ayır
  → Financial (Encrypted) → Decryptor → Financial (Clean) → Sat → Yüksek Credits!
  → Blueprint (Clean) → Patch Data → Yapıları upgrade et!
```
**Eureka:** "Bu şifreli verinin içinde çok değerli bilgi varmış!"

### Faz 4: Karmaşık Kaynaklar (Multi-State)
```
Dark Web Node: her şey karışık, çok Malware
  → Uplink → Separator → State'lere göre ayır
  → Clean → direkt kullan
  → Encrypted → Decryptor hattı
  → Corrupted → Recoverer hattı
  → Malware-infected → Quarantine → imha
```
Oyuncu ilk kez **4 paralel hat** kuruyor. Her hat farklı işleme yapıyor.

### Faz 5: Tier Atlama
```
Government Archive: Research Data (Encrypted T2)
  → 1 Decryptor yetmiyor → Splitter → 4x Decryptor → Merger
  → Research Data (Clean) → Research Lab → Yeni yapı tipi aç!
```
Throughput sorunu — paralel yapılarla çözüm. **His:** "Zordu ama çözdüm."

### Faz 6: Evrensel Fabrika
```
Birden fazla kaynak bölgesi aktif, her biri farklı composition
  → Oyuncu genel amaçlı bir işleme sistemi kurmaya başlar
  → Her content tipi kendi hattına, her state kendi işleyicisine
  → Yeni kaynak bulunca pipeline'a "takıyor"
```

### Gig (Sözleşme) Sistemi
Harita sistemiyle birlikte Gig'ler **bölge sözleşmeleri** olarak çalışır:
- Gig panosu belirli bir kaynak bölgesindeki işi tanımlar
- "Bu Corporate Server'dan 50 GB Financial Data çıkar ve işle"
- Bazı gig'ler özel çıktı ister: "Şifreyi çöz, tekrar şifrele, premium olarak sat"
- Gig boyutu ve karmaşıklığı oyuncu ilerledikçe artar

**Gig Kategorileri:**
| Kategori | Kaynak Bölgesi | İçerik | Zorluk |
|----------|---------------|--------|--------|
| **Web Traffic** | ISP Backbone | Çoğu Standard (Clean) | Kolay |
| **Deep Web** | Dark Web Node | Karışık, çok Corrupted | Orta |
| **Corporate** | Corporate Server | Financial (Encrypted), Blueprint | Zor |
| **Military** | Military Network | Blueprint T3 (Encrypted T3) + Malware | Çok Zor |
| **Blackwall** | Blackwall Fragment | Her şey yüksek tier, hibrit | Endgame |

---

## 9. Yapı/Bileşen Listesi

### Yapı Listesi

**Çıkarım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Uplink** | "Veri kaynağına bağlanıp veri indirir" | Haritadaki kaynak node'unun yanına yerleştirilir, kaynaktan veri çeker |

**Ayırma & Depolama:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Separator** | "Veriyi ayırır" | Gelen veriyi Content tipine ve/veya State'e göre ayırır. Verimlilik %60 başlar |
| **Compressor** | "Veriyi sıkıştırır" | Storage'a koymadan önce boyutu küçültür |
| **Storage** | "Veri depolar" | Her türlü veriyi depolar. Dolarsa pipeline tıkanır |

**Durum İşleme (State Processing):**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Decryptor** | "Şifreli veriyi çözer" | Encrypted state → Clean state |
| **Recoverer** | "Bozuk veriyi kurtarır" | Corrupted state → Clean state |
| **Quarantine** | "Zararlı veriyi bertaraf eder" | Malware-infected → imha |

**Çıktı:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Data Broker** | "Temiz veriyi satar" | Clean state veriyi Credits'e çevirir. İçerik tipine göre farklı fiyat |
| **Research Lab** | "Araştırma verisi toplar" | Research Data (Clean) → Research Points |

**Dağıtım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Splitter** | "Akışı böler" | Tek hattı birden fazla hatta ayırır (1→N). Tier işleme için |
| **Merger** | "Akışları birleştirir" | Birden fazla hattı tek hatta toplar (N→1) |

**Geç Oyun:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| **Encryptor** | "Veriyi şifreler" | Clean veriyi Encrypted state'e çevirir. Premium sipariş sistemi için |

**Potansiyel Yeni Yapılar (Harita Sistemi ile):**
| Yapı | Tooltip | Fonksiyon | Durum |
|------|---------|-----------|-------|
| **Relay** | "Veriyi uzak mesafeye iletir" | Uzak kaynaktan ana üsse veri taşıma | TBD |
| **Scanner** | "Çevredeki kaynakları tarar" | Keşfedilmemiş veri kaynaklarını görünür yapar | TBD |

**Toplam: 10 temel + 1 geç oyun + 2 potansiyel = 11-13 yapı**

### Güncellenmiş Akış Haritası
```
[SİBERUZAY — Kaynak Node]
        ↓
      Uplink (veri çek)
        ↓
    Separator (Content + State ayır)
     ↓    ↓    ↓    ↓
   Clean  Enc  Cor  Malware
     ↓     ↓     ↓     ↓
   Direkt  Dec  Rec  Quarantine
     ↓     ↓     ↓     ↓(imha)
     ↓   Clean Clean
     ↓     ↓     ↓
     └──┬──┘──┬──┘
        ↓     ↓
   İçerik Tipine Göre Yönlendir:
   ├── Standard/Financial/Biometric/Classified → Data Broker → Credits
   ├── Research Data → Research Lab → Research Points
   └── Blueprint Data → Patch Data (yapı upgrade)

GEÇ OYUN:
Clean veri → [Encryptor] → Premium paket → Data Broker → Premium Credits
```

### Patch Data Upgrade Sistemi
Blueprint Data (Clean state) doğrudan Patch Data'ya dönüşür. Patch Data ile yapılar geliştirilir:
- Separator: verimlilik %60 → %70 → %80 → %90
- Decryptor: işleme hızı artışı
- Recoverer: işleme hızı artışı
- Storage: kapasite artışı
- Compressor: sıkıştırma oranı artışı
- vs.

---

## 10. Bağlantı Sistemi

### Doğrudan Link (Kablo) Sistemi
- Yapılar grid üzerine yerleştirilir
- Bir yapının çıkış portunu başka yapının giriş portuna bağlarsın (kablo çekersin)
- Veri bağlantı üzerinden anında akar (konveyör hızı yok)
- Tıkanıklık yapının işleme hızından kaynaklanır, kablodan değil
- Görsel: kablolar üzerinde renkli veri parçacıkları akar

### Neden Bu Sistem
- Konveyör bantları (Factorio) → çok karmaşık, başlı başına bir oyun
- Otomatik bağlantı → çok basit, lojistik kararı yok
- Doğrudan link → "neyi nereye bağlayayım" kararı var ama "bant hızı hesaplama" yok

### Uzak Mesafe Lojistiği (TBD)
Harita sistemiyle birlikte uzak kaynaklardan veri taşıma bir challenge. Seçenekler:
- Uzun kablo çekme
- Relay yapısı ile zıplama
- Kaynak başına lokal işleme + Credits transferi
- **Karar bekleniyor**

---

## 11. Kısıt Sistemi

### Felsefe: Shapez Modeli — Saf Otomasyon
Oyunda Power, Heat veya Trace gibi fiziksel/dijital kısıt sistemi **yok.** Zorluk tamamen otomasyon ve management'tan gelir — tıpkı Shapez gibi.

### Kısıtlar

| Kısıt | Nasıl Çalışır | Oyuncu Kararı |
|-------|---------------|---------------|
| **Content + State karmaşıklığı** | Uzak kaynaklar 5+ content x 3+ state = karmaşık routing | "Bu kaynağı nasıl çözeceğim?" |
| **Throughput (İşleme hızı)** | Yapıların işleme kapasitesi sınırlı, darboğaz yaratır | "Nereye paralel hat kurmalıyım?" |
| **Storage doluluk** | Buffer dolarsa pipeline tıkanır, veri kaybolabilir | "Daha çok Storage mu, daha hızlı çıkış mı?" |
| **Ekonomi** | Yapılar Credits'e mal olur | "Önce nereye yatırım yapayım?" |
| **Harita mesafesi** | Uzak kaynak = daha fazla altyapı yatırımı | "Bu kaynağa ulaşmaya değer mi?" |
| **Gig talepleri** | Belirli çıktı format/miktarı isteniyor | "Pipeline'ımı bu talebe nasıl uyarlayabilirim?" |
| **Malware** | Malware-infected veri Quarantine'e gitmezse işlenemez, yer kaplar | "Malware hattımı ne kadar büyük yapmalıyım?" |

### Neden Power/Heat Yok?
- Oyun tamamen **siberuzayda** geçiyor — fiziksel ısı ve güç kavramları tematik olarak uyumsuz
- Shapez kanıtladı: saf otomasyon yeterli derinlik sağlıyor (%96 Steam puanı)
- Daha az sistem = daha odaklı oynanış = daha "chill" deneyim
- Zorluk zaten yeterli: content çeşitliliği + state tier'ları + throughput + ekonomi
- Power/Heat, combat/defence sistemiyle birlikte post-release'de değerlendirilebilir

---

## 12. İlerleme ve Scale

### Rehberli Sandbox + Harita Keşfi
İki ilerleme ekseni:
1. **Teknoloji ağacı** — Research ile yeni yapı tipleri aç
2. **Harita keşfi** — Yeni bölgelere git, daha değerli kaynaklar bul

### Scale Mekanikleri

**1. Harita Mesafesi (ana scale kaynağı):**
- Yakın kaynaklar: basit, düşük değer, kolay State'ler
- Uzak kaynaklar: karmaşık, yüksek değer, zor State tier'ları
- Doğal zorluk eğrisi — "daha uzağa git" = "daha zor challenge"

**2. Veri State Tier'ları:**
- Her tier öncekinin ~4 katı yapı gerektirir
- Encrypted T1 → T4 arası üstel büyüme

**3. Content Çeşitliliği:**
- Yakın kaynaklar 1-2 content tipi içerir
- Uzak kaynaklar 4-5 content tipi karışık → karmaşık ayrıştırma hatları

**4. Gig Sistemi (ilerleme motoru):**
```
Web Traffic:   Yakın ISP, basit — tek hat yeterli
Corporate:     Orta mesafe, Financial (Encrypted) — Decryptor hattı kur
Military:      Uzak, Blueprint T3 (Encrypted T3) + Malware — devasa altyapı
Blackwall:     Çok uzak, her şey yüksek tier — evrensel fabrika
```

**5. Astronomik Veri Ölçeklemesi:**
```
Uplink hızı:   10 MB/s → 100 MB/s → 1 GB/s → 100 GB/s → 1 TB/s+
Kaynak boyutu:  500 MB → 50 GB → 10 TB → 100 TB+
```

### Devasa Base Vizyonu (Geç Oyun)
```
[SİBERUZAY HARİTASI]
   │
   ├── ISP Bölgesi (yakın) ── Uplink ── basit hat ── Data Broker
   │
   ├── Corporate Bölgesi (orta) ── Uplink ── Separator ── Decryptor dizisi ── Broker
   │                                                    └── Blueprint → Patch Data
   │
   ├── Military Bölgesi (uzak) ── Uplink ── Separator ── karmaşık routing
   │                                    ├── Encrypted T3 hat (16x Decryptor)
   │                                    ├── Quarantine hattı
   │                                    └── Blueprint T3 → Patch Data
   │
   └── Blackwall (çok uzak) ── Uplink ── evrensel fabrika sistemi
```

Her bölge kendi otomasyon challenge'ı, hepsi bir arada çalışıyor.

---

## 13. Görsel Tasarım

### Sanat Stili: Tamamen Prosedürel (Kod ile Üretim)
**Perspektif:** 2D Top-Down
**Yaklaşım:** Sıfır harici art asset. Her şey kod ile çizilir + shader efektleri.

### Harita Görselleştirmesi (Siberuzay)
- Dijital dünya estetiği: koyu arka plan, neon grid çizgileri
- Kaynak node'ları haritada parlayan noktalar olarak görünür
- Her kaynak bölgesi farklı renk teması (corpo = mavi, dark web = mor, military = kırmızı)
- Keşfedilmemiş bölgeler karanlık/bulanık

### Yapılar: Geometrik Şekiller + Glow
```
┌─────────┐
│ UPLINK  │  ← Koyu gri dikdörtgen, neon kenar parlaması
│  ◉───   │  ← İçinde basit ikon
│ ▓▓▓▓▓▓  │  ← Durum barı
└─────────┘
```

### Veri Temsili: İçerik + Durum Renklendirme
Bağlantılar üzerinde akan parçacıklar **iki bilgi** taşır:
- **Parçacık şekli/ikonu:** Content tipi (ör: Financial = $ sembolü, Biometric = parmak izi ikonu)
- **Parçacık rengi:** State durumu

**State renkleri:**
- **Yeşil:** Clean (temiz, hazır)
- **Mor:** Encrypted (şifreli)
- **Sarı:** Corrupted (bozuk)
- **Kırmızı:** Malware-infected (zararlı)

### Renk Paleti
```
Arka plan:     Koyu gri / lacivert (#0a0e14, #1a1e2e)
Grid:          Hafif açık çizgiler (#2a2e3e)
Yapılar:       Koyu gri gövde + renkli neon kenar
State renkleri:
  Clean:       Neon yeşil (#00ff88)
  Encrypted:   Neon mor (#cc44ff)
  Corrupted:   Neon sarı (#ffcc00)
  Malware:     Neon kırmızı (#ff2244)
UI:            Neon cyan + beyaz
Harita bölgeleri:
  ISP:         Açık mavi
  Corporate:   Koyu mavi
  Dark Web:    Mor
  Military:    Kırmızı
  Blackwall:   Turuncu-kırmızı
```

### Shader Efektleri
- **Bloom:** Neon parlamaları
- **CRT Shader:** Tarama çizgileri, hafif kenar bükülmesi
- **Vignette:** Ekran kenarlarında kararma
- **Glow outline:** Yapı kenarlarında renk kodlu parlama

---

## 14. Pazar Araştırması

### Zukowski (howtomarketagame.com) Bulguları

**Tür Uygunluğu:**
- "Crafty-Buildy-Simulation-Strategy" Steam'in yıllardır tutarlı en başarılı indie türü
- Solo/küçük ekipler için ideal alan
- Sistem tabanlı oyunlar az içerikle çok oyun süresi yaratır

**Görsel Kalite:**
- Shader efektleri basit şekilleri profesyonel gösterir
- Görsel TUTARLILIK, görsel KALİTEDEN daha önemli

**Hook + Anchor Formülü:**
- Hook: "Siberuzayda veri kaynaklarını keşfet ve otomasyon kur" (benzersiz)
- Anchor: "Shapez/Mindustry benzeri kaynak çıkarma ve otomasyon" (tanıdık)

**Pazarlama Stratejisi:**
- Demo + Steam Next Fest stratejisi şart
- Steam sayfası mümkün olan en erken açılmalı
- Ekran görüntülerinde gerçek oyun içi gösterilmeli

---

## 15. Referans Oyunlar

### Ana Referanslar

| Oyun | Steam Puanı | Neden Referans | Alınacak Ders |
|------|-------------|----------------|---------------|
| **Shapez 2** | %96 (14K+) | En yakın referans: minimalist chill otomasyon | Saf otomasyon yeterli, Power/Heat gerekmez, sonsuz harita + kaynak dağılımı, combinatorial complexity |
| **Factorio** | %97 (224K+) | Otomasyon türünün kralı | İç içe geçen döngüler, üstel büyüme, kaynak lojistiği |
| **Mindustry** | %95 (28K+) | Kaynak haritası + otomasyon | Haritada dağılmış cevherler, tier'lı kaynaklar, drill ile çıkarma |
| **Hacknet** | %94 (7.5K+) | Hacking estetiği | Terminal estetiği çalışıyor AMA tekrarcılık öldürücü |

### İkincil Referanslar
| Oyun | Alınacak Ders |
|------|---------------|
| **Zachtronics** | Optimizasyon metrikleri, tekrar oynama motivasyonu |
| **Bitburner** | Meta-otomasyon, prestige sistemi |
| **while True: learn()** | Veri akışı görselleştirmesi |

### Kritik Uyarılar
- **Hacknet:** Tekrarcılık öldürücü — harita sistemi her kaynağı farklı kılıyor
- **Shapez:** Endgame motivasyonu düşebilir — harita keşfi ve gig sistemi bunu çözüyor
- **Mindustry:** Savunma elementi dikkat dağıtabilir — bizde savaş yok, saf otomasyon

---

## 16. Gelecek Güncellemeler

### Protocol Katmanı (3. Katman — Potansiyel Güncelleme)
Content + State'e ek olarak **Protocol** katmanı:
- CorpNet, MilSpec, DarkNet, Legacy protokolleri
- Her protokol farklı Decoder yapısı gerektirir
- Harita bölgeleriyle doğal eşleşme

### Trace + Combat/Defence Sistemi (Potansiyel DLC)
Saf otomasyon oyununa ek olarak savunma katmanı:
- **Trace sistemi:** Operasyonlar iz bırakır, Trace birikimi saldırı tetikler
- **Power/Heat sistemi:** Fiziksel kısıtlar combat ile birlikte anlam kazanır
- **Savunma yapıları:** ICE, Black ICE, Daemon, Honeypot
- **Dijital katman:** TAB geçişi ile savunma yapıları için ayrı katman
- Neden şimdi değil: solo geliştirici kapsam kontrolü, chill otomasyon tek başına yeterli

---

## 17. Açık Sorular ve Yapılacaklar

### Acil Kararlar (Refactor İçin)
- [ ] Content tipleri kesinleştirme (6+ tip: Standard, Financial, Biometric, Blueprint, Research, Classified?)
- [ ] Kaynaklar tükenir mi tükenmez mi? (Shapez: tükenmez, Mindustry: tükenmez ama sınırlı alan)
- [ ] Harita prosedürel mi sabit mi?
- [ ] Uzak mesafe lojistiği nasıl çalışacak? (uzun kablo / relay / lokal işleme)
- [ ] Separator Content'e mi, State'e mi, her ikisine mi göre ayırıyor?
- [ ] Data Broker farklı Content tipleri için farklı fiyat mı veriyor?
- [ ] Blueprint Data → Patch Data dönüşümü nasıl? (otomatik mi, yapı mı gerekiyor?)
- [ ] Harita boyutu ve zoom seviyesi

### Sonraki Adımlar (Refactor Planı İçin)
- [ ] Mevcut veri sistemi refactor'u (4 tip → Content + State modeli)
- [ ] Power/Heat/Trace sistemi kaldırma
- [ ] Power Cell ve Coolant Rig yapıları kaldırma
- [ ] Harita sistemi temel implementasyonu
- [ ] Kaynak node sistemi
- [ ] Separator mekaniği güncelleme (content + state ayırma)
- [ ] Data Broker content-based fiyatlandırma
- [ ] Yeni içerik tipleri için Resource dosyaları
- [ ] Parçacık sistemi güncelleme (content + state görselleştirme)

### İleride Tasarlanacak
- [ ] Ekonomi dengeleme (content tipleri fiyat dengesi)
- [ ] Teknoloji ağacı güncelleme (harita keşfi ile entegrasyon)
- [ ] Gig sistemi harita entegrasyonu
- [ ] Protocol katmanı tasarımı (gelecek güncelleme)
- [ ] Trace + Combat/Defence sistemi (DLC)
- [ ] Encryptor geç oyun mekaniği

### Kesinleşmiş Kararlar ✅
- [x] 2D Top-Down perspektif
- [x] Godot 4.6 motoru
- [x] **Chill otomasyon** (savunma yok, gelecek güncelleme)
- [x] Real-time with pause
- [x] Rehberli sandbox ilerleme
- [x] **Cyberpunk / Netrunner — Siberuzay teması** (tamamen dijital gerçeklik)
- [x] **Harita sistemi: siberuzayda dağılmış veri kaynakları** (Shapez/Mindustry modeli)
- [x] **Veri modeli: Content (İçerik) + State (Durum) iki katmanlı sistem**
- [x] **Content:** Verinin ne olduğu (Financial, Biometric, Blueprint, Research vb.) → hedef ve değer belirler
- [x] **State:** Verinin durumu (Clean, Encrypted, Corrupted, Malware-infected) → işleme yolu belirler
- [x] **Combinatorial çeşitlilik:** Content x State x Tier = yüzlerce benzersiz veri varyantı
- [x] **Her State'in tier sistemi:** Encrypted (şifreleme yöntemi), Corrupted (bozulma oranı), Malware (zararlı türü)
- [x] **Protocol 3. katman olarak not düşüldü** (gelecek güncelleme)
- [x] **Kaynak bölgeleri:** ISP, Corporate, Biotech, Dark Web, Government, Military, Blackwall
- [x] **Merkez → dış zorluk eğrisi:** yakın=kolay, uzak=zor
- [x] **Credits:** Content'i Clean state'te satmaktan (farklı content = farklı değer)
- [x] **Research:** Research Data (Clean) → Research Lab
- [x] **Patch Data:** Blueprint Data (Clean) → yapı upgrade
- [x] **Saf otomasyon kısıt modeli (Shapez modeli):** Power/Heat/Trace YOK, zorluk veri karmaşıklığı + throughput + ekonomiden gelir
- [x] Tier sistemi: yeni bina değil, daha fazla bina (üstel büyüme)
- [x] Prosedürel asset'ler + shader efektleri
- [x] Bilinmeyen veri tipleri keşif sistemi
- [x] **Gig sistemi** (harita bölge sözleşmeleri)
- [x] **Sonsuz endgame gig döngüsü**
- [x] **Doğrudan link (kablo) bağlantı sistemi**
- [x] **10 temel + 1 geç oyun yapı** (+ potansiyel Relay, Scanner)
- [x] **Geç oyun: Encryptor + premium sipariş sistemi**
- [x] Sanat stili: tamamen prosedürel
- [x] Shader efektleri: Bloom, CRT, Vignette, Glow outline

### Reddedilen/Değişen Kararlar
- ~~4 temel veri tipi (Clean, Corrupted, Encrypted, Malware)~~ → **Content + State modeline dönüştü**
- ~~Uplink havadan veri çekme~~ → **Haritadaki kaynak node'larından çekme**
- ~~Soyut sandbox (mekân yok)~~ → **Siberuzay haritası**
- ~~Power Cell (zone-based güç)~~ → **Kaldırıldı** — siberuzayda fiziksel güç yok
- ~~Coolant Rig (zone-based soğutma)~~ → **Kaldırıldı** — siberuzayda fiziksel ısı yok
- ~~Heat sistemi~~ → **Kaldırıldı** — saf otomasyon, combat/defence DLC'sine ertelendi
- ~~Trace sistemi~~ → **Ertelendi** — combat/defence DLC'si ile birlikte gelecek
- ~~Power Override mekaniği~~ → **Kaldırıldı** — Power sistemiyle birlikte
- Fragment veri tipi (çıkarıldı)
- Savunma sistemi v1.0'da (ertelendi — DLC)
- Global Trace sistemi (reddedildi, zone-based olarak ertelendi)

---

*Bu döküman canlıdır ve her tasarım session'ında güncellenecektir.*
*Versiyon 0.7 — Power/Heat/Trace kaldırıldı, saf otomasyon modeli (Shapez referansı), siberuzay teması.*
