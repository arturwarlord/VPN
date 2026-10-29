using System.Diagnostics;
using System.Drawing;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace FreeRoute.Windows;

internal sealed class MainForm : Form
{
    private sealed class ProfileItem
    {
        public string Name { get; }
        public string FilePath { get; }
        public bool HasIpv6DefaultRoute { get; }

        public ProfileItem(string name, string filePath, bool hasIpv6DefaultRoute)
        {
            Name = name;
            FilePath = filePath;
            HasIpv6DefaultRoute = hasIpv6DefaultRoute;
        }

        public override string ToString() => Name;
    }

    private readonly string _profilesDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "FreeRouteVPN", "Profiles");
    private readonly ListBox _profiles = new();
    private readonly Label _status = new();
    private readonly Label _hint = new();
    private readonly Button _importButton;
    private readonly Button _connectButton;
    private readonly Button _disconnectButton;
    private bool _busy;
    private string? _connectedProfileName;

    private string BundledEngineDirectory => Path.Combine(AppContext.BaseDirectory, "wireguard");
    private string InstalledEngineDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
        "FreeRouteVPN", "wireguard");
    private string InstalledEnginePath => Path.Combine(InstalledEngineDirectory, "wireguard.exe");

    public MainForm()
    {
        Text = "FreeRoute VPN";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(580, 610);
        Size = new Size(680, 700);
        BackColor = Color.FromArgb(11, 16, 32);
        ForeColor = Color.White;
        Font = new Font("Segoe UI", 10f);
        FormBorderStyle = FormBorderStyle.Sizable;

        var layout = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true,
            Padding = new Padding(24),
            BackColor = BackColor
        };

        var title = new Label
        {
            Text = "FreeRoute",
            Font = new Font("Segoe UI", 24f, FontStyle.Bold),
            ForeColor = Color.White,
            Width = 590,
            Height = 44,
            TextAlign = ContentAlignment.MiddleLeft
        };
        layout.Controls.Add(title);

        var subtitle = new Label
        {
            Text = "Личный VPN-клиент для Windows",
            ForeColor = Color.FromArgb(170, 184, 210),
            Width = 590,
            Height = 30
        };
        layout.Controls.Add(subtitle);

        _status.Text = "Готов к настройке";
        _status.Width = 590;
        _status.Height = 64;
        _status.Padding = new Padding(12);
        _status.TextAlign = ContentAlignment.MiddleLeft;
        _status.BackColor = Color.FromArgb(24, 34, 55);
        _status.ForeColor = Color.White;
        layout.Controls.Add(_status);

        _hint.Text = "Профили сохраняются только в локальной учётной записи Windows.";
        _hint.Width = 590;
        _hint.Height = 54;
        _hint.ForeColor = Color.FromArgb(170, 184, 210);
        layout.Controls.Add(_hint);

        _profiles.Width = 590;
        _profiles.Height = 220;
        _profiles.BackColor = Color.FromArgb(24, 34, 55);
        _profiles.ForeColor = Color.White;
        _profiles.BorderStyle = BorderStyle.None;
        _profiles.SelectedIndexChanged += (_, _) => UpdateSelectionHint();
        layout.Controls.Add(_profiles);

        var buttons = new FlowLayoutPanel
        {
            Width = 590,
            Height = 52,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            BackColor = BackColor
        };

        _importButton = MakeButton("Добавить профиль", Color.FromArgb(47, 88, 158), 165);
        _importButton.Click += (_, _) => ImportProfile();
        buttons.Controls.Add(_importButton);

        _connectButton = MakeButton("Подключить", Color.FromArgb(39, 142, 101), 130);
        _connectButton.Click += async (_, _) => await ConnectSelectedAsync();
        buttons.Controls.Add(_connectButton);

        _disconnectButton = MakeButton("Отключить", Color.FromArgb(74, 83, 104), 120);
        _disconnectButton.Click += async (_, _) => await DisconnectAsync();
        buttons.Controls.Add(_disconnectButton);
        layout.Controls.Add(buttons);

        var note = new Label
        {
            Text = "Имя профиля не подтверждает страну сервера. Выходная страна определяется адресом удалённого узла. Перед подключением приложение предупреждает об отсутствующем IPv6-маршруте.",
            ForeColor = Color.FromArgb(140, 153, 177),
            Width = 590,
            Height = 62
        };
        layout.Controls.Add(note);

        Controls.Add(layout);
        Directory.CreateDirectory(_profilesDirectory);
        ReloadProfiles();
        UpdateButtons();
        Shown += async (_, _) => await RefreshConnectedProfileAsync();
    }

    private static Button MakeButton(string text, Color background, int width) => new()
    {
        Text = text,
        Width = width,
        Height = 42,
        FlatStyle = FlatStyle.Flat,
        BackColor = background,
        ForeColor = Color.White,
        Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
        UseVisualStyleBackColor = false,
        Margin = new Padding(0, 0, 10, 0)
    };

    private void ImportProfile()
    {
        using var dialog = new OpenFileDialog
        {
            Title = "Импортировать профиль WireGuard",
            Filter = "WireGuard config (*.conf)|*.conf|All files (*.*)|*.*",
            CheckFileExists = true,
            Multiselect = false
        };

        if (dialog.ShowDialog(this) != DialogResult.OK)
            return;

        try
        {
            var text = File.ReadAllText(dialog.FileName, Encoding.UTF8);
            ValidateProfile(text);
            var destination = GetUniqueProfilePath(Path.GetFileNameWithoutExtension(dialog.FileName));
            File.WriteAllText(destination, text, new UTF8Encoding(false));
            ReloadProfiles(Path.GetFileName(destination));
            _status.Text = "Профиль добавлен локально";
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                this,
                "Не удалось импортировать профиль. Проверь, что это корректный WireGuard .conf файл.\n\n" + ex.Message,
                "Ошибка импорта",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private static void ValidateProfile(string text)
    {
        if (text.Length == 0 || text.Length > 65536)
            throw new InvalidDataException("Размер файла должен быть меньше 64 КБ.");
        var hasInterface = Regex.IsMatch(text, @"(?im)^\s*\[Interface\]\s*$");
        var hasPeer = Regex.IsMatch(text, @"(?im)^\s*\[Peer\]\s*$");
        var hasPrivateKey = Regex.IsMatch(text, @"(?im)^\s*PrivateKey\s*=\s*\S+");
        var hasPublicKey = Regex.IsMatch(text, @"(?im)^\s*PublicKey\s*=\s*\S+");
        var hasEndpoint = Regex.IsMatch(text, @"(?im)^\s*Endpoint\s*=\s*\S+");
        var hasAllowedIps = Regex.IsMatch(text, @"(?im)^\s*AllowedIPs\s*=\s*\S+");
        if (!hasInterface || !hasPeer || !hasPrivateKey || !hasPublicKey || !hasEndpoint || !hasAllowedIps)
            throw new InvalidDataException("Отсутствуют обязательные секции или параметры WireGuard.");
    }

    private string GetUniqueProfilePath(string originalName)
    {
        var safe = Regex.Replace(originalName, @"[^A-Za-z0-9_.-]", "_").Trim('.', '_', '-');
        if (string.IsNullOrWhiteSpace(safe))
            safe = "profile";
        safe = safe[..Math.Min(safe.Length, 15)];

        var candidate = Path.Combine(_profilesDirectory, safe + ".conf");
        var suffix = 2;
        while (File.Exists(candidate))
        {
            var prefix = safe[..Math.Min(safe.Length, 12)];
            candidate = Path.Combine(_profilesDirectory, prefix + "-" + suffix + ".conf");
            suffix++;
        }
        return candidate;
    }

    private void ReloadProfiles(string? selectFileName = null)
    {
        var old = _profiles.SelectedItem as ProfileItem;
        var desiredName = selectFileName ?? old?.FilePath;
        _profiles.BeginUpdate();
        _profiles.Items.Clear();
        foreach (var path in Directory.EnumerateFiles(_profilesDirectory, "*.conf").OrderBy(Path.GetFileName))
        {
            try
            {
                var text = File.ReadAllText(path, Encoding.UTF8);
                ValidateProfile(text);
                var hasIpv6 = Regex.Matches(text, @"(?im)^\s*AllowedIPs\s*=([^\r\n]+)")
                    .SelectMany(m => m.Groups[1].Value.Split(','))
                    .Any(value => value.Trim().Equals("::/0", StringComparison.OrdinalIgnoreCase));
                _profiles.Items.Add(new ProfileItem(Path.GetFileNameWithoutExtension(path), path, hasIpv6));
            }
            catch
            {
                // An invalid file is not shown in the profile list.
            }
        }
        _profiles.EndUpdate();

        if (_profiles.Items.Count > 0)
        {
            var index = Enumerable.Range(0, _profiles.Items.Count)
                .FirstOrDefault(i => string.Equals(
                    ((ProfileItem)_profiles.Items[i]!).FilePath,
                    desiredName,
                    StringComparison.OrdinalIgnoreCase), -1);
            _profiles.SelectedIndex = index >= 0 ? index : 0;
        }
        UpdateSelectionHint();
        UpdateButtons();
    }

    private ProfileItem? SelectedProfile => _profiles.SelectedItem as ProfileItem;

    private void UpdateSelectionHint()
    {
        var item = SelectedProfile;
        if (item is null)
        {
            _hint.Text = "Импортируй WireGuard .conf профиль. Для разных стран нужны отдельные серверные профили.";
            return;
        }

        _hint.Text = item.HasIpv6DefaultRoute
            ? "Профиль: " + item.Name + " · есть маршрут IPv6; маршрутизацию сервера всё равно нужно проверить."
            : "Профиль: " + item.Name + " · IPv6-маршрут отсутствует — возможна утечка реального IP.";
    }

    private async Task ConnectSelectedAsync()
    {
        var selected = SelectedProfile;
        if (_busy || selected is null)
            return;

        if (!selected.HasIpv6DefaultRoute)
        {
            var answer = MessageBox.Show(
                this,
                "Этот профиль не направляет IPv6-трафик через VPN. Часть сайтов может увидеть исходное подключение и его страну. Продолжить?",
                "Возможна утечка IPv6",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning);
            if (answer != DialogResult.Yes)
                return;
        }

        SetBusy(true, "Подготавливаем VPN…");
        try
        {
            var currentlyRunning = await FindRunningProfileAsync();
            if (currentlyRunning is not null &&
                !string.Equals(currentlyRunning.Name, selected.Name, StringComparison.OrdinalIgnoreCase))
            {
                var answer = MessageBox.Show(
                    this,
                    "Сейчас подключён профиль " + currentlyRunning.Name + ". Отключить его и подключить " + selected.Name + "?",
                    "Смена VPN-профиля",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question);
                if (answer != DialogResult.Yes)
                    return;
                await RunTunnelCommandAsync("/uninstalltunnelservice", currentlyRunning.Name);
            }
            else if (currentlyRunning is not null)
            {
                _connectedProfileName = currentlyRunning.Name;
                _status.Text = "VPN уже подключён: " + currentlyRunning.Name;
                return;
            }

            _status.Text = "Устанавливаем VPN-туннель…";
            await RunTunnelCommandAsync("/installtunnelservice", selected.FilePath);
            _connectedProfileName = selected.Name;
            _status.Text = "Туннель запущен: " + selected.Name + ". Географический выход ещё нужно проверить.";
        }
        catch (Exception ex)
        {
            _status.Text = "Не удалось подключиться";
            MessageBox.Show(this, ex.Message, "Ошибка VPN", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            SetBusy(false, _status.Text);
            await RefreshConnectedProfileAsync();
        }
    }

    private async Task DisconnectAsync()
    {
        if (_busy)
            return;

        SetBusy(true, "Отключаем VPN…");
        try
        {
            var running = await FindRunningProfileAsync();
            if (running is null)
            {
                _connectedProfileName = null;
                _status.Text = "VPN отключён";
                return;
            }

            await RunTunnelCommandAsync("/uninstalltunnelservice", running.Name);
            _connectedProfileName = null;
            _status.Text = "VPN отключён";
        }
        catch (Exception ex)
        {
            _status.Text = "Не удалось отключить VPN";
            MessageBox.Show(this, ex.Message, "Ошибка VPN", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            SetBusy(false, _status.Text);
            await RefreshConnectedProfileAsync();
        }
    }

    private async Task RunTunnelCommandAsync(string command, string value)
    {
        var engine = EnsureEngineInstalled();
        await RunProcessAsync(engine, new[] { command, value }, requireSuccess: true);
    }

    private string EnsureEngineInstalled()
    {
        var bundledExe = Path.Combine(BundledEngineDirectory, "wireguard.exe");
        if (!File.Exists(bundledExe))
            throw new FileNotFoundException(
                "В комплекте отсутствует сетевой движок. Скачай пакет FreeRoute Windows из успешной GitHub Actions сборки.");

        if (!File.Exists(InstalledEnginePath))
        {
            Directory.CreateDirectory(InstalledEngineDirectory);
            foreach (var directory in Directory.EnumerateDirectories(BundledEngineDirectory, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(BundledEngineDirectory, directory);
                Directory.CreateDirectory(Path.Combine(InstalledEngineDirectory, relative));
            }
            foreach (var file in Directory.EnumerateFiles(BundledEngineDirectory, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(BundledEngineDirectory, file);
                var destination = Path.Combine(InstalledEngineDirectory, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                File.Copy(file, destination, overwrite: true);
            }
        }
        return InstalledEnginePath;
    }

    private async Task<(int ExitCode, string Output)> RunProcessAsync(
        string executable, IEnumerable<string> arguments, bool requireSuccess)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = executable,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var argument in arguments)
            startInfo.ArgumentList.Add(argument);

        using var process = new Process { StartInfo = startInfo };
        if (!process.Start())
            throw new InvalidOperationException("Не удалось запустить процесс VPN.");

        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        var output = (await stdout) + Environment.NewLine + (await stderr);
        if (requireSuccess && process.ExitCode != 0)
        {
            var detail = string.IsNullOrWhiteSpace(output) ? "Код ошибки: " + process.ExitCode : output.Trim();
            throw new InvalidOperationException("Команда VPN завершилась с ошибкой. " + detail);
        }
        return (process.ExitCode, output);
    }

    private async Task<ProfileItem?> FindRunningProfileAsync()
    {
        foreach (ProfileItem item in _profiles.Items)
        {
            var serviceName = "WireGuardTunnel$" + item.Name;
            var result = await RunProcessAsync(
                Path.Combine(Environment.SystemDirectory, "sc.exe"),
                new[] { "query", serviceName },
                requireSuccess: false);
            if (result.ExitCode == 0 && result.Output.Contains("RUNNING", StringComparison.OrdinalIgnoreCase))
                return item;
        }
        return null;
    }

    private async Task RefreshConnectedProfileAsync()
    {
        try
        {
            var running = await FindRunningProfileAsync();
            _connectedProfileName = running?.Name;
            _status.Text = running is null ? "VPN отключён" : "VPN подключён: " + running.Name;
        }
        catch
        {
            // Keep the previous visible status if Windows service status cannot be queried.
        }
        UpdateButtons();
    }

    private void SetBusy(bool busy, string status)
    {
        _busy = busy;
        _status.Text = status;
        UpdateButtons();
    }

    private void UpdateButtons()
    {
        _importButton.Enabled = !_busy && _connectedProfileName is null;
        _profiles.Enabled = !_busy && _connectedProfileName is null;
        _connectButton.Enabled = !_busy && SelectedProfile is not null;
        _disconnectButton.Enabled = !_busy && _connectedProfileName is not null;
    }
}
