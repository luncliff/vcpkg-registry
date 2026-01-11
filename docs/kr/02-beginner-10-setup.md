# Vcpkg 설치 및 설정

::: info 튜토리얼 진행 상황
**Beginner 트랙 · 2 / 6 단계**

1. [Vcpkg 소개](./01-beginner-00-intro)
2. **Vcpkg 설치 및 설정** ⬅️
3. 첫 패키지 설치
4. Triplet 기초
5. CMake 프로젝트 연동
6. Manifest 모드 입문
:::

## 시작하기 전에

### 공식 문서 참고

한국어로 번역된 [README_ko_KR.md](https://github.com/microsoft/vcpkg/blob/2021.12.01/README_ko_KR.md)를 먼저 읽고 오시면 좋을 것 같습니다.

## Vcpkg 폴더 준비하기

### Git Clone으로 설치

```console
$ git clone https://github.com/microsoft/vcpkg
remote: Enumerating objects: ...
```

### Zip 다운로드로 설치

Vcpkg의 Git History가 필요하지 않다면 그냥 zip 파일만 다운로드 할수도 있습니다.
Docker 이미지를 만든다면 이런 방법이 더 자주 필요하겠죠?

#### PowerShell

```ps1
# https://github.com/microsoft/vcpkg/archive/refs/heads/master.zip for latest
Invoke-WebRequest -Uri "https://github.com/microsoft/vcpkg/archive/refs/tags/2021.12.01.zip" -OutFile "vcpkg.zip"
Expand-Archive "vcpkg.zip"
```

#### Bash

```bash
wget "https://github.com/microsoft/vcpkg/archive/refs/tags/2021.12.01.zip" -O "vcpkg.zip"
unzip -q -o "vcpkg.zip" -d .
mv "vcpkg-2021.12.01" "vcpkg"
```

### CI 환경에서의 Vcpkg

[GitHub Actions, Azure Pipelines](https://github.com/actions/virtual-environments), [AppVeyor](https://www.appveyor.com/docs/windows-images-software/)를 비롯해 여러 CI 서비스들에서는 이미 호스팅하고 있는 빌드 환경에 Vcpkg 폴더를 별도로 준비해두고 있습니다.

* [Windows](https://github.com/actions/virtual-environments/tree/main/images/win) - `C:/vcpkg`
* [Linux](https://github.com/actions/virtual-environments/tree/main/images/linux) - `/usr/local/share/vcpkg`
* [Mac](https://github.com/actions/virtual-environments/tree/main/images/macos) - `/usr/local/share/vcpkg`

## Vcpkg 폴더 구조 이해하기

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

### Document 폴더

### Script 폴더

### Metadata 폴더

## Bootstrap 실행하기

### Windows에서

### Linux/Mac에서

### 버전 확인

## 환경 변수 설정

### VCPKG_ROOT

### PATH 추가

## 다음 단계

이제 첫 번째 패키지를 설치해보겠습니다.  
👉 [다음: 첫 패키지 설치](./03-beginner-20-first-package)
