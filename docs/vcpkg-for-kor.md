# Vcpkg로 배우는 의존성 관리(WIP)

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

Vcpkg에서는 여러 Script들 사용하고 있지만, 대부분 [CMake Script](https://cmake.org/cmake/help/latest/manual/cmake.1.html)입니다.
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

이전에는 `vcpkg`의 소스 파일들을 `toolsrc`에 내장하고 있었습니다만, 2021년 중반 이후 실행프로그램을 다운로드해서 사용할 수 있도록 구조가 바뀌었습니다.
(구체적인 시기는 Host 플랫폼마다 다릅니다.)

```console
user@host:vcpkg$ ./bootstrap-vcpkg.sh
Downloading vcpkg-macos...
...
user@host:vcpkg$ lipo -archs vcpkg  # available architectures?
x86_64 arm64
```

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
[Registry](https://github.com/microsoft/vcpkg/blob/2021.12.01/docs/maintainers/registries.md)는 말하자면 `ports`, `triplets`, `versions` 3개 폴더의 집합을 의미합니다.
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

[CMake에서 상정(想定)하고 있는 User Flow](https://cmake.org/cmake/help/latest/guide/user-interaction/index.html)가 있는 것처럼,
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

[`ports/libzip/vcpkg.json`](https://github.com/microsoft/vcpkg/blob/2021.12.01/ports/libzip/vcpkg.json)을 열어 내용을 확인해보길 권합니다.

#### 패키지가 설치 가능한지 확인하는 방법

2021년이 지난 현재, 패키지가 설치 가능한지 확인하는 방법은 `ports/${name}/vcpkg.json`에서 `supports` 가 있는지 확인하는 것입니다.
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
몇달 전까지만 해도 vcpkg-tool 에서는 이 값을 검사하지 않았으나, 이제는 `vcpkg install`

간접적인 방법으로 [scripts/ci.baseline.txt](https://github.com/microsoft/vcpkg/blob/2021.12.01/scripts/ci.baseline.txt)를 확인하는 것도 도움이 될 수 있습니다.
Vcpkg 프로젝트는 master 브랜치, PR들의 commit에 [CI를 적용하고 있습니다](https://dev.azure.com/vcpkg/public/_build?definitionId=29&_a=summary).
`"supports"`가 구현되기 전에 CI에서 제외(skip)하거나, 예상되는 실패(fail)를 기록해둔 파일이 바로 이것입니다.


#### 설치 후 파일 배치

임의의 패키지를 설치한 후에는 3개의 폴더가 만들어집니다.

```
.
├── ...
├── buildtrees
├── installed
├── packages
└── ...
```

> TBA

## Host/Target 환경

> TBA

### detect_compiler

### Triplets 이해하기

#### Community Triplet

#### 직접 작성하는 방법

## Import from Vcpkg

* https://cmake.org/cmake/help/latest/guide/using-dependencies/index.html
* https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html

> TBA
