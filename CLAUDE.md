# SYS_ADMIN - Proje Durumu ve Demo Release Plani

## Mevcut Asama: v3.0 Faz I Devam Ediyor (Save/Load tamam, Options + QoL kaldi)
- **GDD:** `docs/GDD.md` (v3.0) - Tum tasarim kararlari burada
- **Kod durumu:** v3.0 Faz A-H tamamlandi, Faz I kismi tamamlandi (save/load/menu/autosave bitti)
- **Hedef:** Steam Next Fest Haziran 2026 icin oynanabilir, polished, save/load'lu, onboarding'i guclu demo
- **Ticari hedef:** Tam oyun icin $9.99 fiyat noktasina yakisan kalite ve guven hissi

## North Star
SYS_ADMIN, **Shapez'e yakin chill puzzle-factory** yonunde ilerlemelidir:
- Oyun, "basit mekanik + derin kombinasyon + guzel layout" hissi satacak
- Scope, Factorio benzeri genis sistemlere kaydirilmayacak
- Demo, "dar ama asiri polished" olacak
- Gorsel dil, **procedural / abstract / readable cyber-board** estetigine yaslanacak
- Oyuncu ilk 10-15 dakikada dokumansiz oynayabilmeli, ilk 60 dakikada ise oyunun hook'unu tam hissetmeli

---

## Kilitlenmis Tasarim Kararlari
Asagidaki kararlar artik **scope lock** kabul edilir. Claude Code bu kararlarla celisen sistem eklememeli.

### Oyun Yonu
- [x] Tur yonu: **Shapez'e yakin chill puzzle-factory**
- [x] Core loop: Contract al -> uygun kaynak bul -> pipeline kur -> isle -> teslim et -> yeni bina / yeni kontrat
- [x] Bina maliyeti yok
- [x] Combat / power / heat / para birimi yok
- [x] Persistent sandbox save var, run-based yapi yok

### Demo Scope Lock
- [x] Demo, **T1-T2** odakli olacak
- [x] Demo roster: Uplink, Classifier, Separator, Recoverer, Research Lab, Decryptor, Encryptor, Compiler, Splitter, Merger, Trash, Bridge, Contract Terminal
- [x] Demo'da **Malware gameplay YOK**
- [x] Malware, sadece **teaser / ileride acilacak sey** olarak var olabilir
- [x] T3-T4 mekanikleri demo'nun zorunlu parcasi olmayacak
- [x] Demo hedefi: 7 tutorial gig + 3-5 paralel orta seviye gig
- [x] Demo hedefi: 12-15 kaynaklik oynanabilir havuz

### Mekanik Kararlari
- [x] **Packet gercek urun** olacak; Compiler ciktisi iki ayri teslim gibi sayilmayacak
- [x] **Encryptor demo icinde zorunlu** olacak; acilip kullanilmayan bina olmayacak
- [x] Gig 6+, Encryptor'u gercekten kullanacak
- [x] Gig 7+, Compiler'i gercekten kullanacak
- [x] Source bandwidth, sadece tooltip verisi degil, gameplay'de gercek limit olacak
- [x] Recoverer deterministic + fuel tabanli kalacak
- [x] Grid kablo routing ve Bridge oyunun ana layout bulmacasi olmaya devam edecek

### Art / Audio Kararlari
- [x] Ana sanat yonu: **procedural-first**
- [x] Hand-crafted detayli illustration zorunlu degil
- [x] Gorsel kalite; siluet, ikon, glow, motion, flow feedback, active/idle kontrasti ile kazanilacak
- [x] Harici asset kullanmak zorunlu degil; gerekiyorsa sadece scope'u kurtaran kucuk yardimci UI/audio parcalari dusunulebilir

### Demo'da Yapilmayacaklar
- [x] Malware Processor implementasyonu
- [x] T3/T4 contract zorunlulugu
- [x] Workshop / mod support
- [x] Multiplayer / co-op
- [x] Buyuk hikaye / campaign katmani
- [x] Tech tree / currency / upgrade ekonomisi buyutme
- [x] Yeni bina patlamasi; mevcut roster polish'i once gelecek

---

## Mevcut Baseline (Tamamlanan Fazlar)

### Faz A: Core Loop - TAMAMLANDI
- [x] Contract Terminal binasi (harita merkezinde sabit, teslimat noktasi)
- [x] Gig data resource + ilerleme sayaci + tamamlama mekanigi
- [x] Bina acma = gig tamamlama (gig_manager.gd)
- [x] Bina maliyet sistemi kaldirildi
- [x] Tutorial gig zinciri (Gig 1-7, sirali) icin ilk iskelet kuruldu

### Faz B: Veri Modeli - TAMAMLANDI
- [x] Clean -> Public yeniden adlandirma
- [x] Eski residue/refined izlerinin buyuk kismi kaldirildi
- [x] Islem etiket sistemi: Decrypted, Recovered, Encrypted

### Faz C: Bina Mekanikleri - TAMAMLANDI
- [x] Classifier binary filtre
- [x] Separator binary filtre
- [x] Recoverer fuel tabanli deterministic model
- [x] Encryptor eklendi
- [x] Compiler paketleyici eklendi
- [x] Trash modeli sadeleştirildi

### Faz D: Tier Revizyon - TAMAMLANDI
- [x] Encrypted tier = key tarifi karmasikligi
- [x] Corrupted tier = fuel islenmisligi
- [x] Research Lab tier secimi

---

## Mevcut Kritik Blokerler
Asagidaki maddeler demo release oncesi mutlaka cozulmeli:

- [x] GDD ile gig/resource gercegi tam hizali degil
- [x] Packet semantigi gercek urun gibi islemiyor
- [x] Source bandwidth gameplay'de uygulanmiyor
- [x] Paralel gig sistemi + gig UI eksik
- [x] Onboarding, "oyuncu neden ne yapiyor" sorusunu UI ile cevaplayacak kadar guclu degil
- [x] Save/load/autosave yok
- [x] Demo source/gig havuzu heniz net sekilde curate edilmemis
- [x] Legacy quarantine/probabilistic/storage izleri demo scope'unu bulandiriyor
- [ ] Demo'yu satin alinabilir gosterecek screenshot/trailer kalitesi henuz garanti degil
- [ ] Demo-scale fabrikada performans/stability kabul kriterleri tanimli degil

---

## Claude Code Calisma Kurallari
Bu dokuman, Claude Code tarafindan **takip edilecek execution plan** olarak kullanilacak.

### Genel Kurallar
- Fazlari **sirayla** ilerlet; gate kapanmadan bir sonraki faza gecme
- Her faz sonunda oyun **playable state**'te kalmali
- GDD ile kod celisirse, once bu dokumandaki kilitlenmis kararlar, sonra GDD referans alinmali
- Scope'u genisletme; polish'i ve clarity'yi one al
- Yeni sistem eklemeden once "demo'da gercekten gerekli mi?" diye kontrol et
- Kullaniciya gorunen tum metinler **Ingilizce** kalmali
- Her biten task sonrasinda bu dokumandaki checkbox'lari guncelle
- Bir faz bitmeden baska fazdan "ufak bir sey" ekleme aliskanligi edinme

### Faz Gecis Kurali
Bir faz ancak su kosullarla "tamam" sayilir:
- Faz icindeki tum must-do maddeler biter
- Fazin DoD maddeleri saglanir
- Yeni eklenen seyler oyunda gorunur ve kullanilir
- Faz, sonraki fazi acikca unblock eder

### Escalation Kurali
Asagidaki durumlarda dur ve kullaniciya don:
- Scope lock ile celisen yeni ihtiyac cikarsa
- Demo yerine full-game endgame sistemine kayma riski olursa
- Bir mekanigin iki farkli yorumundan biri secilmeden ilerlemek riskliyse

---

## Demo Release Fazlari

## Faz E: Scope Freeze + GDD/Kod Hizalama
**Amac:** Repo'daki mevcut sistemleri kilitlenmis demo scope'u ile birebir hizalamak. Bu faz bitmeden yeni UI veya yeni content ekleme.

### Must-Do
- [x] Demo scope disi legacy resource/system izlerini audit et
- [x] `Packet = gercek urun` kuralini veri teslim sayimina uygula
- [x] Gig 6'yi Encryptor kullanacak sekilde duzelt
- [x] Gig 7'yi Compiler paket urunu isteyecek sekilde duzelt
- [x] T3/T4 veya Malware'i zorunlu yapan demo content bagimliliklarini temizle
- [x] Malware'li kaynaklari demo'da sadece teaser rolune indir
- [x] `Source bandwidth` degerini gameplay'de gercek cikis limiti yap
- [x] Build unlock order'ini tutorial kullanim sirasi ile birebir hizala
- [x] Demo'da kullanilmayacak bina/resource/UI izlerini devre disi birak veya temizle
- [x] GDD ve bu plan ile celisen resource aciklamalarini duzelt

### Ozel Duzeltme Hedefleri
- [x] Compiler output'u, iki ayri requirement'e otomatik sayilmasin
- [x] Contract delivery logic packet requirement farkini taniyabilsin
- [x] Demo'da Storage / Quarantine / eski probabilistic zihniyeti oyuncu yuzune cikmasin
- [x] Demo source pool'u T1-T2 odagina gore netlestirilsin

### Definition of Done
- [x] Demo'daki tum gig'ler bu dokumandaki scope lock ile uyumlu
- [x] Encryptor ve Compiler acildiginda hemen kullanilan binalar haline gelmis
- [x] Oyuncuya demo'da "bu sistem ne ise yariyor?" dedirten bina kalmamis
- [x] Legacy sistemler oyuncu acisindan gorunmez veya kaldirilmis

### Bu Fazda Yapilmayacaklar
- [ ] Buyuk yeni UI yazimi
- [ ] Ana menu / save sistemi
- [ ] Gorsel screenshot polish sprint'i

---

## Faz F: Contract Terminal + Gig UI
**Amac:** Oyuncu, dokuman okumadan aktif hedeflerini, eksigini, odulunu ve ilerlemesini oyunun icinden anlayabilsin.

### Must-Do
- [x] Kalici bir **Gig/Contract paneli** ekle
- [x] Aktif gig listesini ve her requirement'in ilerlemesini goster
- [x] Bir "primary tracked objective" sistemi ekle
- [x] Gig reward building'lerini panelde acikca goster
- [x] Yeni gig acildiginda ve bitince toast + panel feedback ver
- [x] Contract Terminal ile panel arasinda net bag kur
- [x] Teslim edilen datayi oyuncuya okunur sekilde feed et
- [x] Hangi gig'in tutorial, hangisinin optional/parallel oldugu net gorunsun
- [x] Gig tamamlaninca "siradaki adim ne?" sorusuna UI cevap versin

### Yuksek Deger Ekleri
- [ ] Requirement tooltip'lerinde beklenen urunun acik etiketi olsun
- [ ] Uygun kaynak tiplerine yonlendiren hafif ipucu katmani ekle
- [ ] "Bu urun icin hangi bina zinciri lazim?" hissini destekleyen aciklama metinleri yaz

### Definition of Done
- [x] Oyuncu aktif kontratlarini tek panelden takip edebiliyor
- [x] Progress sadece toast ile degil, surekli gorunur sekilde izlenebiliyor
- [x] Reward unlock mantigi oyuncu icin gorunur ve anlasilir
- [x] Contract Terminal oyunun gercek "mission hub"i gibi hissettiriyor

### Bu Fazda Yapilmayacaklar
- [ ] Full campaign map screen
- [ ] Fazla sinematik UI
- [ ] Steam entegrasyonu

---

## Faz G: Tutorial + Onboarding + Goal Clarity
**Amac:** Ilk 15 dakika neredeyse frictionless; ilk 60 dakika ise "oyunun hook'u" eksiksiz hissedilmeli.

### Must-Do
- [x] 7 tutorial gig'i yeniden yaz ve akis sirasini kesinlestir
- [x] Her tutorial gig acilan binayi **hemen** kullandirsin
- [x] Ilk kaynak, ilk uplink, ilk classifier, ilk separator, ilk recoverer, ilk key, ilk encryptor, ilk compiler deneyimlerini netlestir
- [x] Oyuncuya "neden akmiyor?" sorusuna cevap veren feedback ekle
- [x] Input/output port mantigini daha gorunur yap
- [x] Tikanma, key yoklugu, fuel yoklugu gibi durumlari UI/FX ile acik goster
- [x] Contract paneli ile tutorial akisini birbirine bagla
- [x] Ilk 2-3 kontratta fazla secim degil, dogru secim alanini sinirla

### Tutorial Zinciri (Kilit Akis)
- [x] Gig 1: Standard Public teslim et
- [x] Gig 2: Financial ve Biometric ayir
- [x] Gig 3: Public filtreleme yap
- [x] Gig 4: Recoverer kullan
- [x] Gig 5: Research Lab + Decryptor kullan
- [x] Gig 6: Encryptor kullan, Decrypted·Encrypted urun teslim et
- [x] Gig 7: Compiler kullan, gercek packet teslim et

### Definition of Done
- [x] Oyuncu ilk 15 dakikada dis yardim olmadan ilerleyebiliyor
- [x] Tutorial boyunca acilip da kullanilmayan bina yok
- [x] "Neden bu gig tamam olmadi?" sorusu UI'da anlasilir cevap buluyor
- [x] Gig 7 sonunda oyuncu oyunun ana dilini ogrenmis oluyor

### Bu Fazda Yapilmayacaklar
- [ ] Overexplaining / uzun tutorial pencereleri
- [ ] Terminal-simulator benzeri metin agir onboarding

---

## Faz H: Demo Content Pack + Balance
**Amac:** Demo, 4-6 saatlik tatmin edici akis ve tekrar oynanabilir seed farki sunmali.

### Must-Do
- [x] Demo source pool'unu curate et
- [x] 12-15 kaynaklik oynanabilir havuz olustur
- [x] 7 tutorial gig + 3-5 paralel gig tasarla
- [x] Demo'daki tum parallel gig'lerin en az biri T2 key, en az biri T2 fuel, en az biri packet kullansin
- [x] Spawn garanti kurallarini demo scope'una gore duzelt
- [x] Source rarity ve yakinlik kurallarini tutorial akisina zarar vermeyecek sekilde ayarla
- [x] Throughput / buffer / processing rate / capacity degerlerini demo temposuna gore dengele
- [x] Key ve fuel tuketimlerinin "beklemek zor ama sinir bozucu degil" dengesini kur

### Demo Source Hedefi
- [x] Kolay: Vending Machine, ATM, Smart Lock, Traffic Camera, Public Database
- [x] Orta: Hospital Terminal, Public Library, Shop Server, Biotech Lab
- [x] Zor teaser veya gec demo: Corporate Server, Government Archive
- [x] Endgame teaser: Military Network / Dark Web Node gorunebilir ama demo core loop'una bagli olmayacak

### Demo Gig Hedefi
- [x] Tutorial 1-7 tamamen calisiyor
- [x] 3-5 parallel gig, tutorial sonrasi aciliyor
- [x] En az 1 gig Blueprint odakli
- [x] En az 1 gig T2 Key kullandiriyor
- [x] En az 1 gig T2 Recoverer fuel kullandiriyor
- [x] En az 1 gig gercek packet urunu istiyor

### Definition of Done
- [ ] Demo tek seed'de 4-6 saatlik saglam bir akis verebiliyor
- [ ] Oyuncu her acilan binayi en az bir kez anlamli kullaniyor
- [ ] Midgame "tek boru cek ve bitir" hissine dusmuyor
- [ ] Demo tamamlandiginda full game meraki olusuyor

### Bu Fazda Yapilmayacaklar
- [ ] T3/T4 dengeleme
- [ ] Full game onlarca gig
- [ ] Malware production chain

---

## Faz I: Save/Load + Meta UX + Demo QoL
**Amac:** Demo, gercek bir urun gibi davranmali; oyuncu cikis yapip geri donebilmeli, fabrika kaybolmamali.

### Must-Do
- [x] New Game / Continue akisi ekle
- [x] Save system ekle
- [x] Load system ekle
- [x] Autosave ekle
- [x] Seed bilgisini save ile bagla
- [x] Gig progress, unlocks, buildings, connections, source discovery durumu kaydolmali
- [x] Save bozulursa oyuncu sessizce mahvolmasin; temel fail-safe davranis ekle
- [ ] Basit Options menusu ekle
- [ ] Audio volume ayari ekle
- [ ] Window/fullscreen gibi en az birkac temel display ayari ekle

### Demo QoL Must-Do
- [ ] Move/remove akislarini puruzsuzlestir
- [ ] Kablo silme / yeniden cekme feedback'ini guclendir
- [x] Pause / speed / shortcut bilgilerini daha net yap
- [x] Undo/redo'yu save/load sonrasi da guvenilir hale getir veya gerekiyorsa scoped tut
- [ ] Hover tooltip'lerde yalnizca faydali bilgi kalsin; bilgi gurultusu temizlensin

### Nice-to-Have (Sadece hizliysa)
- [ ] Seed secimi / reroll UI
- [ ] Basit confirmation dialog'lari
- [ ] Temel keybind ayarlari

### Definition of Done
- [ ] Oyuncu cikis yapip devam edebiliyor
- [ ] 30+ dakikalik bir oturum kayipsiz geri yuklenebiliyor
- [ ] Demo "prototype" degil, "urun" hissi vermeye basliyor

### Bu Fazda Yapilmayacaklar
- [ ] Cloud save entegrasyonu
- [ ] Steam overlay/achievement entegrasyonu
- [ ] Blueprint/copy-paste sistemi (demo icin opsiyonel; release sonrasi da olabilir)

---

## Faz J: Visual Readability + Procedural Art Direction + Audio Polish
**Amac:** Harici art gucune bagimli olmadan oyunu daha pahali, daha okunur ve daha paylasilabilir gostermek.

### Procedural Art Yonu - Zorunlu Kurallar
- [ ] Her bina 4 sey ile ayristirilsin: siluet, ikon, accent renk, calisma animasyonu
- [ ] Uzak zoom -> glow/siluet/traffic okunurlugu
- [ ] Orta zoom -> bina kimligi + portlar + akisin yonu
- [ ] Yakin zoom -> ikon detayi + package karakterleri + activity feedback
- [ ] Active ve idle bina arasindaki kontrast guclendirilsin
- [ ] Source'larin difficulty / deger / tehdit hissi uzaktan da anlasilsin

### Must-Do
- [ ] Tum bina siluetlerini ayristir
- [ ] Tum bina ikonlarinin ayni dilde oldugunu dogrula
- [ ] Contract Terminal'i sahnede daha "merkez" hissettir
- [ ] Delivery, unlock, completion anlarina daha guclu moment-to-moment feedback ekle
- [ ] Kablo traffic'inin screenshot degerini arttir
- [ ] Uzak zoom'da factory "parlayan devre karti" hissi vermeli
- [ ] Source discovery ani daha tatmin edici hale getirilsin
- [ ] Sesleri bina fiilleriyle daha net eslestir
- [ ] UI panelleri tek bir cyber style system ile tutarli hale getirilsin

### Screenshot Pass
- [ ] En az 5 farkli "Steam screenshot worthy" goruntu elde et
- [ ] En az 1 close-up process chain screenshot
- [ ] En az 1 zoomed-out board screenshot
- [ ] En az 1 source discovery / route complexity screenshot
- [ ] En az 1 Contract Terminal + busy network screenshot

### Definition of Done
- [ ] Oyun, assetsiz gorundugu icin degil, bilerek soyut tasarlandigi icin guclu hissettiriyor
- [ ] Zoom-out gorunumu oyunun ana satis noktalarindan biri haline geliyor
- [ ] Bina ve source ayirt ediciligi gameplay clarity'yi destekliyor

### Bu Fazda Yapilmayacaklar
- [ ] Detayli hand-painted art pipeline
- [ ] Karakter/cevre illustrasyonlari
- [ ] Tema degistiren buyuk gorsel pivot

---

## Faz K: Stability, Performance, Test Harness, Bug Bash
**Amac:** Demo, uzun oturumda dagilmayan, softlock yaratmayan, seed bazli tutarli bir build olsun.

### Must-Do
- [ ] Buyuk kablo agi + cok bina icin stress test senaryosu hazirla
- [ ] Demo-scale fabrikada simulation tick maliyetini olc
- [ ] Connection / stall / particle sistemlerinin gereksiz pahali path'lerini optimize et
- [ ] Save/load integrity testleri yaz veya prosedur haline getir
- [ ] Undo/redo edge case'lerini test et
- [ ] Remove/move/build/connect siralarinda softlock olup olmadigini test et
- [ ] Fog, source discovery, unlock, gig completion buglarini taramadan demo cikarma
- [ ] Random seed'lerde tutorial akisinin bozulmadigini dogrula
- [ ] Delivery counting edge case'leri (packet, tagged data, tier mismatch) icin test checklist hazirla
- [ ] Crash yaratan akislari blokla veya degrade et

### Perf/Tech Hedefleri
- [ ] Demo-scale fabrikanin akisi gozle gorulur sekilde stabil olmali
- [ ] Particle ve glow sistemleri readability kaybetmeden optimize edilmeli
- [ ] Simulation, "buyuk fabrika kurunca oynanmaz oluyor" noktasina gelmemeli

### Test Checklist
- [ ] New Game -> first gig -> gig 7 tamamlanabiliyor
- [ ] Gig 7 sonrasi parallel gig'ler aciliyor
- [ ] Save al -> cik -> load et -> ayni ilerleme devam ediyor
- [ ] Uplink source linkleri save/load sonrasi bozulmuyor
- [ ] Contract progress resetlenmiyor veya bozulmuyor
- [ ] Undo/redo temel akislarda calisiyor
- [ ] Birden fazla seed'de baslangic akisi bozulmuyor
- [ ] Demo icinde ilerlenemeyen dead-end yok

### Definition of Done
- [ ] Demo'yu bozan blocker bug kalmamis
- [ ] 1 saatlik internal smoke test temiz geciyor
- [ ] Demo-scale content ile performans kabul edilir seviyede

---

## Faz L: Demo Packaging + Final Release Candidate
**Amac:** Kod olarak hazir olan demoyu, oyuncuya sunulabilir bir build'e donusturmek.

### Must-Do
- [ ] Main menu / continue / new game / options / quit akisi tamam
- [ ] Demo bitis noktasi ve "full game tease" ani tasarlandi
- [ ] Version string ve build ayirt edici bilgileri eklendi
- [ ] Credits / attribution / basic presentation ekranlari eklendi
- [ ] Demo icin temiz bir first-launch experience hazirlandi
- [ ] Steam screenshot / trailer capture icin uygun scene'ler hazir
- [ ] RC bug listesi cikarildi ve temizlendi
- [ ] Final demo build checklist yazildi

### Demo RC Checklist
- [ ] Oyuncu yeni oyuna baslayinca ne yapacagini 30 saniye icinde anliyor
- [ ] Ilk "aha" ani 5 dakika icinde geliyor
- [ ] Encryptor ve Compiler demo icinde gercek kullanim goruyor
- [ ] Demo tamamlandiginda full game meraki olusuyor
- [ ] Build, save/load ve options ile birlikte "release-adjacent" hissettiriyor

### Definition of Done
- [ ] Demo build, kullaniciya gosterilebilir seviyede
- [ ] Demo'nin scope'u acik, temiz ve polish odakli
- [ ] Full game icin kapilar acik ama demo kendi basina tatmin edici

---

## Faz Sirasi Ozet
Claude Code, bundan sonra su sirayi takip edecek:

1. Faz E - Scope Freeze + Hizalama
2. Faz F - Contract/Gig UI
3. Faz G - Tutorial/Onboarding
4. Faz H - Demo Content + Balance
5. Faz I - Save/Load + Meta UX
6. Faz J - Visual/Audio Polish
7. Faz K - Stability/Performance/QA
8. Faz L - Demo Packaging / RC

Bu sirayi ancak acik tasarim onayi ile degistir.

---

## Demo Ready Cikisi Icin Zorunlu Son Kriterler
Demo "hazir" sayilabilmesi icin su maddelerin hepsi saglanmali:

- [ ] 7 tutorial gig tam ve temiz
- [x] 3-5 parallel gig var
- [ ] Encryptor ve Compiler zorunlu kullanim goruyor
- [ ] Packet gercek urun olarak calisiyor
- [ ] Malware gameplay demo'da yok
- [x] Save/load/autosave var
- [x] Contract UI var
- [x] Goal clarity guclu
- [x] Demo source havuzu curate edilmis
- [ ] Temel bug bash tamam
- [ ] Screenshot/trailer capture icin gorsel kalite yeterli

---

## Altyapi

### MCP: tomyud1/godot-mcp (32 arac)
WebSocket port 6505 | Godot editorde "MCP Connected" (yesil) olmali

### Godot
- **Yol:** `D:\godot\Godot_v4.6-stable_win64_console.exe`
- Acmadan once: `taskkill /F /IM Godot_v4.6-stable_win64_console.exe` + dogrula
- Editor: `"D:/godot/Godot_v4.6-stable_win64_console.exe" --editor --path "D:/godotproject/sys-admin"`
- Calistir: `"D:/godot/Godot_v4.6-stable_win64_console.exe" --path "D:/godotproject/sys-admin"`

### Loglama
- Event-based logla, tick-based log BASMA
- Format: `[SistemAdi] Olay — deger`

### Kurallar
- **OYUN DILI INGILIZCE** - Tum user-facing text Ingilizce. Turkce string YAZMA.
- Kullanici teknik degil - ne/neden acikla, kod detayi verme
- Commit + push birlikte, kullanici onayi ile
- Tamamlanan isler commit mesajinda belirt, bu dokumandaki ilgili checkbox'i guncelle

---

## Son Not
Bu planin ana ilkesi:
**Scope buyutme degil, clarity + polish + guvenilirlik.**

Eger bir karar "daha fazla sistem" ile "daha iyi demo hissi" arasinda secim gerektiriyorsa,
**her zaman daha iyi demo hissini sec.**
