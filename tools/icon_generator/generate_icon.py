"""알비(Albi) 앱 아이콘 생성 — 위스키 글래스 + 앰버 모티프.

Pillow 로 1024px 아이콘 아트워크를 생성한다 (rsvg/inkscape 부재 환경 fallback).
출력:
- assets/branding/app_icon.png         : 풀블리드 (peat 배경 + 글래스) — iOS/legacy 소스
- assets/branding/app_icon_foreground.png : adaptive 전경 (투명 배경, 글래스 안전영역 중앙)
- assets/branding/splash_logo.png      : 스플래시 로고 (투명 배경, 글래스 + 워드마크 여백)

실행: python tools/icon_generator/generate_icon.py
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "..", "assets", "branding"
)

# 위스키 팔레트 (app_tokens.dart 와 동일 SoT)
PEAT = (21, 17, 13, 255)          # #15110D 배경
AMBER = (224, 168, 87, 255)       # #E0A857 캐스크 골드 (액체)
AMBER_DEEP = (184, 115, 26, 255)  # #B8731A 짐빔 앰버 (액체 깊은부분)
GLASS = (245, 238, 226, 70)       # 유리 (반투명 크림)
GLASS_EDGE = (245, 238, 226, 180)
HIGHLIGHT = (255, 250, 240, 150)


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def draw_glass(draw: ImageDraw.ImageDraw, cx: float, cy: float, scale: float):
    """중앙(cx,cy) 기준 위스키 텀블러 글래스 + 앰버 액체."""
    # 텀블러: 위가 약간 넓은 사다리꼴.
    top_half = 170 * scale
    bot_half = 140 * scale
    top_y = cy - 175 * scale
    bot_y = cy + 205 * scale
    rim_ry = 34 * scale          # 림 타원 반높이
    liquid_ratio = 0.52          # 액체가 차는 높이 비율 (바닥에서)

    # 유리 몸통 (반투명)
    body = [
        (cx - top_half, top_y),
        (cx + top_half, top_y),
        (cx + bot_half, bot_y),
        (cx - bot_half, bot_y),
    ]
    draw.polygon(body, fill=GLASS)

    # 액체 영역 (바닥부터 liquid_ratio)
    liq_top_y = bot_y - (bot_y - top_y) * liquid_ratio
    # 액체 표면에서의 반너비 (선형 보간)
    t = (liq_top_y - top_y) / (bot_y - top_y)
    liq_half = top_half + (bot_half - top_half) * t
    liquid = [
        (cx - liq_half, liq_top_y),
        (cx + liq_half, liq_top_y),
        (cx + bot_half, bot_y),
        (cx - bot_half, bot_y),
    ]
    draw.polygon(liquid, fill=AMBER_DEEP)
    # 액체 그라데이션 느낌 — 위쪽 밝은 앰버 띠
    band = [
        (cx - liq_half, liq_top_y),
        (cx + liq_half, liq_top_y),
        (cx + (liq_half + bot_half) / 2, (liq_top_y + bot_y) / 2),
        (cx - (liq_half + bot_half) / 2, (liq_top_y + bot_y) / 2),
    ]
    draw.polygon(band, fill=AMBER)

    # 액체 표면 타원
    draw.ellipse(
        [cx - liq_half, liq_top_y - rim_ry * 0.7,
         cx + liq_half, liq_top_y + rim_ry * 0.7],
        fill=_lerp(AMBER, HIGHLIGHT, 0.25),
    )

    # 유리 몸통 외곽선
    draw.line(body + [body[0]], fill=GLASS_EDGE, width=int(7 * scale),
              joint="curve")

    # 림(입구) 타원
    draw.ellipse(
        [cx - top_half, top_y - rim_ry, cx + top_half, top_y + rim_ry],
        outline=GLASS_EDGE, width=int(7 * scale),
    )

    # 하이라이트 (좌측 상단 유리 반사 — 짧고 얇게, 액체 위쪽 빈 유리에만)
    hx = cx - top_half * 0.58
    draw.line(
        [(hx, top_y + 40 * scale), (hx - 6 * scale, liq_top_y - 20 * scale)],
        fill=(255, 250, 240, 110), width=int(6 * scale),
    )


def render(with_bg: bool, scale: float, logo_offset_y: float = 0.0) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if with_bg:
        # peat 라운드 배경 + 미묘한 앰버 글로우
        draw.rectangle([0, 0, SIZE, SIZE], fill=PEAT)
        glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([SIZE * 0.2, SIZE * 0.25, SIZE * 0.8, SIZE * 0.85],
                   fill=(224, 168, 87, 60))
        glow = glow.filter(ImageFilter.GaussianBlur(90))
        img = Image.alpha_composite(img, glow)
        draw = ImageDraw.Draw(img)
    draw_glass(draw, SIZE / 2, SIZE / 2 + logo_offset_y, scale)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # 풀블리드 아이콘 (배경 포함)
    render(with_bg=True, scale=1.0).save(os.path.join(OUT_DIR, "app_icon.png"))

    # adaptive 전경 — 안전영역(중앙 ~66%) 안에 들도록 축소
    render(with_bg=False, scale=0.62).save(
        os.path.join(OUT_DIR, "app_icon_foreground.png")
    )

    # 스플래시 로고 (투명, 약간 작게)
    render(with_bg=False, scale=0.8).save(
        os.path.join(OUT_DIR, "splash_logo.png")
    )

    print("아이콘 생성 완료:", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
