namespace SampleUpdaterAppNet10V2;

partial class MainForm
{
    private System.ComponentModel.IContainer components = null;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    private void InitializeComponent()
    {
        lblTitle = new Label();
        lblVersion = new Label();
        lblBuildTime = new Label();
        grpServer = new GroupBox();
        btnConnect = new Button();
        txtServerUrl = new TextBox();
        label1 = new Label();
        btnCheckUpdate = new Button();
        grpLog = new GroupBox();
        txtLog = new TextBox();
        grpServer.SuspendLayout();
        grpLog.SuspendLayout();
        SuspendLayout();
        // 
        // lblTitle
        // 
        lblTitle.AutoSize = true;
        lblTitle.Font = new Font("微软雅黑", 14F, FontStyle.Bold);
        lblTitle.Location = new Point(23, 21);
        lblTitle.Margin = new Padding(4, 0, 4, 0);
        lblTitle.Name = "lblTitle";
        lblTitle.Size = new Size(446, 26);
        lblTitle.TabIndex = 0;
        lblTitle.Text = ".NET 10 自更新测试程序 (V2 AutoUpdater.NET)";
        // 
        // lblVersion
        // 
        lblVersion.AutoSize = true;
        lblVersion.Font = new Font("微软雅黑", 12F);
        lblVersion.ForeColor = Color.Blue;
        lblVersion.Location = new Point(23, 71);
        lblVersion.Margin = new Padding(4, 0, 4, 0);
        lblVersion.Name = "lblVersion";
        lblVersion.Size = new Size(101, 21);
        lblVersion.TabIndex = 1;
        lblVersion.Text = "版本：v1.0.0";
        // 
        // lblBuildTime
        // 
        lblBuildTime.AutoSize = true;
        lblBuildTime.Font = new Font("微软雅黑", 10F);
        lblBuildTime.ForeColor = Color.Gray;
        lblBuildTime.Location = new Point(23, 106);
        lblBuildTime.Margin = new Padding(4, 0, 4, 0);
        lblBuildTime.Name = "lblBuildTime";
        lblBuildTime.Size = new Size(107, 20);
        lblBuildTime.TabIndex = 2;
        lblBuildTime.Text = "构建时间：未知";
        // 
        // grpServer
        // 
        grpServer.Controls.Add(btnConnect);
        grpServer.Controls.Add(txtServerUrl);
        grpServer.Controls.Add(label1);
        grpServer.Font = new Font("微软雅黑", 9F);
        grpServer.Location = new Point(23, 149);
        grpServer.Margin = new Padding(4, 4, 4, 4);
        grpServer.Name = "grpServer";
        grpServer.Padding = new Padding(4, 4, 4, 4);
        grpServer.Size = new Size(630, 106);
        grpServer.TabIndex = 3;
        grpServer.TabStop = false;
        grpServer.Text = "更新源配置 (AppCast)";
        // 
        // btnConnect
        // 
        btnConnect.Location = new Point(490, 35);
        btnConnect.Margin = new Padding(4, 4, 4, 4);
        btnConnect.Name = "btnConnect";
        btnConnect.Size = new Size(117, 42);
        btnConnect.TabIndex = 2;
        btnConnect.Text = "测试更新源";
        btnConnect.UseVisualStyleBackColor = true;
        btnConnect.Click += btnConnect_Click;
        // 
        // txtServerUrl
        // 
        txtServerUrl.Location = new Point(97, 44);
        txtServerUrl.Margin = new Padding(4, 4, 4, 4);
        txtServerUrl.Name = "txtServerUrl";
        txtServerUrl.Size = new Size(370, 23);
        txtServerUrl.TabIndex = 1;
        txtServerUrl.Text = "\\\\192.168.0.150\\研发部文件共享\\软件组\\SoftwareRepository\\SampleUpdaterAppNet10V2\\appcast.xml";
        // 
        // label1
        // 
        label1.AutoSize = true;
        label1.Location = new Point(23, 47);
        label1.Margin = new Padding(4, 0, 4, 0);
        label1.Name = "label1";
        label1.Size = new Size(60, 17);
        label1.TabIndex = 0;
        label1.Text = "AppCast:";
        // 
        // btnCheckUpdate
        // 
        btnCheckUpdate.Font = new Font("微软雅黑", 11F, FontStyle.Bold);
        btnCheckUpdate.Location = new Point(23, 269);
        btnCheckUpdate.Margin = new Padding(4, 4, 4, 4);
        btnCheckUpdate.Name = "btnCheckUpdate";
        btnCheckUpdate.Size = new Size(630, 57);
        btnCheckUpdate.TabIndex = 4;
        btnCheckUpdate.Text = "检查更新";
        btnCheckUpdate.UseVisualStyleBackColor = true;
        btnCheckUpdate.Click += btnCheckUpdate_Click;
        // 
        // grpLog
        // 
        grpLog.Controls.Add(txtLog);
        grpLog.Font = new Font("微软雅黑", 9F);
        grpLog.Location = new Point(23, 340);
        grpLog.Margin = new Padding(4, 4, 4, 4);
        grpLog.Name = "grpLog";
        grpLog.Padding = new Padding(4, 4, 4, 4);
        grpLog.Size = new Size(630, 326);
        grpLog.TabIndex = 5;
        grpLog.TabStop = false;
        grpLog.Text = "日志";
        // 
        // txtLog
        // 
        txtLog.Dock = DockStyle.Fill;
        txtLog.Location = new Point(4, 20);
        txtLog.Margin = new Padding(4, 4, 4, 4);
        txtLog.Multiline = true;
        txtLog.Name = "txtLog";
        txtLog.ReadOnly = true;
        txtLog.ScrollBars = ScrollBars.Vertical;
        txtLog.Size = new Size(622, 302);
        txtLog.TabIndex = 0;
        // 
        // MainForm
        // 
        AutoScaleDimensions = new SizeF(7F, 17F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(677, 680);
        Controls.Add(grpLog);
        Controls.Add(btnCheckUpdate);
        Controls.Add(grpServer);
        Controls.Add(lblBuildTime);
        Controls.Add(lblVersion);
        Controls.Add(lblTitle);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        Margin = new Padding(4, 4, 4, 4);
        MaximizeBox = false;
        Name = "MainForm";
        StartPosition = FormStartPosition.CenterScreen;
        Text = ".NET 10 自更新测试程序 (V2)";
        Load += MainForm_Load;
        grpServer.ResumeLayout(false);
        grpServer.PerformLayout();
        grpLog.ResumeLayout(false);
        grpLog.PerformLayout();
        ResumeLayout(false);
        PerformLayout();
    }

    #endregion

    private System.Windows.Forms.Label lblTitle;
    private System.Windows.Forms.Label lblVersion;
    private System.Windows.Forms.Label lblBuildTime;
    private System.Windows.Forms.GroupBox grpServer;
    private System.Windows.Forms.Button btnConnect;
    private System.Windows.Forms.TextBox txtServerUrl;
    private System.Windows.Forms.Label label1;
    private System.Windows.Forms.Button btnCheckUpdate;
    private System.Windows.Forms.GroupBox grpLog;
    private System.Windows.Forms.TextBox txtLog;
}
