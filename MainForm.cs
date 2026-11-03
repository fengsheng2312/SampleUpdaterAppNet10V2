using System.Reflection;

namespace SampleUpdaterAppNet10V2;

public partial class MainForm : Form
{
    private AutoUpdateService? _autoUpdate;

    public MainForm()
    {
        InitializeComponent();
    }

    private void MainForm_Load(object? sender, EventArgs e)
    {
        // 显示版本号（从程序集读取——AutoUpdater.NET 的版本比较基准也是 AssemblyVersion）
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        string verStr = version != null ? $"{version.Major}.{version.Minor}.{version.Build}" : "1.0.0";
        lblVersion.Text = $"版本：v{verStr}";
        // 显示构建时间（从 exe 文件最后修改时间读取）
        try
        {
            var exePath = Environment.ProcessPath ?? Assembly.GetExecutingAssembly().Location;
            var buildTime = File.GetLastWriteTime(exePath);
            lblBuildTime.Text = $"构建时间：{buildTime:yyyy-MM-dd HH:mm:ss}";
        }
        catch
        {
            lblBuildTime.Text = "构建时间：未知";
        }

        Log("程序启动完成");
        Log($"当前版本：v{verStr}");
        Log($".NET 版本：{Environment.Version}");
        Log("更新方案：AutoUpdater.NET（NuGet: Autoupdater.NET.Official）");
    }

    /// <summary>测试更新源按钮：探活 AppCast 地址（HTTP 走 HEAD，file/UNC 走 File.Exists）</summary>
    private async void btnConnect_Click(object? sender, EventArgs e)
    {
        try
        {
            var appcast = txtServerUrl.Text.Trim();
            if (string.IsNullOrWhiteSpace(appcast))
            {
                Log("请先填写 AppCast 地址");
                return;
            }
            Log($"正在测试更新源：{appcast}");
            var uri = new Uri(AutoUpdateService.ToAppcastUri(appcast));
            bool ok;
            string detail;
            if (uri.Scheme == Uri.UriSchemeFile)
            {
                // 本地盘符或 UNC 共享：Windows 下 file URI 的 LocalPath 会还原为对应文件系统路径
                var path = uri.LocalPath;
                ok = File.Exists(path);
                detail = ok ? $"文件存在：{path}" : $"文件不存在或共享不可达：{path}";
            }
            else
            {
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
                var resp = await http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead);
                ok = resp.IsSuccessStatusCode;
                detail = ok
                    ? $"HTTP {(int)resp.StatusCode}，内容长度 {resp.Content.Headers.ContentLength ?? -1} 字节"
                    : $"HTTP {(int)resp.StatusCode} {resp.ReasonPhrase}";
            }

            Log(ok ? $"更新源可用（{detail}）" : $"更新源不可用（{detail}）");
            MessageBox.Show(ok ? "更新源访问正常！" : $"更新源访问失败：\n{detail}",
                "测试更新源", MessageBoxButtons.OK,
                ok ? MessageBoxIcon.Information : MessageBoxIcon.Error);
        }
        catch (Exception ex)
        {
            Log($"测试更新源异常：{ex.Message}");
            MessageBox.Show($"测试更新源异常：{ex.Message}", "错误",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    /// <summary>
    /// 检查更新按钮：V1 里这里要手写 扫描→比较→下载→校验→启动Updater 一整段，
    /// V2 全部收敛为一次 CheckUpdate() 调用（内部就是一行 AutoUpdater.Start）。
    /// </summary>
    private void btnCheckUpdate_Click(object? sender, EventArgs e)
    {
        try
        {
            var appcast = txtServerUrl.Text.Trim();
            if (string.IsNullOrWhiteSpace(appcast))
            {
                Log("请先填写 AppCast 地址");
                MessageBox.Show("请先填写 AppCast 地址（http(s):// 或 \\\\server\\share\\appcast.xml）",
                    "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            _autoUpdate = new AutoUpdateService(this, appcast, Log);
            _autoUpdate.CheckUpdate();
        }
        catch (Exception ex)
        {
            Log($"检查更新失败: {ex.Message}");
            Log($"堆栈: {ex.StackTrace}");
            MessageBox.Show($"更新失败: {ex.Message}", "错误",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    /// <summary>输出日志</summary>
    private void Log(string msg)
    {
        if (txtLog.InvokeRequired)
        {
            txtLog.Invoke(new Action<string>(Log), msg);
            return;
        }
        txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] {msg}\r\n");
        txtLog.ScrollToCaret();
    }
}
