# 3Lines launcher 원본

`icon.json`이 색과 도형 좌표의 단일 원본입니다. 선택한 B '책등' 시안의 짙은 녹색 `#28332D`와 밝은 회색 `#E5E9DF`를 사용합니다. 왼쪽 책등과 길이가 줄어드는 세 줄을 각진 도형으로 표현합니다. 1024px 원본 캔버스를 Android adaptive layer의 중앙 72dp에 배치하며, 심볼은 중앙 66dp safe circle 안에 있습니다.

저장소 루트에서 macOS 기본 Swift/CoreGraphics로 재생성합니다. Flutter build, 외부 패키지, 원격 생성기는 필요하지 않습니다.

```sh
swift tool/branding/generate_icons.swift
ruby test/tool/release/launcher_assets_test.rb
```

Android 기존 5개 density, iOS/macOS Contents.json의 모든 크기, web favicon/일반/maskable, Windows 6개 크기 ICO를 생성합니다. Android API26부터 배경색과 투명 vector foreground를 분리한 adaptive icon을 쓰고 API33부터 monochrome vector를 제공합니다. 알림에는 배경 없는 단색 `ic_stat_3lines`를 쓰며 리소스 축소 시에도 보존합니다. 낮은 API에서는 opaque legacy PNG를 씁니다. iOS/macOS PNG도 alpha 없는 RGB입니다. Preview 원/둥근사각은 대표 마스크이며 OEM의 실제 런처 표시까지 검증한 것은 아닙니다.

`previews/`의 48/192/1024와 adaptive circle/rounded를 재생성 후 시각 검토합니다. 색 프로필은 sRGB로 고정합니다. 임의 bitmap을 수정하는 도구가 아니라 단순 기하학 vector를 처음부터 렌더하는 코드입니다.
