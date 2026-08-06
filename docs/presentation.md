---
marp: true
paginate: true
---

<!-- _paginate: false -->

# C++ 패키지 매니저 생태계 운영하기

개인 실험을 넘어서 개발 조직의 도구로 (2021-2025)


박동하, C++ Korea User Group, LINE+ S/W Engineer
luncliff@gmail.com

<!--
발표자 노트
등록된 정식 발표 제목. 다음 슬라이드에서 제목을 풀어서 설명한다.
연락처: luncliff@gmail.com, luncliff@cppkorea.org, dong-ha-park@linecorp.com
전체 흐름은 Why(왜), What(무엇을), How(어떻게)의 내러티브.
vcpkg registry로 C++ 의존성을 직접 제어해온 5년의 기록임을 예고한다.
-->

---

# 목차

- 도입부
- C++ 의존성 구조의 근본적 난제
- vcpkg 패키지 매니저
- 패키지 관리 전략 고민
- 패키지 생태계 운영
- 마무리

<!--
발표자 노트
6개 섹션의 흐름을 미리 보여준다. Why(도입부, 난제) -> What/How(vcpkg, 전략) -> 실천(운영) -> 정리(마무리).
-->

---

# 도입부

<div style="height:6px;width:120px;background:#2b6cb0;margin-top:22px;"></div>

<p style="font-size:26px;color:#5f6368;margin-top:18px;">왜(Why), 무엇을(What), 어떻게(How)의 순서로 여는 이야기</p>

<!--
발표자 노트
섹션 전환. Why, What, How의 내러티브로 연다.
-->

---

# 생태계? Ecosystem?

설명 없이 쓰면 오해를 부르는 단어. 범위를 3단계로 좁혀보면

<div style="border:3px solid #2b6cb0;border-radius:14px;padding:16px 22px;margin-top:20px;">
  <div style="font-size:27px;font-weight:600;color:#2b6cb0;">① 소프트웨어 생태계</div>
  <div style="margin-top:4px;">
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">핵심 플랫폼, 인프라</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">개발 도구, 기술 스택</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">참여자, 지식 기반</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">마켓플레이스, 확장 채널</span>
  </div>
  <div style="margin-top:18px;border:3px dashed #d9dce1;border-radius:12px;padding:16px 20px;font-size:24px;color:#c4c9ce;">② 패키지 생태계 → ③ vcpkg</div>
</div>

<!--
발표자 노트
소프트웨어 생태계라는 말은 정의 없이 쓰면 오해를 부른다. 3장에 걸쳐 범위를 좁힌다.
1단계: 소프트웨어 생태계 = 플랫폼/인프라, 도구/기술 스택, 참여자/지식, 마켓플레이스/확장 채널.
-->

---

# 생태계? Ecosystem?

소프트웨어 생태계의 부분집합: 패키지와 공급망(supply chain)

<div style="border:3px solid #d9dce1;border-radius:14px;padding:14px 22px;margin-top:20px;">
  <div style="font-size:24px;font-weight:600;color:#9aa0a6;">① 소프트웨어 생태계</div>
  <div style="margin-top:12px;border:3px solid #2b6cb0;border-radius:12px;padding:14px 20px;">
    <div style="font-size:27px;font-weight:600;color:#2b6cb0;">② 패키지 생태계</div>
    <div style="margin-top:4px;">
      <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">중앙 패키지 저장소</span>
      <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">패키지 관리자</span>
      <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">의존성 명세(manifest)</span>
      <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">재사용 모듈, 라이브러리</span>
      <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 15px;margin:8px 8px 0 0;font-size:23px;background:#fff;">보안, 감사 도구</span>
    </div>
    <div style="margin-top:16px;border:3px dashed #d9dce1;border-radius:10px;padding:12px 18px;font-size:24px;color:#c4c9ce;">③ vcpkg</div>
  </div>
</div>

<!--
발표자 노트
2단계: 패키지 생태계 = 중앙 저장소, 패키지 관리자, 의존성 명세, 재사용 모듈/라이브러리, 보안/감사 도구.
공급망(supply chain) 개념이 여기에 걸쳐 있다.
-->

---

# 이 발표의 범위

C++ 영역에서, vcpkg로 패키지들을 운영하는 이야기

<div style="border:3px solid #d9dce1;border-radius:14px;padding:12px 22px;margin-top:20px;">
  <div style="font-size:24px;font-weight:600;color:#9aa0a6;">① 소프트웨어 생태계</div>
  <div style="margin-top:10px;border:3px solid #d9dce1;border-radius:12px;padding:12px 20px;">
    <div style="font-size:24px;font-weight:600;color:#9aa0a6;">② 패키지 생태계</div>
    <div style="margin-top:10px;border:3px solid #2b6cb0;background:rgba(43,108,176,.05);border-radius:10px;padding:14px 18px;">
      <div style="font-size:27px;font-weight:600;color:#2b6cb0;">③ vcpkg: C++ 패키지 운영</div>
      <div style="margin-top:4px;">
        <span style="display:inline-block;border:2px solid #2b6cb0;border-radius:8px;padding:6px 16px;margin:8px 8px 0 0;font-size:23px;background:#fff;font-family:Consolas,monospace;">port</span>
        <span style="display:inline-block;border:2px solid #2b6cb0;border-radius:8px;padding:6px 16px;margin:8px 8px 0 0;font-size:23px;background:#fff;font-family:Consolas,monospace;">triplet</span>
        <span style="display:inline-block;border:2px solid #2b6cb0;border-radius:8px;padding:6px 16px;margin:8px 8px 0 0;font-size:23px;background:#fff;font-family:Consolas,monospace;">registry</span>
        <span style="display:inline-block;border:2px solid #2b6cb0;border-radius:8px;padding:6px 16px;margin:8px 8px 0 0;font-size:23px;background:#fff;font-family:Consolas,monospace;">baseline</span>
      </div>
    </div>
  </div>
</div>

<!--
발표자 노트
3단계: 이 발표는 vcpkg의 port, triplet, registry, baseline으로 C++ 패키지들을 운영한 이야기.
큰 그림(생태계) 안에서 오늘 다룰 좌표를 찍고 시작한다.
-->

---

# 의문 (Why)

```PowerShell
winget install --id Microsoft.VisualStudioCode
```
```zsh
brew install opencv python@3.12
```

왜 **우리 팀 산출물**은 이렇게 못 쓰지?

<!--
발표자 노트
개발자는 WinGet, APT, Homebrew를 다 쓴다. 그런데 우리 팀 라이브러리와 프레임워크는 왜 같은 방식으로 못 쓰나.
"우리가 만든 것을 더 쉽게 쓸 수 있어야 하지 않나"라는 개인적 의문이 출발점.
-->

AAR(Android Archive) 배포를 제외하면,
패키지로 소비 가능한 형태가 **전혀 아니었던** 당시 상황.

<!--
발표자 노트
팀내 산출물은 대부분 패키지 매니저로 소비할 수 없는 상태였다. AAR 외에는 표준적 배포 경로가 빈약.
-->

---

# 문제 분석: 넓은 스펙트럼 1

오래된 프로그래밍 언어, C++

- C++17 43%, C++20 34%, C++23 21%로 혼재.
- 컴파일러마다 다른 명령, 명세, 오류 메시지
- 분야가 다양한 만큼, 관리 방법도 사례마다 다름

<!-- _footer: '출처: JetBrains The State of C++ 2025' -->

---

# 문제 분석: 넓은 스펙트럼 2

다른 프로그래밍 언어와 함께 사용하는 경우 증가
- C++ 개발자의 절반가량이 Python을 함께 쓴다(2025년 51%). C, Shell, JavaScript, Java, SQL 등 스펙트럼이 넓다.

<!-- _footer: '출처: JetBrains The State of C++ 2025' -->

---

# 문제 분석: 지식 편차

프로그래밍 실력과 별개로 **빌드 관리** 지식은 편차가 크다...

- 환경이 다르면 경험이 호환되지 않음 (Linux → Windows)
- 각자 경험한 의존성/배포 관리 방식이 상이 (Mental Model 불일치)

<!--
발표자 노트
언어 지식과 빌드/의존성 관리 지식은 별개다. OS가 바뀌면 경험이 이전되지 않는 경우가 많다.
사람마다 의존성 관리와 배포 구성의 멘탈 모델이 다르다.
-->

---

# 문제 분석: 낮은 패키지 매니저 사용률

- 패키지 부족 → 직접 빌드해서 결과물만 사용.
- 소스 코드를 내장(Embed), 산출물 수기 관리
- 방치되는 빌드 스크립트

<div style="font-size:26px;color:#5f6368;background:#fff;border-left:7px solid #2b6cb0;padding:14px 20px;margin-top:22px;">전용 도구(vcpkg 11%, Conan 6%)보다 소스 내장 35%, 직접 빌드 24%가 앞선다.</div>

<!--
발표자 노트
패키지 매니저 사용률이 낮으면 직접 빌드, 산출물 수기 관리, source of truth를 잃은 스크립트로 이어진다.
뒤의 설문 차트에서 데이터로 보여준다.
-->

---

# 목표 (What)

- 개발조직의 역량(organization's ability)에 대한 비전
- 일관적이고, 확장 가능하고, 제어 가능한 개발체계(system)에 대한 열망

<!--
발표자 노트
개인이 아니라 조직 단위 역량이 목표. 일관성, 확장성, 제어가능성을 갖춘 체계를 지향.
-->

---

# 방법 (How)

C++ Blog: [How to start using registries with vcpkg](https://devblogs.microsoft.com/cppblog/how-to-start-using-registries-with-vcpkg/) (2021. 03. 24)

기능 분석 후 판단

- 누적된 vcpkg 사용 경험 → maintainer 다수와 견줄 수 있다는 계산
- 새 registry 기능 → 이후 사용 경험도 크게 개선될 것으로 예상

어차피 Dependency Graph 정리도, CMake 도입도 해야 한다.

**바로 vcpkg 지원부터 시작하자.**

<!-- _footer: '출처: How to start using registries with vcpkg, devblogs.microsoft.com/cppblog' -->

<!--
발표자 노트
2021년 vcpkg registry 기능 공개가 계기. 위 블록은 블로그 overview의 축약 요약이며, 청중이 기능의 감을 잡는 것이 목적.
당시 누적 경험과 역량이면 다수 maintainer와 견줄 수 있다고 판단, 새 기능이 사용 경험을 크게 개선할 것으로 예상.
참고 https://devblogs.microsoft.com/cppblog/how-to-start-using-registries-with-vcpkg/
-->

---

# C++ 의존성 구조의 근본적 난제

<div style="height:6px;width:120px;background:#2b6cb0;margin-top:22px;"></div>

<p style="font-size:26px;color:#5f6368;margin-top:18px;">표준 ABI가 없는 언어에서 되풀이되는 오류의 뿌리</p>

<!--
발표자 노트
섹션 전환. 실제 사용자들이 겪는 오류를 근거로 C++ 특유의 난제를 짚는다.
전처리기 -> 링커 -> 툴체인 -> 패키징 순서로 표면을 훑는다.
-->

---

# 근본 원인: 표준 ABI 부재

- C++ 표준은 ABI를 정의하지 않음. 플랫폼, 컴파일러마다 제각각
  (C는 플랫폼별로 사실상 표준 ABI 존재)
- 빌드 구성 = 인터페이스의 일부
  (매크로, 표준, CRT, 컴파일러, 링키지)
- 암묵적 계약이 어긋나면 오류가 발생하는 취약한 구조

<!--
발표자 노트
이번 섹션의 관통 메시지. 헤더는 타입과 매크로를, 링커는 심볼과 링키지를, 툴체인은 ABI를 각각의 생산자/소비자 경계에서 암묵적으로 합의해야 한다.
vcpkg의 triplet, baseline, binary cache ABI 해시는 이 암묵 계약을 명시화하려는 시도.
-->

---

# 전처리기에서 C++ Modules로

<div style="display:flex;gap:28px;margin-top:20px;">
<div style="flex:1;min-width:0;">
<div style="font-size:24px;color:#5f6368;font-weight:600;margin-bottom:8px;">Pre-processor</div>
<pre style="font-size:26px;background:#f3f4f6;border-radius:10px;padding:18px 22px;line-height:1.5;margin:0;"><code>// math.hpp
#pragma once
#include &lt;vector&gt;
// main.cpp
#include "math.hpp"</code></pre>
</div>
<div style="flex:1;min-width:0;">
<div style="font-size:24px;color:#5f6368;font-weight:600;margin-bottom:8px;">C++23 Modules</div>
<pre style="font-size:26px;background:#f3f4f6;border-radius:10px;padding:18px 22px;line-height:1.5;margin:0;"><code>// math.cppm
export module math;
import std;
export int add(int, int);
// main.cpp
import math;</code></pre>
</div>
</div>

<p style="font-size:22px;color:#5f6368;margin-top:14px;"><code>#include</code> = 텍스트 복제 + 매크로 치환 &nbsp;/&nbsp; <code>import</code> = 바이너리 (복제 비용 소거)</p>

<!--
발표자 노트
#include는 헤더 내용을 그대로 복사하고 #define을 치환한다. Modules는 컴파일러가 해석 가능한 바이너리로 관리.
대부분의 배포는 여전히 전처리기 모델 위에 있다.
-->

---

# Pre-processor 구조의 취약성

소스코드를 복사-붙여넣기로 확장 → 오류 분석 범위도 함께 확대

배포한 소스코드가 올바르게 쓰이려면, 생산자와 소비자가

- 같은 `#define` 집합을 사용해야 하고
- include 순서가 어긋나지 않아야 하고
- Compiler Toolchain (MSVC, Clang, GCC)까지 공유해야 한다

<div style="font-size:26px;color:#5f6368;background:#fff;border-left:7px solid #2b6cb0;padding:14px 20px;margin-top:22px;">계약 조건이 코드에 명시되지 않는다. 하나라도 어긋나면 컴파일 오류, 또는 더 나쁘게는 숨은 불일치.</div>

<!--
발표자 노트
#include는 텍스트 복제이므로 오류가 나면 복제된 전체 범위가 분석 대상이 된다.
생산자/소비자가 지켜야 하는 조건(#define 집합, include 순서, toolchain)은 코드 어디에도 적혀 있지 않다.
다음 슬라이드의 실제 사례들로 이어진다.
-->

---

# Preprocessor 단계 오류

- `windows.h` min/max 매크로 → `std::max` 깨짐 (NOMINMAX)
- 같은 헤더 다른 버전 → 타입 정체성 불일치
- `UNICODE` 불일치 → `TCHAR` 갈림

<!-- _footer: '출처: StackOverflow (windows.h min/max 5004858, C++ FAQ 12573816 등)' -->

<!--
발표자 노트
windows.h min/max 매크로 오염(SO 5004858), 해법 NOMINMAX. 누가 먼저 include하는지가 경계마다 다르다.
include 경로 차이로 같은 타입이 다르게 mangling되어 undefined reference.
UNICODE/_UNICODE 불일치로 TCHAR가 한쪽 char, 다른 쪽 wchar_t. 매크로가 공개 API의 타입을 바꾼다.
-->

---

# 숨어 있다 나타나는 불일치

symbol은 분명히 존재하는데, undefined symbol 오류?

```c
// mylib_api.h: dllexport/dllimport 매크로 트릭
#if defined(BUILDING_MYLIB)
#  define MYLIB_API __declspec(dllexport)   // 생산자: 내보내기
#else
#  define MYLIB_API __declspec(dllimport)   // 소비자: 가져오기
#endif
```

- 생산자가 `BUILDING_MYLIB` 정의를 빠뜨리면 → export 누락
- symbol visibility 옵션(`-fvisibility=hidden`) → 존재하지만 보이지 않는 symbol

<!--
발표자 노트
컴파일 단계의 매크로 불일치가 숨어 있다가 링크 단계에서야 나타나는 대표 사례.
nm/dumpbin으로 보면 symbol은 분명히 있는데 링커는 못 찾는다. export 테이블에 없거나 hidden이기 때문.
dllexport/dllimport 트릭은 매크로 하나로 생산자와 소비자의 역할이 갈리는 구조라는 점을 강조.
-->

---

# 프로그램 만들기 = 천공테이프 잇기

object와 library 조각들을 하나의 타래로 엮는 작업 (Linkage)

<div style="margin-top:26px;font-size:23px;">
  <div style="display:flex;align-items:center;gap:12px;">
    <span style="width:100px;color:#5f6368;font-weight:600;flex:none;">static</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:8px 14px;background:#f3f4f6;font-family:Consolas,monospace;">main.o</span>
    <span style="color:#5f6368;">+</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:8px 14px;background:#f3f4f6;font-family:Consolas,monospace;">math.o</span>
    <span style="color:#5f6368;">+</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:8px 14px;background:#f3f4f6;font-family:Consolas,monospace;">libfmt.a</span>
    <span style="color:#5f6368;">→</span>
    <span style="display:inline-block;border:2px solid #2b6cb0;border-radius:8px;padding:8px 14px;background:rgba(43,108,176,.06);font-family:Consolas,monospace;">app.exe</span>
    <span style="color:#5f6368;">복사해 이어붙임, symbol 전부 내장</span>
  </div>
  <div style="display:flex;align-items:center;gap:12px;margin-top:24px;">
    <span style="width:100px;color:#5f6368;font-weight:600;flex:none;">shared</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:8px 14px;background:#f3f4f6;font-family:Consolas,monospace;">main.o</span>
    <span style="color:#5f6368;">+</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:8px 14px;background:#f3f4f6;font-family:Consolas,monospace;">math.o</span>
    <span style="color:#5f6368;">→</span>
    <span style="display:inline-block;border:2px solid #2b6cb0;border-radius:8px;padding:8px 14px;background:rgba(43,108,176,.06);font-family:Consolas,monospace;">app.exe</span>
    <span style="color:#5f6368;">⇢ 실행 시 참조</span>
    <span style="display:inline-block;border:2px dashed #2b6cb0;border-radius:8px;padding:8px 14px;background:#fff;font-family:Consolas,monospace;">fmt.dll</span>
  </div>
</div>

- shared 다수 사이에서 symbol이 **중복**
- static을 모두 모았는데 **missing symbol**

<!--
발표자 노트
프로그램 binary를 만드는 것은 고전적인 천공테이프 타래를 만드는 것과 유사하다.
static은 구멍(symbol)을 모두 복사해 한 타래로, shared는 실행 시점에 다른 타래를 참조.
이 구조 때문에 소프트웨어 분할과 조직화 상태를 면밀하게 관리해야 한다.
다음 슬라이드의 실제 linker 오류들로 이어진다.
-->

---

# Linker 단계 오류

- `LNK2019` / undefined reference: 정의 누락
- `LNK2005` / multiple definition: 헤더에 정의
- GNU ld 링크 순서 의존
- `extern "C"`, `__declspec` 오설정

<!-- _footer: '출처: StackOverflow C++ FAQ 12573816, 8171102 등' -->

그동안 만든 패키지를 조합해서 만드는 체계적 과정의 산출물로 개선

핵심 패키지마다 도입, 학습, 검증 기간이 예측 가능
품질 관리는 결국 비용(위험) 관리가 아닌가?

층위(Layer)
규모(Scale)
단계(Phase)

문제가 생겼을 때, 개인이 해결하는 방식은 재사용할 수 없다. 같은 오류를 개발조직 마다 되풀이한다.

<!--
발표자 노트
unresolved external / undefined reference는 C++ FAQ 정본(SO 12573816, 조회 100만+).
LNK2005 multiple definition은 헤더에 non-inline 정의를 둔 경우. include 가드는 TU 내부만 막는다.
GNU ld는 왼->오 1패스라 라이브러리가 참조 오브젝트보다 뒤에 와야 한다. extern "C" 맹글링, dllimport __imp_ 미해결.
-->

---

# Toolchain ABI 불일치

- `LNK2038` RuntimeLibrary: `/MT` vs `/MD`
- `_ITERATOR_DEBUG_LEVEL`: Debug vs Release
- GCC 이중 ABI `_GLIBCXX_USE_CXX11_ABI`
- `filesystem` vs `experimental::filesystem`

<!-- _footer: '출처: StackOverflow 28887001, 7668200, C++ FAQ 12573816 등' -->

<!--
발표자 노트
RuntimeLibrary MT vs MD(SO 28887001, protobuf 66089423). _ITERATOR_DEBUG_LEVEL 0 vs 2(SO 7668200).
GCC 5.1+ 이중 ABI로 std::__cxx11 심볼이 갈림. filesystem vs experimental::filesystem.
서로 다른 컴파일러 산출물 혼용은 표준 ABI가 없어 근본적으로 불가.
-->

---

# 패키징 단계 오류 (vcpkg)

- triplet CRT 링키지 불일치 → `LNK2038`
- 서로 다른 triplet 혼용
- 버전 스킴 충돌 (incomparable schemes)

<!-- _footer: '출처: microsoft/vcpkg discussion 41344, issue 45138, 버전 관리 문서' -->

<!--
발표자 노트
x64-windows-static(/MT)과 앱 기본(/MD) 충돌로 LNK2038(discussion 41344). 정적/동적 triplet 혼재(SO 60266710).
버전 스킴 충돌(relaxed vs string)은 overrides로 해결. triplet/baseline/binary cache ABI 해시가 계약을 명시화.
참고 https://learn.microsoft.com/en-us/vcpkg/users/versioning-troubleshooting
-->

---

# 현상: 재사용 단위 왜곡

간단한 문제 같지만, 점차 제각기 다른 스타일이 누적되며 복잡한 문제로 발전.

- 링크엔 `.lib` / `.a` 면 충분
- 그러나 소스 위해 `.h` 동봉

<!-- _footer: '출처: JetBrains The State of C++ (2021~2025)' -->

<!--
발표자 노트
배포 단위가 binary가 아니라 소스(text interface)를 요구하게 된다. 설문의 라이브러리 관리 분포가 이를 뒷받침.
header-only는 전처리 결과가 비대해져 컴파일 시간 폭증. 의존성이 소스와 결합해 그래프 후반에서 심볼 충돌.
-->

---

# 현상: header-only 쏠림

compile, link 단계를 포기하고, 소스 전파에 집중한 형태

- 전처리 결과 비대화 → 컴파일 시간 증가
- 의존성 구조가 소스코드와 결합
- 같거나 '조금' 다른 복사본이 Translation Unit마다 내장
- Dependency Graph 후반에서야 symbol 중복 발견

<!--
발표자 노트
header-only는 배포가 쉽다는 장점 때문에 비중이 늘어나지만, 대가가 있다.
전처리 결과가 비대해져 컴파일 시간이 폭증하고, 의존성이 소스와 결합한다.
서로 다른 TU에 '조금' 다른 복사본이 내장되면, 그래프 후반에 가서야 symbol 중복이 터진다.
설문에 header-only 문항은 없지만, 헤더 include 최적화 지표(2022년 42%, 2023년 39%)가 간접 근거.
-->

---

# 현상: 빌드 설정 복잡도

- 옵션 복잡도가 의존성 복잡도에 비례
- define, include, library 경로 누적
- 결국 source embedding

<!--
발표자 노트
매크로/컴파일러/링커 옵션 조합이 의존성 복잡도와 함께 곱연산으로 늘어난다. 이상적으로는 두 복잡도의 상관이 낮아야 한다.
설문에 header-only 문항은 없어, 헤더 include 최적화 지표(2022년 42%, 2023년 39%)를 근사 근거로 쓸 수 있다.
-->

---

# vcpkg 패키지 매니저

<div style="height:6px;width:120px;background:#2b6cb0;margin-top:22px;"></div>

<p style="font-size:26px;color:#5f6368;margin-top:18px;">manifest, port, triplet, registry로 의존성을 다루는 도구</p>

<!--
발표자 노트
섹션 전환. 설문으로 실태를 보여준 뒤 vcpkg 개념(manifest, port, triplet, registry)을 시각화한다. 화면에 정보를 너무 많이 담지 않는다.
-->


의존성/종속성을 포함하지 않습니다.

---

# C++ 개발자와 패키지 매니저

- 언어가 아니라 개발자들의 실태
- JetBrains 설문 2021-2025

<!--
발표자 노트
질문의 초점을 분명히 한다. 언어의 능력이 아니라 실제 개발자들이 무엇을 쓰는지.
문항: "How do you manage your third-party libraries in C++?" (복수 선택). 표본은 C/C++를 3대 주력 언어로 고른 응답자 한정.
-->

---

# vcpkg 사용률 추이

<div style="display:flex;align-items:flex-end;gap:40px;margin-top:30px;height:280px;padding:0 12px;">
  <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;">
    <div style="width:64%;height:60%;background:#2b6cb0;border-radius:6px 6px 0 0;position:relative;"><span style="position:absolute;top:-36px;left:0;right:0;text-align:center;font-size:26px;">9%</span></div>
    <div style="font-size:26px;color:#5f6368;margin-top:12px;">2021</div>
  </div>
  <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;">
    <div style="width:64%;height:53%;background:#2b6cb0;border-radius:6px 6px 0 0;position:relative;"><span style="position:absolute;top:-36px;left:0;right:0;text-align:center;font-size:26px;">8%</span></div>
    <div style="font-size:26px;color:#5f6368;margin-top:12px;">2022</div>
  </div>
  <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;">
    <div style="width:64%;height:100%;border:2px dashed #cfd3d9;border-bottom:none;border-radius:6px 6px 0 0;display:flex;align-items:center;justify-content:center;font-size:22px;color:#aeb2b8;text-align:center;">&lt; 15%<br>상위 5위 밖</div>
    <div style="font-size:26px;color:#5f6368;margin-top:12px;">2023</div>
  </div>
  <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;">
    <div style="width:64%;height:100%;border:2px dashed #cfd3d9;border-bottom:none;border-radius:6px 6px 0 0;display:flex;align-items:center;justify-content:center;font-size:22px;color:#aeb2b8;text-align:center;">문항<br>없음</div>
    <div style="font-size:26px;color:#5f6368;margin-top:12px;">2024</div>
  </div>
  <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;">
    <div style="width:64%;height:73%;background:#2b6cb0;border-radius:6px 6px 0 0;position:relative;"><span style="position:absolute;top:-36px;left:0;right:0;text-align:center;font-size:26px;">11%</span></div>
    <div style="font-size:26px;color:#5f6368;margin-top:12px;">2025</div>
  </div>
</div>

<p style="font-size:22px;color:#5f6368;margin-top:14px;">2023년 공개 페이지는 상위 5개 항목(≥15%)만 노출되어 vcpkg는 그 밖. 2024년은 리포트 통합 개편으로 언어별 문항 없음.</p>

<!-- _footer: '출처: JetBrains Developer Ecosystem Survey / The State of C++ (2021~2025)' -->

<!--
발표자 노트
vcpkg는 2021년 9%, 2022년 8%, 2025년 11%로 완만한 상승 후 정체.
2023년 공개 페이지는 상위 5개 항목(소스 내장 24%, 시스템 PM 21%, 직접 빌드 19%, 사전 빌드 18%, 무의존 15%)만 보여줘서 vcpkg 수치는 15% 미만이라는 것만 확인 가능.
2024년은 리포트가 단일 페이지로 통합 개편되어 언어별(C++) 문항 자체가 없다.
-->

---

# C++ 의존성 관리방식 in 2025

<div style="margin-top:24px;">
  <div style="display:flex;align-items:center;gap:16px;font-size:26px;margin-top:12px;"><span style="width:430px;flex:none;">시스템 패키지 매니저</span><span style="flex:1;background:#eef0f3;border-radius:6px;height:34px;overflow:hidden;"><span style="display:block;height:100%;width:36%;background:#2b6cb0;border-radius:6px;"></span></span><span style="width:80px;flex:none;text-align:right;">36%</span></div>
  <div style="display:flex;align-items:center;gap:16px;font-size:26px;margin-top:12px;"><span style="width:430px;flex:none;">소스가 빌드의 일부</span><span style="flex:1;background:#eef0f3;border-radius:6px;height:34px;overflow:hidden;"><span style="display:block;height:100%;width:35%;background:#2b6cb0;border-radius:6px;"></span></span><span style="width:80px;flex:none;text-align:right;">35%</span></div>
  <div style="display:flex;align-items:center;gap:16px;font-size:26px;margin-top:12px;"><span style="width:430px;flex:none;">직접 빌드</span><span style="flex:1;background:#eef0f3;border-radius:6px;height:34px;overflow:hidden;"><span style="display:block;height:100%;width:24%;background:#2b6cb0;border-radius:6px;"></span></span><span style="width:80px;flex:none;text-align:right;">24%</span></div>
  <div style="display:flex;align-items:center;gap:16px;font-size:26px;margin-top:12px;"><span style="width:430px;flex:none;">사전 빌드 바이너리</span><span style="flex:1;background:#eef0f3;border-radius:6px;height:34px;overflow:hidden;"><span style="display:block;height:100%;width:22%;background:#2b6cb0;border-radius:6px;"></span></span><span style="width:80px;flex:none;text-align:right;">22%</span></div>
  <div style="display:flex;align-items:center;gap:16px;font-size:26px;margin-top:12px;"><span style="width:430px;flex:none;">vcpkg</span><span style="flex:1;background:#eef0f3;border-radius:6px;height:34px;overflow:hidden;"><span style="display:block;height:100%;width:11%;background:#cbd5e1;border-radius:6px;"></span></span><span style="width:80px;flex:none;text-align:right;">11%</span></div>
  <div style="display:flex;align-items:center;gap:16px;font-size:26px;margin-top:12px;"><span style="width:430px;flex:none;">Conan</span><span style="flex:1;background:#eef0f3;border-radius:6px;height:34px;overflow:hidden;"><span style="display:block;height:100%;width:6%;background:#cbd5e1;border-radius:6px;"></span></span><span style="width:80px;flex:none;text-align:right;">6%</span></div>
</div>

<p style="font-size:22px;color:#5f6368;margin-top:14px;">전용 도구(vcpkg, Conan)보다 시스템 패키지 매니저와 소스 내장이 앞선다.</p>

<!-- _footer: '출처: JetBrains The State of C++ 2025 (n=1,800)' -->

<!--
발표자 노트
시스템 패키지 매니저와 소스 내장이 다수. 전용 도구(vcpkg 11%, Conan 6%)는 상대적으로 낮다.
2025년 시스템 패키지 매니저 21%->36% 급등은 질문명 변경(first-party and third-party)의 프레이밍 효과로 주의. 표본 1,800명.
-->

---

# 설문 요약

> "Dedicated tools like vcpkg (11%) or Conan (6%) see comparatively limited use." (2025)

번역: "vcpkg(11%)나 Conan(6%) 같은 전용 도구는 상대적으로 제한적으로 쓰인다."

<!-- _footer: '출처: JetBrains The State of C++ 2025' -->

<!--
발표자 노트
전용 패키지 매니저 사용은 아직 소수. 발표자 해석 추가 지점: 그럼에도 왜 vcpkg인가로 연결.
-->

---

# 커뮤니티의 목소리 (2021)

> "Nearly three quarters of respondents lack a good packaging solution." (Matt Godbolt)

번역: "응답자의 약 4분의 3이 마땅한 패키징 솔루션이 없다."

> "We'd all be better off if we just picked one and went with it." (Andreas Kling)

번역: "그냥 하나를 골라 밀고 나가는 편이 나을지도 모른다."

<!-- _footer: '출처: JetBrains Developer Ecosystem Survey 2021 (C++)' -->

<!--
발표자 노트
응답자 3/4가 좋은 패키징 솔루션이 없다는 지적. "하나 골라 밀고 가자"는 목소리가 vcpkg 선택의 정당성으로 이어진다.
-->

---

# 커뮤니티의 목소리 (2022-2023)

> "The state of dependency management makes me sad." (Titus Winters, 2022)

번역: "의존성 관리의 현실은 나를 슬프게 한다."

> "Sooner or later, we may reach an inflection point where these package managers (vcpkg, Conan, etc.) … become a defacto standard. But, we're not there yet." (Bryce Adelstein Lelbach, 2023)

번역: "언젠가 이 패키지 매니저들(vcpkg, Conan 등)이 사실상 표준이 되는 변곡점에 도달할 수 있다. 하지만 아직은 아니다."

<!-- _footer: '출처: JetBrains Developer Ecosystem Survey 2022-2023 (C++)' -->

<!--
발표자 노트
문제의식은 널리 공유되지만 아직 도달하지 못했다가 2023 요약. 발표자 해석 추가 지점: 그래서 조직이 registry로 통제하는 선택이 의미를 가진다.
-->

---

# vcpkg 알아보기: manifest(vcpkg.json)

주요 field:
- `dependencies` + `version>=`
- `overrides` + `version`

```json
// vcpkg.json
{
  "dependencies": [
    { "name": "openssl", "version>=": "3.3.0" } // 최소 버전 요구
  ],
  "overrides": [
    { "name": "openssl", "version": "3.3.1" } // 지정한 버전 사용
  ]
}
```

<!--
발표자 노트
과거엔 이름만 나열했지만 이제 버전 고정과 version>= 제어가 가능. JSON 안에 // 주석으로 핵심 field 설명.
참고 https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json
-->

---

# manifest로 vcpkg 패키지들을 설치해보면?
Google Play Store
```console
$ ls
CMakeLists.txt   vcpkg.json      # "dependencies": [ "fmt" ]
```
```console
$ vcpkg install
Fetching registries... Installing 1/1 fmt:x64-windows...
```
```console
$ tree vcpkg_installed/x64-windows
+-- include/fmt/...     # 헤더
+-- lib/fmt.lib         # 라이브러리
+-- share/fmt/...       # CMake config
```

설치 전: 명세(vcpkg.json)만 존재 → 설치 후: 바로 사용 가능한 아티팩트 생성

<!--
발표자 노트
manifest mode: vcpkg.json이 있는 폴더에서 vcpkg install을 실행하면 vcpkg_installed/ 폴더에 결과물이 생성된다.
CMake에서는 toolchain 파일을 통해 find_package(fmt CONFIG REQUIRED)로 바로 사용.
설치 전에는 의존성 '명세'만 있고, 설치 후에는 include/lib/share 구조의 산출물이 생긴다는 점을 대비.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode
-->

---

# vcpkg 알아보기: port 개념

산출물 생성 절차의 정의

- 소스, 도구 확보
- 빌드 시스템 생성
- 빌드, 설치
- 설치 후 검증

<!--
발표자 노트
port는 소스에서 artifact를 만드는 절차 전체(portfile.cmake). 슬라이드엔 단계만, 코드는 다음 슬라이드.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/ports
-->

---

# vcpkg port 예시: 단순한 portfile.cmake

GitHub에서 소스 확보, CMake로 빌드/설치, 설치 후 정리

```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO fmtlib/fmt
    REF "${VERSION}"
    SHA512 <hash>
)
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME fmt)
```

<!--
발표자 노트
공식 문서의 최소 골격. 확보, 구성, 설치, 정리. 실제 port는 여기에 patch, feature, 검증이 더해진다.
-->

---

# vcpkg port 예시: 좀 더 복잡한 portfile.cmake

patch 파일 적용, host 도구 탐색, Python venv 사용

```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    # ...
    PATCHES fix-cmake.patch fix-sources.patch
)

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED)

x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy pybind11 sympy tqdm
    OUT_PYTHON_VAR PYTHON3
)
```

<!--
발표자 노트
단순 예시와 대비되는 고도화된 형태. protoc(host 도구)로 코드 생성, Python 패키지 확보, 크로스컴파일 처리.
개념 예시로 제시한다. 같은 portfile.cmake라도 복잡도가 크게 달라진다는 점이 핵심.
-->

---

# vcpkg port 예시: vcpkg.json

기본적인 패키지 정보, 의존성(`dependencies`), 설치할 때 사용할 기능(`features`) 정의.

```json
{
  "name": "tensorflow-lite",
  "version-semver": "2.20.0",
  "description": "An Open Source Machine Learning Framework for Everyone",
  "homepage": "https://github.com/tensorflow/tensorflow",
  "license": "Apache-2.0",
  "dependencies": [
    // ...
  ],
  "features": {
    // GPU 빌드 옵션 + OpenCL, Vulkan 등 추가 의존성
    "gpu": { "description": "Enable GPU delegates",
             "dependencies": [ "opencl", "vulkan-headers" ] }
  }
}
```

---

# vcpkg 사용자는 manifest 파일로 버전 제어

주요 field: `builtin-baseline`, `overrides`

```json
// vcpkg.json
{
  "builtin-baseline": "b322…",
  "dependencies": ["fmt", "zlib"],
  "overrides": [
    { "name": "zlib", "version": "1.3.1" }
  ]
}
```

<!--
발표자 노트
builtin-baseline로 기준 시점 고정, overrides로 특정 패키지만 버전 못 박기. 과거 재현과 일부만 되돌리기의 토대.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode
-->

---

# 공급 측: port를 만든다

portfile.cmake + vcpkg.json + patch의 조합으로 라이브러리를 패키지화한다.

```text
ports/tensorflow-lite/
+-- portfile.cmake     # 빌드 절차
+-- vcpkg.json         # 패키지 정보, 의존성
+-- *.patch            # 수정 사항
```


<!--
발표자 노트
공급 측 port는 portfile.cmake + vcpkg.json + 패치 조합. 라이브러리를 vcpkg가 이해하는 형식으로 감싼다.
-->

---

# 소비 측: manifest로 가져다 쓴다

필요하다면 vcpkg-configuration.json으로 특정한 vcpkg 버전 또는 registry 목록을 추가.

```text
app/
+-- CMakeLists.txt
+-- vcpkg.json                 # 무엇을 쓸지
+-- vcpkg-configuration.json   # 어디서 가져올지
```

중요: 양쪽에서 사용하는 vcpkg.json은 거의 호환된다. vcpkg manifest를 사용하고 있다면, port를 지원할 수 있는 잠재력을 갖춘 상태.

---

# triplet 개념

target 빌드 환경을 기술하는 CMake 변수 집합

| 변수 | 결정하는 것 |
|---|---|
| `VCPKG_TARGET_ARCHITECTURE` | 명령어 집합: x64, arm64, … |
| `VCPKG_CRT_LINKAGE` | C 런타임(CRT) 연결 방식 |
| `VCPKG_LIBRARY_LINKAGE` | static(.lib/.a) ↔ dynamic(.dll/.so) |
| `VCPKG_CMAKE_SYSTEM_NAME` | 대상 OS: Android, iOS, … |

<!--
발표자 노트
triplet은 아키텍처와 링크 방식 등 빌드 환경을 CMake 변수로 기술한다.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/triplets
-->

---

# vcpkg triplet 예시: 단순한 형태

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
```

<!--
발표자 노트
공식 문서 스타일의 최소 triplet. 아키텍처와 링크 방식을 변수로 정의.
-->

---

# vcpkg triplet 예시: 고도화

SDK 버전, CMake 옵션, vcvars 통제

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_VERSION 10.0.22621.0)

list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
  "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
)
set(VCPKG_LOAD_VCVARS_ENV ON)
```

<!--
발표자 노트
실전 triplet은 SDK 버전 고정, CMake policy 우회, vcvars 로드 등 환경 전반을 통제한다. 개념 예시로 제시.
-->

---

# vcpkg triplet 예시: CMake 명령 활용

triplet은 결국 CMake 스크립트. 명령으로 빌드 환경을 탐지할 수 있다

```cmake
# x64-ios-simulator.cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS)

find_program(XCODEBUILD_EXE xcodebuild REQUIRED)
execute_process(
    COMMAND ${XCODEBUILD_EXE} -version -sdk iphonesimulator Path
    OUTPUT_VARIABLE VCPKG_OSX_SYSROOT
    ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(VCPKG_CXX_FLAGS "-mios-simulator-version-min=16.0")
```

<!--
발표자 노트
이 저장소의 triplets/x64-ios-simulator.cmake 실제 파일 기반.
triplet은 단순 변수 집합이 아니라 CMake 스크립트라서 find_program, execute_process 같은 명령을 쓸 수 있다.
xcodebuild로 iphonesimulator SDK 경로를 탐지해 VCPKG_OSX_SYSROOT에 주입하는 예시.
iOS 실전 빌드는 VCPKG_CHAINLOAD_TOOLCHAIN_FILE + leetal/ios-cmake 조합을 권장.
-->

---

# vcpkg triplet 예시: 크로스컴파일

좀 더 상세한 CMake, toolchain 옵션을 추가.

```cmake
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Android)

if(NOT DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
    set(VCPKG_CMAKE_SYSTEM_VERSION 26)
endif()

set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-linux-android")
set(VCPKG_CMAKE_CONFIGURE_OPTIONS -DANDROID_ABI=arm64-v8a)
```

<!--
발표자 노트
동일 port를 Android arm64로 빌드할 때 triplet만 바꾼다. 여기서 host와 target이 갈린다.
-->

---

# host dependency 개념

- **target platform**: 최종 실행 대상
- **host platform**: 빌드를 수행하는 곳. 예) 생성기, 빌드 도구

<!--
발표자 노트
cross compile에서 host와 target을 구분. Python의 dev/test dependency처럼 빌드에만 필요한 도구가 host dependency.
참고 https://learn.microsoft.com/en-us/vcpkg/users/host-dependencies
-->

---

# host dependency 선언

`"host": true`

```json
{
  "supports": "windows | android",
  "dependencies": [
    // Windows 환경에서 Android용 빌드를 진행한다면, protoc은 Windows용 빌드를 사용해야 한다
    "protobuf",
    { "name": "protobuf", "host": true },
    // 현재 빌드를 진행하는 환경에서 CMake를 실행
    { "name": "vcpkg-cmake", "host": true },
    // Python 환경을 구성하고, 빌드 과정에서 Python 실행
    { "name": "vcpkg-get-python-packages", "host": true }
  ]
}
```

<!--
발표자 노트
target용 protobuf와 별개로, host에서 실행할 protoc를 위해 protobuf를 host:true로도 선언. vcpkg-get-python-packages는 빌드용 Python 패키지를 host에 공급.
-->

---

# host dependency 사용

Python 스크립트 실행을 위해 환경 구성
```cmake
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy pybind11 sympy tqdm
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python: ${PYTHON3}")
```

host protoc 로 .proto 에서 소스 생성
```cmake
find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED)
message(STATUS "Using protoc: ${PROTOC}")
```

<!--
발표자 노트
host:true 선언이 portfile에서 실제로 쓰이는 방식. x_vcpkg_get_python_packages가 numpy, pybind11 등을 host Python에 준비하고 PROTOC는 host protobuf 도구에서 찾는다.
-->

---

# overlay 활용법: 저장소에 port와 triplet을 둔다

vcpkg 전체를 fork할 필요가 없이, `vcpkg install` 할때 쉽게 port 설치에 변화를 줄 수 있다.
예를 들어...

- 임시적인 patch 파일, 버전 조정
- 실험적인 triplet 추가

```text
my-cuda-project/
+-- ports/
|   +-- nvidia-cutlass/
+-- triplets/
|   +-- x64-windows-cuda.cmake
+-- vcpkg.json
```

<!--
발표자 노트
overlay는 vcpkg 전체를 fork하지 않고 필요한 port/triplet만 추가하게 해준다.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports
-->

---

# overlay: upstream 위에 덧그린다

<div style="position:relative;height:440px;margin-top:14px;">
  <div style="position:absolute;left:0;top:74px;width:100%;height:240px;border:3px solid #d9dce1;border-radius:16px;background:#fafafa;box-sizing:border-box;"></div>
  <div style="position:absolute;left:22px;top:88px;font-size:21px;font-weight:600;color:#5f6368;">registry (microsoft/vcpkg): 2,000+ ports</div>
  <span style="position:absolute;left:22px;top:156px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">spdlog 1.15.1</span>
  <span style="position:absolute;left:230px;top:156px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">zlib 1.3.1</span>
  <span style="position:absolute;left:540px;top:156px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#c4c9ce;text-decoration:line-through;font-family:Consolas,monospace;">fmt 11.0.2</span>
  <span style="position:absolute;left:790px;top:156px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">openssl 3.5.0</span>
  <span style="position:absolute;left:22px;top:226px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">protobuf 5.29</span>
  <span style="position:absolute;left:240px;top:226px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">abseil ...</span>
  <span style="position:absolute;left:430px;top:226px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">boost ...</span>
  <span style="position:absolute;left:610px;top:226px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">grpc ...</span>
  <span style="position:absolute;left:780px;top:226px;border:2px solid #d9dce1;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">curl ...</span>
  <span style="position:absolute;left:950px;top:232px;font-size:22px;color:#c4c9ce;">...</span>
  <div style="position:absolute;left:480px;top:0;width:600px;height:140px;border:3px solid #2b6cb0;border-radius:16px;background:rgba(235,242,249,.96);box-sizing:border-box;box-shadow:0 14px 30px rgba(0,0,0,.18);"></div>
  <div style="position:absolute;left:502px;top:14px;font-size:21px;font-weight:600;color:#2b6cb0;">overlay &nbsp;<span style="font-family:Consolas,monospace;font-weight:400;">--overlay-ports=./ports</span></div>
  <span style="position:absolute;left:502px;top:64px;border:2px solid #2b6cb0;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;font-weight:600;color:#1a4e85;font-family:Consolas,monospace;">fmt 10.1.1#patched</span>
  <span style="position:absolute;left:770px;top:64px;border:2px solid #2b6cb0;border-radius:8px;padding:8px 18px;font-size:20px;background:#fff;font-weight:600;color:#1a4e85;font-family:Consolas,monospace;">tensorflow-lite 2.20.0</span>
  <div style="position:absolute;left:60px;top:322px;width:120px;text-align:center;font-size:40px;color:#9aa0a6;line-height:1;">↓</div>
  <div style="position:absolute;left:520px;top:322px;width:120px;text-align:center;font-size:40px;color:#2b6cb0;line-height:1;">↓</div>
  <div style="position:absolute;left:830px;top:322px;width:120px;text-align:center;font-size:40px;color:#2b6cb0;line-height:1;">↓</div>
  <span style="position:absolute;left:50px;top:376px;border:2px solid #d9dce1;border-radius:8px;padding:10px 20px;font-size:21px;background:#fff;color:#5f6368;font-family:Consolas,monospace;">spdlog 1.15.1</span>
  <span style="position:absolute;left:460px;top:376px;border:2px solid #2b6cb0;border-radius:8px;padding:10px 20px;font-size:21px;background:rgba(43,108,176,.08);font-weight:600;color:#1a4e85;font-family:Consolas,monospace;">fmt 10.1.1#patched</span>
  <span style="position:absolute;left:760px;top:376px;border:2px solid #2b6cb0;border-radius:8px;padding:10px 20px;font-size:21px;background:rgba(43,108,176,.08);font-weight:600;color:#1a4e85;font-family:Consolas,monospace;">tensorflow-lite 2.20.0</span>
</div>

<!--
발표자 노트
아래 판 = upstream registry의 port 목록, 위 판 = 내 overlay. 겹치면 위 판이 이긴다.
같은 이름(fmt)은 overlay가 upstream을 가리고(취소선), upstream에 없는 port(tensorflow-lite)는 신규 추가된다.
화살표를 따라 내려가면 실제 설치 결과: 파란 chip = overlay에서, 회색 chip = upstream에서 온 패키지.
overlay port는 버전 제약과 무관하게 항상 overlay의 내용이 그대로 사용된다.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports
-->

---

# overlay 활용법: 나만의 patch 적용

```text
ports/fmt/
+-- portfile.cmake   # PATCHES fix.patch
+-- vcpkg.json
+-- fix.patch
```

- upstream에 없는 patch를 port에 내장
- upstream에 아직 없는 라이브러리 추가
- 버전, 빌드 옵션을 강제로 고정

<!--
발표자 노트
overlay port는 patch를 내장해 upstream이 받아주기 전에도 수정 사항을 반영한다. 신규 라이브러리 추가나 버전 강제도 가능.
-->

---

# overlay 의의

- fork 불필요: 필요한 port만 관리
- opt in / out 자유
- 다수의 overlay를 조합해 원하는 패키지 구성

<!--
발표자 노트
최소 단위로 확장. registry 이것을 형상관리 가능한 JSON으로 끌어올린다.
참고 https://learn.microsoft.com/en-us/vcpkg/users/config-environment
-->

---

# vcpkg registry 설정

주요 field: `default-registry`, `registries[].packages`.

```json
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "<commit>"
  },
  "registries": [
    { "kind": "git",
      "repository": "https://github.com/luncliff/vcpkg-registry",
      "baseline": "<commit>",
      "packages": ["tensorflow-lite", "openssl3"] }
  ]
}
```

<!--
발표자 노트
default-registry는 최신, 특정 registry만 과거 baseline으로 고정하는 조합이 가능. 공개 시 기본 branch의 versions/ 폴더와 port가 일치해야 한다.
참고 https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json
-->

---

# registry 조합 ①: registry 추가

vcpkg-configuration.json diff 몇 줄로 새 패키지 공급처가 생긴다

```diff
 {
   "default-registry": {
     "kind": "git",
     "repository": "https://github.com/microsoft/vcpkg",
     "baseline": "56bb2411..."
   },
   "registries": [
+    {
+      "kind": "git",
+      "repository": "https://github.com/luncliff/vcpkg-registry",
+      "baseline": "9f3a2c1d...",
+      "packages": [ "tensorflow-lite", "openssl3" ]
+    }
   ]
 }
```

<!--
발표자 노트
vcpkg-configuration.json diff만으로 새 registry 도입을 코드리뷰할 수 있다.
packages 목록으로 이 registry가 담당할 패키지 범위를 명시적으로 제한한다.
-->

---

# registry 조합 ②: 시간 되돌리기

default-registry는 최신 유지, 특정 registry만 과거로

```diff
   "registries": [
     {
       "kind": "git",
       "repository": "https://github.com/luncliff/vcpkg-registry",
-      "baseline": "9f3a2c1d...",
+      "baseline": "1b7d44e0...",
       "packages": [ "tensorflow-lite", "openssl3" ]
     }
   ]
```

이 설정이 vcpkg.json을 통과하면서 **dependency graph 결과가 달라진다**

<!--
발표자 노트
baseline commit만 바꾸면 해당 registry가 제공하는 port 목록의 시간이 통째로 되돌아간다.
예: default는 오늘, 내 registry는 6개월 전. 빌드 관리 질문들(과거 재현? 일부만 과거 버전? 도구만 교체?)에 대한 답이 된다.
-->


---

# vcpkg registry: baseline 바느질

<p style="font-size:24px;color:#5f6368;margin:4px 0 0;">여러 git stream에서 임의 시점(commit)을 골라 꿰면 configuration. 조합이 다르면 결과도 다르다</p>

<div style="position:relative;height:385px;margin-top:20px;font-size:20px;">
  <div style="position:absolute;left:0;top:48px;width:22%;line-height:1.35;white-space:nowrap;"><span style="font-family:Consolas,monospace;font-size:17px;">microsoft/vcpkg</span><br><span style="font-size:15px;color:#5f6368;">default-registry</span></div>
  <div style="position:absolute;left:0;top:134px;width:22%;line-height:1.35;white-space:nowrap;"><span style="font-family:Consolas,monospace;font-size:17px;">microsoft/vcpkg</span></div>
  <div style="position:absolute;left:0;top:209px;width:22%;line-height:1.35;white-space:nowrap;"><span style="font-family:Consolas,monospace;font-size:17px;">luncliff/vcpkg-registry</span></div>
  <div style="position:absolute;left:23%;right:1%;top:67px;height:6px;background:#d9dce1;border-radius:3px;"></div>
  <div style="position:absolute;left:23%;right:1%;top:142px;height:6px;background:#d9dce1;border-radius:3px;"></div>
  <div style="position:absolute;left:23%;right:1%;top:217px;height:6px;background:#d9dce1;border-radius:3px;"></div>
  <div style="position:absolute;left:23%;right:1%;top:268px;height:2px;background:#9aa0a6;"></div>
  <div style="position:absolute;right:1%;top:263px;width:0;height:0;border-top:6px solid transparent;border-bottom:6px solid transparent;border-left:10px solid #9aa0a6;"></div>
  <div style="position:absolute;right:3%;top:240px;font-size:18px;color:#5f6368;">시간 t</div>
  <div style="position:absolute;left:calc(42% - 14px);top:-8px;width:28px;height:28px;border-radius:50%;background:#2b6cb0;color:#fff;font-size:17px;display:flex;align-items:center;justify-content:center;">1</div>
  <div style="position:absolute;left:calc(42% - 2px);top:20px;width:4px;height:89px;background:#2b6cb0;"></div>
  <div style="position:absolute;left:28%;top:105px;width:14%;height:4px;background:#2b6cb0;"></div>
  <div style="position:absolute;left:calc(28% - 2px);top:105px;width:4px;height:79px;background:#2b6cb0;"></div>
  <div style="position:absolute;left:28%;top:180px;width:6%;height:4px;background:#2b6cb0;"></div>
  <div style="position:absolute;left:calc(34% - 2px);top:180px;width:4px;height:112px;background:#2b6cb0;"></div>
  <div style="position:absolute;left:calc(34% - 10px);top:292px;width:0;height:0;border-left:10px solid transparent;border-right:10px solid transparent;border-top:14px solid #2b6cb0;"></div>
  <div style="position:absolute;left:calc(84% - 14px);top:-8px;width:28px;height:28px;border-radius:50%;background:#d97706;color:#fff;font-size:17px;display:flex;align-items:center;justify-content:center;">2</div>
  <div style="position:absolute;left:calc(84% - 2px);top:20px;width:0;height:89px;border-left:4px dashed #d97706;"></div>
  <div style="position:absolute;left:56%;top:105px;width:28%;height:0;border-top:4px dashed #d97706;"></div>
  <div style="position:absolute;left:calc(56% - 2px);top:105px;width:0;height:79px;border-left:4px dashed #d97706;"></div>
  <div style="position:absolute;left:56%;top:180px;width:10%;height:0;border-top:4px dashed #d97706;"></div>
  <div style="position:absolute;left:calc(66% - 2px);top:180px;width:0;height:112px;border-left:4px dashed #d97706;"></div>
  <div style="position:absolute;left:calc(66% - 10px);top:292px;width:0;height:0;border-left:10px solid transparent;border-right:10px solid transparent;border-top:14px solid #d97706;"></div>
  <span style="position:absolute;left:30%;top:70px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:56%;top:70px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:70%;top:70px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:93%;top:70px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:42%;top:70px;width:28px;height:28px;border-radius:50%;background:#2b6cb0;border:4px solid #fff;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:84%;top:70px;width:28px;height:28px;border-radius:50%;background:#d97706;border:4px solid #fff;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:40%;top:145px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:72%;top:145px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:88%;top:145px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:28%;top:145px;width:28px;height:28px;border-radius:50%;background:#2b6cb0;border:4px solid #fff;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:56%;top:145px;width:28px;height:28px;border-radius:50%;background:#d97706;border:4px solid #fff;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:50%;top:220px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:82%;top:220px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:92%;top:220px;width:16px;height:16px;border-radius:50%;background:#9aa0a6;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:34%;top:220px;width:28px;height:28px;border-radius:50%;background:#2b6cb0;border:4px solid #fff;transform:translate(-50%,-50%);"></span>
  <span style="position:absolute;left:66%;top:220px;width:28px;height:28px;border-radius:50%;background:#d97706;border:4px solid #fff;transform:translate(-50%,-50%);"></span>
  <div style="position:absolute;left:calc(42% + 14px);top:82px;font-size:16px;color:#2b6cb0;font-weight:600;white-space:nowrap;">2026.06.24</div>
  <div style="position:absolute;left:calc(28% + 14px);top:157px;font-size:16px;color:#2b6cb0;font-weight:600;white-space:nowrap;">2026.04.27</div>
  <div style="position:absolute;left:calc(34% + 14px);top:228px;width:120px;text-align:left;font-size:16px;color:#2b6cb0;font-weight:600;">2.2605.0</div>
  <div style="position:absolute;left:calc(34% - 165px);top:312px;width:330px;border:3px solid #2b6cb0;border-radius:10px;padding:8px 6px;text-align:center;background:#fff;">
    <div style="font-size:19px;font-weight:600;font-family:Consolas,monospace;">vcpkg-configuration.json &#9312;</div>
    <div style="font-size:16px;color:#5f6368;margin-top:2px;">2026.06.24 &middot; 2026.04.27 &middot; 2.2605.0</div>
  </div>
  <div style="position:absolute;left:calc(66% - 165px);top:312px;width:330px;border:3px dashed #d97706;border-radius:10px;padding:8px 6px;text-align:center;background:#fff;">
    <div style="font-size:19px;font-weight:600;font-family:Consolas,monospace;">vcpkg-configuration.json &#9313;</div>
    <div style="font-size:16px;color:#5f6368;margin-top:2px;">또 다른 시점 조합</div>
  </div>
</div>

<!--
발표자 노트
각 lane은 registry의 git stream. 위에서 아래로 내려오는 선이 각 stream의 commit(dot)을 관통하며 지그재그로 꿰맨다.
파란 실선 ①은 이 저장소의 실제 vcpkg-configuration.json 값: microsoft/vcpkg 2026.06.24(default) + 2026.04.27(spirv 계열 고정) + luncliff/vcpkg-registry 2.2605.0.
주황 점선 ②는 다른 시점 조합. 같은 stream들에서 다른 commit을 골라 또 하나의 configuration을 만들 수 있다.
같은 저장소(microsoft/vcpkg)를 서로 다른 시점으로 두 번 참조할 수도 있다는 점도 주목.
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/registries
-->

---

# vcpkg registry 의의

- 파일시스템 폴더들 → 형상관리 가능한 JSON으로
- port와 triplet의 재사용성 강화
- 과거 빌드 재현, 특정 패키지만 과거 버전 사용
- 특정 시점에서 도구만 교체하는 빌드
- 공개 시 규율: 기본 branch의 versions/ 폴더와 port 일치 필수

<!--
발표자 노트
빌드 관리의 핵심 질문에 답한다. 과거 재현? 일부만 과거로? 도구만 교체? 특정 registry의 시간을 바꾸면 dependency graph 결과가 달라진다.
-->

---

# 패키지 관리 전략 고민

<div style="height:6px;width:120px;background:#2b6cb0;margin-top:22px;"></div>

<p style="font-size:26px;color:#5f6368;margin-top:18px;">쓰는 능력에서 만들고 공급하는 능력으로</p>

<!--
발표자 노트
섹션 전환. 쓰는 능력을 넘어 만들고 공급하는 능력으로. 층위, 규모, 단계 세 축으로 접근.
-->

---

# 세 축: 층위, 규모, 단계

- 층위 Layer: 재사용 단위가 아키텍처의 어느 높이에 있는가
- 규모 Scale: 설명 가능한 물리, 논리 구조와 컴포넌트의 협력적 결합
- 단계 Phase: 선제 도입 → OSS 추적 → 검증의 반복, 조직 간 공유

<!--
발표자 노트
Layer는 그래프 편제, Scale은 컴포넌트가 협력적으로 결합하도록 설계, Phase는 선제적 관리와 OSS 변화 추적/검증, 조직 간 공유.
-->

---

# 배포 유연성

- Dependency Graph 전반부, 하위 Layer → 배포 부담 적음
- Graph 후반부, 상위 Layer → 빌드 설정과 오류가 곱연산으로 복잡

<div style="display:flex;align-items:center;gap:14px;margin-top:34px;font-size:19px;">
  <div style="display:flex;flex-direction:column;gap:8px;flex:none;">
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 14px;background:#f3f4f6;font-family:Consolas,monospace;text-align:center;">zlib</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 14px;background:#f3f4f6;font-family:Consolas,monospace;text-align:center;">fmt</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 14px;background:#f3f4f6;font-family:Consolas,monospace;text-align:center;">openssl</span>
  </div>
  <span style="color:#9aa0a6;font-size:28px;flex:none;">→</span>
  <div style="display:flex;flex-direction:column;gap:8px;flex:none;">
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 14px;background:#f3f4f6;font-family:Consolas,monospace;text-align:center;">protobuf</span>
    <span style="display:inline-block;border:2px solid #d9dce1;border-radius:8px;padding:6px 14px;background:#f3f4f6;font-family:Consolas,monospace;text-align:center;">tensorflow-lite</span>
  </div>
  <span style="color:#9aa0a6;font-size:28px;flex:none;">→</span>
  <span style="display:inline-block;border:2px solid #7ba7d7;border-radius:8px;padding:14px 18px;background:#f3f4f6;font-family:Consolas,monospace;flex:none;">our-framework</span>
  <span style="color:#9aa0a6;font-size:28px;flex:none;">→</span>
  <span style="display:inline-block;border:3px solid #2b6cb0;border-radius:10px;padding:18px 22px;background:rgba(43,108,176,.06);font-family:Consolas,monospace;font-weight:600;flex:none;">Application</span>
</div>

<div style="margin-top:30px;height:40px;border-radius:20px;background:linear-gradient(to right,#dbe7f3,#2b6cb0);position:relative;"><span style="position:absolute;left:20px;top:0;line-height:40px;font-size:21px;color:#122a3f;">하위 Layer: 배포 부담 적음</span><span style="position:absolute;right:20px;top:0;line-height:40px;font-size:21px;color:#fff;">상위 Layer: 설정과 오류 곱연산</span></div>


<!--
발표자 노트
하위 Layer일수록 배포 유연성이 크고, 상위 Layer일수록 빌드 설정과 오류 복잡도가 곱연산으로 커진다.
-->

---

# 제품, 일정, 예산 삼각형으로 접근

패키지 시스템이 프로그램 생성 과정을 근본적으로 바꾼 것은 아니다.
여전히 공학 문제이므로, 고전적인 삼각형으로 분석해볼 수 있다

- **제품(Product)**: 제품을 패키지로 변환. 개인 역량에 종속되지 않는, 체계적 과정의 산출물
- **예산(Budget)**: 패키지 생태계 활용. 규모의 경제로 관리 비용 감축
- **일정(Schedule)**: 지속 유지되는 패키지 체계. 도입, 학습, 검증 기간이 예측 가능

<div style="font-size:26px;color:#5f6368;background:#fff;border-left:7px solid #2b6cb0;padding:14px 20px;margin-top:22px;">공급망 투자를 품질 ↔ 비용 ↔ 시간의 트레이드오프로 설명할 수 있다. 뒤의 '보험 모델'로 이어진다.</div>

<!--
발표자 노트
패키지 시스템 자체는 컴파일-링크라는 프로그램 생성 과정을 바꾸지 않았다. 그래서 여전히 공학적 분석 대상이고,
제품-일정-예산 삼각형의 트레이드오프로 공급망 투자를 설명할 수 있다.
제품: 개인기가 아닌 체계의 산출물. 예산: 규모의 경제. 일정: 예측 가능한 도입/학습/검증 기간.
-->

---

# 패키지화가 일으키는 재편

기존 산출물을 패키지로 만들면, 자연스럽게 따라오는 것들

- 공급을 위한 물리, 논리 구조의 재편
- 일관성 있는 규칙에 대한 재고민
- 비즈니스 요구사항과 컴포넌트 명세를 재검토하기 좋은 지점
- 리팩터링, 배포, 검증 단위의 조정

<!--
발표자 노트
패키지화는 단순한 포장이 아니라 구조 재편의 계기가 된다.
기존에 작성된 것들을 패키지로 만들면서 물리/논리 구조 재편이 발생하고, 명세 재검토와 단위 조정이 따라온다.
-->

---

# 문제 형태 다시보기: 안티패턴

<div style="border:2px dashed #d99;background:#fff6f6;border-radius:12px;padding:16px 22px;font-size:28px;color:#7a2a2a;margin-top:14px;">직접 빌드 → 소스 내장 → 산출물 수기 관리 → 스크립트 방치</div>

<div style="text-align:center;font-size:32px;color:#5f6368;margin:12px 0;">↓</div>

<div style="font-size:26px;color:#5f6368;background:#fff;border-left:7px solid #2b6cb0;padding:14px 20px;">개인이 푸는 방식은 다음 유사 문제에서 재현되지 않는다. 같은 오류가 조직 곳곳에서 되풀이된다.</div>

<!--
발표자 노트
앞서 본 문제들은 하나의 안티패턴 사슬로 연결된다. 개인의 해결은 재현되지 않기에 조직 차원의 접근이 필요.
-->

---

# 질문이 달라진다: 기술 → 위험

<div style="display:flex;gap:28px;margin-top:24px;">
  <div style="flex:1;border:2px solid #d9dce1;border-radius:12px;padding:18px 22px;font-size:28px;line-height:1.5;">
    <div style="font-size:22px;color:#5f6368;margin-bottom:8px;font-weight:600;">기술, 업무 단위</div>
    왜 문제가 터지는걸까?
  </div>
  <div style="flex:1;border:2px solid #2b6cb0;background:rgba(43,108,176,.05);border-radius:12px;padding:18px 22px;font-size:28px;line-height:1.5;">
    <div style="font-size:22px;color:#2b6cb0;margin-bottom:8px;font-weight:600;">위험, 운영</div>
    발생할 수밖에 없는 문제에, 어떻게 대응할까?
  </div>
</div>

<div style="font-size:26px;color:#5f6368;background:#fff;border-left:7px solid #2b6cb0;padding:14px 20px;margin-top:22px;">조직은 공급망을 Technique이 아니라 Risk로 다룬다. 보험 모델로 이어진다.</div>

<!--
발표자 노트
개인이 문제를 푸는 방식은 다음 유사 문제에서 재현되지 않는다. 조직은 공급망을 Technique이 아니라 Risk로 다뤄야 한다.
-->

---

# 접근: 보험(Insurance) 모델

- 미리 비용을 지불해서, 대응이 어려운 규모로 문제가 커지는 것을 제한
- 지속적으로 공급망을 점검하고 검증할 필요성

<!--
발표자 노트
보험 비유. 사전 비용으로 위험이 통제 불능으로 커지는 것을 막는다. 핵심은 지속적 점검과 검증.
-->

---

# 고민의 축 전환: 기술 → 위험

<p style="font-size:24px;color:#5f6368;margin:4px 0 0;">규모가 커질수록 관심이 개인기(기술)에서 운영(위험)으로</p>

<div style="display:flex;align-items:flex-end;gap:24px;margin-top:26px;">
  <div style="flex:1;">
    <div style="background:#2b6cb0;border-radius:10px 10px 0 0;padding:14px 16px;color:#fff;font-size:23px;line-height:1.35;height:100px;box-sizing:border-box;display:flex;flex-direction:column;justify-content:flex-end;">도구 전문성<br>멘탈 모델</div>
    <div style="font-size:25px;text-align:center;margin-top:10px;font-weight:600;">개인 Person</div>
  </div>
  <div style="flex:1;">
    <div style="background:#2b6cb0;border-radius:10px 10px 0 0;padding:14px 16px;color:#fff;font-size:23px;line-height:1.35;height:175px;box-sizing:border-box;display:flex;flex-direction:column;justify-content:flex-end;">공급망 설계와 운영<br>소비/생산 역량</div>
    <div style="font-size:25px;text-align:center;margin-top:10px;font-weight:600;">조직 Organization</div>
  </div>
  <div style="flex:1;">
    <div style="background:#2b6cb0;border-radius:10px 10px 0 0;padding:14px 16px;color:#fff;font-size:23px;line-height:1.35;height:250px;box-sizing:border-box;display:flex;flex-direction:column;justify-content:flex-end;">자본화<br>거버넌스, 검수<br>공유 인프라</div>
    <div style="font-size:25px;text-align:center;margin-top:10px;font-weight:600;">법인 Enterprise</div>
  </div>
</div>

<div style="margin-top:24px;height:44px;border-radius:22px;background:linear-gradient(to right,#bcd3ec,#2b6cb0);position:relative;"><span style="position:absolute;left:20px;top:0;line-height:44px;font-size:24px;color:#122a3f;">기술 Technique</span><span style="position:absolute;right:20px;top:0;line-height:44px;font-size:24px;color:#fff;">위험 Risk</span></div>

<p style="font-size:22px;color:#5f6368;margin-top:12px;">계단 높이 = 배포단위와 문제의 크기 / 하단 축 = 고민의 성격이 기술에서 위험으로 이동</p>

<!--
발표자 노트
개인은 도구 전문성과 설계 분별력, 멘탈 모델. 조직은 공급망 설계/운영과 소비/생산 역량, 제품 특성. 법인은 소프트웨어 자본화, 거버넌스와 검수, 공유 인프라.
규모가 커질수록 고민의 축이 기술에서 위험으로 이동한다.
-->

---

# 관점: 소프트웨어 자본 (Software Capital)

> "John Lakos shows how to create and grow **Software Capital**."
> (Large-Scale C++ Vol.1: Process and Architecture, 2020 소개문)

- 컴포넌트를 논리와 물리 설계의 기본 단위로: 계층적 재사용(hierarchical reuse)
- 재사용이 쌓일수록 생산성이 기하급수적으로 증가한다는 관점
- 자산(asset)보다 자본(capital): 보유가 아니라, 생산에 재투입되어 계속 수익을 낳는 축적물
- 조직 산출물을 패키지 공급망에 참여시키는 것 = 소프트웨어 자본을 쌓는 일

<!--
발표자 노트
Large-Scale C++ Vol.1 (John Lakos, Addison-Wesley, 2020) 공식 소개문: "shows how to create and grow Software Capital".
핵심 주장: 컴포넌트가 논리/물리 설계의 기본 단위, feedback과 hierarchical reuse로 생산성의 기하급수적 향상.
번역 검증: 'capital'은 회계상 자산(asset)과 달리, 생산에 재투입되어 지속적으로 생산성을 낳는 생산수단. 따라서 '자산화'보다 '소프트웨어 자본(의 축적)'이 정확한 번역.
패키지 공급망 참여 = 재사용 가능한 형태로 산출물을 정제해 자본으로 축적하는 과정.
-->

---

# 사내 소프트웨어에 필요한 아키텍처 시야

- 최종 소프트웨어에 포함될 배포 단위(Unit of Release)를 어떻게 분할?
- 관여하는 조직 간에 패키지 공유 수준을 어떻게 맞출까?
- Dependency Graph의 종단(Application) vs 비종단(Library, Framework)
- 층위가 복합적인 경우: Development Kit, CLI tool 지원

<!--
발표자 노트
배포 단위 분할과 조직 간 공유 수준이 핵심 결정. Dev Kit이나 CLI 도구 지원처럼 층위가 복합적인 경우도 고려.
-->

---

# 패키지 생태계 운영

<div style="height:6px;width:120px;background:#2b6cb0;margin-top:22px;"></div>

<p style="font-size:26px;color:#5f6368;margin-top:18px;">Layer에 따라 upstream과 internal registry로 나눈다</p>

<!--
발표자 노트
섹션 전환. Layer에 따른 upstream 대 internal registry 배분 전략.
-->

---

# Layer에 따른 배분

전략 질문: 우리 조직이 쓰는 외부 라이브러리들을 어떻게 분배하는 것이 전략적인가?

- 하위 Layer (작은 단위, 빠른 갱신) → **vcpkg upstream**
- 상위 Layer (큰 단위, 검증과 수정 필요) → **internal / private registry**

<div style="font-size:26px;color:#5f6368;background:#fff;border-left:7px solid #2b6cb0;padding:14px 20px;margin-top:22px;">판단 기준: 누가 검증할 수 있고, 누가 수정할 수 있는가.</div>

<!--
발표자 노트
빠르게 바뀌는 하위 Layer는 생태계의 도움을 받고, 검증/수정이 필요한 상위 Layer는 내부 registry로 통제한다.
-->

---

# 판단 근거: upstream 생태계의 도움

upstream 영역의 패키지들은 생태계의 도움을 받는다

- 지속적인 latest 업데이트 → 사내 문제가 이미 제보된 것인지 확인 가능 (추적 시 소거법 분석)
- 실제 사용자 존재 → 지속적인 모니터링이 유지된다고 확신 가능
- 관리 비용을 생태계와 공유

<!--
발표자 노트
문제 발생 시 이미 제보됐는지 확인하는 것이 소거법 분석에 큰 도움이 된다.
사용자가 있다는 것 = 누군가는 계속 지켜본다는 뜻. 관리 비용이 분산된다.
-->

---

# 판단: 선제적 upstream 기여

우리 제품에서 잠재적 사용이 예상되면, vcpkg upstream에 미리 기여한다

- 조직 내 역량이 부족해지는 순간 → public space에서 충분히 많은 사람이 검토
- 소스코드 관리가 아니라 **패키징** 기여라는 점이 중요
- upstream에서 성공적으로 관리 중이라면 → 신뢰 기본선 ↑, 패키지 도입 비용 ↓

<!--
발표자 노트
잠재 사용이 보이면 미리 upstream에 port를 올린다. 패키징 기여는 소스코드 공개와 다르므로 부담이 적다.
upstream에서 잘 관리되고 있다는 사실 자체가 사내 도입 심사의 신뢰 기본선을 높여준다.
-->

---

# 개인 수준: 개인 registry 운영

목적: 확장보다 관리와 운영 경험 축적. 선택과 집중

- OpenSSL: 빌드 과정에서 Perl 사용
- TensorFlow Lite: 소규모 라이브러리 다수 의존
- NVIDIA CUDA 계열 (cuDNN, Triton): CUDA 빌드 오류 경험
- Apple CoreML Tools: Python + Xcode 조합

<!--
발표자 노트
흥미 본위로 선정한 환경에서 가장 익숙한 도구로. 지속적으로 배포가 발생하는 중규모 빌드 복잡도의 C++ 프로젝트를 골랐다.
각 사례가 서로 다른 난점을 준다: Perl, 소규모 다수 의존성, CUDA 빌드 오류, Python+Xcode.
-->

---

# 개인 수준: upstream 승격

지속 관리가 필요하고 공익성 있는 대규모 프로젝트
→ 개인 registry에서 실험 후 upstream으로, vcpkg 팀 CI로 검증

- Gstreamer: Meson 빌드시스템
- libtorch: PyTorch C++ 코드 + dependency 전체
- Microsoft QUIC: 자체 수정한 OpenSSL 변형
- ONNX, ONNX Runtime: GPU 빌드 지원 복잡성, 실무적 필요
- ImGui: WebGPU 빌드 지원, 커뮤니티 요청

<!--
발표자 노트
대규모/공익성 프로젝트는 개인 registry에서 검증 후 upstream으로 승격하고, vcpkg 팀이 운영하는 CI로 검증받는다.
기타 커뮤니티 요청 라이브러리들도 포함.
-->

---

# 조직 수준: Enterprise registry

LINE GitHub Enterprise에도 vcpkg-registry 생성

- 재현 가능한 빌드: 다양한 조합의 baseline을 검증
- 사내 저장소들로 빌드: 절차와 옵션을 CMake로 재작성, OSS보다 철저한 경량화로 복잡성 차단
- 분산되어 있던 patch 파일 수집 → port에 내장
- 팀원들이 쓰는 빌드 도구에 맞춘 triplet 구성

<!--
발표자 노트
사내 registry는 OSS보다 더 철저히 경량화한다. 복잡성을 차단하고, 흩어진 patch를 port에 모으고, 팀 도구에 맞춘 triplet을 제공.
-->

---

# 조직 수준: CI (GitHub Actions)

회사와 팀에서 지원하는 도구들을 기준으로 설계

- 각 target platform마다 필요한 port 검증에 집중
- 6개월 이전까지 전체 dependency의 시간을 되돌리는 job matrix
- 새 OSS 버전 출시 → branch 생성 → port 갱신 → 빌드 log로 오류 사전 확인
- GitHub Hosted Runner가 아닌 Enterprise Runner 기준: Docker image + Container Registry 운영

<!--
발표자 노트
CI는 target별 port 검증에 집중. job matrix로 6개월 전까지 시간을 되돌려 검증.
사내 지원 도구가 바뀌면 그에 맞게 대응: Enterprise Runner용 Docker image와 Container Registry를 직접 운영.
-->

---

# Enterprise 제약: 권한과 빌드 분할

생태계를 만드는 이유: 다른 개발조직이 우리 자산을 쉽게 활용하도록

- 사내 private Git 저장소 접근 권한과 Secret 관리
- 빌드 머신 메모리 부족 → 빌드 규모 분할 → 응집성과 배포단위(Unit of Release) 재설계 필연
- 최선은 소스 경량화: C++ 표준 라이브러리와 시스템 SDK로 코드 수준의 군살 제거

<!--
발표자 노트
라이브러리라면 분할과 함께 인터페이스 재설계가 필연적으로 따라온다.
패키지 생태계에 합류하려면 응집성과 배포단위를 신중하게 설계해야 한다.
-->

---

# Enterprise 제약: caching과 보존

vcpkg는 실전에 유익한 caching 기능들을 이미 제공하고 있다

- binary caching: 빌드 결과물을 ABI hash 단위로 재사용. 파일시스템, NuGet, HTTP, Object Storage(S3, Azure Blob, GCS) 등 지원
  → 사내 Object Storage에 연결해 전체 소요시간 단축
- asset caching: 소스 아카이브와 도구 다운로드를 mirror에 보관
  → 원본 URL이 사라져도 재현 가능, 격리망 빌드 지원
- 검증 단계의 ZIP artifact 약 70~80 GB 규모 유지
- 빌드 결과물은 사내 Nexus repository에 metadata와 함께 보존

<!--
발표자 노트
binary caching: VCPKG_BINARY_SOURCES로 설정. 동일한 ABI hash면 빌드 없이 캐시에서 복원.
asset caching: X_VCPKG_ASSET_SOURCES로 mirror 설정. upstream 다운로드가 사라지거나 변조되는 경우에도 대비, air-gapped 환경 지원.
검증 산출물 70-80GB. 결과물은 Nexus에 metadata와 함께 보존해 추적 가능하게 유지.
참고 https://learn.microsoft.com/en-us/vcpkg/consume/binary-caching-overview
참고 https://learn.microsoft.com/en-us/vcpkg/concepts/asset-caching
-->

---

# 마무리

<div style="height:6px;width:120px;background:#2b6cb0;margin-top:22px;"></div>

<p style="font-size:26px;color:#5f6368;margin-top:18px;">종결이 없는 여정, 그러나 자산으로 남는 것</p>

<!--
발표자 노트
섹션 전환. 교훈, 예시, 보험 모델의 한계, 결론 순.
-->

---

# 교훈: 결국은 도구 이해도

이해도가 높아지지 않으면 빠르게 한계가 찾아온다

- 공급망 기여에서 접하는 문제 영역이 넓기 때문
- 질문에 대해 사고하는 것을 도와주기 때문

예를 들어, 다음 질문들에 답해본다면?

<!--
발표자 노트
공급망 기여는 문제 영역이 넓어 도구 이해도가 한계선이 된다. 이해도는 답보다 질문을 사고하는 힘을 길러준다.
-->

---

# 예: S-BOM 요구

"우리 C++ 프로젝트의 Software Bill of Materials를 제출하세요"

- vcpkg가 이미 기능 지원
- 설치할 때마다 SPDX 문서 자동 생성
- `installed/<triplet>/share/<port>/vcpkg.spdx.json`

<!-- _footer: '참고: vcpkg Software Bill of Materials 문서' -->

<!--
발표자 노트
S-BOM 요구는 흔해지고 있다. vcpkg는 이미 SBOM 기능을 지원한다.
참고 https://learn.microsoft.com/en-us/vcpkg/reference/software-bill-of-materials
-->

---

# 예: XZ Utils 백도어 (2024)

liblzma 5.6.0 / 5.6.1에 백도어 삽입 (CVE-2024-3094)

같은 사건이 다시 일어난다면?

1. 안전한 버전으로 port 수정
2. registry 갱신 (versions + baseline)
3. 소비자는 baseline 교체만으로 안전 버전 전파

<!-- _footer: '참고: XZ Utils backdoor, en.wikipedia.org' -->

<!--
발표자 노트
XZ Utils 백도어 사건. registry가 있으면 안전 버전으로 port를 고치고 즉시 갱신해 전파를 차단한다.
참고 https://en.wikipedia.org/wiki/XZ_Utils_backdoor
-->

---

# 예: 오래된 도구 재현

"3년 전 빌드 도구로 다시 빌드해주세요"

1. 도구 설치 (구버전 SDK, 컴파일러)
2. vcpkg triplet 작성: 도구 버전 고정
3. 새 triplet에서 실패하는 port만 확인, 수정

개인기가 아니라 절차로 대응한다

<!--
발표자 노트
과거 도구 재현 요청도 triplet 작성과 실패 port 확인으로 대응. 개인기가 아니라 절차로 처리된다는 점이 핵심.
-->

---

# 보험 모델의 한계

보험 상품이 있어도, 가입하지 않으면 의미가 없다

- 층위와 규모를 키우면 → 결국 조직 수준에서 Why, What, How 정의 필요
- 제품 관련 패키지를 모두 관리할 수 있다는 것은 허상(Fantasy)
- 목적(Why)은 어디까지나 **관리 가능한 수준의 유지**
- 패키지 매니저 도입과 생태계 구성(What, How)
  = build management 비용을 **registry라는 자산으로 변환**하는 방법

<!--
발표자 노트
보험이 있어도 가입 안 하면 소용없다. 층위와 규모가 커지면 개인이 아니라 조직 수준의 Why-What-How 정의가 필요해진다.
모든 패키지를 관리한다는 건 허상. 목적은 관리 가능한 수준 유지이고, 패키지 매니저와 생태계는 그 비용을 registry라는 자산으로 바꾸는 수단.
-->

---

# 결론

근본적으로 이 문제에는 종결 조건이 없다.
계속 변하는 도구와 소프트웨어의 흐름을 따라가는 과정

- OSS가 만들어가는 생태계를 **받아들이고, 복제하고, 운영**하면
- 그 흐름을 더 쉽게 사용할 수 있다
- 소프트웨어를 지속적으로 사용 가능한 자산으로 만들 수 있다

<!--
발표자 노트
종결이 없는 여정. 그러나 OSS 생태계를 수용-복제-운영하면 흐름을 더 쉽게 탈 수 있고,
소프트웨어를 지속 사용 가능한 자산으로 만들 수 있다.
-->

---

# 다시, 첫 질문

> 우리 팀에서 만드는 제품을,
> CLI 명령 또는 설정파일 N줄로 사용할 수 있어야 하지 않나?

<!--
발표자 노트
시작 질문으로 되돌아와 수미상관으로 닫는다.
-->

---

# 감사합니다

박동하, C++ Korea User Group
luncliff@gmail.com

<!--
발표자 노트
Q&A. 공개 버전 다운로드 청중을 위해 각 슬라이드 노트에 상세 내용과 참고 URL을 남겨두었다.
-->
