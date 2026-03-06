# SYS_ADMIN — Game Design Evaluation
**Tarih:** 2026-03-06
**Değerlendiren:** Tecrübeli Game Designer Perspektifi
**Versiyon:** GDD v0.8 + Refactor Faz 6 sonrası

---

## GENEL PUAN: 8/10

Sağlam bir çekirdek tasarım, doğru mimari kararlar, iyi referans seçimi. Ekonomi ve onboarding tarafı güçlendirilirse Steam Next Fest'te dikkat çekme potansiyeli yüksek.

---

## 1. Çekirdek Fantezi ve Tema Uyumu — 9/10

Oyunun en güçlü yanı **tema ile mekanik arasındaki bütünlük.** "Siberuzayda veri madenciliği" konsepti, otomasyon türünün "kaynak çıkar → işle → sat" döngüsüne birebir oturuyor.

**Güçlü noktalar:**
- Content + State veri modeli, cyberpunk temasını **mekanik düzeyinde** destekliyor
- Power/Heat sisteminin kaldırılması doğru karar — siberuzayda fiziksel ısı absürt olurdu
- Yapı isimleri (Uplink, Decryptor, Quarantine) doğrudan cyberpunk dünyasına ait

**Risk:**
- "Netrunner" fantezisi şu an pasif. Oyuncu fabrika müdürü gibi hissediyor, netrunner gibi değil
- **Öneri:** Kaynak keşfinde kısa bir "hack" animasyonu/ritüeli, "içeri sızdım" hissini güçlendirir

---

## 2. Content + State Veri Modeli — 10/10

Bu oyunun **en parlak tasarım kararı.** İki boyutlu veri modeli çarpımsal karmaşıklık yaratıyor — Shapez'in Shape x Color modelinin doğrudan karşılığı.

**Neden mükemmel:**
- 6 content x 4 state = 24 temel kombinasyon, tier'larla yüzlerce
- Her yeni content tipi eklemek **bedava karmaşıklık** üretiyor
- Oyuncu "Financial Data (Encrypted T2)" gördüğünde hem ne olduğunu hem ne yapması gerektiğini anlıyor
- Separator'ın iki modu (state/content) oyuncuya routing kararı veriyor

**Küçük endişe:**
- 6 content tip demo için fazla olabilir. Demo sınırlarında **3-4 content tip** yeterli

---

## 3. Çekirdek Döngü — 8/10

"Keşfet → Çek → Ayır → İşle → Kullan → Genişle → Optimize Et" döngüsü sağlam.

**Güçlü:**
- Her adım bir öncekine bağımlı ama oyuncu sırayı kendisi belirliyor
- "Bir Şey Daha" faktörü güçlü tasarlanmış
- Darboğaz → Optimize döngüsü otomasyon türünün kanıtlanmış dopamin kaynağı

**Zayıf noktalar:**

### a) Erken oyun onboarding boşluğu
ISP Backbone'dan Standard Data (Clean) çekip satmak çok düz bir deneyim. Uplink → Data Broker, bitti.
- **Öneri:** İlk kaynağa bile %10-15 Corrupted veya Encrypted karıştırın

### b) Malware'in imha-only olması düz
Quarantine verinin %100'ünü yok ediyor. Mekanik olarak "sorun gör → sil" döngüsü.
- **Öneri:** Malware'den kısmi veri kurtarma (%10-30) veya Corrupted'a dönüşme zincirleme ihtiyacı

---

## 4. Yapı/Bileşen Mimarisi — 9/10

Component-based mimari teknik olarak mükemmel ve oyun tasarımına doğrudan fayda sağlıyor.

**Neden iyi:**
- Yeni yapı = mevcut component'lerin birleşimi
- Port sistemi evrensel
- Balance kolaylaştırıyor

**Öneri:** Demo'da başlangıçta sadece 4-5 yapı açık olsun, diğerleri Research ile açılsın

---

## 5. Harita ve İlerleme Sistemi — 8/10

Ring-based zorluk sistemi iyi çalışıyor.

**Güçlü:**
- Seed-based prosedürel üretim = her oyun farklı
- Ring 0 auto-discover, dışarısı keşif gerektiriyor
- 8 kaynak tipi yeterli çeşitlilik sunuyor

**Endişeler:**

### a) Lojistik boyut eksik
Kablo mesafe sınırı yok. Uzak kaynakların ekstra zorluğu yok.
- **Öneri:** Kablo spaghetti'yi estetik zorluk olarak kabul edin (Factorio paraleli)

### b) Keşif motivasyonu
- **Öneri:** Keşfedilmemiş kaynakların siluet/sinyal göstermesi oyuncunun merakını tetikler

---

## 6. Ekonomi Sistemi — 6/10 (En Zayıf Alan)

### Sorunlar:

### a) Yapı maliyeti yok = kaynak baskısı yok
Oyuncu sonsuz yapı koyabiliyor. Kararların ağırlığı yok.
- **Kritik öneri:** Demo'da bile basit bir maliyet sistemi olmalı

### b) Üç kaynak birbirinden bağımsız
Credits, Research, Patch Data arasında seçim baskısı yok.
- **Öneri:** Bazı upgrade'ler hem Patch Data hem Credits istesin

### c) Content fiyatlandırma aralığı çok geniş
Standard=1x vs Classified=10x — oyuncu Standard'ı görmezden gelir.
- **Öneri:** Fiyat aralığını daraltın (1x-5x) veya Standard'ın hacimsel avantajını vurgulayın

---

## 7. Kısıt Derinliği — 7/10

**Mevcut kısıtlar:**
1. Content + State karmaşıklığı ✅ (güçlü)
2. Throughput darboğazı ✅ (güçlü)
3. Storage doluluk ✅ (orta)
4. Ekonomi ❌ (henüz aktif değil)
5. Harita mesafesi ⚠️ (kablo sınırı yok)

**Öneri:** Tier sistemi (Encrypted T1 → T4 arası 4x yapı gereksinimi) oyunun can damarı. Demo'da en az T1-T2 farkı hissedilmeli.

---

## 8. Separator Tasarımı — 9/10

İki modlu Separator çok akıllı bir tasarım kararı.

**Neden çalışıyor:**
- State modu + Content modu = zincirleme routing problemi
- İki Separator zincirleme = önce state ayır, sonra content ayır

**Küçük sorun:** %60 verimlilik başlangıcı hayal kırıklığı yaratabilir.
- **Öneri:** Kaybı "overhead" olarak frame'leyin, "kayıp" değil

---

## 9. Oyuncu Deneyimi (UX Flow) — 7/10

**İyi:**
- Yerleştirme → bağlama → akış görme döngüsü sezgisel
- Prosedürel görsel + shader efektleri cyberpunk atmosferini ucuza yaratıyor
- Undo/Redo sistemi chill deneyim için şart

**Endişeler:**

### a) Geri bildirim döngüsü yavaş
1 saniyelik tick + işleme süresi = 5-10 saniye bekleme.
- **Öneri:** Parçacık akışı tick'ten bağımsız sürekli olsun

### b) Bilgi yoğunluğu
6 content, 4 state, tier'lar, 10+ yapı...
- **Öneri:** Demo'ya minimal guided first run ekleyin (4 adımlık, 2 dakikalık rehber)

---

## 10. Steam Next Fest Demo İçin Kritik Öncelikler

| Öncelik | Öğe | Neden |
|---------|-----|-------|
| **P0** | Yapı maliyet sistemi (basit bile olsa) | Karar verme baskısı olmadan oyun sandbox tool hissediyor |
| **P0** | İlk 5 dakika deneyimi (guided start) | Steam Fest'te oyuncu 10 dakikadan fazla vermez |
| **P1** | Gig sistemi (en az 3-5 basit gig) | "Ne yapmalıyım?" sorusuna yanıt |
| **P1** | Content tipi sayısını demo'da sınırla (3-4) | Bilişsel yükü azalt |
| **P2** | Tier farkını göster (en az T1 vs T2) | Üstel büyüme hissini ver |
| **P2** | Ses efektleri (minimal) | Geri bildirim döngüsünü güçlendir |

---

## ÖZET

| Alan | Puan | Durum |
|------|------|-------|
| Tema Uyumu | 9/10 | Mükemmel — mekanik ve tema bütünleşik |
| Veri Modeli | 10/10 | Oyunun en güçlü yanı |
| Çekirdek Döngü | 8/10 | Sağlam, erken oyun iyileştirmesi gerekli |
| Mimari | 9/10 | Teknik olarak örnek gösterilebilir |
| Harita Sistemi | 8/10 | İyi, lojistik boyut düşünülebilir |
| Ekonomi | 6/10 | En zayıf alan — demo öncesi iyileştirilmeli |
| Kısıt Derinliği | 7/10 | Yeterli ama ekonomi ile güçlenmeli |
| Separator | 9/10 | Çok akıllı tasarım kararı |
| UX Flow | 7/10 | Onboarding ve geri bildirim iyileştirilmeli |
| **GENEL** | **8/10** | **Güçlü temel, ekonomi ve onboarding odaklı iyileştirme gerekli** |

---

**En Büyük Güç:** Content + State veri modeli — sonsuz genişletilebilirlik ve doğal karmaşıklık eğrisi.

**En Büyük Risk:** Ekonomi sistemi eksikliği ve erken oyun deneyiminin düzlüğü. Demo'da oyuncunun "bu oyunda kararlarım önemli" hissini yaşaması şart.
