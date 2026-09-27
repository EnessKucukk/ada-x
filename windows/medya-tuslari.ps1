# Medya Tuşları - bu dosyayı değil, BASLAT.bat dosyasını çalıştır.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$kod = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public class Eylem
{
    public string Kimlik, Ad;
    public byte MedyaVk;                 // 0 ise ayar menüsünü açar
    public int Mod, VMod, TMod;          // 0 kapalı, 1 iki kez bas, 2 kısayol   (V = varsayılan, T = taslak)
    public uint Tus, VTus, TTus;
    public int Ekler, VEkler, TEkler;    // basılı tutulan tuşlar (Ctrl, Shift, Alt, Win, Tab)
    public ComboBox ModKutu;
    public Button TusDugme;

    public Eylem(string kimlik, string ad, byte medyaVk, int mod, uint tus, int ekler)
    {
        Kimlik = kimlik; Ad = ad; MedyaVk = medyaVk;
        Mod = VMod = mod; Tus = VTus = tus; Ekler = VEkler = ekler;
    }
}

public static class MedyaTuslari
{
    const uint VK_ESCAPE = 0x1B;
    const byte VK_VOLUME_MUTE = 0xAD, VK_VOLUME_DOWN = 0xAE, VK_VOLUME_UP = 0xAF;
    const byte VK_MEDIA_NEXT = 0xB0, VK_MEDIA_PREV = 0xB1, VK_MEDIA_PLAY_PAUSE = 0xB3;
    const byte VK_MASKE = 0xE8;   // boş tuş: Win/Alt bırakılınca Başlat menüsü açılmasın diye

    static readonly uint[] EK_TUSLAR = { 0xA2, 0xA3, 0xA0, 0xA1, 0xA4, 0xA5, 0x5B, 0x5C, 0x09 };
    static readonly string[] EK_ADLARI = { "Sol Ctrl", "Sağ Ctrl", "Sol Shift", "Sağ Shift", "Sol Alt", "Sağ Alt", "Sol Win", "Sağ Win", "Tab" };
    const int ALT_WIN = (1 << 4) | (1 << 5) | (1 << 6) | (1 << 7);
    const int TAB = 1 << 8;

    // ---------- Windows API ----------
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x100, WM_KEYUP = 0x101, WM_SYSKEYDOWN = 0x104, WM_SYSKEYUP = 0x105;
    const uint LLKHF_INJECTED = 0x10;
    const uint KEYEVENTF_EXTENDEDKEY = 0x1, KEYEVENTF_KEYUP = 0x2;

    delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr extra; }

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint mapType);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);

    // ---------- Durum ----------
    static List<Eylem> eylemler = new List<Eylem>();
    static int ciftMs = 300, sesAdimi = 2;
    static IntPtr hook = IntPtr.Zero;
    static HookProc proc = TusGeldi;   // çöp toplayıcı silmesin diye alanda tutuluyor
    static bool[] basili = new bool[256];
    static bool[] bastirildi = new bool[256];
    static uint sonTus = 0;
    static int sonZaman = 0;
    static Eylem yakalanan = null;     // şu an tuşu kaydedilen işlem
    static bool yukleniyor = false;

    static string betikYolu, ayarDosyasi;
    static EventWaitHandle goster;
    static Icon simge;
    static Form form;
    static Font kalin;
    static NotifyIcon ikon;
    static NumericUpDown ciftKutu, adimKutu;
    static CheckBox baslangicKutu;

    // =====================================================================
    public static void Baslat(string betik, bool gizli)
    {
        bool yeni;
        goster = new EventWaitHandle(false, EventResetMode.AutoReset, "MedyaTuslari_AyarlariGoster", out yeni);
        if (!yeni) { goster.Set(); return; }   // zaten çalışıyor: onun ayar penceresini aç

        betikYolu = betik;
        ayarDosyasi = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MedyaTuslari", "ayarlar.txt");

        eylemler.Add(new Eylem("oynat",   "Oynat / Duraklat", VK_MEDIA_PLAY_PAUSE, 1, 0xA3, 0));
        eylemler.Add(new Eylem("sessiz",  "Sesi kapat / aç",  VK_VOLUME_MUTE,      1, 0xA1, 0));
        eylemler.Add(new Eylem("sesac",   "Ses aç",           VK_VOLUME_UP,        2, 0x26, 1 << 1));
        eylemler.Add(new Eylem("seskis",  "Ses kıs",          VK_VOLUME_DOWN,      2, 0x28, 1 << 1));
        eylemler.Add(new Eylem("sonraki", "Sonraki şarkı",    VK_MEDIA_NEXT,       2, 0x27, 1 << 1));
        eylemler.Add(new Eylem("onceki",  "Önceki şarkı",     VK_MEDIA_PREV,       2, 0x25, 1 << 1));
        eylemler.Add(new Eylem("menu",    "Bu menüyü aç",     0,                   2, 0x51, TAB));
        AyarlariOku();

        Application.EnableVisualStyles();
        simge = SimgeYap();
        FormuKur();
        IkonuKur();

        hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
        if (hook == IntPtr.Zero)
        {
            MessageBox.Show("Klavye dinlenemedi.", "Medya Tuşları");
            return;
        }

        Thread dinleyici = new Thread(new ThreadStart(delegate()
        {
            while (true)
            {
                goster.WaitOne();
                form.BeginInvoke(new MethodInvoker(AyarlariGoster));
            }
        }));
        dinleyici.IsBackground = true;
        dinleyici.Start();

        if (!gizli) AyarlariGoster();
        Application.Run();

        ikon.Visible = false;
        ikon.Dispose();
        UnhookWindowsHookEx(hook);
    }

    // =====================================================================
    //  Klavye
    // =====================================================================
    static IntPtr TusGeldi(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            KBDLLHOOKSTRUCT k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            int msg = wParam.ToInt32();
            uint vk = k.vkCode & 0xFF;

            if ((k.flags & LLKHF_INJECTED) == 0)   // kendi gönderdiğimiz tuşları yok say
            {
                if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN)
                {
                    bool tekrar = basili[vk];      // basılı tutunca Windows tekrar gönderir
                    basili[vk] = true;
                    if (TusIsle(vk, tekrar)) return (IntPtr)1;
                }
                else if (msg == WM_KEYUP || msg == WM_SYSKEYUP)
                {
                    basili[vk] = false;
                    if (bastirildi[vk]) { bastirildi[vk] = false; return (IntPtr)1; }
                }
            }
        }
        return CallNextHookEx(hook, nCode, wParam, lParam);
    }

    // true dönerse tuş programlara gitmez
    static bool TusIsle(uint vk, bool tekrar)
    {
        // --- Ayar penceresinde tuş kaydediliyor ---
        if (yakalanan != null)
        {
            Eylem e = yakalanan;
            if (vk == VK_ESCAPE) { YakalamaIptal(); bastirildi[vk] = true; return true; }
            if (e.TMod == 2 && EkMi(vk)) return false;   // Ctrl/Shift/Alt/Win/Tab: asıl tuşu bekle
            if (tekrar) return true;

            e.TTus = vk;
            e.TEkler = e.TMod == 2 ? SuankiEkler() : 0;
            if ((e.TEkler & ALT_WIN) != 0) Bas(VK_MASKE, false);
            yakalanan = null;
            DugmeYaz(e);
            bastirildi[vk] = true;
            return true;
        }

        // --- Kısayollar (Sağ Ctrl + Yukarı gibi) ---
        int ekler = SuankiEkler();
        foreach (Eylem e in eylemler)
        {
            if (e.Mod == 2 && e.Tus == vk && e.Ekler == ekler)
            {
                bool sesTusu = e.MedyaVk == VK_VOLUME_UP || e.MedyaVk == VK_VOLUME_DOWN;
                if (!tekrar || sesTusu) Calistir(e);   // basılı tutunca sadece ses değişmeye devam etsin
                if ((ekler & ALT_WIN) != 0) Bas(VK_MASKE, false);
                sonTus = 0;
                bastirildi[vk] = true;
                return true;
            }
        }

        // --- İki kez basma ---
        if (!tekrar)
        {
            int simdi = Environment.TickCount;
            if (vk == sonTus && simdi - sonZaman < ciftMs)
            {
                foreach (Eylem e in eylemler)
                    if (e.Mod == 1 && e.Tus == vk) Calistir(e);
                sonTus = 0;
            }
            else
            {
                sonTus = vk;
                sonZaman = simdi;
            }
        }
        return false;
    }

    static void Calistir(Eylem e)
    {
        if (e.MedyaVk == 0) { form.BeginInvoke(new MethodInvoker(AyarlariGoster)); return; }
        int adet = 1;
        if (e.MedyaVk == VK_VOLUME_UP || e.MedyaVk == VK_VOLUME_DOWN) adet = Math.Max(1, sesAdimi / 2);   // Windows her basışta %2 değiştirir
        for (int i = 0; i < adet; i++) Bas(e.MedyaVk, true);
    }

    static void Bas(byte vk, bool genis)
    {
        uint f = genis ? KEYEVENTF_EXTENDEDKEY : 0;
        keybd_event(vk, 0, f, UIntPtr.Zero);
        keybd_event(vk, 0, f | KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    static bool EkMi(uint vk)
    {
        if (vk == 0x10 || vk == 0x11 || vk == 0x12) return true;
        foreach (uint t in EK_TUSLAR) if (t == vk) return true;
        return false;
    }

    static int SuankiEkler()
    {
        int m = 0;
        for (int i = 0; i < EK_TUSLAR.Length; i++)
            if ((GetAsyncKeyState((int)EK_TUSLAR[i]) & 0x8000) != 0) m |= 1 << i;
        return m;
    }

    // =====================================================================
    //  Tuş adları
    // =====================================================================
    static string TusAdi(uint vk)
    {
        for (int i = 0; i < EK_TUSLAR.Length; i++) if (EK_TUSLAR[i] == vk) return EK_ADLARI[i];
        switch (vk)
        {
            case 0x25: return "Sol ok";
            case 0x26: return "Yukarı ok";
            case 0x27: return "Sağ ok";
            case 0x28: return "Aşağı ok";
            case 0x20: return "Boşluk";
            case 0x0D: return "Enter";
            case 0x08: return "Geri sil";
            case 0x14: return "Caps Lock";
            case 0x90: return "Num Lock";
            case 0x91: return "Scroll Lock";
            case 0x13: return "Pause";
            case 0x2C: return "Print Screen";
            case 0x2D: return "Insert";
            case 0x2E: return "Delete";
            case 0x24: return "Home";
            case 0x23: return "End";
            case 0x21: return "Page Up";
            case 0x22: return "Page Down";
            case 0x5D: return "Menü tuşu";
            case 0x6A: return "Numpad *";
            case 0x6B: return "Numpad +";
            case 0x6D: return "Numpad -";
            case 0x6E: return "Numpad ,";
            case 0x6F: return "Numpad /";
            case 0xAD: return "Sessiz tuşu";
            case 0xAE: return "Ses kıs tuşu";
            case 0xAF: return "Ses aç tuşu";
            case 0xB0: return "Sonraki tuşu";
            case 0xB1: return "Önceki tuşu";
            case 0xB3: return "Oynat tuşu";
        }
        if (vk >= 0x70 && vk <= 0x87) return "F" + (vk - 0x6F);
        if (vk >= 0x60 && vk <= 0x69) return "Numpad " + (vk - 0x60);
        uint c = MapVirtualKey(vk, 2) & 0xFFFF;
        if (c > 32) return char.ToUpper((char)c).ToString();
        return ((Keys)vk).ToString();
    }

    static string KombinasyonAdi(int ekler, uint tus)
    {
        string s = "";
        for (int i = 0; i < EK_TUSLAR.Length; i++)
            if ((ekler & (1 << i)) != 0) s += EK_ADLARI[i] + " + ";
        return s + TusAdi(tus);
    }

    // =====================================================================
    //  Ayar dosyası  (%APPDATA%\MedyaTuslari\ayarlar.txt)
    // =====================================================================
    static void AyarlariOku()
    {
        if (!File.Exists(ayarDosyasi)) return;
        try
        {
            foreach (string satir in File.ReadAllLines(ayarDosyasi))
            {
                int i = satir.IndexOf('=');
                if (i < 0) continue;
                string ad = satir.Substring(0, i).Trim();
                string deger = satir.Substring(i + 1).Trim();
                if (ad == "cift_ms") ciftMs = int.Parse(deger);
                else if (ad == "ses_adimi") sesAdimi = int.Parse(deger);
                else
                {
                    foreach (Eylem e in eylemler)
                    {
                        if (e.Kimlik != ad) continue;
                        string[] p = deger.Split(',');
                        e.Mod = int.Parse(p[0]);
                        e.Tus = uint.Parse(p[1]);
                        e.Ekler = int.Parse(p[2]);
                    }
                }
            }
        }
        catch { }
        ciftMs = Math.Min(1000, Math.Max(150, ciftMs / 50 * 50));
        sesAdimi = Math.Min(20, Math.Max(2, sesAdimi / 2 * 2));
    }

    static void AyarlariYaz()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(ayarDosyasi));
        List<string> satirlar = new List<string>();
        satirlar.Add("cift_ms=" + ciftMs);
        satirlar.Add("ses_adimi=" + sesAdimi);
        foreach (Eylem e in eylemler) satirlar.Add(e.Kimlik + "=" + e.Mod + "," + e.Tus + "," + e.Ekler);
        File.WriteAllLines(ayarDosyasi, satirlar.ToArray());
    }

    static string KisayolYolu()
    {
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), "Medya Tuslari.lnk");
    }

    static void BaslangicAyarla(bool acik)
    {
        string yol = KisayolYolu();
        if (!acik)
        {
            if (File.Exists(yol)) File.Delete(yol);
            return;
        }
        Type t = Type.GetTypeFromProgID("WScript.Shell");
        object kabuk = Activator.CreateInstance(t);
        object lnk = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, kabuk, new object[] { yol });
        Type lt = lnk.GetType();
        lt.InvokeMember("TargetPath", BindingFlags.SetProperty, null, lnk,
            new object[] { Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe") });
        lt.InvokeMember("Arguments", BindingFlags.SetProperty, null, lnk,
            new object[] { "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + betikYolu + "\" gizli" });
        lt.InvokeMember("WindowStyle", BindingFlags.SetProperty, null, lnk, new object[] { 7 });
        lt.InvokeMember("Save", BindingFlags.InvokeMethod, null, lnk, null);
    }

    // =====================================================================
    //  Pencere
    // =====================================================================
    static TableLayoutPanel YeniTablo(int kolon)
    {
        TableLayoutPanel t = new TableLayoutPanel();
        t.ColumnCount = kolon;
        t.AutoSize = true;
        t.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        t.Margin = new Padding(0);
        return t;
    }

    static Label YeniEtiket(string yazi, bool koyu, Padding bosluk)
    {
        Label l = new Label();
        l.Text = yazi;
        l.AutoSize = true;
        l.Margin = bosluk;
        l.Anchor = AnchorStyles.Left;
        if (koyu) l.Font = kalin;
        return l;
    }

    static NumericUpDown YeniSayi(int en, int cok, int adim)
    {
        NumericUpDown n = new NumericUpDown();
        n.Minimum = en; n.Maximum = cok; n.Increment = adim;
        n.Width = TextRenderer.MeasureText("00000", form.Font).Width + 30;
        n.Anchor = AnchorStyles.Left;
        return n;
    }

    static Button YeniDugme(string yazi)
    {
        Button b = new Button();
        b.Text = yazi;
        b.AutoSize = true;
        b.Padding = new Padding(10, 3, 10, 3);
        b.Margin = new Padding(6, 0, 0, 0);
        return b;
    }

    static void FormuKur()
    {
        form = new Form();
        form.Text = "Medya Tuşları - Ayarlar";
        form.Font = new Font("Segoe UI", 10f);
        kalin = new Font(form.Font, FontStyle.Bold);
        form.Icon = simge;
        form.FormBorderStyle = FormBorderStyle.FixedDialog;
        form.MaximizeBox = false;
        form.StartPosition = FormStartPosition.CenterScreen;
        form.AutoSize = true;
        form.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        form.Padding = new Padding(14);
        form.FormClosing += delegate(object s, FormClosingEventArgs a)
        {
            if (a.CloseReason == CloseReason.UserClosing) { a.Cancel = true; Gizle(); }   // X: kaydetmeden gizle
        };

        TableLayoutPanel ana = YeniTablo(1);
        form.Controls.Add(ana);

        ana.Controls.Add(YeniEtiket("Her işlem için nasıl çalışacağını seç, sonra sağdaki düğmeye\ntıklayıp kullanmak istediğin tuşa bas. Bitince Kaydet'e bas.",
            false, new Padding(3, 0, 3, 12)));

        TableLayoutPanel tablo = YeniTablo(3);
        tablo.Controls.Add(YeniEtiket("İşlem", true, new Padding(3, 0, 16, 4)));
        tablo.Controls.Add(YeniEtiket("Nasıl?", true, new Padding(3, 0, 12, 4)));
        tablo.Controls.Add(YeniEtiket("Tuş", true, new Padding(3, 0, 3, 4)));

        int modGenislik = TextRenderer.MeasureText("Kısayol (tuş birleşimi)", form.Font).Width + 40;
        int tusGenislik = TextRenderer.MeasureText("Tuşlara birlikte bas... (Esc: iptal)", form.Font).Width + 30;

        foreach (Eylem e in eylemler)
        {
            Eylem bu = e;
            tablo.Controls.Add(YeniEtiket(e.Ad, false, new Padding(3, 6, 16, 3)));

            ComboBox mk = new ComboBox();
            mk.DropDownStyle = ComboBoxStyle.DropDownList;
            mk.Width = modGenislik;
            mk.Items.AddRange(new object[] { "Kapalı", "2 kez bas", "Kısayol (tuş birleşimi)" });
            mk.Margin = new Padding(3, 5, 12, 3);
            mk.Anchor = AnchorStyles.Left;
            mk.SelectedIndexChanged += delegate { ModDegisti(bu); };

            Button td = new Button();
            td.AutoSize = true;
            td.MinimumSize = new Size(tusGenislik, 0);
            td.Margin = new Padding(3);
            td.Click += delegate { YakalamaBaslat(bu); };

            e.ModKutu = mk;
            e.TusDugme = td;
            tablo.Controls.Add(mk);
            tablo.Controls.Add(td);
        }
        ana.Controls.Add(tablo);

        TableLayoutPanel secenek = YeniTablo(2);
        secenek.Margin = new Padding(0, 14, 0, 0);
        ciftKutu = YeniSayi(150, 1000, 50);
        adimKutu = YeniSayi(2, 20, 2);
        secenek.Controls.Add(YeniEtiket("İki basış arası en fazla (milisaniye):", false, new Padding(3, 6, 12, 3)));
        secenek.Controls.Add(ciftKutu);
        secenek.Controls.Add(YeniEtiket("Ses her seferde kaç % değişsin:", false, new Padding(3, 6, 12, 3)));
        secenek.Controls.Add(adimKutu);
        baslangicKutu = new CheckBox();
        baslangicKutu.Text = "Windows açılınca otomatik başlat";
        baslangicKutu.AutoSize = true;
        baslangicKutu.Margin = new Padding(3, 10, 3, 3);
        secenek.Controls.Add(baslangicKutu);
        secenek.SetColumnSpan(baslangicKutu, 2);
        ana.Controls.Add(secenek);

        FlowLayoutPanel dugmeler = new FlowLayoutPanel();
        dugmeler.FlowDirection = FlowDirection.RightToLeft;
        dugmeler.WrapContents = false;
        dugmeler.AutoSize = true;
        dugmeler.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        dugmeler.Anchor = AnchorStyles.Right;
        dugmeler.Margin = new Padding(0, 18, 0, 0);

        Button kaydet = YeniDugme("Kaydet");
        kaydet.Font = kalin;
        kaydet.Click += delegate { Kaydet(); };
        Button kapat = YeniDugme("Programı kapat");
        kapat.Click += delegate { Application.Exit(); };
        Button varsayilan = YeniDugme("Varsayılana dön");
        varsayilan.Click += delegate { Varsayilan(); };
        dugmeler.Controls.Add(kaydet);
        dugmeler.Controls.Add(kapat);
        dugmeler.Controls.Add(varsayilan);
        ana.Controls.Add(dugmeler);
        form.AcceptButton = kaydet;

        IntPtr h = form.Handle;   // BeginInvoke için pencere hazır olsun
    }

    static void IkonuKur()
    {
        ikon = new NotifyIcon();
        ikon.Icon = simge;
        ikon.Text = "Medya Tuşları";
        ContextMenuStrip menu = new ContextMenuStrip();
        menu.Items.Add("Ayarlar", null, delegate { AyarlariGoster(); });
        menu.Items.Add("Kapat", null, delegate { Application.Exit(); });
        ikon.ContextMenuStrip = menu;
        ikon.DoubleClick += delegate { AyarlariGoster(); };
        ikon.Visible = true;
    }

    static Icon SimgeYap()
    {
        Bitmap bmp = new Bitmap(32, 32);
        using (Graphics g = Graphics.FromImage(bmp))
        using (SolidBrush mavi = new SolidBrush(Color.FromArgb(30, 136, 229)))
        using (Font f = new Font("Segoe UI Symbol", 20, FontStyle.Bold, GraphicsUnit.Pixel))
        using (StringFormat sf = new StringFormat())
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            g.FillEllipse(mavi, 0, 0, 31, 31);
            sf.Alignment = StringAlignment.Center;
            sf.LineAlignment = StringAlignment.Center;
            g.DrawString("♪", f, Brushes.White, new RectangleF(0, 1, 32, 32), sf);
        }
        return Icon.FromHandle(bmp.GetHicon());
    }

    // ---------- Pencere olayları ----------
    static void AyarlariGoster()
    {
        if (!form.Visible) TaslagiYukle();
        form.Show();
        if (form.WindowState == FormWindowState.Minimized) form.WindowState = FormWindowState.Normal;
        form.TopMost = true;    // öne gelsin
        form.TopMost = false;
        form.Activate();
    }

    static void Gizle()
    {
        YakalamaIptal();
        form.Hide();
    }

    static void TaslagiYukle()
    {
        foreach (Eylem e in eylemler) { e.TMod = e.Mod; e.TTus = e.Tus; e.TEkler = e.Ekler; }
        ciftKutu.Value = ciftMs;
        adimKutu.Value = sesAdimi;
        baslangicKutu.Checked = File.Exists(KisayolYolu());
        EkraniYenile();
    }

    static void EkraniYenile()
    {
        yukleniyor = true;
        foreach (Eylem e in eylemler) { e.ModKutu.SelectedIndex = e.TMod; DugmeYaz(e); }
        yukleniyor = false;
    }

    static void Varsayilan()
    {
        YakalamaIptal();
        foreach (Eylem e in eylemler) { e.TMod = e.VMod; e.TTus = e.VTus; e.TEkler = e.VEkler; }
        ciftKutu.Value = 300;
        adimKutu.Value = 2;
        EkraniYenile();
    }

    static void ModDegisti(Eylem e)
    {
        if (yukleniyor) return;
        YakalamaIptal();
        e.TMod = e.ModKutu.SelectedIndex;
        if (e.TMod == 2 && EkMi(e.TTus)) e.TTus = 0;   // kısayolda asıl tuş Ctrl/Shift olamaz
        if (e.TMod == 1) e.TEkler = 0;
        DugmeYaz(e);
        if (e.TMod != 0 && e.TTus == 0) YakalamaBaslat(e);
    }

    static void DugmeYaz(Eylem e)
    {
        Button b = e.TusDugme;
        b.Enabled = e.TMod != 0;
        if (yakalanan == e) b.Text = e.TMod == 1 ? "Bir tuşa bas... (Esc: iptal)" : "Tuşlara birlikte bas... (Esc: iptal)";
        else if (e.TMod == 0) b.Text = "—";
        else if (e.TTus == 0) b.Text = "Tıkla ve tuşa bas";
        else b.Text = KombinasyonAdi(e.TEkler, e.TTus);
    }

    static void YakalamaBaslat(Eylem e)
    {
        if (e.TMod == 0) return;
        YakalamaIptal();
        yakalanan = e;
        DugmeYaz(e);
    }

    static void YakalamaIptal()
    {
        if (yakalanan == null) return;
        Eylem e = yakalanan;
        yakalanan = null;
        DugmeYaz(e);
    }

    static void Kaydet()
    {
        YakalamaIptal();
        foreach (Eylem e in eylemler)
        {
            if (e.TMod != 0 && e.TTus == 0)
            {
                MessageBox.Show(form, "\"" + e.Ad + "\" için bir tuş seçmedin.", "Medya Tuşları");
                return;
            }
        }
        for (int i = 0; i < eylemler.Count; i++)
        {
            for (int j = i + 1; j < eylemler.Count; j++)
            {
                Eylem a = eylemler[i], b = eylemler[j];
                if (a.TMod != 0 && a.TMod == b.TMod && a.TTus == b.TTus && a.TEkler == b.TEkler)
                {
                    MessageBox.Show(form, "\"" + a.Ad + "\" ile \"" + b.Ad + "\" aynı tuşu kullanıyor.", "Medya Tuşları");
                    return;
                }
            }
        }

        foreach (Eylem e in eylemler) { e.Mod = e.TMod; e.Tus = e.TTus; e.Ekler = e.TEkler; }
        ciftMs = (int)ciftKutu.Value;
        sesAdimi = (int)adimKutu.Value;

        try { AyarlariYaz(); }
        catch (Exception ex) { MessageBox.Show(form, "Ayarlar kaydedilemedi:\n" + ex.Message, "Medya Tuşları"); }
        try { BaslangicAyarla(baslangicKutu.Checked); }
        catch (Exception ex) { MessageBox.Show(form, "Otomatik başlatma ayarlanamadı:\n" + ex.Message, "Medya Tuşları"); }

        Gizle();
        ikon.ShowBalloonTip(3000, "Medya Tuşları", "Kaydedildi. Program sağ alttaki ♪ simgesinde çalışıyor.", ToolTipIcon.Info);
    }
}
'@

try {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $kod -IgnoreWarnings -ErrorAction Stop
    [MedyaTuslari]::Baslat($PSCommandPath, ($args -contains 'gizli'))
}
catch {
    $mesaj = ($Error | Select-Object -First 6 | ForEach-Object { $_.ToString() }) -join "`n`n"
    [System.Windows.Forms.MessageBox]::Show("Bir hata oluştu:`n`n$mesaj", "Medya Tuşları") | Out-Null
}
