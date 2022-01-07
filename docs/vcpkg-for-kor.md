# 한국어로 쓴 Vcpkg 설명서

> [JetBrains 2021 Developer Ecosystem Survey](https://www.jetbrains.com/lp/devecosystem-2021/cpp/)를 보면 상당히 많은 개발자분들이 여전히 패키지 매니저의 도움을 받지 않고 계신 것 같습니다.
> 이번 글로 보다 많은 분들께서 외부 라이브러리를 사용할 때 도움을 받으실 수 있기를 바랍니다.

[Vcpkg](https://github.com/microsoft/vcpkg) 프로젝트 [`2021.12.01`](https://github.com/microsoft/vcpkg/releases/tag/2021.12.01)를 기준으로 설명합니다.

## Getting Started

### 1. 메뉴얼부터

한국어로 번역된 [README_ko_KR.md](https://github.com/microsoft/vcpkg/blob/2021.12.01/README_ko_KR.md)를 먼저 읽고 오시면 좋을 것 같습니다.
지금은 README 뿐이지만, 여러분이 나머지 내용들을 번역해서 기여할 수도 있을 것입니다.
이 글을 끝까지 따라해본 뒤라면 충분히 가능하리라고 생각합니다.

#### Vcpkg 폴더 준비하기

Vcpkg만의 특징 중 하나는 "1개 폴더에서 모든 일을 수행할 수 있다"는 것입니다.  
여러 패키지 매니저들마다 각각의 고유한 특징이 있습니다만, 이 특징은 **관리를 쉽게 만들어주기 때문에** 큰 장점이라고 할 수 있습니다.  
만약 뭔가 잘못된 것 같으면 그 폴더를 통째로 `rm -rf` 해버린 다음, 처음부터 다시 시작할 수 있기 때문이죠.

Vcpkg 폴더를 준비하는 방법은 메뉴얼을 따라서 GitHub에서 clone 해오는 것입니다.

```console
$ git clone https://github.com/microsoft/vcpkg
remote: Enumerating objects: ...
```

Vcpkg의 Git History가 필요하지 않다면 그냥 zip 파일만 다운로드 할수도 있습니다.
Docker 이미지를 만든다면 이런 방법이 더 자주 필요하겠죠?

```ps1
# https://github.com/microsoft/vcpkg/archive/refs/heads/master.zip for latest
Invoke-WebRequest -Uri "https://github.com/microsoft/vcpkg/archive/refs/tags/2021.12.01.zip" -OutFile "vcpkg.zip"
Expand-Archive "vcpkg.zip"
```

```bash
wget "https://github.com/microsoft/vcpkg/archive/refs/tags/2021.12.01.zip" -O "vcpkg.zip"
unzip -q -o "vcpkg.zip" -d .
mv "vcpkg-2021.12.01" "vcpkg"
```

[GitHub Actions, Azure Pipelines](https://github.com/actions/virtual-environments), [AppVeyor](https://www.appveyor.com/docs/windows-images-software/)를 비롯해 여러 CI 서비스들에서는 이미 호스팅하고 있는 빌드 환경에 Vcpkg 폴더를 별도로 준비해두고 있습니다.
덕분에 PATH 환경변수를 약간 수정하는 정도로 사용할 수 있습니다. (별도의 CLI 명령을 사용하지 않아도 되는 경우도 있습니다.)

* [Windows](https://github.com/actions/virtual-environments/tree/main/images/win) - `C:/vcpkg`
* [Linux](https://github.com/actions/virtual-environments/tree/main/images/linux) - `/usr/local/share/vcpkg`
* [Mac](https://github.com/actions/virtual-environments/tree/main/images/macos) - `/usr/local/share/vcpkg`


#### Vcpkg 폴더는 어떻게 구성되어 있는가?

기능적으로는 계속 변화하고 있지만 파일 구조(Organization)만큼은 대부분 그 이전과 같이 유지하고 있습니다.

```
.
├── ...
├── LICENSE.txt
├── README.md
├── bootstrap-vcpkg.bat
├── bootstrap-vcpkg.sh
├── docs
│   ├── ...
│   └── ...
├── ports
│   ├── ...
│   └── ...
├── scripts
│   ├── ...
│   ├── buildsystems
│   ├── ci.baseline.txt
│   └── ...
├── triplets
│   ├── ...
│   ├── community
│   ├── x64-windows.cmake
│   └── x86-windows.cmake
└── versions
    ├── ...
    ├── baseline.json
    └── ...
```

편의상 몇가지 파일들이 생략되었습니다만, 입문자가 알아야 하는 파일/폴더들은 대략 위와 같습니다.
크게 3가지 그룹으로 묶을 수 있습니다.

##### Document

Vcpkg의 사용법, 규칙, 응용방법에 대해서 설명하는 문서들입니다.
파일들이 꽤 많이 있습니다만, 모든 파일을 읽을 필요는 없습니다. 필요에 따라 검색하면서 읽는 방법으로 충분합니다.

```
.
├── LICENSE.txt
├── README.md
├── docs
│   ├── examples
│   ├── maintainers
│   ├── specifications
│   └── ...
└── ...
```

대신 Vcpkg를 어느정도 수준까지 사용하느냐에 따라서 검색에 포함할 폴더가 달라집니다.

1. 라이브러리를 설치(Install)하는 경우: `README.md`, `docs/examples/`
2. 라이브러리를 지원받는 경우: `docs/users/`
3. 라이브러리를 지원/공유하는 경우: `docs/maintainers/`
4. vcpkg의 확장기능을 사용하는 경우: `docs/specifications/`

##### Script

Vcpkg 폴더에는 여러 언어로 작성된 Script들이 들어있지만, 대부분 [CMake Script](https://cmake.org/cmake/help/latest/manual/cmake.1.html)입니다.
때문에 라이브러리를 설치하는 것보다 더 높은 수준의 일을 하고자 한다면, CMake 문법에 익숙해야 합니다.

```
.
├── ...
├── bootstrap-vcpkg.bat
├── bootstrap-vcpkg.sh
├── ports
│   ├── ...
│   └── ...
├── scripts
│   └── buildsystems
│       ├── ...
│       ├── meson
│       ├── msbuild
│       ├── osx
│       └── vcpkg.cmake
└── triplets
    ├── ...
    └── x86-windows.cmake
```

프로젝트의 README.md에서 설명하듯, bootstrap-vcpkg 스크립트를 가장 먼저 실행해야 합니다.
Vcpkg는 폴더에 있는 파일만으로는 사용할 수 없고, 이를 사용하는 [전용프로그램 `vcpkg`](https://github.com/microsoft/vcpkg-tool)를 필요로 합니다.

이전에는 `vcpkg`의 소스 파일들을 toolsrc에 내장하고 있었습니다만, 2021년 중반 이후 실행프로그램을 다운로드해서 사용할 수 있도록 구조가 바뀌었습니다.
(구체적인 시기는 Host 플랫폼마다 다릅니다.)

소스코드를 사용해서 빌드할때는 스크립트에서 제공하는 옵션들을 확인해야 할 수 있습니다.
예를 들면, Mac 환경에서는 AppleClang을 사용하도록 하는 옵션이 있었습니다. [한-참 늦게(2019년 9월) 지원된 C++ 17 `<filesystem>`](https://developer.apple.com/documentation/xcode-release-notes/xcode-11-release-notes) 때문이죠.

```console
user@host:vcpkg$ ./bootstrap-vcpkg.sh --allowAppleClang
Warning: -allowAppleClang no longer has any effect; ignored.
```

```console
user@host:vcpkg$ ./bootstrap-vcpkg.sh
Downloading vcpkg-macos...
...
user@host:vcpkg$ lipo -archs vcpkg  # Mac: available architectures?
x86_64 arm64
```

>
> 소스코드를 사용해서 `vcpkg`을 빌드하던 시기에는 내부 소스 코드를 수정해서 몇가지 문제 상황에 대해서 우회하는 조치가 필요한 경우도 있었습니다.  
> 어느 패키지의 빌드 방법이 잘못 작성되어있거나, 라이브러리 프로젝트에서 특정한 Windows UCRT(Universial C Runtime)만 지원하는 제약으로 인해 불일치가 발생하는 경우입니다.
>
> `vcpkg`는 이런 경우를 오류로 처리했었는데, 무시하도록 소스코드를 수정해서 다음 절차로 넘어가곤 했던 것이죠.  
> 지금은 여러 triplet에 대해서 Vcpkg 프로젝트의 CI에서 검출해내고 있기 때문에 이런 까다로운 상황을 만나는 일은 거의 없으리라 예상합니다.
>

앞서 이 글이 `2021.12.01` 버전을 기준으로 한다고 설명했는데, 이 버전은 [vcpkg-tool](https://github.com/microsoft/vcpkg-tool)의 버전이 아닙니다.
이에 대한 보다 자세한 설명은 후술하겠습니다.  
여기서 기억해야 하는 것은 "**Vcpkg 폴더에는 그에 맞는 `vcpkg` 버전이 있다**"는 것입니다.

`vcpkg`의 버전은 아래와 같은 방법으로 확인할 수 있습니다.

```console
user@host:vcpkg$ ./vcpkg --version
Vcpkg package management program version 2021-11-24-48b94a6946b8a70abd21529218927fd478d02b6c

See LICENSE.txt for license information.
```

##### Metadata

Document, Script를 제외하고 남는 것은 Vcpkg 폴더에 작성되어있는 port들과, 그 전체에 대한 baseline 정보입니다. 이들은 versions 폴더에 배치되어있습니다.

```
.
├── ...
└── versions
    ├── ...
    ├── baseline.json
    └── ...
```

### 2. [Vcpkg에서의 버전](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/versioning.md) 이해하기

Vcpkg에는 3가지에 버전을 부여합니다. 첫번째는 `vcpkg` 프로그램, 두번째는 Registry, 마지막으로 Port입니다.
`vcpkg`의 버전은 이제 https://github.com/microsoft/vcpkg-tool 에서 관리하고 있습니다. 말할 것도 없이, 프로그램에 사용된 소스코드의 버전입니다.  
[Registry](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/maintainers/registries.md)는 말하자면 ports, triplets, versions 3개 폴더의 집합을 의미합니다.
이에 대해서는 깊이 이해하고 있을 필요는 없습니다. 앞서 준비한 Vcpkg 폴더가 곧 Registry로써 기능한다는 것만 인지하면 됩니다.  
Port는 주요 정보(`vcpkg.json`), 빌드를 위한 절차(`portfile.cmake`), Vcpkg에서 빌드하도록 만들기 위한 Patch 등의 파일들을 묶어둔 폴더를 말합니다.
형태가 너무 막연하다면, 도합 130 라인정도 되는 [ports/spdlog](https://github.com/microsoft/vcpkg/tree/2021.12.01/ports/spdlog)의 파일들을 한번 살펴보면 좋을 것 같습니다. 

> [Conan C/C++ Package Manager](https://conan.io)를 사용해본 사람이라면 `conanfile.py` 혹은 Recipe와 유사하다는 생각이 들 것입니다.

#### Port의 버전

현재 Vcpkg에서는 각 port들의 버전을 4가지 종류로 구분하여 관리하고 있습니다.
버전을 확인할때는 `vcpkg search` 명령을 사용합니다. 이 명령은 port들의 이름, Feature, 버전, 설명을 출력해줍니다.
(Feature에 대해서는 후술하겠습니다.)

```console
$ ./vcpkg help search
The argument should be a substring to search for, or no argument to display all libraries.
Example:
  vcpkg search png
...
```

예시를 그대로 따라해보면 이름 또는 Feature에 `png`가 포함되어 있는 경우를 필터링해서 보여줍니다.

```console
user@host:vcpkg$ ./vcpkg search png
...
libpng                   1.6.37#16        libpng is a library implementing an interface for reading and writing PNG ...
libpng[apng]                              This is backward compatible with the regular libpng, both in library usage...
lodepng                  2020-03-15#1     PNG encoder and decoder in C++
opencv4[png]                              PNG support for opencv
pngpp                    0.2.10           A C++ wrapper for libpng library.
pngwriter                0.7.0#3          PNGwriter is a very easy to use open source graphics library that uses PNG...
qtbase[png]                               Enable PNG
...
```

위에서는 2가지 경우를 확인할 수 있습니다.

* [유의적 버전](https://semver.org/lang/ko/)을 따르는 경우: `version-semver`에 해당합니다.
* Port 작성 날짜: 2020-03-15와 같이 '-'을 넣어 표기합니다. `version-date`에 해당합니다.

남은 2가지 경우는 아래와 같습니다. 예시로 Port이름을 적어두었으니 `vcpkg search` 명령으로 한번 찾아보기를 권합니다.
혹은 관심이 있는 라이브러리를 찾아서 어떤 버전인지 확인해보는 것도 좋겠습니다.

* 특별한 의미를 가진 문자열: `version-string`에 해당합니다. (예: `ijg-libjpeg`의 버전은 `9d`)
* '.'으로 구분하는 숫자: `version`에 해당합니다. (예: `alsa`의 버전은 `1.2.5.1`)


### 3. 패키지(Package) 설치

일부 특수한 목적을 가진 Port들이 있지만, 대부분의 Port들은 패키지를 설치하기 위한 것들을 담고 있습니다.
헤더(Header) 파일, 링킹(Linking)이 가능한 라이브러리, 관련 Tool로써 기능하는 프로그램/스크립트들을 말합니다.
어떤 패키지를 설치하기 위해서 관련 Port들을 읽어볼 필요는 없습니다.
그 내용은 문제가 생겼을때 살펴보면 됩니다. 발생한 문제의 종류나 원인에 따라서는 빌드 로그만으로도 충분합니다.

[CMake에서 상정(想定)하고 있는 용례(User Flow)](https://cmake.org/cmake/help/latest/guide/user-interaction/index.html)가 있는 것처럼,
Vcpkg 또한 [패키지를 설치하고 사용할 때의 시나리오](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/examples/installing-and-using-packages.md)가 정해져 있습니다.
**이 과정에는 Port의 파일들을 확인하는 것은 없습니다.**
만약 본격적인 Vcpkg 지원/활용을 계획하고 있다면, 그만큼 완성도 있는 `portfile.cmake`가 작성되어있다는 합의(Consensus)가 되어있다는 점을 늘 생각해야 합니다.

#### 설치된 패키지 확인

현재 설치된 라이브러리는 `vcpkg list` 명령으로 확인할 수 있습니다.

```console
$ ./vcpkg list
No packages are installed. Did you mean `search`?
```

아무것도 나오지 않는게 당연합니다. 아직 무엇도 설치하지 않았으니까요.  
[`zlib`](https://zlib.net)의 후계 프로젝트 [`zlib-ng`](https://github.com/zlib-ng/zlib-ng)를 설치한 다음에 확인해보겠습니다.

```console
$ ./vcpkg list
vcpkg-cmake:x64-osx   2021-09-13
zlib-ng:x64-osx       2.0.5       zlib replacement with optimizations for 'next ge...
```

3번째 열(列)에 패키지에 대한 설명이 나오는데, 내용이 너무 길어 일부가 생략된 것을 볼 수 있습니다.
전체 설명이 필요한 경우 `--x-full-desc` 옵션을 사용해 전체 내용을 볼 수 있습니다.

```console
$ ./vcpkg list --x-full-desc
vcpkg-cmake:x64-osx   2021-09-13       
zlib-ng:x64-osx       2.0.5       zlib replacement with optimizations for 'next generation' systems
```

별다른 단어를 제공하지 않으면 `vcpkg list`는 현재 Vcpkg 폴더에 설치된 모든 패키지를 보여줍니다.
zlib을 명시해 불필요한 내용을 제외시켜 보겠습니다.

```console
$ ./vcpkg list zlib
zlib-ng:x64-osx       2.0.5       zlib replacement with optimizations for 'next ge...
```

#### 패키지 설치

패키지는 `vcpkg install` 명령으로 설치합니다.
이때 `vcpkg.json`에 명시된 `"dependencies"`까지 함께 설치합니다.

```console
$ ./vcpkg install libzip[core,openssl]
Computing installation plan...
The following packages will be built and installed:
    libzip[core,openssl]:x64-osx -> 1.8.0
  * openssl[core]:x64-osx -> 1.1.1l#4
  * vcpkg-cmake[core]:x64-osx -> 2021-09-13
  * vcpkg-cmake-config[core]:x64-osx -> 2021-11-01
  * zlib[core]:x64-osx -> 1.2.11#13
Additional packages (*) will be modified to complete this operation.
...
```

[`ports/libzip/vcpkg.json`](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/libzip/vcpkg.json)을 열어 어떤 패키지를 필요로 하는지 내용을 확인해보길 권합니다.

만약 설치가 실패한다면 보다 상세한 내용을 확인할 필요가 있습니다. 이때는 `--debug` 옵션을 사용합니다.
이 옵션은 다른 명령에도 사용할 수 있습니다.
Debug 빌드는 성공하지만 Release 빌드는 실패하는 등의 일반적이지 않은 상황에서 특히 유용합니다.

```
vcpkg install --debug zlib-ng
```

#### 패키지가 설치 가능한지 확인하는 방법

2021년이 지난 현재, 패키지가 설치 가능한지 확인하는 방법은 `ports/${name}/vcpkg.json`에서 `"supports"` 가 있는지 확인하는 것입니다.
이 부분이 없다면 (아마도) 모든 경우 빌드할 수 있는 패키지입니다.
만약 작성되어 있다면 그 표현식을 확인해봐야 합니다.

나름 유명한 암호(Cryptography) 라이브러리 [Botan](https://botan.randombit.net)의 경우 아래와 같이 작성되어 있습니다.

```json
{
  "name": "botan",
  "version": "2.18.1",
  "port-version": 4,
  "description": "A cryptography library written in C++11",
  "homepage": "https://botan.randombit.net",
  "supports": "!(windows & arm)",
  "features": {
    "amalgamation": {
      "description": "Do an amalgamation build of the library"
    }
  }
}
```

해석하자면, 이 패키지는 Windows ARM 환경에 대해서는 **빌드할 수 없다!** 는 것을 표현하고 있습니다.

과거에는 이런 내용이 대부분 빌드 절차를 설명하는 `portfile.cmake`에 들어있었으나, 수많은 Maintainer/Contributor들의 노력으로 이제는 `vcpkg.json`으로 관련 내용들이 옮겨졌습니다.
몇달 전까지만 해도 vcpkg-tool 에서는 이 값을 검사하지 않았으나, 이제는 `vcpkg install` 하는 시점에 가능한지를 확인해줍니다.

예를 들어, Mac Host 환경에서 Linux Target 환경에서만 설치할 수 있는 liburing을 설치하려고 하면 아래와 같이 실패합니다.

```console
$ ./vcpkg install liburing
Computing installation plan...
Error: liburing[core] is only supported on 'linux'
```

`vcpkg` 프로그램이 이런 검사를 수행하지 않는 Vcpkg 버전을 사용하고 있을 수도 있습니다.
이때는 직접적으로는 사용자가 자신이 사용하는 패키지들의 `portfile.cmake`에 대해서 충분히 읽어두는 수 밖에 없습니다.
간접적인 방법으로는 [scripts/ci.baseline.txt](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/ci.baseline.txt)를 확인하는 것도 도움이 될 수 있습니다.
Vcpkg 프로젝트는 master 브랜치, PR들의 commit에 [CI를 적용하고 있습니다](https://dev.azure.com/vcpkg/public/_build?definitionId=29&_a=summary).
이 파일은 `"supports"`가 구현되기 전에 CI에서 제외(skip)하거나, 예상되는 실패(fail)를 기록해둔 것입니다.

#### 설치 후 파일 배치

임의의 패키지를 설치한 후에는 downloads를 포함해 4개의 폴더가 만들어집니다.

```
.
├── ...
├── downloads
├── buildtrees
├── installed
├── packages
└── ...
```

##### downloads

downloads는 이름 그대로 `vcpkg`에서 필요한 프로그램(CMake, Ninja, NuGet), 소스코드(zip, tar), 공개된 텍스트파일(LICENSE, patch) 등을 저장하는 폴더입니다.
`vcpkg`에서 파일을 다운로드 하기에 앞서 이 폴더를 확인하기 때문에, **만약 이 폴더에 패키지들을 설치하기 위해 필요한 파일들이 모두 있다면 네트워크를 사용하지 않는 것도 가능합니다.**
(실제 빌드 환경에는 최소한의 Toolchain만 설치되어 있으면 되는 것이죠.)

##### buildtrees

buildtrees는 소스코드의 압축을 해제하고, 빌드 과정에서 만들어지는 중간 결과물들을 보관하는 폴더입니다.
소스코드로부터 만들어진 Object 파일들이 저장되긴 하지만, 이 파일들이 재사용되어 빌드를 가속해주지는 않습니다.
`vcpkg`는 언제나 Clean 빌드를 수행합니다.

좀 전에 `zlib-ng`를 설치했는데 Linux 환경에서는 이런 파일들이 생성됩니다.
`vcpkg`, CMake Script들에서 실행하는 핵심적인 프로세스들의 stdout, stderr이 저장되어 있습니다.
`zlib-ng`만 살펴보면, 소스코드 zip의 압축을 풀고(extract), CMake를 사용해서 Configure-Generate하고(config), 이렇게 생성된 파일들을 사용해서 빌드/설치를 수행합니다(install).

```
$ tree -L 2 ./buildtrees/
./buildtrees/
├── detect_compiler
│   ├── config-x64-linux-rel-err.log
│   ├── config-x64-linux-rel-out.log
│   ├── stdout-x64-linux.log
│   └── x64-linux-rel
├── vcpkg-cmake
│   ├── stdout-x64-linux.log
│   └── x64-linux.vcpkg_abi_info.txt
└── zlib-ng
    ├── config-x64-linux-dbg-err.log
    ├── config-x64-linux-dbg-out.log
    ├── config-x64-linux-rel-err.log
    ├── config-x64-linux-rel-out.log
    ├── extract-err.log
    ├── extract-out.log
    ├── install-x64-linux-dbg-err.log
    ├── install-x64-linux-dbg-out.log
    ├── install-x64-linux-rel-err.log
    ├── install-x64-linux-rel-out.log
    ├── src
    ├── stdout-x64-linux.log
    ├── x64-linux-dbg
    ├── x64-linux-rel
    └── x64-linux.vcpkg_abi_info.txt
```

##### installed/packages

거의 모든 의존성을 vcpkg를 통해서 해결한다면 installed, 일부 라이브러리만 필요하다면 packages를 사용하게 될 것입니다.
이렇게 사용하는 이유는 두 폴더의 구성 형태가 다르기 때문입니다.

installed 폴더는 흔히 알려진 `/usr/local` 스타일, 즉 [GNU Coding Standards 에서 설명하는 설치 폴더](https://www.gnu.org/prep/standards/html_node/Directory-Variables.html) 구성을 따릅니다. CMake에서는 [GNUInstallDirs](https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html) 모듈이 이 구성에 맞춰 프로젝트를 설치할 수 있도록 지원하고 있습니다.

```console
$ tree -L 3 ./installed/
./installed/
├── vcpkg
│   ├── info
│   │   ├── vcpkg-cmake_2021-09-13_x64-linux.list
│   │   └── zlib-ng_2.0.5_x64-linux.list
│   ├── status
│   └── updates
│       ├── 0000000000
│       └── 0000000001
└── x64-linux
    ├── debug
    │   └── lib
    ├── include
    │   ├── zconf-ng.h
    │   └── zlib-ng.h
    ├── lib
    │   ├── libz-ng.a
    │   └── pkgconfig
    └── share
        ├── vcpkg-cmake
        └── zlib-ng
```

Vcpkg에서는 Debug/Release 빌드를 함께 설치합니다. 다만 `${prefix}/lib`에는 Release 빌드를, `${prefix}/debug/lib`에는 Debug 빌드를 설치합니다. `${prefix}/include`에 설치된 Header 파일들은 두 빌드 형상(Configuration)이 공유하는 것을 전제(前提)합니다.
더 많은 패키지를 설치할수록, installed 폴더에는 더 많은 파일들이 생성될 것입니다. 이 때문에 다수의 의존성을 적은 빌드 설정으로 해결하고자 할 때는 installed 폴더를 사용합니다.

packages는 빌드 결과물을 **installed로 복사하기 전에** 설치를 하는 목적지(Destination) 역할을 하는 폴더 입니다.
따라서 각 패키지들마다 독립적으로 폴더를 부여합니다.

```console
$ tree -L 2 ./packages/
./packages/
├── detect_compiler_x64-linux
├── vcpkg-cmake_x64-linux
│   ├── BUILD_INFO
│   ├── CONTROL
│   └── share
└── zlib-ng_x64-linux
    ├── BUILD_INFO
    ├── CONTROL
    ├── debug
    ├── include
    ├── lib
    └── share
```

zlib-ng_x64-linux 폴더 밑에도 include, lib, share등 GNU 표준 스타일 폴더가 있는 것을 확인할 수 있습니다.
이런 특징 때문에 각 패키지들마다 별도의 빌드 설정을 사용하고 있거나, 여러 설치 폴더를 함께 사용할 때는 packages 폴더를 사용하는 것이 더 편할 수 있습니다.

## Host/Target 환경

앞서 `vcpkg install`을 실행할 때 x64-windows, x64-linux, x64-osx와 같은 단어들을 확인할 수 있었습니다.
이들은 [triplets에 있는 파일들](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/triplets.md)의 이름과 동일합니다.

```
$ tree ./triplets/
./triplets/
├── arm-uwp.cmake
├── arm64-windows.cmake
├── community
│   ├── arm64-android.cmake
│   ├── arm64-ios.cmake
│   ├── arm64-linux.cmake
│   ├── arm64-mingw-dynamic.cmake
│   ├── arm64-uwp.cmake
│   ├── arm64-windows-static-md.cmake
│   ├── arm64-windows-static.cmake
│   ├── armv6-android.cmake
│   ├── ...
│   └── x86-windows-v120.cmake
├── x64-linux.cmake
├── x64-osx.cmake
├── x64-uwp.cmake
├── x64-windows-static.cmake
├── x64-windows.cmake
└── x86-windows.cmake

```

`vcpkg install` 명령은 이 Triplet을 명시하지 않으면 현재 빌드를 수행하고 있는 환경(Host)과 빌드 결과물이 실행될 환경(Target)이 동일한 것으로 처리하며, 이를 위해 적절한 Triplet을 추정해냅니다.
이때 Host 환경의 컴파일러 정보를 얻기 위해 사용하는 것이 [`detect_compiler`](https://github.com/microsoft/vcpkg/tree/2021.12.01/scripts/detect_compiler)입니다.

### 1. Triplets 읽어보기

Vcpkg에서 [Triplet](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/triplets.md)들은 빌드 결과물이 실제로 실행되는 환경(Target 환경)을 CMake 파일로 표현한 것입니다.
예를 들어, x64-uwp.cmake는 아래와 같은 내용을 담고 있습니다.

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

set(VCPKG_CMAKE_SYSTEM_NAME WindowsStore)
set(VCPKG_CMAKE_SYSTEM_VERSION 10.0)

```

변수 이름에 `VCPKG_` 접두어를 사용하고 있습니다.
만약 설치과정에서 패키지가 CMake를 사용한다면, 이 변수의 값들은 적절한 CMake 변수들로 치환됩니다.
[자세한 치환 방법은 각 플랫폼마다 다릅니다](https://github.com/microsoft/vcpkg/tree/2021.12.01/scripts/toolchains).
정확한 사용법과 그 의미에 대해서는 아래 2개 문서를 확인하시길 바랍니다.

* https://cmake.org/cmake/help/latest/manual/cmake-variables.7.html
* https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling

>
> Vcpkg에서는 패키지를 CMake를 사용해 빌드하는 것을 권장합니다.
>

#### Community Triplet

triplets 폴더를 보면 community 라는 하위 폴더가 있습니다.
앞서 Vcpkg CI가 port 폴더 아래 배치된 패키지들의 설치 가능 여부를 확인한다고 설명했었는데, **community 폴더의 Triplet에 대해서는 이 검사를 수행하지 않습니다.**
만약 이 Triplet들을 사용해야 한다면, 직접 CI를 구성해서 언제든 패키지 설치 가능성을 점검할 수 있도록 준비하는 것을 권합니다.

>
> 비교적 많이 사용되는 [Android 환경에 대한 안내는 2020년 5월](https://github.com/microsoft/vcpkg/pull/11264)에, [iOS 환경에 대한 지원은 2020년 4월](https://github.com/microsoft/vcpkg/pull/6275) 추가되었습니다.
>

### 2. Triplet 작성하기

이 저장소에는 Android, iOS Simulator를 대상으로 하는 Triplet이 몇개 있습니다.
CMake 문법에 익숙하다면 읽고 의미를 해석해보는게 도움이 되리라 생각합니다.

> TBA

```cmake

```

## CMake에서 Vcpkg로 설치한 패키지를 사용하기

* https://cmake.org/cmake/help/latest/guide/using-dependencies/index.html
* https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html

> TBA


## Vcpkg Feature 사용하기

### 1. Binary Caching

### 2. Overlay

#### Port

#### Triplet

### 3. Registry

### 4. Manifest

