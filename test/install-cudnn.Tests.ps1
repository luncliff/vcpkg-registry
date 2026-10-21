BeforeAll {
  $script:installer = Join-Path $PSScriptRoot '../scripts/install-cudnn.ps1'
  $script:originalTemp = $env:TEMP
  $script:originalCudnn = $env:CUDNN
  $env:TEMP = $TestDrive
  $env:CUDNN = $null
  Mock Invoke-WebRequest {}
  Mock Copy-Item {
    if ((Split-Path $Destination -Leaf) -eq 'lib') { throw 'COPY_COMPLETE' }
  }
}

AfterAll {
  $env:TEMP = $script:originalTemp
  $env:CUDNN = $script:originalCudnn
}

Describe 'cuDNN archive compatibility' {
  It 'extracts DLLs from <DllDirectory> and libraries from <LibDirectory>' -ForEach @(
    @{ DllDirectory = 'bin'; LibDirectory = 'lib/x64' },
    @{ DllDirectory = 'bin'; LibDirectory = 'lib' },
    @{ DllDirectory = 'bin/x64'; LibDirectory = 'lib' }
  ) {
    Mock Expand-Archive {
      $package = Join-Path $DestinationPath 'cudnn-archive'
      foreach ($file in @("$DllDirectory/cudnn64_9.dll", 'include/cudnn.h', "$LibDirectory/cudnn.lib")) {
        $path = Join-Path $package $file
        New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
        New-Item -ItemType File $path | Out-Null
      }
    }
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
    { & $script:installer -CudaVersion 13.4 -ExtractRoot $root } | Should -Throw '*COPY_COMPLETE*'
    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
      $Uri -like '*_cuda13-archive.zip'
    }
    Should -Invoke Copy-Item -Times 1 -Exactly -ParameterFilter {
      $Path -like '*cudnn64_9.dll' -and (Split-Path $Destination -Leaf) -eq 'bin'
    }
    Should -Invoke Copy-Item -Times 1 -Exactly -ParameterFilter {
      $Path -like '*cudnn.lib' -and (Split-Path $Destination -Leaf) -eq 'lib'
    }
  }
}
