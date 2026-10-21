BeforeAll {
  $script:installer = Join-Path $PSScriptRoot '../scripts/install-cuda.ps1'
  $script:originalTemp = $env:TEMP
  $env:TEMP = $TestDrive
  if (-not (Get-PSDrive C -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name C -PSProvider FileSystem -Root $TestDrive | Out-Null
  }
  Mock Test-Path { $false }
  Mock Invoke-WebRequest {}
  Mock Start-Process { throw 'INSTALL_ATTEMPTED' }
}

AfterAll {
  $env:TEMP = $script:originalTemp
}

Describe 'CUDA artifact selection' {
  It 'selects the CUDA <Version> artifact and components' -ForEach @(
    @{ Version = '12.9'; File = 'cuda_12.9.1_576.57_windows.exe' },
    @{ Version = '13.1'; File = 'cuda_13.1.2_windows.exe' },
    @{ Version = '13.4'; File = 'cuda_13.4.3_windows_x86_64.exe' }
  ) {
    { & $script:installer -CudaVersion $Version -InstallRoot "$TestDrive/toolkit" } |
      Should -Throw '*INSTALL_ATTEMPTED*'
    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -like "*/$File" }
    if ($Version -eq '12.9') {
      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
        $ArgumentList -match 'nvcc_12.9' -and $ArgumentList -match 'nvprof_12.9'
      }
    } else {
      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList.Trim() -eq '-s' }
    }
  }

  It 'defaults to CUDA 13.4' {
    { & $script:installer -InstallRoot "$TestDrive/toolkit" } | Should -Throw '*INSTALL_ATTEMPTED*'
    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
      $Uri -like '*/cuda_13.4.3_windows_x86_64.exe'
    }
  }

  It 'preserves URL and component overrides' {
    {
      & $script:installer -DownloadURL 'https://example.invalid/cuda.exe' `
        -InstallRoot "$TestDrive/toolkit" -Components nvcc_13.1 -CudaVersion 13.1
    } | Should -Throw '*INSTALL_ATTEMPTED*'
    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
      $Uri -eq 'https://example.invalid/cuda.exe'
    }
    Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -match 'nvcc_13.1' }
  }

  It 'rejects unsupported versions' {
    { & $script:installer -CudaVersion 14.0 } | Should -Throw
    Should -Invoke Invoke-WebRequest -Times 0
  }

  It 'checks the CUDA <Version> artifact without installing' -ForEach @(
    @{ Version = '12.9'; File = 'cuda_12.9.1_576.57_windows.exe' },
    @{ Version = '13.1'; File = 'cuda_13.1.2_windows.exe' },
    @{ Version = '13.4'; File = 'cuda_13.4.3_windows_x86_64.exe' }
  ) {
    Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200 } }
    & $script:installer -CudaVersion $Version -VerifyDownload
    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
      $Uri -like "*/$File" -and $Method -eq 'Head'
    }
    Should -Invoke Start-Process -Times 0
  }

  It 'rejects unavailable artifacts' {
    Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 404 } }
    { & $script:installer -VerifyDownload } | Should -Throw '*Artifact check failed*'
    Should -Invoke Start-Process -Times 0
  }

  It 'rejects installer failures' {
    Mock Start-Process { [pscustomobject]@{ ExitCode = 42 } }
    { & $script:installer -InstallRoot "$TestDrive/toolkit" } |
      Should -Throw '*Installer failed with exit code 42*'
  }

  It 'requires an installed compiler after exit code <Code>' -ForEach @(
    @{ Code = 0 },
    @{ Code = 3010 }
  ) {
    Mock Start-Process { [pscustomobject]@{ ExitCode = $Code } }
    { & $script:installer -InstallRoot "$TestDrive/toolkit" } | Should -Throw '*Install not found*'
  }
}
