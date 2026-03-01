# SYS_ADMIN - Game Design Document
**Versiyon:** 0.1 (Tasarım Aşaması)
**Son Güncelleme:** 2026-03-02
**Motor:** Godot 4.6 (Forward Plus, Jolt Physics, D3D12)
**Durum:** Tasarım devam ediyor, implementasyona geçilmedi

---

## İÇİNDEKİLER
1. [Oyun Özeti](#1-oyun-özeti)
2. [Tasarım Sütunları](#2-tasarım-sütunları)
3. [Teknik Kararlar](#3-teknik-kararlar)
4. [Çekirdek Döngü](#4-çekirdek-döngü)
5. [Kaynak Sistemi](#5-kaynak-sistemi)
6. [Veri Tipleri ve Tier Sistemi](#6-veri-tipleri-ve-tier-sistemi)
7. [Veri İşleme Zinciri](#7-veri-i̇şleme-zinciri)
8. [İki Katmanlı Dünya](#8-i̇ki-katmanlı-dünya)
9. [Yapı/Bileşen Listesi](#9-yapıbileşen-listesi)
10. [Savunma Sistemi](#10-savunma-sistemi)
11. [İlerleme ve Scale](#11-i̇lerleme-ve-scale)
12. [Görsel Tasarım](#12-görsel-tasarım)
13. [Pazar Araştırması](#13-pazar-araştırması)
14. [Referans Oyunlar](#14-referans-oyunlar)
15. [Açık Sorular ve Yapılacaklar](#15-açık-sorular-ve-yapılacaklar)

---

## 1. Oyun Özeti

**SYS_ADMIN**, oyuncunun bir **netrunner** olarak dijital bir sistemi yönettiği 2D top-down otomasyon/management + base defense oyunudur.

**Temel Konsept:**
- Oyuncu bir netrunner'ın rig'ini kurar ve yönetir
- Ağdan veri çeker, işler, dönüştürür ve satar
- Aynı zamanda sistemini virüslere ve saldırılara karşı korur
- İki katmanlı dünya: Fiziksel (donanım) + Dijital (yazılım/savunma)

**Tür:** Otomasyon/Management + Base Defense
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner
**Hedef:** Rehberli Sandbox - kazanma koşulu yok, oyuncu sürekli yönetir ve optimize eder

**Tek Cümle:** "Bir netrunner olarak dijital sisteminizi kurun, veri akışlarını yönetin ve saldırılara karşı savunun."

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

### Sütun 3: Oyuncunun Kurduğu Sistemi Test Edecek Engeller
- Artan veri hacmi mevcut sistemi yetersiz bırakır
- Heat ve Trace birikimi sürekli tehdit yaratır
- Saldırı dalgaları savunmayı test eder
- Tier atlama anlarında pipeline yeniden tasarlanmalı

### Sütun 4: Diegetic Aesthetic (Dünya İle Bütünleşik Estetik)
- Her görsel eleman oyun dünyasına ait hissettirmeli
- Basit şekiller + shader efektleri ile "pahalı" görünüm
- Fiziksel katman: metalik, somut, sıcak tonlar
- Dijital katman: neon, soyut, soğuk tonlar
- CRT shader, bloom, glitch efektleri dünyayı güçlendirir
- Zukowski: "Grafikleriniz son teknoloji olmak zorunda değil ama niyetiniz net olmalı"

---

## 3. Teknik Kararlar

| Karar | Seçim | Gerekçe |
|-------|-------|---------|
| **Perspektif** | 2D Top-Down | Solo geliştirici için hız, otomasyon türünde kanıtlanmış (Factorio %97, Shapez %96, Mindustry %96) |
| **Katman Sistemi** | Fiziksel + Dijital (TAB geçiş) | İki farklı gameplay loop'u görsel olarak ayırır |
| **Asset Pipeline** | Prosedürel şekiller + shader efektleri | Minimum asset ihtiyacı, kod ile üretim |
| **Zaman Mekaniği** | Real-time with pause | Otomasyon kurma = düşünme zamanı, savunma = hızlı karar. Hız kontrolü: 1x, 2x, 3x + duraklat |
| **İlerleme** | Rehberli Sandbox | Teknoloji ağacı yön verir ama oyuncuyu zorlamaz. Kazanma yok, sadece yönet |
| **İsimlendirme** | Cyberpunk terimleri | Neural Processor, Data Siphon gibi tematik isimler. Tooltip ile gerçek karşılığı açıklanır (ör: "Veri işler") |
| **Motor** | Godot 4.6 | Forward Plus renderer, Jolt Physics, D3D12 |

---

## 4. Çekirdek Döngü

### Ana Metafor: "Tabak Çevirme" (Plate Spinning)
Oyuncu aynı anda birden fazla sistemi dengede tutuyor. Bir şeyi düzeltmek başka bir ihtiyacı ortaya çıkarıyor.

### Dakika Dakika Akış
```
[VERİ GELİR] → Data Siphon ile ağdan veri çekilir
      ↓
[AYIR] → Separator ile veri tiplerine ayrılır
      ↓
[DEPOLA] → Storage'da tamponlanır
      ↓
[İŞLE] → Çok aşamalı işleme zincirinden geçer
      ↓
[ÜRETİM] → Son ürünler ortaya çıkar (Credits, araştırma, savunma)
      ↓
[GENİŞLE] → Yeni yapılar al, sistemi büyüt
      ↓
[TEHDİT] → Trace arttı, saldırı dalgası geldi
      ↓
[SAVUN] → Dijital katmanda saldırıyı bertaraf et
      ↓
[ONAR + OPTİMİZE] → Hasarı onar, pipeline'ı iyileştir
      ↓
[TEKRAR] → ...döngü, artan karmaşıklıkla
```

### Temel Gerilim
**"Büyümek ZORUNDASIN ama büyümek yeni sorunlar yaratır."**
- Daha fazla veri = daha fazla gelir AMA daha fazla Power/Heat/Trace
- Daha büyük sistem = daha fazla kapasite AMA daha büyük saldırı yüzeyi
- Daha hızlı işleme = daha verimli AMA daha fazla ısı ve iz

### İki Mod Arasında Geçiş
| | İnşa/Optimize Modu | Tehdit Modu |
|---|---|---|
| **Tempo** | Sakin, düşünceli | Gergin, hızlı |
| **Oyuncu ne yapar** | Yapı ekler, bağlantı kurar, optimize eder | Savunma yönlendirir, karantina uygular, hasar onarır |
| **His** | "Şu sistemi biraz daha verimli yapayım..." | "Virüs ana sunucuya ulaşmadan durdurmalıyım!" |
| **Pause kullanımı** | Planlama için | Acil karar için |

Bunlar keskin geçişler değil - savunma sırasında da sistem çalışmaya, veri akmaya devam ediyor.

### "Bir Şey Daha" Faktörü (Bağımlılık Döngüsü)
> "Storage dolmak üzere, bir tane daha koyayım... ama Power yetmiyor, Power Cell ekleyeyim... hmm Heat çok yükseldi, Coolant lazım... oh Trace alarm veriyor, savunmayı kontrol edeyim... tamam şimdi Storage'a döneyim..."

---

## 5. Kaynak Sistemi

### Temel Kaynaklar

| Kaynak | Tipi | Katman | Rol |
|--------|------|--------|-----|
| **Clean Data** | Ana kaynak | Her ikisi | Sistemi besler, temel gelir kaynağı. Tier'lı |
| **Corrupted Data** | Dönüştürülebilir | Her ikisi | Başta waste, recover edilince yeni yapılar/araştırma açar. Tier'lı |
| **Encrypted Data** | Dönüştürülebilir | Her ikisi | Başta waste, decrypt edilince premium Credits geliri. Tier'lı |
| **Malware Data** | Tehlike/Kaynak | Her ikisi | Filtrelenmezse sisteme sızar. Analiz edilirse dijital savunmanın kaynağı olur. Tier'lı |
| **Power** | Altyapı | Fiziksel | Her yapı tüketir. Override ile artırılabilir (risk/ödül). Yetersizse sistem durur |
| **Heat** | Kötü birikim | Fiziksel | Her çalışan yapı üretir. Çalışma yoğunluğuna göre değişir. Soğutulmazsa donanım hasar alır |
| **Trace** | Kötü birikim | Dijital | Siphon, decrypt, recover artırır. Yükselince saldırı dalgaları gelir |
| **Credits** | Para birimi | Meta | Veri satışından kazanılır. Fiziksel yapı satın almak için kullanılır |

### Kaynak Etkileşimleri
```
Daha çok Data Siphon → Daha çok veri AMA daha çok Power + Heat + Trace
Override kullan       → Daha hızlı AMA daha çok Heat
Decrypt/Recover       → Değerli çıktı AMA Trace ↑↑
Malware filtrele      → Güvenli AMA kaynak harcarsın
Malware analiz et     → Savunma güçlenir AMA riskli (kaçabilir)
```

### İki Kötü Kaynak: Heat ve Trace
- **Heat** = Fiziksel katmanın tehdidi → Çok birikirse donanım hasar alır/çöker
- **Trace** = Dijital katmanın tehdidi → Çok birikirse büyük saldırı dalgası gelir

İkisi birlikte oyunun gerilim kaynağı. Biri fiziksel katmanı, diğeri dijital katmanı tehdit ediyor.

### Power Override Mekaniği
Oyuncu her yapıya ne kadar güç vereceğini seçebilir:
```
Düşük güç ──── Normal ──── Override
Yavaş          Standart     Hızlı
Az heat        Normal heat  Çok heat
Verimli        Dengeli      Riskli
```

### Veri Tiplerinin Çıktıları
| Veri Tipi | İşlenince Ne Olur |
|-----------|-------------------|
| Clean Data | Sistemi besler + temel Credits geliri |
| Encrypted Data | Premium Credits (ana gelir kaynağı) |
| Corrupted Data | Research → yeni yapılar açılır |
| Malware | Defense Intel → dijital savunma güçlenir |

**Kritik tasarım: Credits fiziksel dünyanın para birimi, Malware dijital savunmanın kaynağı.**

### Oyuncunun Sürekli Kararı
> "Temiz verimle ne yapayım? Satıp kredi mi kazanayım? Araştırmaya mı yönlendireyim? Savunmayı mı besleyeyim? Yoksa hepsini satıp acil Coolant mu alayım çünkü Heat kritik?"

---

## 6. Veri Tipleri ve Tier Sistemi

### 4 Temel Veri Tipi
1. **Clean Data** (Temiz Veri) - Yeşil
2. **Corrupted Data** (Bozuk Veri) - Sarı
3. **Encrypted Data** (Şifreli Veri) - Mor
4. **Malware Data** (Zararlı Veri) - Kırmızı

### Tier Sistemi: Yeni Bina Değil, Daha Fazla Bina
Factorio mantığı: "Tier 2 fırın" yok, daha fazla fırın koyarsın. Bizde de:

**Encrypted Data Tier Örneği:**
```
Tier 1 (4-bit şifreleme):
  → 1 Decryptor yeterli
  → Düşük ödül, düşük Trace

Tier 2 (16-bit şifreleme):
  → 4 Decryptor paralel çalışır
  → Splitter ile veri dağıtılır, Merger ile birleştirilir
  → 4x Power, 4x Heat
  → Orta ödül, orta Trace

Tier 3 (256-bit şifreleme):
  → 16 Decryptor + karmaşık routing
  → 16x Power, 16x Heat
  → Yüksek ödül, yüksek Trace

Tier 4 (Kuantum şifreleme):
  → 64 Decryptor + yeni özel yapı gerektirebilir
  → Devasa altyapı
  → Devasa ödül, devasa Trace
```

**Aynı mantık tüm veri tiplerine uygulanır:**
- Corrupted Tier 2 → 4 Recoverer paralel
- Malware Tier 2 → 4 Quarantine paralel

### Tier Sistemi Neden Scale Yaratır
Her tier öncekinin ~4 katı yapı gerektiriyor (üstel büyüme). Bu doğal olarak devasa base'ler oluşturuyor:
```
Tier 3 her şey:
  16 Decryptor + 16 Recoverer + 16 Quarantine = 48 işleme yapısı
  + Splitter/Merger dizileri = ~30 yardımcı yapı
  + Power Cell dizisi = ~30 enerji yapısı
  + Coolant dizisi = ~20 soğutma yapısı
  + Depolama = ~12 storage
  + Savunma hattı = ~50 savunma yapısı
  = 200+ yapı
```

---

## 7. Veri İşleme Zinciri

### Mevcut Tasarım (Henüz Yeterli Derinlikte Değil - Geliştirme Devam Edecek)

**Sorun:** Şu anki zincir çok kısa. "Decrypt et → sat" tek adımlık bir süreç, otomasyon oyunu gibi hisettirmiyor.

**Hedef:** Factorio'daki gibi çok aşamalı dönüşüm zinciri. Her aşama bir yapı, her yapının çıktısı bir sonrakinin girdisi.

**Mevcut zincir taslağı (geliştirilecek):**
```
Data Siphon → Ham veri çeker
      ↓
Separator → 4 veri tipine ayırır
      ↓
Storage → Tamponlar
      ↓
İlk İşlem:
  Clean → doğrudan kullanılabilir
  Corrupted → Recoverer → kurtarılmış veri
  Encrypted → Decryptor → çözülmüş veri
  Malware → Quarantine → kontrol altına alınmış kod
      ↓
[ARA AŞAMALAR - TASARLANACAK]
  Parser → yapılandırma
  Analyzer → analiz
  Compiler → paketleme
      ↓
Çıktı:
  Router → Credits (satış)
  Research Lab → Yeni yapılar
  Weapon Forge → Savunma programları
```

### Açık Tasarım Sorusu
Zincir şu an ~3-4 aşamalı. Hedef ~5-7 aşama olmalı ki gerçek bir otomasyon hissi versin. Ara aşamaların (Parser, Analyzer, Compiler) tam tanımları ve birbirleriyle etkileşimleri tasarlanacak.

**Önemli prensip:** Bazı yapılar (Parser, Analyzer gibi) tüm veri hatları tarafından paylaşılmalı. Bu darboğaz yaratır ve oyuncuyu lojistik puzzle çözmeye zorlar.

---

## 8. İki Katmanlı Dünya

### Fiziksel Katman (TAB - Aktif)
**Ne görülür:** Donanım bileşenleri, kablolar, ısı göstergeleri, duman, LED'ler
**Ne yapılır:** Donanım yerleştir, kablola, enerji dağıt, soğutma kur
**Estetik:** Koyu gri, metalik gümüş, turuncu/kırmızı (ısı). Somut, sıcak tonlar.

**Göstergeler:**
- Yapı üzerinde sıcaklık barı (yeşil → sarı → kırmızı)
- Doluluk barları (depolama, bellek)
- Fan dönüş animasyonları
- Kablo kalınlığı = bant genişliği
- Duman parçacıkları = aşırı ısınma
- LED yanıp sönme = aktif/pasif

### Dijital Katman (TAB - Aktif)
**Ne görülür:** Veri akışları, firewall'lar, savunma yapıları, virüs yayılımı
**Ne yapılır:** Savunma yapıları yerleştir, firewall çek, virüs müdahale
**Estetik:** Siyah arka plan, neon yeşil/mavi/mor, kırmızı (tehdit). Soyut, soğuk tonlar.

**Göstergeler:**
- Akan 0/1 parçacıkları (renk kodlu: yeşil=temiz, kırmızı=virüs, mor=şifreli, sarı=corrupted)
- Firewall parlaklığı = güç seviyesi
- Virüs yayılımı = kırmızı sıvı/sis efekti (Creeper World referansı)
- Tarama halkası animasyonları (IDS/IPS)
- Honeypot yanıp sönmesi

### TAB Geçişi
- Aynı grid, aynı yerleşim, farklı "lens"
- Fiziksel katmanda koyulan yapılar dijital katmanda karşılıklarını etkiler
- Kısa geçiş animasyonu: fiziksel dünya "çözünüp" dijitale dönüşür
- Her iki katman da real-time çalışır, TAB sadece görünümü değiştirir

### Katmanlar Arası Bağlantı
Fiziksel donanım dijital katmanın sınırlarını belirler:
```
Fiziksel CPU gücü     → Dijital'de kaç savunma programı çalışabilir
Fiziksel RAM          → Dijital'de anti-virus tarama hızı
Fiziksel bant genişliği → Dijital'de ne kadar veri akışı yönetilebilir
Fiziksel soğutma      → Dijital'de sistem ne kadar süre tam yükte çalışabilir
```

---

## 9. Yapı/Bileşen Listesi

### Mevcut Yapı Listesi (Taslak - Geliştirilecek)

**Çıkarım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Data Siphon | "Ağdan veri çeker" | Haritadaki data node'larına bağlanır, ham veri yığını üretir |

**Ayırma & Depolama:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Separator | "Veriyi tiplerine ayırır" | Ham veriyi Clean/Corrupt/Encrypt/Malware olarak ayırır |
| Storage | "Veri depolar" | Tampon depolama. Power tüketir, Heat üretir. Dolarsa pipeline tıkanır |

**İlk İşlem (Tier'lı veriyi çözen yapılar):**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Decryptor | "Şifreli veriyi çözer" | Encrypted data → çözülmüş veri. Çok Power, çok Heat, Trace ↑ |
| Recoverer | "Bozuk veriyi kurtarır" | Corrupted data → kurtarılmış veri. Trace ↑ |
| Quarantine | "Zararlı veriyi izole eder" | Malware → kontrol altında kod. Kaçarsa sisteme sızar |

**Ara İşlem (Tasarlanacak - zincir derinliği için):**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Parser | "Veriyi yapılandırır" | Raw data → Structured data |
| Analyzer | "Veriyi analiz eder" | Structured data → Intelligence |
| Compiler | "Veriyi paketler" | Intelligence → Data Package (satışa hazır) |

**Savunma/Çıktı (Tasarlanacak):**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Reverse Engineer | "Zararlıyı tersine mühendisler" | Contained malware → Defense Intel |
| Weapon Forge | "Savunma programı üretir" | Defense Intel → savunma güçlendirmesi |
| Router | "İşlenmiş veriyi satar" | Final ürün → Credits |
| Research Lab | "Yeni teknoloji araştırır" | Corrupted veriden → yeni yapı/yetenek açma |

**Altyapı:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Power Cell | "Enerji üretir" | Sisteme Power sağlar |
| Coolant Rig | "Isıyı düşürür" | Heat azaltır. Yoksa donanım hasar alır |
| Relay Node | "Bileşenleri bağlar" | Veri transfer hattı. Bant genişliği sınırı var |

**Dağıtım:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| Splitter | "Veri akışını böler" | Tek hattı birden fazla hatta ayırır (tier işleme için) |
| Merger | "Veri akışlarını birleştirir" | Birden fazla hattı tek hatta toplar |

**Dijital Katman Savunma Yapıları:**
| Yapı | Tooltip | Fonksiyon |
|------|---------|-----------|
| ICE | "Temel savunma bariyeri" | Gelen saldırıları durdurur |
| Black ICE | "Saldırganı geri hackler" | Savunma + karşı saldırı. Cycles tüketir |
| Daemon | "Otomatik savunma programı" | Bölgesini devriye gezer, virüs tespit eder |
| Trace Killer | "İzleri siler" | Trace seviyesini aktif olarak düşürür |
| Honeypot | "Sahte hedef" | Virüsleri kendine çeker, gerçek sistemi korur |
| Quarantine Node | "Enfekte alanı izole eder" | Virüslü bölgeyi karantinaya alır |

**Toplam: ~23 yapı tipi** (geliştirilecek)

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
- [B] Bant genişliği haritası
- [D] Hasar haritası

---

## 10. Savunma Sistemi

### Virüs/Saldırı Mekaniği
- Saldırılar **Trace seviyesine** bağlı
- Trace arttıkça saldırı dalgaları büyür ve sıklaşır
- Virüsler **dijital katmanda** yayılır
- Creeper World referansı: virüs = sıvı gibi ağ üzerinde yayılır
- Korunmasız node'lar "su altında kalır"

### Saldırı Kaynakları
- Data Siphon çekimi → Trace ↑ (temel)
- Decrypt işlemi → Trace ↑↑ (en karlı = en tehlikeli)
- Recover işlemi → Trace ↑
- Filtrelenmemiş Malware → doğrudan sızma

### Savunma + Otomasyon Bağlantısı
**Mindustry uyarısı:** Geç oyunda otomasyon ve savunma birbirinden kopmamalı.
**Çözüm:**
- Malware verisi dijital savunmanın kaynağı → otomasyon hattı savunmayı besliyor
- Virüsler otomasyon hattına hasar veriyor → savunma otomasyonu koruyor
- İkisi birbirinden ayrılamaz

### Savunmanın Scale'i
```
Küçük base → düşük Trace → küçük saldırılar → az savunma yeterli
Büyük base → yüksek Trace → büyük saldırılar → devasa savunma hattı gerekli
```

---

## 11. İlerleme ve Scale

### Rehberli Sandbox Modeli
- Shapez/Factorio referansı: oyunun kendisi sandbox, ama teknoloji ağacı yön veriyor
- Oyuncu kendi hızında ilerliyor ama hep bir "sonraki hedef" var
- Kazanma koşulu yok - sistem büyüdükçe talepler ve tehditler de büyüyor

### Scale Mekanikleri

**1. Veri Tier'ları (ana scale kaynağı):**
- Her tier öncekinin ~4 katı yapı gerektiriyor
- Tier 1 → Tier 4 arası üstel büyüme
- Oyun doğal olarak devasa base'ler yaratıyor

**2. Ağ Katmanları (Network Tiers):**
```
Tier 1 Ağ: Düşük hacim, çoğu clean, güvenli
Tier 2 Ağ: Orta hacim, daha fazla encrypted/corrupted
Tier 3 Ağ: Yüksek hacim, çoğu encrypted, malware riski
Tier 4 Ağ: Devasa hacim, neredeyse hepsi şifreli/tehlikeli
```
Her yeni ağ katmanı mevcut altyapının yetersiz kalmasına neden oluyor.

**3. Trace Otomatik Scale:**
- Büyüme → Trace ↑ → Büyük saldırı → Büyük savunma lazım → Daha çok altyapı → Daha çok büyüme → ...
- Sonsuz döngü, oyun kendi kendini scale ediyor

**4. Bileşik Ürünler (geç oyun - tasarlanacak):**
- Farklı hatlardan gelen işlenmiş verilerin birleştirilmesi
- Daha değerli son ürünler = daha karmaşık pipeline'lar

### Devasa Base Vizyonu (Geç Oyun)
```
┌──────────────────────────────────────────────────────┐
│ [SIPHON ÇİFTLİĞİ]                                   │
│  ■■■■■■■■■■■■                                        │
│     ↓                                                │
│ [SEPARATOR DİZİSİ]                                   │
│  ▣▣▣▣▣▣▣▣                                           │
│  ↓    ↓    ↓    ↓                                    │
│ [DEPO] [DEPO] [DEPO] [DEPO]                          │
│  ↓     ↓      ↓       ↓                             │
│ [DECRYPT DİZİSİ]  [RECOVER DİZİSİ]  [QUARANTINE]    │
│  ◆◆◆◆◆◆◆◆◆◆◆◆◆◆   ◇◇◇◇◇◇◇◇◇◇     ⬡⬡⬡⬡⬡⬡       │
│     ↓                  ↓              ↓              │
│ [ARA İŞLEM HATLARI - Parser, Analyzer, Compiler]     │
│     ↓                  ↓              ↓              │
│ [ÇIKTI] Credits    Research       Defense             │
│                                                      │
│ [POWER GRID]  ████████████████  [COOLING] ◎◎◎◎◎◎◎◎◎ │
│                                                      │
│ ═══════════════ SAVUNMA HATTI ═══════════════════    │
│ ⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡⬡       │
└──────────────────────────────────────────────────────┘
```

---

## 12. Görsel Tasarım

### Geometrik Fonksiyonellik (Şekillerin Dili)
Her şekle bir görev vererek oyuncunun ekranı bir bakışta "okumasını" sağla.
- **Daireler (Nodes):** Giriş ve çıkış noktaları. Verinin doğduğu ve bittiği yerler
- **Kareler (Logic):** Verinin manipüle edildiği yerler (filtreleme, şifreleme, ayrıştırma)
- **Üçgenler (Gates):** Verinin hangi yöne gideceğine karar veren switch noktaları
- **Altıgenler (Firewall):** Savunma kalkanları

### Veri Temsili: Hareketli 0/1 Parçacıkları
Node'lar arasındaki bağlantılarda akan küçük 0 ve 1'ler:
- **Yeşil 0/1:** Temiz veri (Clean)
- **Sarı 0/1:** Bozuk veri (Corrupted)
- **Mor 0/1:** Şifreli veri (Encrypted)
- **Kırmızı 0/1:** Zararlı veri (Malware)

### Arka Plan: Grid Sistemi
- Koyu gri/lacivert tonlarında hafif ızgara
- "Buraya bir şey koyabilirim" hissi verir
- Strateji/otomasyon alanı mesajı

### Shader ve Efektler
- **Bloom:** Çizgiler ve şekiller hafif parlama (neon etkisi)
- **CRT Shader:** Eski terminal hissi, tarama çizgileri, kenar bükülmesi
- **Glitch Effect:** Virüs saldırısında ekran "yırtılması"

### Fiziksel vs Dijital Katman Estetiği
```
Fiziksel Katman:              Dijital Katman:
─────────────────             ─────────────────
Koyu gri, metalik             Siyah arka plan
Gümüş, turuncu tonlar         Neon yeşil/mavi/mor
Somut, sıcak                  Soyut, soğuk
Duman, LED, fan dönüşü        Parçacık akışı, neon çizgiler
```

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
- Anchor (çapa): "Factorio/Mindustry benzeri otomasyon" (tanıdık)
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

### PlayWay Modeli (Referans)
- Hızlıca Steam sayfası oluştur → reklam yap → wishlist tepkilerine bak → en iyisini geliştir
- Data-driven karar verme

---

## 14. Referans Oyunlar

### Ana Referanslar

| Oyun | Steam Puanı | Neden Referans | Alınacak Ders |
|------|-------------|----------------|---------------|
| **Factorio** | %97 (224K+ yorum) | Otomasyon türünün kralı | İç içe geçen döngüler, "The Factory Must Grow", teknoloji ağacı |
| **Shapez** | %96 (14K+ yorum) | Minimalist otomasyon | Az yapı tipiyle derin oynanış, başlangıçta 2 yapı ile yumuşak giriş |
| **Mindustry** | %96 (24K+ yorum) | Otomasyon + Savunma hibriti | İki loop'un birleşimi ÇALIŞIYOR ama geç oyunda denge bozulabilir |
| **Creeper World 4** | %95 (3.7K+ yorum) | Benzersiz savunma mekaniği | Sıvı düşman = virüs yayılımı metaforu, savunmadan saldırıya geçiş |
| **Hacknet** | %94 (7.5K+ yorum) | Hacking estetigi | Terminal estetiği çalışıyor AMA tekrarcılık öldürücü |

### İkincil Referanslar
| Oyun | Alınacak Ders |
|------|---------------|
| **Zachtronics (TIS-100, EXAPUNKS)** | Optimizasyon metrikleri, histogram skorları, tekrar oynama motivasyonu |
| **Bitburner** | Meta-otomasyon ("otomasyonu otomatikleştirmek"), prestige sistemi |
| **while True: learn()** | Veri akışı görselleştirmesi, pipe-and-filter mekaniği |
| **Oxygen Not Included** | Çoklu kaynak dengeleme, kademeli açılma, heatmap overlay'ler |

### Kritik Uyarılar (Rakiplerden Dersler)

**Hacknet uyarısı:** Tekrarcılık öldürücü - her görev gerçekten farklı hissetmeli.

**Mindustry uyarısı:** Geç oyunda otomasyon ve savunma birbirinden kopmamalı. ~7. seviyeden sonra fabrika kısmı otomatikleşiyor ama daha ilginç olmuyor.

**Zachtronics uyarısı:** Gerçek programlama gerektirmek kitleyi daraltır. Oyun "programlama hissi" vermeli ama gerçek kod yazdırmamalı.

**Shapez uyarısı:** Tüm mekanikler açıldıktan sonra motivasyon düşebilir - endgame derinliği şart.

---

## 15. Açık Sorular ve Yapılacaklar

### Öncelikli Tasarım Soruları (Sonraki Session'larda Çözülecek)

**1. Veri İşleme Zinciri Derinliği** ⚠️ EN KRİTİK
- Şu anki zincir çok kısa (~3-4 aşama), hedef ~5-7 aşama
- Ara aşamaların (Parser, Analyzer, Compiler) tam tanımları yapılacak
- Decrypt sonrası veri ile ne yapılacağı netleştirilecek
- "Sadece filtreleme oyununa" dönüşmemesi için dönüşüm derinliği artırılacak
- Farklı hatlardan gelen verilerin birleşme noktaları tasarlanacak

**2. Yapı Listesi Tamamlama**
- Mevcut ~23 yapı, artırılabilir
- Her yapının net girdi/çıktı tanımı yapılacak
- Yapılar arası etkileşim matrisi oluşturulacak
- Görsel tasarımları (şekil, renk, boyut) belirlenecek

**3. Savunma Detayları**
- Virüs tipleri ve davranışları
- Saldırı dalgası mekaniği (nasıl tetiklenir, nasıl büyür)
- Savunma yapılarının detaylı fonksiyonları
- Creeper World sıvı yayılım mekaniğinin uyarlanması

**4. Ekonomi Dengeleme**
- Credits kazanım/harcama dengesi
- Yapı fiyatları ve açılma koşulları
- Veri tier'larının değer oranları
- Override mekaniğinin risk/ödül dengesi

**5. İlerleme Sistemi Detayları**
- Teknoloji ağacı yapısı
- Ağ katmanları açılma koşulları
- Yapı açılma sırası ve koşulları
- "Rehberli" kısmın nasıl çalışacağı

**6. Ek Kaynaklar / Mekanikler**
- Sadece 4 veri tipi ile yeterli derinlik sağlanabilir mi?
- Ek mekanikler gerekiyorsa neler olabilir?
- Bileşik ürünler sistemi

**7. Depolama Mekaniği**
- Storage kapasitesi ve yönetimi
- Dolu/boş depo etkileri
- Farklı depolama tipleri gerekli mi?

### Kesinleşmiş Kararlar ✅
- [x] 2D Top-Down perspektif
- [x] Godot 4.6 motoru
- [x] Fiziksel + Dijital iki katmanlı dünya (TAB geçiş)
- [x] Real-time with pause zaman mekaniği
- [x] Rehberli sandbox ilerleme
- [x] Cyberpunk/Netrunner teması
- [x] Cyberpunk isimlendirme + tooltip açıklama
- [x] 4 temel veri tipi: Clean, Corrupted, Encrypted, Malware
- [x] 3 altyapı kaynağı: Power, Heat (kötü), Trace (kötü)
- [x] Credits para birimi
- [x] Tier sistemi: yeni bina değil, daha fazla bina (üstel büyüme)
- [x] Veri renk kodlaması: Yeşil, Sarı, Mor, Kırmızı
- [x] Power Override mekaniği
- [x] Malware = dijital savunmanın kaynağı
- [x] Credits = fiziksel dünyanın para birimi
- [x] Corrupted data = araştırma/yeni yapı açma kaynağı
- [x] Encrypted data = premium gelir kaynağı
- [x] Diegetic aesthetic tasarım sütunu
- [x] Prosedürel asset'ler + shader efektleri

### Kesinleşmemiş / Geliştirilecek ❓
- [ ] Veri işleme zinciri ara aşamaları
- [ ] Tam yapı listesi ve fonksiyonlar
- [ ] Savunma mekaniği detayları
- [ ] Ekonomi dengeleme
- [ ] İlerleme / teknoloji ağacı
- [ ] Ek kaynaklar veya mekanikler
- [ ] Depolama detayları
- [ ] Bileşik ürünler sistemi
- [ ] Yapı okunabilirliği (şekil/renk) finalizasyonu
- [ ] Tutorial / onboarding akışı

---

*Bu döküman canlıdır ve her tasarım session'ında güncellenecektir.*
*İmplementasyona kesinleşmiş tasarım olmadan geçilmeyecektir.*
