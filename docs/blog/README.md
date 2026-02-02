# Blog Articles

이 디렉토리는 vcpkg-registry 웹사이트의 블로그 스타일 아티클을 포함합니다.

## Purpose

블로그 아티클은 기술 가이드나 참고 문서와는 구분되며, 다음과 같은 내용을 다룹니다:

- 개인적인 경험과 의견
- 튜토리얼 형식의 긴 형식 콘텐츠
- vcpkg 사용 사례와 베스트 프랙티스 공유
- 커뮤니티 중심의 서사적 내용

## Content Guidelines

### Language
- 주로 한국어로 작성됩니다
- 필요시 영어 번역을 추가할 수 있습니다

### License
- 모든 블로그 아티클은 저장소 LICENSE (CC0-1.0 Universal)를 따릅니다
- 각 아티클에 명시적인 라이선스 표기가 필요하지 않습니다

### Organization vs Technical Documents

**Blog Articles (docs/blog/):**
- 경험 공유 및 의견 기반 콘텐츠
- 긴 형식의 튜토리얼 및 가이드
- 시간에 민감한 콘텐츠 (특정 버전 기준)

**Technical Guides (docs/guide-*.md):**
- vcpkg 포트 생성/업데이트 가이드
- 시스템 유지보수 문서
- 단계별 프로세스 문서

**Tutorials (docs/kr/):**
- 체계적인 학습 경로
- 초급/중급 트랙으로 구성
- 최신 vcpkg 버전 기준

**Reference Materials (docs/references.md, etc.):**
- 빠른 참조 자료
- 링크 모음
- 문제 해결 참고자료

## Adding New Articles

새로운 블로그 아티클을 추가할 때:

1. `docs/blog/` 디렉토리에 `.md` 파일 생성
2. VitePress 설정 파일 (`docs/.vitepress/config.mts`) 업데이트:
   - `nav` 섹션의 'Blog' 아이템에 추가
   - `sidebar`의 'Blog Articles' 섹션에 추가
3. 파일 이름은 영문 소문자와 하이픈 사용 (예: `my-article.md`)
4. Frontmatter에 제목, 날짜 등 메타데이터 포함 고려

## Current Articles

- **vcpkg-for-kor.md** - 레거시 한글 vcpkg 가이드 (2021.12.01 기준)
  - 참고: 새로운 구조화된 튜토리얼은 `docs/kr/` 참조
