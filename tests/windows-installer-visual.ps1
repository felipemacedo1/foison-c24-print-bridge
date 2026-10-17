# Actual released installer UI on Windows 2022. OS guard MUST reject installation.
# Welcome/license/directory/error screenshots; no claim about Win7 or completion.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$version=[IO.File]::ReadAllText((Join-Path $root 'VERSION')).Trim()
$exe=Join-Path $root ('dist/'+$version+'/FoisonC24-Setup-Win7-x64.exe')
$out=Join-Path $root 'dist/visual';New-Item -ItemType Directory -Force $out|Out-Null
Add-Type -ReferencedAssemblies System.Drawing @'
using System;using System.Text;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;using System.Collections.Generic;
public static class InstallerVisual {
 delegate bool Callback(IntPtr w,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(Callback c,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr w,Callback c,IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr w,out uint p);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr w);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr w,StringBuilder b,int n);
 [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr w,int id);
 [DllImport("user32.dll")] static extern bool PostMessage(IntPtr w,uint m,IntPtr a,IntPtr b);
 [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr w,IntPtr dc,uint flags);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr w,out Rect r);
 struct Rect {public int L,T,R,B;}
 public static IntPtr[] Windows(int pid){var a=new List<IntPtr>();EnumWindows((w,p)=>{uint id;GetWindowThreadProcessId(w,out id);if(id==pid && IsWindowVisible(w))a.Add(w);return true;},IntPtr.Zero);return a.ToArray();}
 public static string Text(IntPtr w){var b=new StringBuilder(8192);GetWindowText(w,b,b.Capacity);return b.ToString();}
 public static string Children(IntPtr w){var b=new StringBuilder();EnumChildWindows(w,(c,p)=>{b.AppendLine(Text(c));return true;},IntPtr.Zero);return b.ToString();}
 public static void Button(IntPtr w,int id){var b=GetDlgItem(w,id);if(b==IntPtr.Zero)throw new Exception("Button missing");PostMessage(b,0xF5,IntPtr.Zero,IntPtr.Zero);}
 public static void Save(IntPtr w,string path){Rect r;if(!GetWindowRect(w,out r) || r.R<=r.L || r.B<=r.T)throw new Exception("Window is not ready or no longer exists");using(var b=new Bitmap(r.R-r.L,r.B-r.T)) {using(var g=Graphics.FromImage(b)){var dc=g.GetHdc();try{if(!PrintWindow(w,dc,0))throw new Exception("PrintWindow failed");}finally{g.ReleaseHdc(dc);}}b.Save(path,ImageFormat.Png);}}
}
'@
$p=Start-Process $exe -PassThru
try {
  $expected=@{'welcome'='Configuração da impressora Foison C24.';'license'='licença';'directory'='Pasta Destino'}
  foreach($page in @('welcome','license','directory')) {
    # NSIS can briefly expose a bootstrap window before the real MUI dialog.
    # Wait for the expected page text, never capture/reuse the first transient HWND.
    $deadline=[DateTime]::UtcNow.AddSeconds(20);$window=[IntPtr]::Zero
    do {
      foreach($candidate in @([InstallerVisual]::Windows($p.Id))) {
        if([InstallerVisual]::Children($candidate).Contains($expected[$page])) {$window=$candidate;break}
      }
      if($window -ne [IntPtr]::Zero) {break};Start-Sleep -Milliseconds 100
    } while([DateTime]::UtcNow -lt $deadline)
    if($window -eq [IntPtr]::Zero) {throw ('Expected installer page did not appear: '+$page)}
    Start-Sleep -Milliseconds 200
    $text=[InstallerVisual]::Children($window)
    [IO.File]::WriteAllText((Join-Path $out ($page+'.txt')),$text,[Text.Encoding]::UTF8)
    [InstallerVisual]::Save($window,(Join-Path $out ($page+'.png')))
    if($page -eq 'welcome' -and -not $text.Contains('Configuração da impressora Foison C24.')) {throw 'Portuguese welcome did not survive NSIS compilation/display'}
    if($text.Contains([string][char]0xfffd) -or $text.Contains([string][char]0xc3+[char]0xa7)) {throw 'Corrupt Unicode UI text'}
    [InstallerVisual]::Button($window,1)
  }
  Start-Sleep -Seconds 2
  $windows=@([InstallerVisual]::Windows($p.Id));$n=0;$seen=$false
  foreach($w in $windows) {
    $text=[InstallerVisual]::Children($w)
    [IO.File]::WriteAllText((Join-Path $out ('rejection-'+$n+'.txt')),$text,[Text.Encoding]::UTF8)
    [InstallerVisual]::Save($w,(Join-Path $out ('rejection-'+$n+'.png')))
    if($text.Contains('OPERATING_SYSTEM')) {$seen=$true}
    $n++
  }
  if(-not $seen) {throw 'Unsupported OS was not visibly diagnosed'}
  Write-Host 'PASS actual NSIS Portuguese UI and unsupported-OS diagnostic. Finish/uninstall/Win7 visual NOT EXECUTED.'
} finally {
  # This OS is rejected before extraction/provisioning. Kill only our UI process.
  if(-not $p.HasExited) {$p.Kill();$p.WaitForExit(10000)|Out-Null};$p.Dispose()
}
