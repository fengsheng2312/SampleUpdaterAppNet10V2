using AutoUpdaterDotNET;

namespace SampleUpdaterAppNet10V2;

/// <summary>
/// 自更新服务（V2：基于官方 NuGet 包 AutoUpdater.NET 实现）。
///
/// 对比 V1（AutoUpdateService + ShareRepositoryClient + SmbProbe + 自研 Updater.exe）：
///  - V1：扫描共享目录取最新包 → 手动复制下载 → 手动 SHA256 校验 → 启动自研 Updater.exe 解压替换
///  - V2：只剩"配置 + 一行 AutoUpdater.Start(appcastUri)"，
///        检查更新、更新对话框、下载进度、校验和比对、ZipExtractor 解压替换、重启主程序，
///        全部由 AutoUpdater.NET 库内部完成（对应包内的 ZipExtractor.exe，无需自建更新器工程）。
/// </summary>
public class AutoUpdateService
{
    private readonly string _appcastPathOrUrl;
    private readonly Action<string>? _log;
    private readonly Form _owner;

    public AutoUpdateService(Form owner, string appcastPathOrUrl, Action<string>? log = null)
    {
        _owner = owner;
        _appcastPathOrUrl = appcastPathOrUrl;
        _log = log;
    }

    /// <summary>检查更新（对应 V1 的 CheckUpdateAsync + DownloadUpdateAsync + ApplyUpdate 三件套）</summary>
    public void CheckUpdate()
    {
        // ===== 库行为配置（这些静态属性替代了 V1 手写的全部流程控制） =====
        AutoUpdater.RunUpdateAsAdmin = false;   // 应用装在用户目录，无需提权（V1 的 Updater 也是普通权限）
        AutoUpdater.ReportErrors = false;       // 错误不走库默认弹窗，统一由下方事件回调写日志
        AutoUpdater.ShowSkipButton = true;      // 允许"跳过此版本"（V1 无此功能，库自带持久化）
        AutoUpdater.ShowRemindLaterButton = true; // 允许"稍后提醒"
        AutoUpdater.HttpUserAgent = "SampleUpdaterAppNet10V2";
        AutoUpdater.SetOwner(_owner);

        // 手动接管检查结果：为的是保留本应用"日志框"的展示风格；
        // 若想完全用库的默认体验，删掉这段事件订阅即可（一行 Start 直接弹标准更新对话框）。
        AutoUpdater.CheckForUpdateEvent -= OnCheckForUpdate;
        AutoUpdater.CheckForUpdateEvent += OnCheckForUpdate;

        AutoUpdater.ApplicationExitEvent -= OnApplicationExit;
        AutoUpdater.ApplicationExitEvent += OnApplicationExit;

        var uri = ToAppcastUri(_appcastPathOrUrl);
        _log?.Invoke($"检查更新（AutoUpdater.NET）：{uri}");

        // ★ 核心就这一行：拉取 appcast.xml → 对比 Assembly 版本 → 有更新则走事件回调
        AutoUpdater.Start(uri);
    }

    /// <summary>AppCast 检查结果回调（替代 V1 MainForm 里手写的版本比较/下载/校验/启动更新器分支）</summary>
    private void OnCheckForUpdate(UpdateInfoEventArgs args)
    {
        if (args.Error != null)
        {
            _log?.Invoke($"检查更新失败：{args.Error.Message}");
            MessageBox.Show(_owner,
                $"检查更新失败：{args.Error.Message}",
                "检查更新", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        if (!args.IsUpdateAvailable)
        {
            _log?.Invoke($"当前已是最新版本（已安装 v{args.InstalledVersion}，服务器 v{args.CurrentVersion}）");
            MessageBox.Show(_owner,
                $"当前已是最新版本\n当前版本: v{args.InstalledVersion}",
                "检查更新", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        _log?.Invoke($"发现新版本: v{args.CurrentVersion}（当前 v{args.InstalledVersion}），下载源: {args.DownloadURL}");
        // 弹出库自带的标准更新对话框（含下载进度条、校验、解压替换、重启）。
        // 用户点"更新"→ 下载完成后 ZipExtractor 接管替换，主程序随之退出；
        // 用户点"稍后提醒/跳过"→ 库自动持久化，下次 Start 时自动生效。
        AutoUpdater.ShowUpdateForm(args);
    }

    /// <summary>更新前优雅退出（对应 V1 ApplyUpdate 里的手动 Application.Exit + Environment.Exit）</summary>
    private void OnApplicationExit()
    {
        _log?.Invoke("准备退出以应用更新...");
        Application.Exit();
    }

    /// <summary>
    /// 把用户输入的"更新源"规整为 AutoUpdater.NET 可用的绝对 URI。
    /// 支持三种写法：
    ///  1. http(s):// 服务器上的 appcast.xml
    ///  2. UNC 共享路径 \\server\share\appcast.xml（V1 的共享目录场景）
    ///  3. 本地路径 D:\update\appcast.xml
    /// 后两种 .NET 的 Uri 会直接解析为 file:// URI —— 库内部用 WebClient 下载，原生支持 file 方案。
    /// </summary>
    public static string ToAppcastUri(string pathOrUrl)
    {
        if (!Uri.TryCreate(pathOrUrl.Trim(), UriKind.Absolute, out var uri) ||
            uri.Scheme is not ("http" or "https" or "file"))
            throw new ArgumentException($"无法识别的更新源地址：{pathOrUrl}", nameof(pathOrUrl));
        return uri.AbsoluteUri;
    }
}
