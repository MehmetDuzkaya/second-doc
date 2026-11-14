# SecondDock ⚓️
### macOS Çoklu Monitör Dock Yöneticisi (ExtraDock Alternatifi)

SecondDock, macOS üzerinde her monitörünüze bağımsız dock'lar eklemenizi, dilediğiniz gibi konumlandırmanızı ve yönetmenizi sağlayan native (Swift & AppKit) bir masaüstü aracıdır.

---

## 🚀 Özellikler

1. **Bağımsız Çoklu Monitör Desteği:**
   - 1. Ekran, 2. Ekran veya harici monitörlerinizin her biri için ayrı ayrı dock'lar oluşturabilirsiniz.
   - Monitör takılıp çıkarıldığında dock'lar otomatik olarak kendi ekranlarına yeniden hizalanır.

2. **Sınırsız Dock Oluşturma & Silme:**
   - Menü çubuğundaki (Menu Bar) simgeden `➕ Yeni Dock Oluştur...` seçeneğiyle istediğiniz kadar dock açabilirsiniz.
   - Her dock'a özel isim verebilirsiniz (örn: *İş Araçları*, *Geliştirme*, *Tasarım*).

3. **Esnek Konumlandırma & Boyutlandırma:**
   - Her dock için ekranın **Alt**, **Üst**, **Sol** veya **Sağ** kenarını seçebilirsiniz.
   - İkon boyutu (32px - 96px arası) ayarlanabilir.

4. **Sürükle & Bırak (Drag & Drop):**
   - Finder veya Launchpad'den herhangi bir uygulamayı doğrudan dock'un üzerine sürükleyip bırakarak anında ekleyebilirsiniz.
   - Dock üzerindeki uygulamaya sağ tıklayarak **Finder'da Göster** veya **Dock'tan Kaldır** diyebilirsiniz.

5. **macOS Dock Efektleri:**
   - **Büyütme (Magnification):** Fareyi simgelerin üzerine getirdiğinizde macOS'in orijinal dock'undaki gibi akıcı büyüme efekti.
   - **Çalışma Göstergesi:** Açık olan uygulamaların altında küçük beyaz çalışma noktası (Running indicator).
   - **Tıklama Animasyonu:** Uygulamayı açarken sıçrama (bounce) animasyonu.
   - **Otomatik Gizleme (Auto-hide):** İsteğe bağlı olarak fare uzaklaştığında dock'u gizleme.
   - **Vibrancy (Buzlu Cam):** macOS Liquid Glass / HUD yarı saydam tasarımı.

6. **Kalıcılık (Persistence):**
   - Oluşturduğunuz tüm dock'lar, konumları ve eklenen uygulamalar `~/Library/Application Support/SecondDock/docks.json` dosyasında saklanır. Uygulamayı yeniden açtığınızda her şey kaldığı yerden gelir.


## 💡 Kullanım İpuçları

- **Menü Çubuğu (Status Bar):** Ekranın sağ üst köşesindeki dock simgesine tıklayarak tüm dock'larınızı görebilir, ayarlarını değiştirebilir veya yeni dock ekleyebilirsiniz.
- **Uygulama Ekleme:**
  - Finder'dan uygulamayı doğrudan dock'un üzerine sürükleyip bırakın.
  - Veya dock üzerindeki boş alana sağ tıklayıp **"Uygulama Ekle..."** seçin.
  - Veya menü çubuğundaki dock menüsünden **"Uygulama Ekle..."** deyin.
- **Uygulama Kaldırma:**
  - İkona sağ tıklayın -> **"Dock'tan Kaldır"**.
- **Dock Ayarları:**
  - Menü çubuğundan ilgili dock'un altındaki **"Ayarlar..."** seçeneğine tıklayarak monitörünü, kenarını, ikon boyutunu veya efektlerini dilediğiniz zaman güncelleyebilirsiniz.

