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

기능적으로는 계속 변화하고 있지만 파일 구조만큼은 대부분 그 이전과 같이 유지하고 있습니다.

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
│       └── vcpkg.cmake // -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake
└── triplets
    ├── ...
    └── x86-windows.cmake
```

프로젝트의 README.md에서 설명하듯, bootstrap-vcpkg 스크립트를 가장 먼저 실행해야 합니다.
Vcpkg는 폴더에 있는 파일만으로는 사용할 수 없고, 이를 사용하는 [전용프로그램 `vcpkg`](https://github.com/microsoft/vcpkg-tool)를 필요로 합니다.

이전에는 `vcpkg`의 소스 파일들을 toolsrc에 내장하고 있었습니다만, 2021년 중반 이후 실행프로그램을 다운로드해서 사용할 수 있도록 구조가 바뀌었습니다.
(구체적인 시기는 Host 플랫폼마다 다릅니다.)

소스코드를 사용해서 빌드할때는 스크립트에서 제공하는 옵션들을 확인해야 할 수 있습니다.
예를 들면, Mac 환경에서는 AppleClang을 사용하도록 하는 옵션이 있었습니다.
[한-참 늦게(2019년 9월) 지원된 C++ 17 `<filesystem>`](https://developer.apple.com/documentation/xcode-release-notes/xcode-11-release-notes) 때문이죠.
이제는 불필요한 옵션이 되었습니다.

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
Port는 패키지의 정보(`vcpkg.json`), 빌드를 위한 절차(`portfile.cmake`), Vcpkg에서 빌드하도록 만들기 위한 Patch 등의 파일들을 묶어둔 폴더를 말합니다.
형태가 너무 막연하다면, 도합 130 라인정도 되는 [ports/spdlog](https://github.com/microsoft/vcpkg/tree/2021.12.01/ports/spdlog)의 파일들을 한번 살펴보면 좋을 것 같습니다. 

> [Conan C/C++ Package Manager](https://conan.io)를 사용해본 사람이라면 `conanfile.py` 혹은 Recipe와 유사하다는 생각이 들 것입니다.

#### Port의 버전

현재 Vcpkg에서는 각 port들의 버전을 4가지 종류로 구분하여 관리하고 있습니다.
버전을 확인할때는 `vcpkg search` 명령을 사용합니다.
이 명령은 port들의 이름, Feature, 버전, 설명을 출력해줍니다.
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

[CMake에서 상정하고 있는 용례(User Flow)](https://cmake.org/cmake/help/latest/guide/user-interaction/index.html)가 있는 것처럼,
Vcpkg 또한 [패키지를 설치하고 사용할 때의 시나리오](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/examples/installing-and-using-packages.md)가 정해져 있습니다.
**이 과정에는 Port의 파일들을 확인하는 것은 없습니다.**
만약 본격적인 Vcpkg 지원/활용을 계획하고 있다면, 그만큼 완성도 있는 `portfile.cmake`가 작성되어있다는 합의가 되어있다는 점을 늘 생각해야 합니다.

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

```console
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

`vcpkg install`을 실행할 때 x64-windows, x64-linux, x64-osx와 같은 단어들을 확인할 수 있었습니다.
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

`vcpkg install` 명령은 이 **Triplet을 명시하지 않으면** 현재 빌드를 수행하고 있는 환경(Host)과 빌드 결과물이 실행될 환경(Target)이 동일한 것으로 처리하며, 이를 위해 적절한 Triplet을 추정해냅니다.
이때 Host 환경의 컴파일러 정보를 얻기 위해 사용하는 것이 [`detect_compiler`](https://github.com/microsoft/vcpkg/tree/2021.12.01/scripts/detect_compiler)입니다.

### 1. Triplets 읽어보기

Vcpkg에서 [Triplet](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/triplets.md)들은 빌드 결과물이 실제로 실행되는 환경(Target 환경)을 CMake 파일로 표현한 것입니다.
대표적으로 5개 변수가 있는데, Vcpkg 저장소의 [`triplets/x64-uwp.cmake`](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/x64-uwp.cmake)는 아래와 같은 내용을 담고 있습니다.

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

set(VCPKG_CMAKE_SYSTEM_NAME WindowsStore)
set(VCPKG_CMAKE_SYSTEM_VERSION 10.0)

```

변수 이름에 `VCPKG_` 접두어를 사용하고 있습니다.
만약 설치과정에서 패키지가 CMake를 사용한다면, [이 변수의 값들은 적절한 CMake 변수들로 치환](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/vcpkg-cmake/vcpkg_cmake_configure.cmake#L302-L331)됩니다.
결과적으로는 [CMake Toolchain(Cross Compiling)](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#id12)에서 정의하는 변수들로 연결되는 것이죠.
[자세한 치환 방법은 각 플랫폼마다 다른데](https://github.com/microsoft/vcpkg/tree/2021.12.01/scripts/toolchains),
이 때문에 여러분이 배포하고 있는 플랫폼에 맞는 정확한 사용법과 그 의미에 대해 알아둘 필요가 있습니다.
관련된 CMake 변수들의 의미는 아래 2개 문서에서 찾아볼 수 있습니다.

* https://cmake.org/cmake/help/latest/manual/cmake-variables.7.html
* https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling

>
> 대부분의 `VCPKG_`변수들은 CMake 변수들로 전달된다고 했는데,
> 이런 구현상의 이유로 때문에 [Vcpkg에서는 패키지를 가급적 CMake를 사용해 빌드하는 것을 권장](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/maintainers/maintainer-guide.md#prefer-using-cmake)하고 있습니다.
>

CMake에 익숙하지 않더라도 [vcpkg.cmake에서 관련된 내용을 먼저 짚어보는 것이](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/buildsystems/vcpkg.cmake#L239-L357) 앞으로의 내용을 이해할 때 도움이 될 것 같습니다.
관련헤서 vcpkg.cmake에서 주목할만한 부분은 Triplet의 Architecture, Platform 값을 `VCPKG_TARGET_TRIPLET` 변수로 재조합하는 부분입니다.

`vcpkg install` 명령에서 **Triplet을 명시하는 경우** 영향을 받는 부분 중 하나가 바로 이 변수입니다.
예를 들어, `vcpkg install --triplet x86-windows ...`와 같이 명령했다면 `VCPKG_TARGET_TRIPLET`은 `x86-windows`가 되는 것이죠.

Triplet 파일에는 정의해야하는 변수가 5개 있습니다.
실제로 몇개는 생략해도 괜찮지면, 실제로 vcpkg를 사용해본 경험으로는 5개를 모두 정의해야 하는 경우가 더 많으리라 생각합니다.
각각의 의미를 설명하자면, 아래와 같습니다.

* `VCPKG_CMAKE_SYSTEM_NAME`, `VCPKG_TARGET_ARCHITECTURE`:  
  [Target System, Architecture를 의미합니다.](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/maintainers/control-files.md#supports). 현실적인 이유로 인해, 이 변수들에 사용할 수 있는 값은 [CMake의 지원범위](https://cmake.org/cmake/help/latest/manual/cmake-variables.7.html)를 따릅니다. 실제로 Vcpkg에서 원하는 기대값들은 [ports/vcpkg-cmake/vcpkg_cmake_configure.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/vcpkg-cmake/vcpkg_cmake_configure.cmake#L280-L303)에서 확인할 수 있습니다.

* `VCPKG_CRT_LINKAGE`:  
  Target환경이 Windows 일때만 의미가 있습니다. `static`은 `/MT[d]`, `dynamic`은 `/MD[d]` 컴파일러 옵션으로 연결됩니다. 이 부분이 다소 [곤란한 문제](https://docs.microsoft.com/en-us/cpp/c-runtime-library/potential-errors-passing-crt-objects-across-dll-boundaries)가 될 수 있다는 것을 Windows 개발자 분들은 아마 알고 계시리라 생각합니다.

* `VCPKG_LIBRARY_LINKAGE`:  
  `static`일때는 정적 라이브러리(`.lib`, `.a`)를, `dynamic`일때는 동적 로딩 라이브러리(`.dll`, `.so`, `.dylib`)를 만들때 사용됩니다.

* `VCPKG_CMAKE_SYSTEM_VERSION`:  
  [`CMAKE_SYSTEM_VERSION`](https://cmake.org/cmake/help/latest/variable/CMAKE_SYSTEM_VERSION.html)으로 사용됩니다. 이 변수는 Target 시스템의 SDK 버전을 의미하는데, Mac이라면 [11.2](https://developer.apple.com/documentation/macos-release-notes), Windows에서는 [10.0.19041.0 등](https://developer.microsoft.com/en-us/windows/downloads/sdk-archive/)을 사용합니다.

위 5개 변수만 사용해도 왠만한 빌드 설정을 제어할 수 있겠다는 느낌을 받으셨을수도 있습니다.
실제로는 빌드 환경에 따라서 [좀 더 많은 변수들을](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/triplets.md#variables) 커스터마이징해서 사용하기도 합니다.
만약 특정한 컴파일러를 사용한다면 `VCPKG_CXX_FLAGS`, `VCPKG_LINKER_FLAGS` 변수를,
Visual Studio가 "Program Files(x86)"같은 기본 위치가 아닌 다른 폴더에 설치되었다면 `VCPKG_VISUAL_STUDIO_PATH` 변수를,
Mac 환경에서 Simulator 빌드를 하고 싶다면 `VCPKG_OSX_SYSROOT` 변수를 변경하는 식입니다.

### 2. Triplet 예외 적용하기

Triplet은 `vcpkg install`명령을 통해 설치하는 모든 패키지들에게 적용됩니다.
하지만 배포 정책에 따라서 어떤 패키지들은 특정한 `VCPKG_LIBRARY_LINKAGE` 값을 사용하도록 하고 싶을 수 있습니다. 이것을 [Per-port customization](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/triplets.md#per-port-customization)이라고 합니다.

이때는 Triplet 파일 안에서 `PORT` 변수에 따라 분기하는 것으로 제어합니다.
예를 들어, 앞서 설치해봤던 `libzip`을 Windows x86_64환경에서 Static 라이브러리로 사용하고 싶다면 `triplets/x64-windows.cmake`를 아래와 같이 변경하면 됩니다.

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

list(APPEND STATIC_PORTS "libzip" "zlib")
# build static library(.lib) if the port is in `STATIC_PORTS`
if(PORT IN_LIST STATIC_PORTS)
    set(VCPKG_LIBRARY_LINKAGE static)
    message(STATUS "${PORT} will be '${VCPKG_LIBRARY_LINKAGE}'") # ${port} will be 'static'
endif()
```

위 예시에서는 [IN_LIST를 사용해 List 변수에 해당 PORT가 포함되는지](https://cmake.org/cmake/help/latest/command/if.html?highlight=in_list#existence-checks) 검사한 뒤, `VCPKG_LIBRARY_LINKAGE`을 변경하고 있습니다.
지금은 `dynamic`에서 `static`으로 바꾸지만, 그 반대의 경우도 가능하겠죠.
이렇게 변경한 후 다시 `libzip`을 설치해보면 아래와 같이 Triplet 파일(CMake script)에서 `message(STATUS ...)`가 출력되는 것을 볼 수 있습니다.

```
PS C:\vcpkg> .\vcpkg.exe install libzip:x64-windows
Computing installation plan...
...
-- libzip will be 'static'
...
```

여기서 `vcpkg install`에 전달한 `libzip`이 `PORT` 변수로 사용된다는 것도 알 수 있는데, 그렇다면 패키지를 동시에 설치하면 어떻게 될까요?

```
PS C:\vcpkg> .\vcpkg.exe install --triplet x64-windows spdlog libzip
Computing installation plan...
...
-- libzip will be 'static'
...
-- spdlog will be 'static'
...
```

이렇게 패키지(port)들마다 Triplet 스크립트가 각각 적용된다는 것을 알 수 있습니다.
두 패키지의 `"dependencies"`들은 `VCPKG_LIBRARY_LINKAGE`값이 어떻게 적용되었는지 installed 폴더에서 확인해보시길 권해드립니다.

### 3. Community Triplet

triplets 폴더를 보면 community 라는 하위 폴더가 있습니다.
앞서 Vcpkg CI가 port 폴더 아래 배치된 패키지들의 설치 가능 여부를 확인한다고 설명했었는데, **community 폴더의 Triplet에 대해서는 이 검사를 수행하지 않습니다.**
달리 말해, 어떤 패키지를 설치할 때 Community Triplet을 사용한다면 **설치가 성공한다고 장담할 수 없습니다**.
만약 이 Triplet들을 사용해야 한다면, 직접 CI를 구성해서 언제든 패키지 설치 가능성을 점검할 수 있도록 준비하는 것을 권합니다.

>
> 비교적 많이 사용되는 [Android 환경에 대한 안내는 2020년 5월](https://github.com/microsoft/vcpkg/pull/11264)에, [iOS 환경에 대한 지원은 2020년 4월](https://github.com/microsoft/vcpkg/pull/6275) 추가되었습니다.
>

## CMake에서 Vcpkg로 설치한 패키지를 사용하기

### 1. CMake Toolchain = Vcpkg

Bootstrap을 마친 이후, CMake 프로젝트에서 Configure/Generate할 때 Toolchain으로 vcpkg.cmake 파일의 경로를 사용하면 됩니다.
실제로 이 `CMAKE_TOOLCHAIN_FILE` 변수가 사용되는 지점은 CMake의 `project` 명령이 수행될 때 입니다.
따라서 Vcpkg의 동작을 바꾸고 싶다면 `project` 명령이 호출되기 전에 CMake변수들을 변경해야 합니다.

>
> 이런 작업을 필요로 하는 경우가 Android Gradle Plugin의 CMake 빌드와 Vcpkg를 결합해 빌드할 때 입니다.
> 보다 자세한 설명은 후술하겠습니다.
>

```console
$ cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake -DCMAKE_BUILD_TYPE=Debug
```

CMake 3.19+ 버전을 사용하고 있다면 [CMake Preset](https://cmake.org/cmake/help/latest/)에서 `"cacheVariables"` 필드를 사용할수도 있습니다.
3.20 버전을 예로 들면 아래 JSON과 같습니다.
`CMAKE_TOOLCHAIN_FILE` 변수의 타입을 `FILEPATH`를 써서 임의의 파일에 대한 경로라는 것을 명시하고, 환경변수 `VCPKG_ROOT`를 사용해 Vcpkg 폴더를 찾도록 하고 있습니다.

`CMAKE_SYSTEM_VERSION` 변수의 값이 `"10.0.18362.0"`로 설정되어 있는데, **이것이 `vcpkg`에서 패키지들을 설치할 때 사용하던 `VCPKG_SYSTEM_VERSION`과 다르다는 것을 이해해야 합니다**.
이 CMakePresets.json을 사용하는 프로젝트는 Vcpkg 바깥에 있기 때문에, Vcpkg Triplet의 영향을 받지 않습니다.
다만 패키지들을 찾을 때 `VCPKG_TARGET_TRIPLET`을 참고할 뿐입니다.
만약 설치된 패키지들과 같은 Target SDK를 사용하도록 하려면 이처럼 Triplet과 같은 값을 사용하도록 별도로 `CMAKE_SYSTEM_VERSION`을 지정해 줄 필요가 있습니다.

```json
{
    "version": 2,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 20,
        "patch": 1
    },
    "configurePresets": [
        {
            "name": "vcpkg-x64-windows-debug",
            "displayName": "vcpkg(x64-windows) debug",
            "generator": "Visual Studio 16 2019",
            "binaryDir": "${sourceDir}/build-x64-windows",
            "cacheVariables": {
                "BUILD_TESTING": "ON",
                "BUILD_SHARED_LIBS": "ON",
                "CMAKE_BUILD_TYPE": {
                    "type": "STRING",
                    "value": "Debug"
                },
                "CMAKE_TOOLCHAIN_FILE": {
                    "type": "FILEPATH",
                    "value": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
                },
                "VCPKG_TARGET_TRIPLET": "x64-windows",
                "CMAKE_SYSTEM_VERSION": "10.0.18362.0"
            }
        }
    ],
    "buildPresets": [
        {
            "name": "vcpkg-x64-windows-debug",
            "configurePreset": "vcpkg-x64-windows-debug"
        }
    ],
    "testPresets": [
        {
            "name": "vcpkg-x64-windows-debug",
            "configurePreset": "vcpkg-x64-windows-debug",
            "output": {
                "outputOnFailure": true
            },
            "execution": {
                "noTestsAction": "error",
                "stopOnFailure": false
            }
        }
    ]
}
```

### 2. Find Package/Header/Library

먼저, CMake 프로젝트에서는 외부 라이브러리를 가져올(import) 때 몇가지 정해진 방법이 있다는 점을 알아둘 필요가 있습니다.
Modern CMake는 Target 기반으로 동작하고, Build를 수행하는 Target들은 `target_link_libraries`를 통해서 링킹하도록 하고 있습니다.
(이미 빌드가 완료된 Imported Target들에 대해서는 `target_link_options`에서 설정된 값들, 또는 `target_link_directories`에서 확인할 수 있는 설치경로 등이 포함됩니다.)
이에 대한 기본적인 내용을 알기 위해서는 CMake에서 작성한 3개 문서를 함께 이해하고 있어야 합니다.

* https://cmake.org/cmake/help/latest/guide/using-dependencies/index.html
* https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html
* https://cmake.org/cmake/help/latest/command/find_package.html

하지만 이런 내용들은 꽤나 지적 부담이 됩니다.
특히 **어떤 상황에서 기대와 다르게 동작할 수 있는지** 알아야 한다는 점에서 말이죠...

다행스럽게도 Vcpkg에서는 몇몇 중요한 CMake 명령들이 별다른 세부사항 없이도 수행되도록 지원하고 있습니다.
이 과정에서 각 Port들이 제공하는 `vcpkg-cmake-wrapper.cmake`를 실행(CMake `include`명령)해서 `CMAKE_MODULE_PATH`를 확장하거나, 
vcpkg.cmake에서 `CMAKE_PREFIX_PATH`, `CMAKE_FIND_ROOT_PATH`에 vcpkg 하위 폴더들을 추가하는 방법을 사용합니다.

결과적으로는 아래 3개 CMake 명령들이 영향을 받습니다.

* `find_package`: IMPORTED Target을 추가합니다.
* `find_path`: Header 경로를 찾을 때 사용합니다.
* `find_library`: Linkage 가능한 Library 파일을 찾을때 사용합니다.

#### find_package

다행스럽게도 많은 패키지들이 CMake의 모듈(Module)들을 지원하고 있고, `vcpkg install` 명령 이후 Import 방법을 출력하도록 하고 있습니다.
이렇게 친절하게 만드는 구체적인 방법은 Port 작성법을 다룰 때 설명하겠습니다.

예를 들어, `zlib` 또는 `libjpeg-turbo`를 설치하면 아래와 같은 사용법(Usage) 가이드가 나오는 것을 확인할 수 있습니다.
이 내용들은 CMake에서 Vcpkg를 통해 설치한 패키지들을 Import할 때 어떻게해야 하는지를 보여줍니다.

```console
$ vcpkg install zlib
...
The package zlib is compatible with built-in CMake targets:

    find_package(ZLIB REQUIRED)
    target_link_libraries(main PRIVATE ZLIB::ZLIB)

```

```console
$ vcpkg install libjpeg-turbo
...
The package libjpeg-turbo is compatible with built-in CMake targets:

    find_package(JPEG REQUIRED)
    target_link_libraries(main PRIVATE ${JPEG_LIBRARIES})
    target_include_directories(main PRIVATE ${JPEG_INCLUDE_DIR})

```

"Vcpkg 에서만 이렇게 사용하는 것이 아닌가?"라는 오해가 있을까 염려되어 부연하자면,
**CMake Module [`FindZLIB.cmake`](https://cmake.org/cmake/help/latest/module/FindZLIB.html), [`FindJPEG.cmake`](https://cmake.org/cmake/help/latest/module/FindJPEG.html)에서 적절하게 Detect할 수 있도록** 맞도록 Vcpkg의 `zlib`, `libjpeg-turbo` Port들이 작성된 것입니다.

#### pkg-config

모든 패키지들이 **CMake만을** 지원하는 것은 아닙니다.
여전히 `.pc`파일, 즉 [pkg-config](https://en.wikipedia.org/wiki/Pkg-config)를 사용해 include path, library search path를 전달받아 사용하는 프로젝트들도 있을 것입니다.

일부 패키지들은 .pc 파일을 설치하며, [`fmt`](https://github.com/fmtlib/fmt)도 그 중 하나입니다.
해당 패키지를 설치해보면 `installed/${triplet}/lib/pkgconfig`, `installed/${triplet}/debug/lib/pkgconfig` 폴더 밑에 `fmt.pc` 파일이 생성된 것을 확인할 수 있습니다.

```pc
prefix=${pcfiledir}/../..

exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: fmt
Description: A modern formatting library
Version: 8.0.1
Libs: -L"${libdir}" -lfmt
Cflags: -I"${includedir}"

```

이런 방식이라면 pkg-config 프로그램에서 참고할 prefix로 `${VCPKG_ROOT}/installed/${triplet}`을 주는 것으로 충분하겠죠.

CMake 사용자라면 이 파일들을 [FindPkgConfig.cmake](https://cmake.org/cmake/help/latest/module/FindPkgConfig.html)를 통해 사용할 수 있습니다.
Linux Kernel 5 버전 이상을 사용하고 있다면 Vcpkg를 통해 [axboe/liburing](https://github.com/axboe/liburing)을 설치하고 사용할 수 있습니다.

```console
$ vcpkg install liburing
...
```

Modern CMake는 Target기반으로 동작한다고 설명했었습니다.
아래와 같이 Imported Target `PkgConfig::liburing`을 만들도록 하기위해 `IMPORTED_TARGET`을, 
이렇게 생성된 Target을 현재 실행중인 CMake 스크립트들이 사용할 수 있도록 `GLOBAL`을 사용합니다.

```cmake
find_package(PkgConfig REQUIRED)

# Create CMake target - PkgConfig::liburing
pkg_check_modules(liburing REQUIRED
    IMPORTED_TARGET GLOBAL liburing>=2.0)

target_link_libraries(main
PRIVATE
    PkgConfig::liburing
    # ...
)
```

#### [find_path](https://cmake.org/cmake/help/latest/command/find_path.html)

편의상의 이유로, C++ 라이브러리들 중 상당수가 Header Only 정책을 사용하고 있습니다.
이런 프로젝트들은 Header파일과 그 경로만 있으면 사용할 수 있도록 설계되어 있는데,
이 때문에 CMakeLists.txt를 작성할 때 그저 Test프로그램들의 빌드만을 수행할 뿐 실제 파일들의 설치와 `find_package`을 지원하지 않는 경우가 많습니다.

Vcpkg에 등록된 Header Only 패키지들은 CMake에게 "지정한 include 패턴으로 Header를 찾아라"라는 것으로 그 경로를 획득할 수 있습니다.

```console
$ ./vcpkg install egl-registry
...
The package egl-registry is header only and can be used from CMake via:

    find_path(EGL_REGISTRY_INCLUDE_DIRS "EGL/egl.h")
    target_include_directories(main PRIVATE ${EGL_REGISTRY_INCLUDE_DIRS}) 

```

CMakeLists.txt를 직접 작성해 `EGL_REGISTRY_INCLUDE_DIRS`변수의 값이 어떻게 출력되는지 확인해보시기 바랍니다.

```cmake
project(test_vcpkg_import LANGUAGES CXX)

find_path(EGL_REGISTRY_INCLUDE_DIRS "EGL/egl.h")
message(STATUS "Detected EGL: ${EGL_REGISTRY_INCLUDE_DIRS})
```

#### [find_library](https://cmake.org/cmake/help/latest/command/find_library.html), [find_program](https://cmake.org/cmake/help/latest/command/find_program.html)

Vcpkg의 패키지들이 생성하는 파일 중에서 라이브러리 파일들은 `CMAKE_BUILD_TYPE`에 따라 `debug/lib` 혹은 `lib`에 배치됩니다.
Release 빌드일 때는 별도로 configuration 이름을 경로에 넣지 않은게 의아한 분들도 계실텐데, 특별한 이유는 없습니다.
[GNU standard에서 libdir의 경로에는 configuration 이름을 넣지 않기 때문입니다](https://www.gnu.org/prep/standards/html_node/Directory-Variables.html).
vcpkg.cmake에서는 [`find_*`명령을 사용할 때 Debug라면 `debug/lib`을 먼저, 그 이외의 경우는 `lib` 폴더 하위에서 요청받은 라이브러리를 찾도록 `CMAKE_FIND_ROOT_PATH`를 변경](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/buildsystems/vcpkg.cmake#L394-L408)합니다.
(다른 변수들도 변경해서 가능하면 installed 폴더를 먼저 찾도록 합니다.)

이 동작을 확인하기에 좋은 패키지는 [Google Protocol Buffers](https://developers.google.com/protocol-buffers/)입니다.
`protobuf` Port는 `protoc` 프로그램을 함께 빌드하기 때문에, CMake의 `find_library`, `find_program`을 모두 사용해보기 좋습니다.

```console
$ ./vcpkg install protobuf
...
The package protobuf provides CMake targets:

    find_package(protobuf CONFIG REQUIRED)
    target_link_libraries(main PRIVATE protobuf::libprotoc protobuf::libprotobuf protobuf::libprotobuf-lite)

```

참고로 CMake에는 [`FindProtobuf.cmake`](https://cmake.org/cmake/help/latest/module/FindProtobuf.html) 모듈이 있습니다.
이 모듈에서 정의하는 변수들과 그 값을 비교해보면서 `find_library`, `find_program`이 어떻게 다르게 동작하는 확인해보면 Vcpkg의 유용함을 몸소 느껴보실 수 있을 것입니다.

```cmake
find_package(protobuf CONFIG REQUIRED)

find_program(PROTOC_PATH NAMES protoc REQUIRED)
message(STATUS "Detected 'protoc': ${PROTOC_PATH}")

find_library(PROTOBUF_LIB NAMES protobufd protobuf REQUIRED)
message(STATUS "Detected 'protobuf': ${PROTOBUF_LIB})
```

### 3. 주의사항

`find_package`, `find_library`는 `CMAKE_BUILD_TYPE`의 영향을 받습니다.
**이 변수를 `vcpkg install`을 사용해 설치한 모든 패키지들이 사용했다** 점에 주의할 필요가 있습니다.
따라서 임의의 한 패키지가 Debug 빌드를 했다면, 해당 패키지의 라이브러리는 마찬가지로 Debug 빌드한 라이브러리들과 링킹했었고, 최종적으로 어플리케이션 빌드에도 함께 사용되어야 할 수 있다는 것입니다.

`VCPKG_LIBRARY_LINKAGE`를 `dynamic`으로 바꾼 뒤 패키지를 설치하면 링킹관계를 보다 쉽게 확인할 수 있습니다. `.so`파일이라면 `ldd`, `.dylib`이라면 `otool -L` 명령으로 의존관계를 확인해볼 수 있습니다.
Windows 환경이라면 [lucasg/Dependencies](https://github.com/lucasg/Dependencies)를 사용해서 Debug/Release DLL들을 한번 검사해보면 쉽게 확인할 수 있겠습니다.

## Vcpkg의 Port 이해하기

이제 Vcpkg 프로젝트 파일들의 대부분을 차지하는 Port에 대한 설명으로 넘어갈 때가 된 것 같습니다.
이제까지 어떤 경우에는 Port, 어떤 경우에는 Package라는 단어를 사용했는데, 이 시점에서 정의하고 넘어가야할 것 같습니다.

### 1. Port != Package

Vcpkg는 임의의 Package를 **소스코드로부터 빌드해서 설치**하는 방식으로 동작합니다.
이런 맥락에서, Port는 **Package를 Vcpkg에서 빌드하기 위한 방법**을 기술한 것이라고 설명할 수 있겠습니다.
`vcpkg` 프로그램이 Port의 내용를 바탕으로 설치를 수행하고,
이 **설치가 완료된 결과물들이 Package**가 되는 것이죠.
이런 뉘앙스를 각 폴더들의 이름(buildtrees, packages, installed)에서 이미 직감하셨을지도 모르겠습니다.

### 2. Port Feature

앞서 [`libzip`](https://github.com/nih-at/libzip)을 설치할 때 예시에서는 `libzip[core,openssl]`라고 표기했는데, 이때 `[]`안에 들어있는 부분을 Port Feature라고 합니다.
각 Port들이 지원하는 Feature는 `vcpkg search` 명령을 통해 확인할 수 있습니다.

```console
$ ./vcpkg.exe search libzip
libzip                   1.8.0            A library for reading, creating, and modifying zip archives.
libzip[bzip2]                             Support bzip2-compressed zip archives
libzip[commoncrypto]                      AES (encryption) support using Apple's Common Crypto API
libzip[default-aes]                       Use default AES
libzip[liblzma]                           Support XZ compressed zip archives using liblzma
libzip[mbedtls]                           AES (encryption) support using mbedtls
libzip[openssl]                           AES (encryption) support using OpenSSL
...
```

여기서 `libzip[bzip2]`에 대한 설명이 있습니다.
그 내용을 보면 [libzip 라이브러리](https://github.com/nih-at/libzip)에서 [`.bz2` 파일 양식](https://en.wikipedia.org/wiki/Bzip2)을 지원하도록 한다는 것이죠.
`vcpkg install`명령을 해보면 [bzip2 라이브러리](https://sourceware.org/bzip2/)를 함께 설치한다는 것을 알 수 있습니다.

```console
$ ./vcpkg.exe install libzip[openssl]
Computing installation plan...
The following packages will be built and installed:
  * bzip2[core]:x86-windows -> 1.0.8#2
    libzip[bzip2,core,default-aes,openssl,wincrypto]:x86-windows -> 1.8.0
  * openssl[core]:x86-windows -> 1.1.1l#4
  * zlib[core]:x86-windows -> 1.2.11#13
Additional packages (*) will be modified to complete this operation.
Detecting compiler hash for triplet x86-windows...
```

`vcpkg`는 임의의 Feature가 필요하다면, 해당 Feature에서 필요로 하는(`"dependencies"`) 패키지들을 함께 설치합니다.
달리 말하면 해당 라이브러리와 링킹(Linkage)하도록 빌드(Build)한다는 것이죠.
예를 들어, `[openssl]`과 같이 Feature를 사용하면 `libzip`에서 `openssl` 라이브러리와 링킹할 것입니다.
`[zstd]`으로 표현한다면 `zstd`라이브러리와 링킹하도록 빌드할 것입니다.

`vcpkg`에서 Port를 설치할 때, Port 작성자가 정의한 Feature들을 모두 사용하는 것은 아닙니다.
`libzip`의 `vcpkg.json` 파일을 살펴보면 `"default-features"`에서 `"bzip2"`, `"default-aes"`가 들어있습니다.
설명하자면, `libzip`의 `portfile.cmake`를 작성한 사람은 `"bzip2"`, `"default-aes"` 2가지가 "이 패키지를 설치할 떄 필요하다"라고 생각했다는 것이죠.
Feature를 지정하지 않으면 이 값들(`"default-features"`)이 그대로 적용됩니다.

```console
$ ./vcpkg.exe install libzip
Computing installation plan...
The following packages will be built and installed:
  * bzip2[core]:x86-windows -> 1.0.8#2
    libzip[bzip2,core,default-aes,wincrypto]:x86-windows -> 1.8.0
  * zlib[core]:x86-windows -> 1.2.11#13
```

하지만 bzip2이 필요하지 않을수도 있습니다.
이런 경우 Feature에 `core`를 명시하는 것으로, 사용자가 원하는 dependencies만 설치하도록 강제할 수 있습니다.
"내가 요구한 것만 설치하라"라는 의미로 사용하는 것이죠.

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

`core`를 지정했을 때는 `bzip2`를 설치하지 않는 것을 확인할 수 있습니다.
하지만 `core`와 함께 명시한 `openssl`과 관련된 라이브러리는 함께 설치하고 있습니다.

## Vcpkg의 Port 작성방법

프로젝트가 어떤 빌드 시스템을 사용하고 있느냐에 따라서 빌드 방법이 상당히 달라지게 됩니다.
Vcpkg는 Meson, Makefile 프로젝트를 지원하기는 하지만, CMake 프로젝트를 지원하는데 특화되어 있습니다.
[Port로 작성하려는 프로젝트의 빌드 시스템 파일이이 적절하지 않다고 판단되면 CMakeLists.txt를 내장하기도 합니다](https://github.com/microsoft/vcpkg/tree/2021.12.01/ports/7zip).

몇 년 전에 비하면 Vcpkg 프로젝트는 굉장히 활발하게 움직이고 있습니다.
[Discussions에서 검색해보는 것 만으로도](https://github.com/microsoft/vcpkg/discussions) 시간을 많이 아낄 수 있을 것이라 생각합니다.

### 1. Public Source

빌드를 하려면 역시 소스코드부터 있어야겠죠.
현재는 크게 3가지 방법이 사용되고 있습니다.
각각 URL, GitLab, GitHub 입니다.

#### Download from URL

portfile.cmake에서는 Vcpkg에서 지원하는 여러 CMake function/macro들을 사용할 수 있습니다.
그 중 단연코 가장 많이 사용하는 것들 중 하나는 [`vcpkg_download_distfile`](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_download_distfile.cmake)입니다.

한번 다운로드한 뒤에는 다운로드한 파일을 재사용하고, Hash 값을 검사해 변경이 발생했는지 확인할 수 있습니다.
[Port d3dx12](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/d3dx12/portfile.cmake#L10-L19)에서 그 예시를 볼 수 있습니다.

```cmake
vcpkg_download_distfile(D3DX12_H
    URLS "https://raw.githubusercontent.com/walbourn/directx-vs-templates/${VERSION}/d3d12game_win32_dr/d3dx12.h"
    FILENAME "directx-vs-templates-${VERSION}-d3dx12.h"
    SHA512 b053a8e6593c701a0827f8a52f20e160070b8b71242fd60a57617e46b87e909e11f814fc15b084b4f83b7ff5b9a562280da64a77cee3a171ef17839315df4245
)
```

#### Download + Extract

반드시 소스파일을 다운로드 받을 필요는 없습니다.
지금은 빌드를 준비하는 중이니, zip 파일을 받아서 압축을 해제하는 방법이 필요하겠죠.
[Port fftw3](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/fftw3/portfile.cmake)를 예시로 확인해보겠습니다.

```cmake
vcpkg_download_distfile(ARCHIVE
    URLS "http://www.fftw.org/fftw-3.3.10.tar.gz"
    FILENAME "fftw-3.3.10.tar.gz"
    SHA512 2d34b5ccac7b08740dbdacc6ebe451d8a34cf9d9bfec85a5e776e87adf94abfd803c222412d8e10fbaa4ed46f504aa87180396af1b108666cde4314a55610b40
)

vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE ${ARCHIVE}
    PATCHES
        omp_test.patch
        patch_targets.patch
        fftw3_arch_fix.patch
        aligned_malloc.patch
)
```

여기서 다운로드 받을떄 tar.gz를 사용한 것에 주의해야 합니다.
Vcpkg의 `vcpkg_extract_source_archive_ex`, 현 시점에서 구현체인 [`vcpkg_extract_source_archive`](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_extract_source_archive.cmake#L205-L210) 때문입니다.

#### [Source from Git](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_from_git.cmake)

Git을 사용해 patch를 적용할 수 있다는 점이 특히 편리합니다.
Vcpkg에서 임의의 Port를 빌드할 떄, 이미 설치한 Package들을 사용하려면 빌드 시스템 파일들이 수정되어야 하는 경우가 많습니다.
빌드 시스템 파일을 수정해야 한다는 것은 그만큼 Makefile, CMake, Meson에 대한 경험을 요구한다는 의미도 됩니다.
이 부분을 낯설게 느끼실수도 있습니다만, 걱정할 필요 없습니다.
수많은 Port 폴더들이 가지고 있는 patch 예시들이 있으니까요.

[Port libyuv](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/libyuv/portfile.cmake)가 이 방법을 사용하고 있습니다.
URL을 조금 수정하면 다운로드 받기 위해 Username, Password를 전달하는 것도 가능하겠군요.
요즘은 쉽게 무효화시킬 수 있는 Token을 사용하는 경우가 많으니 Token 값을 그대로 적어넣어도 큰 부담이 없겠습니다만, 
꺼림칙 하다면 `vcpkg_download_distfile`의 `FILENAME`과는 달리 [CMake에서 환경변수를 사용하는](https://cmake.org/cmake/help/latest/command/set.html#set-environment-variable) 방법을 사용하는 것도 괜찮은 방법입니다.

```cmake
vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://chromium.googlesource.com/libyuv/libyuv
    REF 287158925b0e03ea4499a18b4e08478c5781541b #2021-4-15
    PATCHES
        fix_cmakelists.patch
        fix-build-type.patch
)
```

여기서 Port에서 사용하는 Patch 파일들과 `PATCHCES` 부분를 관리하는 것이 번거로운 부분 중 하나입니다.
만약 Patch 목록이 조건부로 바뀌어야 한다면, 아래와 같이 List 변수를 사용하면 됩니다.

```cmake
if(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND PATCHES fix-windows-source.patch
                        fix-uwp-build.patch
    )
endif()

vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL ${DOWNLOAD_URL}
    REF ${DOWNLOAD_COMMIT}
    PATCHES
        fix-cmakelists.patch
        ${PATCHES}
)
```

이렇게 다운로드 받은 소스 폴더가 buildtrees 폴더 밑에 어떤 경로를 부여받는지, portfile.cmake에 아래와 같은 내용을 넣어서 출력을 확인해보길 권합니다.

```cmake
# vcpkg_from_git(...)
message(STATUS "Using sources: ${SOURCE_PATH}")
```

> 
> 잠깐 스스로의 힘으로 이런 질문에 답을 해보셨으면 좋겠습니다.  
> **"패키지 매니저에 맞추기 위해 프로젝트의 빌드시스템 파일을 수정해야 한다면, 과연 그 파일은 범용성있게 작성한 것인가?"**
> 

#### [Source from GitLab](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_from_gitlab.cmake)

[Cairo 라이브러리](https://www.cairographics.org/)는 GitLab에서 소스파일을 제공하고 있는데,
[Port cairo](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/cairo/portfile.cmake)를 살펴보면 GitLab에서 소스코드를 다운로드 받는 방법을 알 수 있겠군요.

```cmake
vcpkg_from_gitlab(
    GITLAB_URL https://gitlab.freedesktop.org
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cairo/cairo
    REF 156cd3eaaebfd8635517c2baf61fcf3627ff7ec2 #v1.17.4
    SHA512 2c516ad3ffe56cf646b2435d6ef3cf25e8c05aeb13d95dd18a7d0510d134d9990cba1b376063352ff99483cfc4e5d2af849afd2f9538f9136f22d44d34be362c
    HEAD_REF master
    PATCHES 0001-meson-fix-macOS-build-and-add-macOS-ci.patch
            cairo_static_fix.patch
)
```

GitLab instance에 대한 `GITLAB_URL`, Git 저장소(`REPO`)와 branch(`HEAD_REF`), 다운로드 받은 파일에 대한 Hash 값(`SHA512`)이 추가된 것을 확인할 수 있습니다.

#### [Source from GitHub](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_from_github.cmake)

 GitHub의 사용법도 거의 같습니다.
결국 `SOURCE_PATH`에 소스코드를 준비해주는 것이 핵심 역할이고,
그 과정에서 저장소에서 지정된 Commit을 다운로드 받아 Hash 검사를 하고, Patch를 적용하는 것이죠.
GitHub의 Mirror 저장소에서 소스코드를 받는 Port들이 많지만 대부분 유사한 패턴으로 작성되어있습니다.

```cmake
# https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/abseil/portfile.cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO abseil/abseil-cpp
    REF 278e0a071885a22dcd2fd1b5576cc44757299343 #LTS 20210324, Patch 2
    SHA512 a9e8e9169ebcfb8bc2eca28152ad2f655f48e6281ea932eb712333f3d0aa0b6fa1a9b184f3e2ddd75d932a54b501cc5c7bb29a1c9de5d2146f82fc5754653895
    HEAD_REF master
    PATCHES
        # ...
        fix-cxx-standard.patch
        fix-32-bit-arm.patch
)
```

여기서는 `GITLAB_URL`에 해당하는 부분이 보이지 않는데, [`GITHUB_HOST`로 지정할 수 있습니다](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_from_github.cmake#L17-L19).
GitHub Enterprise에서 소스코드를 다운로드 받아야 한다면 이 필드와 함께 `AUTHORIZATION_TOKEN`이 필요합니다. 해당 저장소에 접근할 수 있는 권한이 필요하기 때문입니다.
[GitHub Settings / Developer Settings / Personal Access Tokens](https://github.com/settings/tokens)에서 해당 저장소에 접근할 수 있는(Read) 권한을 가진 Token을 생성한 후, 그 값을 적어주면 됩니다.

```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ...
    REF ${commit} # or Git Tag (ex. REF v1.2.3)
    SHA512 ${download_file_hash}
    GITHUB_HOST https://git-dev.hellworld.com
    AUTHORIZATION_TOKEN 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 # maintainer@hellworld.com
)
```

특수한 목적이 아니라면 Token들은 만료일이 정해져있을 것입니다.
**여기서 만료된 토큰으로 다운로드를 받으면 어떤일이 발생할지 한번 상상해보셨으면 좋겠습니다.**  
먼저, 사용자를 확인할 수 없으니 GitHub에서는 404 페이지를 보여줄 것입니다.
`vcpkg_from_github`은 `vcpkg_download_distfile`를 사용해 그 웹 페이지를 .tar.gz 파일로 다운로드 하게 되고, 그렇다면 SHA512 값이 잘못되었다고 오류 메세지가 출력될 것입니다.
다운로드 받는 시각에 따라서 HTML 페이지 내용도 달라질테니, SHA512 값은 계속 잘못되었다고 표시될 것입니다.

처음으로 port를 작성하고 있다면, SHA512값을 CLI로 계산하려 하실지도 모르겠습니다.
정확한 SHA512값을 모른다면 0을 적고, `vcpkg install` 명령을 사용해서 계산된 값을 확인하면 됩니다.
download폴더에 .tar.gz 파일이 정상적인 파일인지 확인한 뒤에, 그 값을 그대로 사용하면 됩니다.

[Port zlib-ng](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/zlib-ng/portfile.cmake)의 SHA512 값을 0으로 바꾼 다음, 어떤 메세지가 출력되는지 보겠습니다.

```cmake
# port/zlib-ng/portfile.cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zlib-ng/zlib-ng
    REF 2.0.5
    SHA512 0
    HEAD_REF master
)
```

```console
$ vcpkg install --triplet x64-windows zlib-ng
Computing installation plan...
The following packages will be built and installed:
    zlib-ng[core]:x64-windows -> 2.0.5
Detecting compiler hash for triplet x64-windows...
Restored 0 packages from C:\vcpkg\archives in 164.1 us. Use --debug to see more details.
Starting package 1/1: zlib-ng:x64-windows
Building package zlib-ng[core]:x64-windows...
CMake Error at scripts/cmake/vcpkg_download_distfile.cmake:74 (message):
  

  File does not have expected hash:

          File path: [ C:/vcpkg/downloads/zlib-ng-zlib-ng-2.0.5.tar.gz ]
      Expected hash: [ 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 ]
        Actual hash: [ a643089a8189bf8bd24d679b84f07ae14932b4d88b88e94c44cca23350d6a9bbdaa411822d3651c2b0bf79f30c9f99514cc252cf9e9ab0b3a840540206466654 ]

  The cached file SHA512 doesn't match.  The file may have been corrupted.
  To re-download this file please delete cached file at path
  C:/vcpkg/downloads/zlib-ng-zlib-ng-2.0.5.tar.gz and retry.

Call Stack (most recent call first):
  scripts/cmake/vcpkg_download_distfile.cmake:231 (z_vcpkg_download_distfile_test_hash)
  scripts/cmake/vcpkg_from_github.cmake:175 (vcpkg_download_distfile)
  ports/zlib-ng/portfile.cmake:1 (vcpkg_from_github)
  scripts/ports.cmake:145 (include)


Error: Building package zlib-ng:x64-windows failed with: BUILD_FAILED
```

Actual hash 로 출력된 값이 0으로 바꾸기 전과 일치하는 것을 확인할 수 있습니다.
새로운 Port를 작성하고 있다면 이 값을 그대로 적용하면 됩니다.

### 2. Managing Patch

Patch 파일을 만드는 방법에 대해서도 가볍게 다뤄보겠습니다.

#### Pull Request as a patch

Patch 파일을 매번 내장하는 것보단, 빌드하려는 프로젝트에 제출된 PR을 적용하는 것도 괜찮은 방법이 될 수 있습니다.
[그 PR의 diff만 다운로드 받아서, Patch로 적용하면](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/farmhash/portfile.cmake#L4-L8) 되니까요.

만약 PR 내용이 바뀌면, 나중에 Hash 값이 달라졌을테니 주기적으로 다시 빌드하는 방법으로 확인할 수 있죠.
그런 일련의 절차가 불편할 것 같다면, `FILENAME`에 날짜 같은 것을 사용하는 것도 괜찮을 겁니다.
[창의력을 발휘해서 실행시각에 따라서 변하는 CMake 변수](https://cmake.org/cmake/help/latest/command/string.html#timestamp)를 사용하고 싶을 수 있겠지만,
가급적 Literal을 사용해서 고정시키는게 좋습니다.
그래야 downloads 폴더에서 비교해볼 때 편할테니까요.

```cmake
vcpkg_download_distfile(WIN_PR_PATCH
    URLS "https://github.com/google/farmhash/pull/40.diff"
    FILENAME farmhash-pr-40.patch
    SHA512 265f5c15c17da2b88c82e6016a181abe73d2d94492cdb0cba892acf67a9d40815d54fa81e07351254fe2a39aea143b125924db0e7df14aac84a7469a78612cbd
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/farmhash
    REF 0d859a811870d10f53a594927d0d0b97573ad06d
    SHA512 7bc14931e488464c1cedbc17551fb90a8cec494d0e0860db9df8efff09000fd8d91e01060dd5c5149b1104ac4ac8bf7eb57e5b156b05ef42636938edad1518f1
    HEAD_REF master
    PATCHES ${WIN_PR_PATCH} # <----
```

### 3. Build with [CMake](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_build_cmake.cmake)

[Port spdlog](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/spdlog/portfile.cmake)를 따라서 작성하기만 해도 됩니다.

소스코드를 다운로드 받아, `SOURCE_PATH`에 압축을 풀어둔 다음에는 CMake 프로젝트들을 설치하기 위한 3가지 과정을 수행하게 됩니다.
그 다음에는 Vcpkg에서 Fixup이라고 부르는, vcpkg의 설치 스타일에 맞게 파일들을 재배치하는 과정이 이어집니다.
빌드하려는 프로젝트의 설치가 어떻게 완료되느냐에 따라 4번 과정은 생략할 수도 있습니다.
보통 `.pc` 혹은 CMake `find_package`을 위한 파일들을 생성하지 않는 경우에 해당합니다.

1. Configure/Generate
2. Build
3. Install
4. Fixup

#### Host dependency

이런 과정을 거치려면 먼저 `${port}/vcpkg.json` 파일에서 Host dependency로 `vcpkg-cmake`, `vcpkg-cmake-config`를 사용하도록 작성해야 합니다.
Host dependency에는 현재 빌드를 수행하고 있는 환경(Host 환경)에 따라서 달라지는 port들이 사용되며, 보통 스크립트 혹은 vcpkg의 다른 port들이 설치한 프로그램들을 사용해야 할 때 명시합니다.
프로그램을 설치하는 port의 대표적인 예시로는 `protoc`을 설치하는 [Port protobuf](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/protobuf/portfile.cmake), `flatc`를 설치하는 [Port flatbuffers](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/flatbuffers/portfile.cmake)를 예시로 들 수 있겠습니다.

보다 구체적인 예를 들자면, `x64-osx`(Host 환경)에서 `arm64-osx`(Target 환경)로 크로스 컴파일할 때 아래와 같이 출력됩니다.
실제 사용가능한 라이브러리를 만들어야 하는 `fmt`, `spdlog`만 `arm64-osx`로 설치하고, 나머지는 Host 환경을 따르는 것이죠.

```console
$ ./vcpkg install spdlog:arm64-osx
Computing installation plan...
The following packages will be built and installed:
  * fmt[core]:arm64-osx -> 8.0.1
    spdlog[core]:arm64-osx -> 1.9.2
  * vcpkg-cmake[core]:x64-osx -> 2021-09-13
  * vcpkg-cmake-config[core]:x64-osx -> 2021-11-01
Additional packages (*) will be modified to complete this operation.
Detecting compiler hash for triplet x64-osx...
...
```

#### [Port vcpkg-cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/vcpkg-cmake)

CMake를 사용하고 있지만 Host dependency가 없던 시절의 스타일대로 작성된 [Port nsync](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/nsync/vcpkg.json)를 바꾸면서 연습을 해보시면 좋겠습니다.

```json
{
  "name": "nsync",
  "version": "1.24.0",
  "description": "nsync is a C library that exports various synchronization primitives, such as mutexes",
  "homepage": "https://github.com/google/nsync"
}
```

현재의 vcpkg에서는 이런식으로 작성해야 합니다.

```json
{
  "name": "nsync",
  "version": "1.24.0",
  "description": "nsync is a C library that exports various synchronization primitives, such as mutexes",
  "homepage": "https://github.com/google/nsync",
  "dependencies": [
    {
      "name": "vcpkg-cmake",
      "host": true
    }
  ]
}
```

`vcpkg-cmake`는 이제 더는 사용하지 않는 `vcpkg_configure_cmake`, `vcpkg_install_cmake`를 대체하기 위한 CMake 함수들이 내장된, 이른바 Script Port입니다.
Configure/Generate, Build, Install 단계는 아래와 같이 작성합니다.
프로젝트에서 일정한 빌드 순서를 요구하지 않는다면, Build는 생략할 수 있습니다.
저의 경험으로, Custom Target을 정의하고 있다면 Build 단계가 필요할 가능성이 높습니다.

```cmake
# cmake -G Ninja -S ${SOURCE_PATH} -B . -DNSYNC_ENABLE_TESTS=OFF
vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    GENERATOR Ninja
    OPTIONS
        -DNSYNC_ENABLE_TESTS=OFF
)

# cmake --build . --target codegen
vcpkg_cmake_build(TARGET codegen) 

# cmake --build . --target install
vcpkg_cmake_install()
```

nsync는 `vcpkg_cmake_build`가 필요하지 않으니 생략하면 되겠습니다.

#### Copy PDB (for Windows)

Install을 마치면 이제 후속작업으로 빌드 결과물들을 정리해야 합니다.

```cmake
vcpkg_copy_pdbs()
```

Windows 환경에서 DLL을 빌드한다면 그에 상응하는 PDB도 설치합니다.
이를 위해 사용하는 것이 `vcpkg_copy_pdbs` 입니다.
편의상의 이유로 이 함수는 Non-Windows, Static 빌드에서는 오류를 발생시키지 않습니다. 단순히 아무일도 하지 않고 넘어깁니다.

#### Library / CRT Linkage

nsync의 portfile.cmake 최상단을 보면 Windows 환경에서 언제나 static으로 빌드하도록 강제하고 있습니다.
이 라이브러리는 [`declspec(dllexport)`](https://docs.microsoft.com/en-us/cpp/cpp/dllexport-dllimport)처리가 되어있지 않기 때문에, 이와 같이 

```cmake
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()
```

[`vcpkg_check_linkage`](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_check_linkage.cmake)에서는 Library, CRT 링킹을 덮어쓸 수 있습니다.
Triplet 파일에서 기대하는 전체 구성을 무시하는 방법이기 때문에, Port들이 이 값을 덮어쓰는 것은 좋은 방법은 아닙니다.
하지만 링킹 방법을 제한하는 형태로 설계한 프로젝트라면 그런 점도 존중해야겠죠.

#### Fixup, [Port vcpkg-cmake-config](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/vcpkg-cmake-config)

nsync는 fixup이 필요하지 않은 라이브러리입니다.
하지만 가볍게 연습은 된 것 같으니, 다시 [Port spdlog](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/spdlog/portfile.cmake#L42-L43)로 이동해보겠습니다.
여기서 주의깊게 살펴볼 부분은 `vcpkg_cmake_config_fixup`, `vcpkg_fixup_pkgconfig`입니다.

```cmake
vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSPDLOG_FMT_EXTERNAL=ON
        -DSPDLOG_INSTALL=ON
        -DSPDLOG_BUILD_SHARED=${SPDLOG_BUILD_SHARED}
        -DSPDLOG_WCHAR_FILENAMES=${SPDLOG_WCHAR_FILENAMES}
        -DSPDLOG_BUILD_EXAMPLE=OFF
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/spdlog)
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()
```

`vcpkg_cmake_config_fixup`를 사용하기 위해선 `vcpkg-cmake-config`라는 Host dependency가 필요합니다.
vcpkg.json에서 일부만 가져와보면, 아래와 같이 작성되어있습니다.

```json
{
  "name": "spdlog",
  "version-semver": "1.9.2",
  "dependencies": [
    "fmt",
    {
      "name": "vcpkg-cmake",
      "host": true
    },
    {
      "name": "vcpkg-cmake-config",
      "host": true
    }
  ]
}
```

Port vcpkg-cmake-config의 역할을 `vcpkg_cmake_config_fixup` 함수를 portfile.cmake에서 사용할 수 있도록 해주는 것입니다.
`vcpkg_cmake_config_fixup`는 Port에서 설치하는 CMake 모듈(FindXXX.cmake) 또는 `find_package`를 위한 Config 파일(xyz-config.cmake)들을 `${CURRENT_PACKAGES_DIR}` 하위 폴더에 적절하게 재배치 하는 것입니다.
이런 Config 파일들에는 `CMAKE_INSTALL_PREFIX`가 절대 경로로 포함되어 있는데, [이를 상대 경로로 바꾸어 vcpkg 폴더 전체의 경로가 바뀌어도 동작할 수 있도록 수정하는 작업도 함께 수행합니다](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/vcpkg-cmake-config/vcpkg_cmake_config_fixup.cmake#L34-L41).

이와 관련해서, 설치한 패키지에서 경로 의존적인 문제가 발생하고, 이를 Fixup에서 해결할 수 없는 문제가 발생할수도 있습니다.
이는 프로젝트의 CMakeLists.txt에서 적절하지 않은 방법(Workaround)을 사용하고 있다는 신호입니다.
관련 내용을 수정하거나, 차라리 vcpkg에서의 `find_package` 지원을 포기해야 합니다.

[vcpkg_fixup_pkgconfig](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_fixup_pkgconfig.cmake)는 `pkg-config` 프로그램에서 사용하는 .pc 파일들을 재배치합니다.
[마찬가지로, 경로를 수정하는 작업을 포함하고 있습니다](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_fixup_pkgconfig.cmake#L149-L160).

```cmake
            string(REPLACE "${CURRENT_PACKAGES_DIR}" [[${prefix}]] contents "${contents}")
            string(REPLACE "${CURRENT_INSTALLED_DIR}" [[${prefix}]] contents "${contents}")
            string(REPLACE "${unix_packages_dir}" [[${prefix}]] contents "${contents}")
            string(REPLACE "${unix_installed_dir}" [[${prefix}]] contents "${contents}")

            string(REGEX REPLACE "(^|\n)prefix[\t ]*=[^\n]*" "" contents "${contents}")
            if("${config}" STREQUAL "DEBUG")
                # prefix points at the debug subfolder
                string(REPLACE [[${prefix}/debug]] [[${prefix}]] contents "${contents}")
                string(REPLACE [[${prefix}/include]] [[${prefix}/../include]] contents "${contents}")
                string(REPLACE [[${prefix}/share]] [[${prefix}/../share]] contents "${contents}")
            endif()
```

이런 내용이라면 prefix는 `installed/${triplet}` 폴더가 될 것이라 예상할 수 있습니다.
Vcpkg 폴더를 다른 곳으로 옮기더라도 .pc 파일들을 수정해줄 필요가 없는 것이죠.

### 4. Packaging

#### Port validation

그 다음은 `vcpkg` 프로그램이 수행하는 Port validation을 통과할 수 있도록 License 파일을 복사해두고, 불필요한(또는 비어있는) 폴더를 삭제합니다.
대부분의 경우 debug 폴더의 헤더 파일들과, share 폴더를 제거하는 것으로 충분합니다.
Fixup 과정에서 관련 파일들은 Release 빌드의 share 폴더(`"${CURRENT_PACKAGES_DIR}/share"`)로 이동했거나, 애초부터 존재하지 않았을테니까요.

```cmake
file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
)
```

이런 대략적인 작성을 마치고 추가적인 수정이 필요하다면 `vcpkg` 프로그램에서 경고 메세지를 보여줄 것입니다.
보통 비어있는 폴더가 있으므로 REMOVE_RECURSE를 통해 지워야 한다거나,
라이브러리 파일들이 Triplet에서 명시한것과 다른 CRT를 사용하고 있다거나 하는 내용들입니다.
`/Wx` 또는 `-Werror`를 사용해 컴파일 경고를 없앨때처럼 하나씩 미리 지워두는게 좋습니다.

### 5. Build with [Meson](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_configure_meson.cmake)

...

### 6. Build with [Makefile](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_build_make.cmake)

...

## Vcpkg의 Triplet 작성방법

Target 환경의 아키텍처, Library / CRT 링킹, System Library의 Root, 컴파일러  옵션 등
여러 Port들을 설치할 때 일괄적으로 적용되어야 하는 것들은 Triplet에 작성합니다.
현재 Vcpkg CI에서 검사하는 Triplet들은 `triplets/` 폴더에 위치해 있으며, 
커뮤니티의 요구에 의해 추가된 Triplet들은 `triplets/community/`에 있습니다.

보통 Triplet에서는 복잡한 작업을 수행하지 않습니다. 앞서 설명한 것처럼, portfile.cmake들이 사용할 변수들을 미리 준비해주기만 하면 됩니다.
[현재 vcpkg에서는 여기서 설정한 변수들을 바탕으로 vcpkg_common_definitions.cmake에서 추가 변수들을 정의하고, portfile.cmake로 바로 전달하도록 구현하고 있습니다.](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/ports.cmake#L128-L142)

```cmake
# scripts/ports.cmake
# ...
    include("${CMAKE_TRIPLET_FILE}") # <-- 선택한 Triplet

    # ...

    set(HOST_TRIPLET "${_HOST_TRIPLET}")
    set(CURRENT_HOST_INSTALLED_DIR "${_VCPKG_INSTALLED_DIR}/${HOST_TRIPLET}" CACHE PATH "Location to install final packages for the host")

    set(TRIPLET_SYSTEM_ARCH "${VCPKG_TARGET_ARCHITECTURE}")
    include("${SCRIPTS}/cmake/vcpkg_common_definitions.cmake")  # <-- VCPKG_ 변수 추가

    include("${CURRENT_PORT_DIR}/portfile.cmake") # <-- 빌드 하려는 Port
# ...
```

이런 구조라면 다수의 Port를 관리할 때 전용 Triplet을 작성하고 싶은 마음이 들 것입니다.
가령 chef.cmake(주방장?)라는 Triplet을 만들고, 여기서 `VCPKG_` 변수 뿐만 아니라 `BEEF_`(소고기?)변수를 추가로 정의하는 것이죠.
이렇게 해두면 관리중인 Port들은 `BEEF_` 변수를 바탕으로 빌드설정을 조작할 수 있을 것입니다.

예를 들어 beef-common이라는 라이브러리를 만들어 Port를 작성했다면 아래와 같은 형태가 될 것입니다.

```cmake
# port/beef-common/portfile.cmake
if(BEEF_INSTALL_FOR_MOBILE)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
elseif(BEEF_INSTALL_FOR_DESKTOP)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY ONLY_DYNAMIC_CRT)
endif()
```

이런 식으로 설정해두면 Port와 Triplet이 서로 깊게 관여하게 됩니다.
결합을 지양하는 개발자라면 꺼림칙할수도 있겠습니다만, 이것은 충분히 유효한 방법입니다.
Vcpkg에서 확장의 여지를 남겨놓은 부분 중 하나이므로 적극적으로 활용하면서 경험을 쌓아보는것을 권합니다.

**이때 중요한 것은 Port와 Triplet의 조합을 생각하는 것입니다**.

Port들의 복잡도를 높이지 않고 싶다면 Triplet을 최대한 Vcpkg의 Triplet들과 유사하게 작성하면 됩니다.  
하나의 Port가 모든 Triplet을 지원해야 하는 것은 아닙니다.
Triplet은 빌드의 Target 환경에 대해 기술하는 것이므로, 소수의 Target 환경만 고려하면 된다면 필요한만큼의 Triplet만 지원하면 됩니다.

이 저장소에는 [Android](../triplets/arm64-android.cmake), [iOS Simulator](../triplets/arm64-ios-simulator.cmake)를 대상으로 하는 Triplet이 몇개 있습니다.
CMake 문법에 익숙하다면 아래의 내용을 읽고나서 의미를 해석해보는게 도움이 되리라 생각합니다.

### [arm64-windows](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/arm64-windows.cmake), [arm64-windows-static](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/arm64-windows-static.cmake), [arm64-windows-static-md](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/arm64-windows-static-md.cmake)

Windows Triplet들의 이름에 `-static`이 덧붙는다면, 
Library 빌드 옵션을 static으로 사용한다는 의미입니다. (반대로 `-dynamic`이 붙는 경우도 있습니다.)
CRT 역시 static으로 맞춰주고 있는데, 사실 두 설정을 맞춰줄 필요는 없습니다.

```cmake
# arm64-windows.cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
```

```cmake
# community/arm64-windows-static.cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)
```

만약 `/MD` 컴파일 옵션을 사용해야 한다면, CRT를 dynamic으로 변경해주면 됩니다.
명시적으로 이런 작업을 한 경우, Triplet 이름에 `-md`를 덧붙입니다.

```cmake
# community/arm64-windows-static-md.cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
```

### VCPKG_CMAKE_SYSTEM_NAME을 바꾸는 경우

portfile.cmake에서는 `VCPKG_TARGET_IS_*`, `VCPKG_HOST_IS_*` 변수를 사용해 세부사항을 결정하는 경우를 많이 볼 수 있습니다. 
Triplet에서 [이 변수를 어떻게 설정하느냐에 따라 관련 변수들의 값이 바뀝니다](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/cmake/vcpkg_common_definitions.cmake#L35-L57).
동시에 [Cross compile 여부를 판단](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling)할때도 사용됩니다.

일례로, [x64-freebsd.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/x64-freebsd.cmake), [x64-openbsd.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/x64-openbsd.cmake)는 VCPKG_CMAKE_SYSTEM_NAME를 각각의 이름에 맞게 설정하고 있습니다.

```cmake
# community/x64-freebsd.cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME FreeBSD)
```
```cmake
# community/x64-openbsd.cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME OpenBSD)
```

### MinGW (Minimalist GNU for Windows)

MinGW로 빌드 환경을 구축했다면 환경변수를 추가/변경해 여러 개발도구들이 선택되도록 조정한 상태일 것입니다.
Vcpkg의 Windows 빌드는 환경변수들을 그대로 사용하지 않기 때문에, 이런 조정된 값들이 빌드를 진행하는 프로세스로 전달되도록 [`VCPKG_ENV_PASSTHROUGH`](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/users/config-environment.md#vcpkg_keep_env_vars) 변수를 지정해줘야 합니다.

[x86-mingw-static.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/x86-mingw-static.cmake)에서는 PATH 환경변수를 빌드 프로세스로 넘기고 있습니다.

```cmake
# community/x86-mingw-static.cmake
set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_ENV_PASSTHROUGH PATH)

set(VCPKG_CMAKE_SYSTEM_NAME MinGW)
```

[x86-mingw-dynamic.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/x86-mingw-dynamic.cmake)도 같습니다.

```cmake
# community/x86-mingw-dynamic.cmake
set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_ENV_PASSTHROUGH PATH)

set(VCPKG_CMAKE_SYSTEM_NAME MinGW)
set(VCPKG_POLICY_DLLS_WITHOUT_LIBS enabled)
```

이 CMake 변수는 List 변수이므로 아래와 같이 [`list`](https://cmake.org/cmake/help/latest/command/list.html#modification)를 사용하는 것도 괜찮은 방법입니다.

```cmake
list(APPEND VCPKG_ENV_PASSTHROUGH PATH VULKAN_SDK CUDA_HOME CUDA_PATH)
message(STATUS "Passing Env: ${VCPKG_ENV_PASSTHROUGH})
```

### Apple Targets

Apple 플랫폼을 Target으로 빌드할 때는 보통 `VCPKG_CMAKE_SYSTEM_VERSION`(`CMAKE_SYSTEM_VERSION`), `VCPKG_OSX_SYSROOT`([`CMAKE_OSX_SYSROOT`](https://cmake.org/cmake/help/latest/variable/CMAKE_OSX_SYSROOT.html)), `VCPKG_OSX_ARCHITECTURES`([`CMAKE_OSX_ARCHITECTURES`](https://cmake.org/cmake/help/latest/variable/CMAKE_OSX_ARCHITECTURES.html)) 변수를 설정하게 됩니다.
각각 SDK의 버전, SDK의 위치, 적용할 Architecture를 의미합니다.
실제로 각 변수들이 어떻게 사용되는지는 여러 CMake 스크립트 파일들을 함께 확인해야 알 수 있습니다.
쉬운 부분부터 살펴보겠습니다.

[Apple M1](https://en.wikipedia.org/wiki/Apple_M1) 장비들은 [64bit ARM](https://en.wikipedia.org/wiki/AArch64#ARMv8.4-A)를 사용하므로, `VCPKG_OSX_ARCHITECTURES` 값은 arm64가 됩니다.
이를 위한 Triplet은 [arm64-osx](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/arm64-osx.cmake)입니다. 여기서는 `VCPKG_CMAKE_SYSTEM_NAME`를 함께 설정해주고 있습니다.

```cmake
# community/arm64-osx.cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)
```

> 
> `VCPKG_OSX_ARCHITECTURES`라는 이름에서 볼 수 있는 것처럼, 여러 Arch를 동시에 빌드하도록 만들 수 있습니다.
> 관심이 있다면 [관련 PR](https://github.com/microsoft/vcpkg/pull/18156)도 함께 보면 좋을 것 같습니다.
>

같은 아키텍처에 iOS를 Target으로 빌드할때는 어떨까요? [arm64-ios](https://github.com/microsoft/vcpkg/blob/2021.12.01/triplets/community/arm64-ios.cmake)를 보면 `VCPKG_CMAKE_SYSTEM_NAME`만 다르고 `VCPKG_OSX_ARCHITECTURES`는 설정하지 않고 있습니다.
이것은 기본 Chainload Toolchain 파일인 [scripts/toolchains/ios.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/toolchains/ios.cmake)에서 `VCPKG_TARGET_ARCHITECTURE`를 사용해 [`VCPKG_OSX_ARCHITECTURES`를 추정하도록 구현](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/toolchains/ios.cmake#L7-L32)하고 있기 때문입니다.

반대로 [scripts/toolchains/osx.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/toolchains/osx.cmake)에서는 Host 시스템과 관련된 최소한의 내용만 설정하고 있기 때문에 Triplet 파일을 가급적 자세하게 작성해야 할수도 있습니다.

```cmake
# community/arm64-ios.cmake
set(VCPKG_TARGET_ARCHITECTURE arm64) # --> set(_vcpkg_ios_target_architecture "arm64")
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS) # --> scripts/toolchains/ios.cmake
```

여기서 만약 iPhone SDK 버전을 12.0으로 설정하고 싶다면 `VCPKG_CMAKE_SYSTEM_VERSION`를 추가하면 됩니다. 다만 이 값이 제대로 적용되지 않는다면, Port에서 사용하고 있는 빌드시스템 파일로 CMAKE_SYSTEM_VERSION이 전달되지 않거나, 덮어쓰고 있을수도 있습니다.
이런 경우는 `VCPKG_CXX_FLAGS`를 변경해 [`CMAKE_CXX_FLAGS`에서 컴파일 옵션으로 SDK 버전을 적용하도록 해야 합니다.](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-ios-tvos-or-watchos)


```cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME iOS)
set(VCPKG_CMAKE_SYSTEM_VERSION 12.0) # 또는 VCPKG_C_FLAGS, VCPKG_CXX_FLAGS
```

보통은 이정도에서 간단하게 해결할 수 있는데, 만약 iPhone SDK가 아니라 iPhoneSimulator SDK를 사용해야 하는 상황이라면 sysroot 관련 컴파일 옵션이 바뀌어야 합니다.
이 때는 `VCPKG_OSX_SYSROOT`를 사용합니다.
[CMake 에서 설명하는 것처럼, 이 변수에 사용할 경로는 `xcodebuild -showsdks` 명령으로 확인할 수 있습니다](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-ios-tvos-or-watchos).

아래는 CMake의 [`execute_process` 명령](https://cmake.org/cmake/help/latest/command/execute_process.html)을 사용해 xcodebuild 프로그램을 실행하고, CLI 출력을 `VCPKG_OSX_SYSROOT`에 저장한 것입니다.
가장 마지막에 사용한 인자 Path를 지우면 어떻게 바뀌는지 확인해보면 다른 좋은 사용방법을 떠올릴 수 있을 것입니다.

```cmake
find_program(XCODEBUILD_EXE xcodebuild REQUIRED)
execute_process(
    COMMAND ${XCODEBUILD_EXE} -version -sdk iphonesimulator Path
    OUTPUT_VARIABLE VCPKG_OSX_SYSROOT
    ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "Detected SDK: ${VCPKG_OSX_SYSROOT}")
```

## Vcpkg Chainload

`VCPKG_CHAINLOAD_TOOLCHAIN_FILE`은 Vcpkg로 CMake 프로젝트를 빌드할 때 그 확장성을 극대화할 수 있는 변수 중 하나입니다.
이미 android.toolchain.cmake와 같이 이미 작성된 CMake 스크립트들을 사용할 때 필요한 기능입니다.
하지만 이 변수를 언제나 설정해야 하는 것은 아닙니다.
Vcpkg는 지원하는 Target 플랫폼들을 위해 기본적인 CMake 스크립트들을 내장하고 있습니다. 이들은 Port vcpkg-cmake에 있는 `vcpkg_cmake_configure` 함수를 통해, buildtrees/ 폴더에서 빌드시스템 파일을 생성할 때 사용됩니다.

전체 목록은 [vcpkg_cmake_configure.cmake](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/vcpkg-cmake/vcpkg_cmake_configure.cmake#L280-L303)에서 확인할 수 있습니다.

```cmake
    if(NOT DEFINED VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
        if(NOT DEFINED VCPKG_CMAKE_SYSTEM_NAME OR _TARGETTING_UWP)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/windows.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Linux")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/linux.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Android")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/android.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Darwin")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/osx.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "iOS")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/ios.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/freebsd.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/openbsd.cmake")
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "MinGW")
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/mingw.cmake")
        endif()
    endif()
```

vcpkg_cmake_configure 함수는 portfile.cmake에서 사용하기 때문에, `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` 변수의 값을 변경하려면 Triplet 혹은 portfile.cmake 내에서 `set`해야 합니다.

### iOS Toolchain

[leetal/ios-cmake](https://github.com/leetal/ios-cmake)는 제가 2018년 이후 Apple 플랫폼 빌드와 관련해 해결책을 찾아야 할때 우선적으로 참고하는 프로젝트입니다.
많은 경우 이 프로젝트에서 지원하는 ios.toolchain.cmake를 사용하는 것으로 번거로운 작업을 간소화할 수 있습니다.

... (추가 필요함) ...


### Android

... (추가 필요함) ...

#### 1. Android Gradle Plugin + CMake

#### 2. android.toolchain.cmake

#### 3. VCPKG_TARGET_TRIPLET


## Vcpkg Feature 사용하기

앞서까지는 Vcpkg에서 지원하는 패키지들을 설치하기 위한 내용이었습니다.

[docs/specification/](https://github.com/microsoft/vcpkg/tree/2021.12.01/docs/specifications) 폴더에 Vcpkg에서 지원하는 추가 기능들에 대해서 몇개의 문서들이 들어있습니다.

... (추가 필요함) ...

### 1. Manifest

### 2. Binary Caching

### 3. Overlay

#### Port

#### Triplet

### 4. Registry
