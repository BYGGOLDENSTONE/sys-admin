# SYS_ADMIN — Game Design Document

**Versiyon:** 2.0 (Tam Yeniden Tasarim)
**Son Guncelleme:** 2026-03-07
**Motor:** Godot 4.6
**Hedef:** $9.99, 100K+ satis, Steam Next Fest Haziran 2026

---

## ICINDEKILER

1. [Oyun Ozeti](#1-oyun-ozeti)
2. [Tasarim Sutunlari](#2-tasarim-sutunlari)
3. [Cekirdek Dongu](#3-cekirdek-dongu)
4. [Sutun 1: Grid Kablo Routing](#4-sutun-1-grid-kablo-routing)
5. [Sutun 2: Zengin Mekanik Seti](#5-sutun-2-zengin-mekanik-seti)
6. [Sutun 3: Gorsel Kimlik](#6-sutun-3-gorsel-kimlik)
7. [Veri Modeli: Content + State](#7-veri-modeli-content--state)
8. [Ekonomi: Veri = Malzeme](#8-ekonomi-veri--malzeme)
9. [Yapi Detaylari](#9-yapi-detaylari)
10. [Harita ve Kaynaklar](#10-harita-ve-kaynaklar)
11. [Ilerleme Sistemi](#11-ilerleme-sistemi)
12. [Kisit ve Zorluk](#12-kisit-ve-zorluk)
13. [Gig Sistemi](#13-gig-sistemi)
14. [Gorsel Tasarim Detaylari](#14-gorsel-tasarim-detaylari)
15. [Referans Oyunlar](#15-referans-oyunlar)
16. [Pazar Stratejisi](#16-pazar-stratejisi)
17. [Kapsam ve Yol Haritasi](#17-kapsam-ve-yol-haritasi)
18. [Acik Sorular](#18-acik-sorular)

---

## 1. Oyun Ozeti

**SYS_ADMIN**, oyuncunun siberuzayda veri kaynaklarini kesfedip, grid tabanli kablo routing ile parlayan veri pipeline'lari kurdugu 2D top-down chill otomasyon oyunudur. Oyuncunun fabrikasi yukaridan bakildiginda canli bir devre kartina benzer.

**Tek Cumle:** "Siberuzayda devre karti gibi veri fabrikalari tasarla — her kaynak yeni bir muhendislik bulmacasi."

**Temel Fantezi:** Koyu bir arka plan uzerinde, senin tasarladigin neon kanallardan renkli veri nehirleri akiyor. Her yeni kaynak farkli bir bulmaca sunuyor. Zoom out yaptiginda kocaman, parlayan bir devre karti goruyorsun — ve onu sen tasarladin.

**Tur:** Chill Otomasyon
**Perspektif:** 2D Top-Down
**Tema:** Cyberpunk / Netrunner / Siberuzay
**Hedef:** Rehberli Sandbox — kazanma kosulu yok, surekli optimize et

**Ana Referanslar:**
- **Factorio:** Grid routing, mekansal bulmacalar, bant yonetimi
- **Satisfactory:** Kaynak → malzeme → uretim dongusu, Assembler (coklu girdi)
- **Shapez:** Kademeli bulmaca karmasikligi, chill otomasyon

---

## 2. Tasarim Sutunlari

### Sutun 1: Fabrikan Bir Devre Karti
Oyuncunun yaratimi yukaridan bakildiginda guzel, canli bir devre karti gibi gorunmeli. Parlayan kanallar, titreyen binalar, akan veri nehirleri. Screenshot'lar "bu ne guzel sey?" dedirtmeli.

### Sutun 2: Basit Ogren, Derin Ustalan
Her mekanik sezgisel ("sifreli dosya icin anahtar lazim" — herkes anlar). Ama birlestirildiklerinde gercek muhendislik bulmacalari yaratirlar. Karmasiklik bireysel mekanikten degil, KOMBINASYONDAN gelir.

### Sutun 3: Her Kaynak Yeni Bir Bulmaca
Yakin kaynaklar basit (tek veri tipi, kolay durum). Uzak kaynaklar karmasik (coklu tip, zor durumlar, yuksek tier). Her yeni kaynak genuinely farkli pipeline tasarimi gerektirir.

### Sutun 4: Layout = Oyun
Kablolar grid uzerinde fiziksel yer kaplar, serbestce kesilemez. Yerlesim planlamak hangi binayi kullanacagin kadar onemli. Factorio'nun bant sistemini bu kadar bagimlastiran sey budur.

---

## 3. Cekirdek Dongu

### Ana Akis: "Kesfet → Cek → Ayir → Isle → Biriktir → Uret → Genisle"

```
[KESFET]   — Haritada yeni veri kaynagi bul
     |
[CEK]      — Uplink kur, veri cekmeye basla
     |
[SINIFLA]  — Classifier ile content tiplerini ayir (Biometric/Financial/...)
     |
[AYIR]     — Her tip icin Separator ile state ayir (Clean/Encrypted/Corrupted/Malware)
     |
[ISLE]     — Duruma gore isle:
     |         Decryptor (sifreyi kir — Key gerekli!)
     |         Recoverer (bozugu kurtar — %70 basari, %30 atik!)
     |         Quarantine (malware'i imha et — dolunca flush!)
     |
[BIRIKTIR] — Clean veri → Storage (malzeme havuzu)
     |
[BIRLESTIR]— Compiler ile 2 farkli Clean → 1 Refined malzeme
     |
[URET]     — Malzeme harcayarak yeni yapi uret
     |
[GENISLE]  — Yeni yapilarla yeni kaynaklara eris
     |
[OPTIMIZE] — Darbogaz? Kablo rotasini degistir, paralel hat kur
```

### Satisfactory Paraleli

```
Satisfactory:                    SYS_ADMIN:
Demir Cevheri → Erit → Ingot    Financial(Encrypted) → Decrypt → Financial(Clean)
Bakir Cevheri → Erit → Ingot    Blueprint(Corrupted) → Recover → Blueprint(Clean)
Ingot + Ingot → Assembler        Clean + Clean → Compiler → Refined
Refined → Makine uret            Refined → Yapi uret
Yeni makine → Yeni cevher        Yeni yapi → Yeni kaynak
```

### Temel Gerilim
**"Degerli kaynaklar her yerde olabilir — goruyorsun ama isleyemiyorsun. Isleyebilmek icin once daha basit kaynaklardan malzeme biriktirmen lazim."**

### Bagimlilik Dongusu
> "Hemen yanımda bir Askeri Ag var... Classified Data goruyorum... ama Encrypted T3, Decryptor'um bile yok... Decryptor icin Research lazim, Hastane Terminali'ni gordum biraz otede... ama oraya hat cekmek icin mevcut kablolarimin arasından rota bulmam lazim..."

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
- Kesisme icin **Bridge** binasi gerekli
- Binalarin port pozisyonlari sabit (giris sol, cikis sag vb.)
- Veri kablo boyunca akar (aninda degil, gorulebilir sekilde)

**Ornek — Once vs Sonra:**

```
ONCE (noktadan noktaya):         SONRA (grid routing):

  [Uplink]--------[Separator]      [Uplink]═══╗
       |               |                      ║
  [Storage]-------[Decryptor]      [Separator]═╬═══[Decryptor]
                                              ║         ║
  (kablolar havada gecer,          [Storage]══╝    [Storage]
   kesisme sorun degil)
                                   Kablolar yer kapliyor!
                                   Rota planla!
```

### Bridge (Kopru) Binasi
- Iki kablonun kesismesi gerektiginde araya konur
- Maliyeti: 10 Standard(Clean)
- Isleme yapmaz — saf altyapi
- Bir kablo yatay, digeri dikey gecer
- Iyi tasarim = az kopru = verimli layout

### Kablo Yerlestirme UX (Kritik — Oyunun Hissi Buna Bagli)

Kablo dosemek oyunun en sik yapilan eylemi. Akici ve tatmin edici olmali.

**Temel Interaksiyon:**
- Tikla-surukle ile kablo doser (Factorio belt modeli)
- Surukleme yonu otomatik yon belirler
- Koseler otomatik olusur (L-seklinde surukle = otomatik kose)
- Baslangic/bitis noktasi bina portlarina snap'lenir
- Ghost onizleme: dosenmeden once rota yesil/kirmizi gosterilir (gecerli/gecersiz)

**Hizli Duzenleme:**
- Sag tikla kablo segmentini siler
- Alan secimi ile toplu silme (dikdortgen secim)
- Ctrl+Z undo destegi (kablo doseme geri alinabilir)
- Mevcut kabloyu "itmek" icin surukle (yol degistirme kolayligi)

**Akilli Yardimlar:**
- Otomatik yol onerisi: bina A'dan bina B'ye tikla, en kisa geçerli rota onerilir
- Oyuncu oneriyi kabul edebilir veya manuel doseyelibilir
- Mevcut kablolari otomatik olarak bypass eder (mumkunse)

**Neden Bu Kadar Onemli:**
Factorio'da bant dosemek ZEVKLI cunku akici. Klunky kablo doseme = oyuncu routing'den nefret eder. Bu UX oyunun kalbi.

### Neden Bu Her Seyi Degistirir
- Yerlesim planlamasi = ana bulmaca
- Alan = kaynak — kompakt tasarimlar verimli ama routing zor
- Yeni kaynak ekleme = mevcut kablo aginin icinden yeni rota bulma
- Zoom-out gorunumu = parlayan devre karti = "factory porn"

---

## 5. Sutun 2: Zengin Mekanik Seti

### Problem
Tum isleme binalari ayni mekanik: girdi → cikti kutusu. Cesitlilik yok.

### Cozum: Her Bina Genuinely Farkli Mekanik

| Bina | Fiil | Benzersiz Mekanik | Dusunme Turu |
|------|------|-------------------|-------------|
| **Uplink** | Cek | Kaynaktan veri cikarir | Kaynak secimi |
| **Classifier** | Sinifla | N cikis, content tipine gore dagit | Dagitim planlama |
| **Separator** | Ayir | 4 cikis, state'e gore dagit | Dagitim planlama |
| **Decryptor** | Coz | CIFT GIRDI: veri + key gerekli | Lojistik senkronizasyon |
| **Recoverer** | Kurtar | OLASILIKSAL: %70 basari + %30 atik | Risk/atik yonetimi |
| **Quarantine** | Imha et | DOLULUK/FLUSH: kapasite dolar, bosaltma suresi var | Buffer zamanlama |
| **Compiler** | Birlestir | CIFT GIRDI: 2 farkli Clean → 1 Refined | Lojistik senkronizasyon |
| **Replicator** | Kopyala | 1 → 2 kopya (yavas ama degerli) | Maliyet/fayda analizi |
| **Research Lab** | Uret | Research(Clean) tuketir → Key uretir | Tedarik zinciri |
| **Storage** | Depola | Buffer, Clean = malzeme havuzu | Kaynak planlama |
| **Splitter** | Bol | 1→2 esit dagitim | Paralel hat tasarimi |
| **Merger** | Birlestir | 2→1 akis toplama | Paralel hat tasarimi |
| **Bridge** | Gecir | Kablo kesisme noktasi | Mekansal bulmaca |
| **Gig Board** | Sozlesme | Gorev terminali, odul verir | Hedef belirleme |

**14 bina, 9 genuinely farkli dusunme turu.** Mevcut tasarimdaki 2'den (ayir + temizle) buyuk siçrama.

---

## 6. Sutun 3: Gorsel Kimlik

### Problem
Dikdortgenler + ince cizgiler + kucuk noktalar $9.99 icin yeterince cekici degil.

### Cozum: Canli Devre Karti Estetigi

**Kablolar → Veri Otoyollari:**
- Grid hucresi boyutunda parlayan kanallar (ince cizgi degil!)
- Ic renk = akan verinin dominant state'i (yesil/mavi/turuncu/kirmizi)
- Icinden semboller akar: $ @ # ? ! 0/1
- Yogun trafik = parlak, bos = sonuk
- Koseler ve kavsaklar yumusak gecisli

**Binalar → Canli Makineler:**
- Calisirken animasyonlu (donen elementler, yanip sonen ekranlar, port flash'lari)
- Bostayken sonuk ve hareketsiz (kontrast = anlam)
- Asiri yuklendiginde kirmizi uyari parlamasi
- Her binanin benzersiz silueti (zoom-out'da bile taninabilir)

**Zoom Seviyeleri:**
- **Uzak:** Parlayan devre karti manzarasi — STEAM SCREENSHOT SEVIYESI
- **Orta:** Binalar, kanallar, veri akisi gorunur
- **Yakin:** Bireysel paketler, bina detaylari, port aktivitesi

**Hedef:** Oyuncunun fabrikasi ekran goruntusu olarak Reddit'e atildiginda "bu ne guzel sey, ne oyunu bu?" dedirtmeli.

---

## 7. Veri Modeli: Content + State

### Temel Prensip
Her veri paketi iki boyutlu:
- **Content (Icerik):** Verinin NE oldugu → malzeme turunu belirler
- **State (Durum):** Verinin NE HALDE oldugu → isleme yolunu belirler

### Content Tipleri (6)

| Content | Kaynak Ornekleri | Malzeme Rolu | Gorsel Sembol |
|---------|-----------------|--------------|---------------|
| **Standard** | Otomat, Trafik Kamerasi | Temel yapilar | 0/1 |
| **Financial** | ATM, Corporate Server | Orta seviye yapilar | $ |
| **Biometric** | Akilli Kilit, Hastane | Ozel yapilar | @ |
| **Blueprint** | Corporate, Devlet, Askeri | Ileri yapilar | # |
| **Research** | Hastane, Biyotek, Devlet | Key uretimi + ileri | ? |
| **Classified** | Bank, Askeri, Blackwall | Endgame yapilar | ! |

### State Tipleri (4)

| State | Anlami | Isleyici Bina | Depolama Maliyeti | Gorsel Renk |
|-------|--------|---------------|-------------------|-------------|
| **Clean** | Kullanima hazir | Yok — direkt malzeme | 1 MB/paket | Yesil |
| **Encrypted** | Kilitli, anahtar lazim | Decryptor (Key gerekli) | 2 MB/paket | Mavi |
| **Corrupted** | Hasarli, kismen kurtarilabilir | Recoverer (%70 basari) | 3 MB/paket | Turuncu |
| **Malware** | Tehlikeli, imha edilmeli | Quarantine (doldur/bosalt) | DEPOLANAMAZ | Kirmizi |

### State Tier Sistemi

Her state'in (Clean haric) zorluk kademesi var:

**Encrypted Tier'lari:**
```
T1 (4-bit):     1 Decryptor yeterli, 1 Key/paket
T2 (16-bit):    1 Decryptor ama yavas, 2 Key/paket
T3 (256-bit):   Paralel Decryptor gerekli (Splitter → NxDecryptor → Merger), 4 Key/paket
T4 (Kuantum):   Endgame challenge
```

**Corrupted Tier'lari:**
```
T1 (%10 hasar):  Recoverer %80 basari
T2 (%30 hasar):  Recoverer %60 basari
T3 (%60 hasar):  Recoverer %40 basari, bol atik
T4 (%90 hasar):  Recoverer %20 basari
```

**Malware Tier'lari:**
```
T1 (Worm):       Standart karantina, 1 MB/paket
T2 (Trojan):     2 MB/paket, daha hizli dolar
T3 (Ransomware): 5 MB/paket, cok hizli dolar
T4 (Rootkit):    10 MB/paket, flush daha uzun surer
```

### Carpimsal Derinlik
6 content x 4 state x 4 tier = ~96 varyant. Her kaynak benzersiz karisim → her kaynak benzersiz bulmaca.

---

## 8. Ekonomi: Veri = Malzeme

### Para Birimi Yok — Veri = Para
Credits, Research Points, soyut para birimi yok. Storage'daki Clean veri = malzeme stogun.

### Malzeme Hiyerarsisi

**Ham Malzeme (Storage'daki Clean veri):**

| Malzeme | Nereden Gelir | Ne Uretir |
|---------|--------------|-----------|
| Standard(Clean) | Her yerde, bol | Storage, Bridge, temel seyler |
| Financial(Clean) | ATM, Corporate | Orta seviye yapilar |
| Biometric(Clean) | Akilli Kilit, Hastane | Ozel yapilar |
| Blueprint(Clean) | Corporate, Devlet | Ileri yapilar |
| Research(Clean) | Hastane, Biyotek | Research Lab yakit + ileri |
| Classified(Clean) | Askeri, Blackwall | Endgame yapilar |

**Refined Malzeme (Compiler'dan):**

| Refined Malzeme | Tarif (Compiler) | Kullanimlar |
|----------------|-----------------|-------------|
| **Calibrated Data** | Standard + Biometric | Bina upgrade'leri |
| **Recovery Matrix** | Blueprint + Standard | Recoverer upgrade'leri |
| **Security Core** | Research + Blueprint | Quarantine yapimi + upgrade |
| **Trade License** | Financial + Classified | Gig Board yapimi |
| **Neural Index** | Biometric + Research | Research Lab upgrade'leri |
| **Recycled Data** | Residue + Research | Atik geri donusumu → Standard(Clean) |

**Onemli:** Decryption Key'ler Research Lab tarafindan uretilir (Compiler'dan degil). Research Lab, Research(Clean) tuketir → Key uretir. Decryptor surekli Key tuketir = Research Lab surekli calismali = aktif tedarik zinciri.

### Yapi Maliyetleri

| Bina | Maliyet | Ne Zaman Acilir |
|------|---------|-----------------|
| Uplink | Ilk bedava, sonraki 50 Standard | Oyun basi |
| Storage | 30 Standard | Oyun basi |
| Separator | Bedava (baslangic seti) | Oyun basi |
| Splitter | 20 Standard | Oyun basi |
| Merger | 20 Standard | Oyun basi |
| Bridge | 10 Standard | Oyun basi |
| Classifier | 40 Standard + 20 Biometric | 2. content kesfi |
| Recoverer | 30 Biometric + 20 Standard | Corrupted kesfi |
| Research Lab | 50 Research | Research kesfi |
| Decryptor | 40 Research + 30 Financial | Encrypted kesfi |
| Compiler | 40 Blueprint + 30 Standard | 3+ content kesfi |
| Replicator | 50 Blueprint + 30 Research | Blueprint kesfi |
| Quarantine | 1 Security Core | Malware kesfi |
| Gig Board | 1 Trade License | Classified kesfi |

**NOT:** Degerler dengeleme testleriyle ayarlanacak. Model onemli, rakamlar degil.

---

## 9. Yapi Detaylari

### UPLINK — "Veri cikarici"
- Haritadaki kaynak node'unun yanina yerlestirilir
- Kaynaktan veri ceker (kaynağin bandwidth hizinda)
- Cikti: kaynağin content+state dagilimina gore karisik paketler
- Tek cikis portu (sag)
- Her pipeline'in baslangic noktasi

### CLASSIFIER — "Icerik ayirici"
- Gelen veriyi CONTENT TIPINE gore ayirir
- N cikis portu — her tespit edilen content tipi icin bir cikis
- Ornek: Financial+Biometric aliyorsa 2 cikis portu aktif
- Veriyi DEGISTIRMEZ — saf routing
- Tooltip: "Veriyi turune gore yonlendirir — Financial bir yone, Biometric baska yone"

### SEPARATOR — "Durum ayirici"
- Gelen veriyi STATE'e gore ayirir
- 4 cikis portu: Clean, Encrypted, Corrupted, Malware
- Bagli olmayan portlardaki veri YOK EDILIR (kasitli secim)
- Tooltip: "Veriyi durumuna gore yonlendirir — temiz, sifreli, bozuk veya enfekte"

### DECRYPTOR — "Sifre kirici" (CIFT GIRDI)
- IKI giris portu: Veri (sol) + Key (ust)
- Encrypted veri + Decryption Key → Clean veri
- Key tuketimi: T1=1, T2=2, T3=4 Key/paket
- Key yoksa bina DURUR, veri kuyrukta bekler
- Cikti: Clean veri (content tipi korunur)
- Tooltip: "Sifreyi kirar. Research Lab'dan Decryption Key gerektirir."

**Ornek pipeline:**
```
Research Lab (Key uretir) ═══╗
                              ╠══ Decryptor ══ Clean cikti
Encrypted veri ══════════════╝
```

### RECOVERER — "Veri kurtarici" (OLASILIKSAL + YAN URUN)
- Tek giris: Corrupted veri
- IKI cikis portu: Clean (sag) + Residue (alt)
- Basari orani tier'a bagli: T1=%80, T2=%60, T3=%40, T4=%20
- Basarili → Clean veri (content korunur)
- Basarisiz → Residue (dijital atik)
- Residue portu bagli degilse → dahili buffer (10 MB) dolunca bina DURUR
- Tooltip: "Bozuk veriyi kurtarmayi dener. Her zaman basarili olmaz — dijital atik uretir."

**Ornek pipeline:**
```
Corrupted veri ══ Recoverer ═══ Clean cikti (%70)
                          ╚═══ Residue (%30) → Quarantine veya Compiler (geri donusum)
```

### QUARANTINE — "Malware firini" (DOLULUK/FLUSH)
- Tek giris: Malware verisi + Recoverer'dan Residue
- CIKIS YOK (veri imha edilir)
- 50 MB dahili kapasite
- Dolunca → FLUSH modu (5 saniye, giris kabul etmez)
- Flush sirasinda upstream pipeline tiKANIR — buffer planla!
- Yuksek tier malware daha hizli doldurur
- Tooltip: "Malware ve dijital atigi guvenle imha eder. Dolunca bosaltma suresi gerekir."

### COMPILER — "Malzeme birlestirici" (CIFT GIRDI)
- IKI giris portu: Malzeme A (sol) + Malzeme B (ust)
- 2 farkli Clean veri tipi → 1 Refined malzeme
- Tarif otomatik algilanir (bagli girdilere gore)
- Yanlis kombinasyon → veri reddedilir
- Cikti: Refined malzeme (Storage'da ayri depolanir)
- Tooltip: "Iki farkli temiz veri turunu ileri malzemeye donusturur."

### REPLICATOR — "Veri kopyalayici" (BENZERSIZ DIJITAL MEKANIK)
- Tek giris, IKI cikis (orijinal + kopya)
- Herhangi bir veri paketinin kusursuz kopyasini olusturur
- **YAVAS: 2 MB/s** (kasitli darbogaz)
- Nadir veriler icin degerli (Classified, yuksek tier Blueprint)
- Hicbir otomasyon oyununda kaynak kopyalama yok — dijital dunyaya ozel
- Tooltip: "Veriyi kopyalar. Yavas ama guclu — nadir kaynaklari cogalt."

### RESEARCH LAB — "Anahtar fabrikasi"
- Tek giris: Research(Clean)
- Cikti: Decryption Key'ler
- 5 MB Research(Clean) tuketir → 1 Key uretir
- Key'ler kablo ile Decryptor'lara gider
- Tooltip: "Arastirma verisini sifre cozme anahtarina donusturur."

### STORAGE — "Veri deposu"
- Her tur veriyi depolar
- Clean veri = global malzeme havuzu (yapi uretimi icin)
- State'e gore yer: Clean=1, Encrypted=2, Corrupted=3 MB/paket
- Malware DEPOLANAMAZ (otomatik reddedilir)
- Kapasite: 100 MB (upgrade edilebilir)
- Tooltip: "Veri depolar. Temiz veri burada yapi malzemesi olarak kullanilir."

### SPLITTER — "Akis bolici"
- 1 giris → 2 cikis (esit dagitim, donusumlu)
- Paralel isleme icin kullanilir (or: 4x Decryptor setup)
- Tooltip: "Veri akisini iki cikisa esit boler."

### MERGER — "Akis birlestirici"
- 2 giris → 1 cikis (donusumlu)
- Paralel isleme ciktilarini yeniden birlestirme
- Tooltip: "Iki veri akisini tek akista birlestirir."

### BRIDGE — "Kablo koprüsü"
- Iki kablonun kesismesi gereken yere konur
- Isleme yapmaz — saf altyapi
- Bir kablo yatay, digeri dikey gecer
- Tooltip: "Kablolarin girisim olmadan kesismesini saglar."

### GIG BOARD — "Sozlesme terminali"
- Bolgedeki mevcut gig'leri (gorevleri) gosterir
- Her gig: "X miktar Y veri isle/teslim et"
- Veri HARCANMAZ — throughput sayilir, veri sistemde kalir
- Tamamlaninca bonus odul
- Tooltip: "Sozlesme al, odul kazan. Veri harcanmaz, sadece sayilir."

---

## 10. Harita ve Kaynaklar

### Harita Yapisi
- 512x512 grid
- Prosedürel uretim (seed-based, her oyunda farkli)
- **Rastgele dagitim** — ring/bolge sistemi YOK
- Sis perdesi (fog of war): kesfedilmemis alanlar gizli
- Yakin bina yerlestirme ile kesif
- Kaynaklar tukenmez (chill otomasyon, stres yok)

### Tasarim Felsefesi: Factorio/Satisfactory Modeli
Kaynaklar haritaya **rastgele sacilmis.** Zorluk konumdan degil, kaynağin TIPINDEN gelir. Bir ATM kolay, bir Askeri Ag zor — nerede olurlarsa olsunlar.

**Neden ring sistemi degil:**
- **Merak:** Yanindaki Askeri Ag'i goruyorsun ama isleyemiyorsun — "bir gun orayi cozeceğim"
- **Oyuncu secimi:** Hangi yone gidecegini SEN seciyorsun, oyun seni merkezden disa zorlamiyor
- **Replayability:** Her seed genuinely farkli strateji gerektirir
- **Benzersiz fabrikalar:** Herkesin kablo agi farkli gorunur — Reddit'e atilan her screenshot benzersiz
- **Referans:** Factorio, Satisfactory, Mindustry — hicbiri ring sistemi kullanmiyor

### Kaynak Tipleri ve Zorluklari

Her kaynak SOMUT ve AKILDA KALICI isme sahip. Zorluk kaynağin tipine bagli, konumuna degil.

**Kolay Kaynaklar (1 content, basit state'ler):**

| Kaynak | Content | State'ler | Karmasiklik |
|--------|---------|-----------|-------------|
| **Otomat** | Sadece Standard | %100 Clean | En basit — sadece bagla ve depola |
| **ATM** | Sadece Financial | %70 Clean, %30 Corrupted | State ayirma ogren |
| **Akilli Kilit** | Sadece Biometric | %80 Clean, %20 Corrupted | Tek tip, basit state |
| **Trafik Kamerasi** | Standard + Biometric | Cogu Clean | 2 content — Classifier ogren |

**Orta Kaynaklar (2-3 content, karisik state'ler):**

| Kaynak | Content | State'ler | Karmasiklik |
|--------|---------|-----------|-------------|
| **Hastane Terminali** | Biometric + Research | Clean + Encrypted T1 | Ilk Encrypted — Decryptor lazim |
| **Halk Kutuphanesi** | Standard + Research | Clean + Corrupted | Research kaynagi, basit state'ler |
| **Magaza Sunucusu** | Standard + Financial + Biometric | Clean + Corrupted karisik | 3 content — Compiler lazim |
| **Biyotek Labi** | Biometric + Research + Blueprint | Corrupted + Encrypted T1 | Karisik isleme |

**Zor Kaynaklar (2-4 content, agir state'ler, yuksek tier):**

| Kaynak | Content | State'ler | Karmasiklik |
|--------|---------|-----------|-------------|
| **Corporate Server** | Financial + Blueprint | Encrypted T1-T2 | Agir decryption, paralel hat |
| **Banka Kasasi** | Financial + Classified | Encrypted T2-T3 | Yuksek tier, cok Key tuketir |
| **Devlet Arsivi** | Research + Blueprint + Classified | Encrypted T3 + Corrupted | Coklu pipeline ustaligi |

**Cok Zor Kaynaklar (karisik content, tum state'ler, malware):**

| Kaynak | Content | State'ler | Karmasiklik |
|--------|---------|-----------|-------------|
| **Askeri Ag** | Blueprint + Classified | Encrypted T3 + Malware | Quarantine sart, karmasik routing |
| **Dark Web Node** | Tum tipler | Tum state'ler, tum tier'lar | Evrensel fabrika challenge |
| **Blackwall Parcasi** | Classified + Blueprint | Maks tier + agir Malware | Nihai optimizasyon |

### Spawn Garanti Kurallari
Harita uretimi su kurallara uyar:
- **Spawn yaninda:** En az 2 kolay kaynak (oyuncu hemen baslar)
- **Yakin cevre:** En az 1 orta kaynak (ilk challenge)
- **Harita genelinde:** Her content tipinden en az 1 kaynak var (progression kilitlenmez)
- **Dagilim:** Kolay kaynaklar bol (~%40), orta oranli (~%30), zor az (~%20), cok zor nadir (~%10)
- **Karisim:** Zor kaynak spawn'in yanininda ciKABILIR — gorebilirsin ama isleyemezsin (merak!)

### Kaynak Sayilari (Seed Basina)
- **Toplam:** ~25-35 kaynak/harita
- Kolay: ~10-14
- Orta: ~8-10
- Zor: ~5-7
- Cok zor: ~2-4

### "Gorebilirsin Ama Isleyemezsin" Mekanigi
Bu oyunun en guclu motivasyon kaynaği:
```
Oyuncu spawn'da basliyor...
  → Yaninda bir Otomat (kolay, Standard Clean) — guzel, basla
  → 10 kare otede bir Askeri Ag gorünuyor! — Classified Data, Encrypted T3 + Malware
  → "Vay, orada ne var... ama Decryptor'um bile yok..."
  → 3 saat sonra: "SONUNDA o Askeri Ag'i islemeye hazirim!"
  → Bu his = oyunun bagimlilık dongusu
```

### Kaynak Ozellikleri (Data Resource)
Her kaynak su bilgilere sahip:
- **Isim:** Somut, akilda kalici (ATM, Hastane, Askeri Ag)
- **Zorluk seviyesi:** Kolay / Orta / Zor / Cok Zor
- **Content dagilimi:** Hangi content tipleri, hangi oranlarda
- **State dagilimi:** Her content icin hangi state'ler, hangi oranlarda
- **Maks tier:** Encrypted/Corrupted/Malware icin tier limiti
- **Bant genisligi:** Maks cikis hizi (MB/s)
- **Hucre sayisi:** Kaynağin haritadaki fiziksel boyutu (organik sekil)
- **Tukenmez:** Kaynaklar bitmez (chill otomasyon)

---

## 11. Ilerleme Sistemi

### Tech Tree Yok — Kesif = Kilit Acma
Bir content tipini veya state'i ilk kez kesf ettiğinde, ilgili binalar acilir.

| Ilk Kesif | Acilan Binalar | Neden |
|-----------|---------------|-------|
| Oyun basi | Uplink, Storage, Separator, Splitter, Merger, Bridge | Temel toolkit |
| Corrupted state | Recoverer | "Bozuk veri! Onaracak alet lazim" |
| 2. content tipi | Classifier | "Karisik veri! Turlerine ayirmam lazim" |
| Research content | Research Lab, Decryptor | "Sifreli veri! Anahtar lazim" |
| 3+ content tipi | Compiler | "Yeterli cesitlilik var, malzeme birlestirebilirim" |
| Blueprint content | Replicator | "Nadir sema! Kopyalamak istiyorum" |
| Malware state | Quarantine | "Tehlike! Guvenle imha etmeliyim" |
| Classified content | Gig Board | "Gizli veri! Sozlesme alabilirim" |

### Ilerleme Asamalari

| Asama | Tetikleyici | Oyuncu Deneyimi | His |
|-------|------------|----------------|-----|
| **Copcu** | Ilk kolay kaynak | Tek content, temelleri ogren | "Anladim" |
| **Ayirici** | 2+ content kesfi | Coklu tip, ayirmayi ogren | "Farkli veriler farkli islem istiyor!" |
| **Muhendis** | Encrypted kesfi | Cift girdili binalar, key tedarik zinciri | "Bu gercek bir fabrika artik" |
| **Mimar** | 5+ kaynak aktif | Karmasik coklu kaynak pipeline'lari, routing bulmacalari | "Yaptığım devre kartına bak!" |
| **Netrunner** | Zor/cok zor kaynaklar | Her sey, optimizasyon, gig'ler | "Sisteme hakim oldum" |

---

## 12. Kisit ve Zorluk

### Felsefe: Shapez Modeli — Saf Otomasyon
Power, heat, combat yok. Challenge tamamen otomasyon ve yonetimden gelir.

| Kisit | Nasil Calisir | Oyuncu Karari |
|-------|--------------|---------------|
| **Kablo routing** | Kablolar grid'de yer kaplar, serbestce kesilemez | "Mevcut layout'u bozmadan buraya nasil hat cekerim?" |
| **Content karmasikligi** | Zor kaynaklar 3-4+ content tipi | "Daha buyuk ayirma sistemi kurmam lazim" |
| **State karmasikligi** | Zor kaynaklar 4 state + yuksek tier | "Her state icin ayri isleme hatti lazim" |
| **Throughput** | Binalarin isleme hizi sinirli | "Paralel hat mi, upgrade mi?" |
| **Depolama alani** | Farkli state'ler farkli yer kaplar | "Islemeden mi depolasam, once mi islesem?" |
| **Key tedariği** | Decryptor surekli Key tuketiyor | "Research Lab yeterli Key uretiyor mu?" |
| **Atik yonetimi** | Recoverer'dan Residue cikiyor | "Atik nereye gidecek?" |
| **Quarantine zamanlama** | Doluluk/flush dongusu girisi bloke eder | "Quarantine oncesi buffer planlamam lazim" |
| **Malzeme onceligi** | Yapilar belirli Clean veri tipleri harcar | "Hangi yapiyi once ureteyim?" |
| **Harita routing** | Yeni kaynak = mevcut fabrikadan gecen kablo | "Yeni kaynagi mevcut aga nasil entegre ederim?" |

### Gec Oyun Zorlugu
Bireysel mekanikler zorlasmaz — hepsini AYNI ANDA, BIRDEN FAZLA kaynak icin yonetmen ve her yeni kablo mevcut grid layout'una uydurmak gerekir. Zor kaynaklar haritanin her yerinde olabilir — yakin gorunur ama ancak yeterli altyapi kuruldugunda islenebilir.

---

## 13. Gig Sistemi

### Genel Bakis
Gig Board gec oyun binasi. Opsiyonel hedefler + bonus oduller sağlar.

### Nasil Calisir
1. Gig Board'u haritaya yerlestir
2. Board 3 mevcut gig gosterir
3. Pipeline'ini Gig Board'a bagla
4. Veri akar → gig ilerleme sayaci artar
5. Gig tamam → odul verilir
6. Veri HARCANMAZ — throughput sayilir, sistemde kalir

### Ornek Gig'ler

| Gig | Gereksinim | Odul |
|-----|-----------|------|
| "ISP Temizligi" | 200 MB Corrupted → Clean isle | 100 Standard(Clean) bonus |
| "Kurum Casusluğu" | 100 Financial(Clean) teslim et | Compiler tarifi acilir |
| "Askeri Istihbarat" | 50 Classified(Clean) teslim et | Research Lab hiz +%20 |
| "Atik Yonetimi" | 100 MB Malware imha et | Quarantine kapasite +25 MB |
| "Seri Uretim" | 20 Decryption Key uret | Decryptor hiz +%15 |

### Gig Veri Harcamaz Cunku
- Gig = "bunu YAPABILDIĞINI kanıtla" hedefi
- Oyuncunun malzeme uretimi etkilenmez
- Gig'ler saf ek motivasyon
- Satisfactory'nin milestone sistemiyle ayni mantik

### Ileri Gig'ler: Refined Malzeme Talebi
Bazi gig'ler Clean veri degil, REFINED malzeme teslimi ister. Bu Compiler'i gec oyunda aktif tutar:

| Ileri Gig | Gereksinim | Odul |
|-----------|-----------|------|
| "Guvenlik Paketi" | 5 Security Core teslim et | Quarantine kapasite x2 |
| "Ticaret Anlasmasi" | 10 Trade License teslim et | Tum bina hizlari +%10 |
| "Neural Arastirma" | 8 Neural Index teslim et | Research Lab hizi x2 |

Bu gig'ler icin Compiler SUREKLI calisir — Storage'da biriken Clean veriyi Refined'a donusturur.

---

## 14. Gorsel Tasarim Detaylari

### Sanat Stili: Prosedürel + Shader (Sifir Harici Asset)
Her sey kodla cizilir + shader efektleri. Sprite yok, satin alinan asset yok.

### Devre Karti Estetigi
Zoom-out'da oyuncunun fabrikasi parlayan bir PCB (baski devre karti) gibi gorunmeli:
- Koyu arka plan (derin lacivert/siyah)
- Parlak neon kanallar (kablolar)
- Dikdortgen bina siluetleri
- Her sey grid duzende bagli
- Aktiviteyle titresir

### Renk Paleti

```
Arka plan:     #0a0e14 (derin koyu mavi-siyah)
Grid:          #1a1e2e (hafif grid cizgileri)
Kablolar:      State'e gore parlama rengi
Binalar:       Koyu govde + isleve gore renkli neon kenarlar
UI:            Neon cyan + beyaz

State Renkleri:
  Clean:       #00ff88 (neon yesil)
  Encrypted:   #4488ff (neon mavi)
  Corrupted:   #ff8844 (neon turuncu)
  Malware:     #ff2244 (neon kirmizi)
```

### Shader Efektleri
- **Bloom:** Kablo ve binalarda neon parlama
- **CRT:** Hafif tarama cizgileri + kromatik sapma
- **Vignette:** Ekran kenarlarinda kararma
- **Glow outline:** Bina kenarlarinda renk kodlu titresim

### Ses Tasarimi

Otomasyon oyunlarinin tatmini buyuk olcude SESTEN gelir. Fabrika "canli" hissetmeli.

**Ambient Katmani:**
- Temel: dusuk frekanslı dijital hum (fabrikanin genel sesi)
- Aktif kablo sayisina gore yogunluk artar
- Zoom seviyesine gore ses degisir (yakin = detay, uzak = genel ugultu)

**Bina Sesleri (her bina benzersiz):**
- Uplink: veri cekme/indirme sesi (pulse)
- Classifier/Separator: ayirma/routing "tik-tak" sesi
- Decryptor: sifre kirma sesi (dijital "crack" efekti)
- Recoverer: tarama/onarma sesi + basarisiz oldugunda farkli ton
- Quarantine: uyari sesi + flush sirasinda bosaltma efekti
- Compiler: birlestirme/sentez sesi (iki sesin birlesip ucuncuye donusmesi)
- Replicator: kopyalama "mirror" efekti
- Storage: doldukca daha dolu/tok ses

**UI Sesleri:**
- Kablo doseme: tatmin edici "snap" sesi (her segment)
- Bina yerlestirme: agir/sagdam "placement" sesi
- Yeni kesif: dikkat cekici bildirim melodisi
- Yeni bina acilma: basari jingle'i
- Malzeme yeterliligi: olumlu onay sesi
- Hata: yumusak uyari (agresif degil — chill oyun)

**Implementasyon:** Prosedürel ses + free SFX kutuphaneleri. Her sesin pitch/volume parametreleri data-driven (bina state'ine gore).

---

## 15. Referans Oyunlar

| Oyun | Ne Aliyoruz | Ne Almiyoruz |
|------|------------|-------------|
| **Factorio** | Grid routing, mekansal bulmaca, bant yonetimi | Savas, kirlilik, devasa karmasiklik |
| **Satisfactory** | Kaynak → Malzeme → Uretim, Assembler (=Compiler) | 3D, buyuk kapsam |
| **Shapez** | Kademeli bulmaca, chill atmosfer | Sekil-spesifik mekanikler |
| **Mindustry** | Harita kaynaklar, cikarim | Kule savunma |
| **Hacknet** | Cyberpunk estetik, terminal hissi | Tekrarci oynanis |

### Kritik Dersler
- **Factorio'dan:** Grid routing = oyun. Bantlar kesilemeyince layout ana bulmaca OLUR. 200K+ inceleme bunun kaniti.
- **Satisfactory'den:** Coklu girdili tarifler (Assembler) en iyi lojistik bulmacalari yaratir. Surekli kaynak tuketimi fabrikalari canli tutar.
- **Shapez'den:** Saf otomasyon yeterli. Savas gereksiz. Kademeli karmasiklik anahtardir.
- **Hacknet'ten:** Cyberpunk tema tek basina yetmez. Tekrardan kacinilmali.

---

## 16. Pazar Stratejisi

### Hedef
- **Fiyat:** $9.99
- **Satis hedefi:** 100K+
- **Platform:** Steam (birincil)
- **Cikis:** Steam Next Fest demo sonrasi

### Hook + Anchor
- **Hook (benzersiz):** "Siberuzayda parlayan devre kartlari tasarla — daha once gormedİğin veri otomasyonu"
- **Anchor (tanidik):** "Factorio-tarz grid routing + Satisfactory-tarz crafting zincirleri"

### Neden 100K Ulasilabilir
1. Otomasyon turu sadik, katilimci kitleye sahip
2. Cyberpunk + otomasyon genuinely yeni kombinasyon
3. Grid routing Factorio-derinliğinde mekansal bulmaca sagliyor
4. Devre karti estetigi screenshot'a deger
5. $9.99 durtuk satin alma fiyat noktasi
6. Solo gelistirici hikayesi indie kitleyle rezonans yapar

### Steam Next Fest Stratejisi
- Demo icerigi: grid routing + ayirma + isleme + birlestirme
- ~12-15 kaynak (kolay + orta + birkac zor)
- 4-6 saatlik demo deneyimi (otomasyon oyuncusu uzun oturum oynar)
- Screenshot'lar MUTLAKA etkileyici olmali (devre karti estetigi = satis noktasi)

---

## 17. Kapsam ve Yol Haritasi

### Demo Milestone Sistemi (Gig Board Yerine)
Demoda Gig Board yok — onun yerine basit milestone'lar oyuncuya yon verir:

| Milestone | Tetikleyici | Odul/Bildirim |
|-----------|-----------|---------------|
| "Ilk Baglanti" | Ilk kablo dosenildi | Tutorial tamamlandi bildirimi |
| "Veri Akisi" | Ilk Clean veri Storage'a ulasti | "Ilk malzemen hazir!" |
| "Ayristirici" | Ilk Classifier veya Separator kuruldu | "Veri cesitliligini yonetiyorsun" |
| "Sifre Kirici" | Ilk Decryptor + Research Lab calisti | "Sifreli veriler artik senin icin degil" |
| "Muhendis" | Ilk Compiler uretimi yapildi | "Ileri malzeme uretimi baslatildi!" |
| "Fabrika Sahibi" | 5 kaynak ayni anda aktif | "Devre kartin buyuyor!" |
| "Demo Sonu" | Ilk zor kaynagi islemeye basladin | "Tam oyunda daha fazlasi seni bekliyor..." |

Bu milestone'lar tutorial + motivasyon islevi gorur. Oyuncu ne yapmasi gerektigini anlar.

### Demo Kapsami (Next Fest) — 4-6 saat
- Grid kablo routing + Bridge
- 10 bina: Uplink, Classifier, Separator, Recoverer, Decryptor, Research Lab, Storage, Compiler, Splitter, Merger
- ~12-15 kaynak (kolay + orta + birkac zor — haritada gorunur ama islenemez olanlar dahil)
- 5 content: Standard, Financial, Biometric, Research, Blueprint
- 3 state: Clean, Corrupted, Encrypted (T1-T2)
- 4-5 Compiler tarifi
- Tam gorsel islem (devre karti estetigi)
- Replicator acilabilir (Blueprint kesfi ile)
- Malware + Quarantine YOK (tam oyuna sakla)
- Gig Board YOK (tam oyuna sakla)

### Tam Oyun Kapsami
- 14 binanin tamami
- ~25-35 kaynak/harita (rastgele dagilim)
- 6 content tipinin tamami
- 4 state + tam tier sistemi (T1-T4)
- Quarantine, Gig Board
- Tam Compiler tarif listesi
- Upgrade sistemi

### Lansman Sonrasi Potansiyel
- Protokol katmani (3. veri boyutu)
- Yeni bina tipleri
- Savas/savunma DLC
- Topluluk challenge'lari

---

## 18. Acik Sorular

### Tasarlanacak
- [ ] Bina isleme hizlari ve dengeleme
- [ ] Compiler tarif dengeleme (malzeme miktarlari)
- [ ] Gig odul dengeleme
- [ ] Upgrade maliyetleri ve ilerleme egrisi
- [ ] Kaynak spawn dagilim algoritmasi ve dengeleme
- [ ] Kablo kose/kavsakk gorsel tasarimi
- [ ] Bina boyutlari (1x1 mi, bazi 2x2 mi)
- [ ] Overclock mekanigi (demo sonrasi potansiyel)
- [ ] Ses asset'leri secimi (prosedürel vs free library)

### Dogrulanmis Kararlar
- [x] Grid kablo routing (Factorio modeli)
- [x] Cift girdili binalar (Decryptor + Compiler)
- [x] Olasiliksal Recoverer + Residue yan urunu
- [x] Doluluk/flush Quarantine
- [x] Replicator (benzersiz dijital mekanik)
- [x] Veri = Malzeme ekonomi (Satisfactory modeli)
- [x] Kesif = Kilit Acma ilerleme
- [x] Devre karti gorsel kimligi
- [x] 14 bina toplam
- [x] 6 content x 4 state veri modeli
- [x] Rastgele dagitimli harita, somut kaynak isimleri
- [x] Chill otomasyon (savas yok)
- [x] $9.99 fiyat hedefi

### Reddedilen Fikirler
- ~~Credits/para birimi~~ → Veri = Malzeme
- ~~Tech Tree~~ → Kesif = Kilit Acma
- ~~Power/Heat sistemi~~ → Saf otomasyon
- ~~Noktadan noktaya kablolar~~ → Grid routing
- ~~Ayni mekanikli isleyiciler~~ → Her bina benzersiz
- ~~Soyut kaynak isimleri~~ → Somut isimler (ATM, Hastane, vb.)
- ~~Mesafe sinirli kablolar~~ → Kablolar serbest uzunluk, zorluk routing'den
- ~~Ring/halka sistemi~~ → Rastgele dagitim (Factorio modeli) — zorluk konumdan degil kaynak tipinden
- ~~Research Points~~ → Research Lab direkt Key uretir
- ~~Patch Data~~ → Refined malzeme sistemi
- ~~Compressor (ayri bina)~~ → Scope disinda, gerekirse sonra eklenir

---

*Bu dokuman canlidir ve her tasarim oturumunda guncellenecektir.*
*Versiyon 2.1 — Rastgele Dagitim Harita Guncellemesi: Ring sistemi kaldirildi, Factorio-tarz serbest kaynak dagitimi*
