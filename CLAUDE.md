# SYS_ADMIN - Proje Durumu

## Mevcut Asama: v3.0 Implementasyon — Gig-Driven Core Loop
- **GDD:** `docs/GDD.md` (v3.0) — Tum tasarim kararlari burada
- **Kod durumu:** Faz A tamamlandi, Faz B sirada
- **Gecmis:** Tamamlanmis fazlar git log'da. `git log --oneline` ile bak.

## Proje Ozeti
- 2D Top-Down Chill Otomasyon | Godot 4.6 | Prosedürel sanat + shader
- Core Loop: Contract Terminal → gig al → pipeline kur → isle → teslim et → yeni bina ac
- Hedef: $9.99, Steam Next Fest Haziran 2026

---

## v3.0 Donusum Plani (v2.0 Kod → v3.0 Tasarim)

### Faz A: Core Loop — TAMAMLANDI
- [x] Contract Terminal binasi (harita merkezinde sabit, teslimat noktasi)
- [x] Gig data resource + ilerleme sayaci + tamamlama mekanigi
- [x] Bina acma = gig tamamlama (gig_manager.gd)
- [x] Bina maliyet sistemi kaldirildi (base_cost, material_costs, refined_costs)
- [x] Tutorial gig zinciri (Gig 1-7, sirali)

### Faz B: Veri Modeli
- [ ] Clean → Public yeniden adlandirma (data_enums.gd)
- [ ] Islem etiket sistemi: Decrypted, Recovered, Encrypted (birikir)
- [ ] Residue state + RefinedType enum kaldir

### Faz C: Bina Mekanikleri
- [ ] Classifier → binary filtre (sag: secilen content, sol: kalan)
- [ ] Separator → binary filtre (sag: secilen state, sol: kalan)
- [ ] Recoverer → deterministik + yakit (ProbabilisticComponent → DualInputComponent)
- [ ] Quarantine → Trash (flush kaldir, basit imha)
- [ ] Storage kaldir
- [ ] Encryptor binasi ekle (DualInputComponent: veri + Key → Encrypted etiketi)
- [ ] Compiler → paketleyici (Refined yerine: A + B → Paket [A·B])

### Faz D: Tier Revizyon
- [ ] Encrypted tier: Key tarifi zorlasiyor (T1:Research, T2:+Financial, T3:+Biometric)
- [ ] Corrupted tier: yakit islenmisligi artiyor (T1:Public, T2:Decrypted, T3:Decrypted·Encrypted)
- [ ] Research Lab: tier'a gore farkli Key tarifleri

### Faz E: Polish + Demo
- [ ] Paralel gig sistemi + Gig UI
- [ ] Dengeleme + tutorial + demo build

### Degismeyen Sistemler
Grid kablo routing, kablo rendering, gorsel polish, ses, harita uretimi, fog of war, kamera, minimap, undo

---

## Mimari Kurallar

### Component-Based — HER DEGISIKLIKTE UYGULA
- **ASLA** `building_type == "xxx"` string kontrolu YAZMA → `if def.component != null`
- Yapiya ozel davranisi if/match ile kodlama → component varligini kontrol et
- Degerleri koda gomme → component Resource'a koy
- Yeni yapi = yeni .tres + mevcut component birlestir
- Sistemler arasi iletisim = signal (loose coupling)

### v3.0 Hedef Component Eslesmesi

| Yapi | Component | Mekanik |
|------|-----------|---------|
| Uplink | generator | Kaynaktan veri cek |
| Classifier | classifier (binary) | Secilen content sag, kalan sol |
| Separator | processor → ayri comp | Secilen state sag, kalan sol |
| Decryptor | dual_input | Veri + Key → Decrypted |
| Recoverer | dual_input (yeni) | Veri + ayni tur yakit → Recovered |
| Research Lab | producer | Research → Key |
| Encryptor | dual_input (yeni) | Veri + Key → Encrypted |
| Compiler | dual_input (yeni) | A + B → Paket [A·B] |
| Splitter | splitter | 1→2 |
| Merger | merger | 2→1 |
| Bridge | ozel | Kablo kesisimi |
| Trash | yeni basit | Veri imha |
| Contract Terminal | yeni ozel | Gig + teslimat |

---

## Renk Paleti
**State:** Public `#00ffaa`, Encrypted `#2288ff`, Corrupted `#ffaa00`, Malware `#ff1133`
**Content:** Standard `#7788aa`, Financial `#ffcc00`, Biometric `#ff33aa`, Blueprint `#00ffcc`, Research `#9955ff`, Classified `#ff3388`, Key `#ffaa00`
**UI:** `#00bbee` | **BG:** `#060a10` | **Grid:** `#0f1520`

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
- **OYUN DILI INGILIZCE** — Tum user-facing text Ingilizce. Turkce string YAZMA.
- Kullanici teknik degil — ne/neden acikla, kod detayi verme
- Commit + push birlikte, kullanici onayi ile
- Tamamlanan isler commit mesajinda belirt, CLAUDE.md'den kaldir
