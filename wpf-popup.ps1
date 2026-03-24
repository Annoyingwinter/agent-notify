param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [Parameter(Mandatory = $true)]
    [string]$Body,
    [Parameter(Mandatory = $true)]
    [string]$Kind,
    [Parameter(Mandatory = $true)]
    [string]$LogPath
)

$ErrorActionPreference = "Stop"

function Write-ChildLog {
    param([string]$Message)

    try {
        $timestamp = (Get-Date).ToString("s")
        Add-Content -Path $LogPath -Value "[$timestamp] child $Message" -Encoding UTF8
    } catch {
    }
}

try {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativeWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@

    $console = [NativeWindow]::GetConsoleWindow()
    if ($console -ne [IntPtr]::Zero) {
        [NativeWindow]::ShowWindow($console, 0) | Out-Null
    }

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Write-ChildLog "boot kind=$Kind"

    $theme = switch ($Kind) {
        "error" {
            @{
                Background = "#FFF7E9EC"
                Accent = "#FFC1121F"
                Foreground = "#FF5A0C13"
                Badge = "!"
            }
        }
        "attention" {
            @{
                Background = "#FFFFF6E0"
                Accent = "#FFE2A80B"
                Foreground = "#FF5C4300"
                Badge = "?"
            }
        }
        default {
            @{
                Background = "#FFEAF7EE"
                Accent = "#FF1F8F4E"
                Foreground = "#FF10361F"
                Badge = [char]0x2713
            }
        }
    }

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="360"
        Height="150"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="True"
        Background="Transparent"
        ShowInTaskbar="False"
        ShowActivated="True"
        Topmost="True"
        WindowStartupLocation="Manual">
  <Border CornerRadius="16"
          Padding="18"
          Background="{Binding Background}"
          BorderBrush="{Binding Accent}"
          BorderThickness="2">
    <Border.Effect>
      <DropShadowEffect BlurRadius="24" ShadowDepth="5" Opacity="0.28"/>
    </Border.Effect>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="44"/>
        <ColumnDefinition Width="14"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border Width="44" Height="44" CornerRadius="22" Background="{Binding Accent}" VerticalAlignment="Top">
        <TextBlock Text="{Binding Badge}" Foreground="White" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <StackPanel Grid.Column="2">
        <TextBlock Text="{Binding Title}" Foreground="{Binding Foreground}" FontSize="16" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>
        <TextBlock Text="{Binding Body}" Margin="0,6,0,0" Foreground="{Binding Foreground}" FontSize="12.5" TextWrapping="Wrap" MaxHeight="54"/>
        <TextBlock Text="Click to dismiss" Margin="0,10,0,0" Foreground="{Binding Foreground}" Opacity="0.72" FontSize="11"/>
      </StackPanel>
    </Grid>
  </Border>
</Window>
'@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $window.DataContext = [pscustomobject]@{
        Title = $Title
        Body = $Body
        Background = $theme.Background
        Accent = $theme.Accent
        Foreground = $theme.Foreground
        Badge = $theme.Badge
    }

    $workArea = [System.Windows.SystemParameters]::WorkArea
    $window.Left = [Math]::Round($workArea.Right - $window.Width - 18)
    $window.Top = [Math]::Round($workArea.Top + 18)

    $fadeIn = New-Object Windows.Media.Animation.DoubleAnimation(0, 1, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(140)))
    $fadeOut = New-Object Windows.Media.Animation.DoubleAnimation(1, 0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(180)))
    $fadeOut.add_Completed({
        Write-ChildLog "closing after fade-out"
        $window.Close()
    })

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(6)
    $timer.add_Tick({
        $timer.Stop()
        $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeOut)
    })

    $window.add_Loaded({
        Write-ChildLog "window loaded"
        $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeIn)
        $timer.Start()
        $window.Activate() | Out-Null
        $window.Topmost = $true
        $window.Focus() | Out-Null
    })

    $window.add_MouseLeftButtonDown({
        Write-ChildLog "window dismissed by click"
        $timer.Stop()
        $window.Close()
    })

    Write-ChildLog "showing dialog"
    $null = $window.ShowDialog()
    Write-ChildLog "dialog exited"
} catch {
    Write-ChildLog ("fatal: " + $_.Exception.Message)
}
