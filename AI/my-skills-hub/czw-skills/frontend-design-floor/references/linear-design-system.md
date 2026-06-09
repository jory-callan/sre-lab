
# Linear 风格设计系统参考

## 快速颜色参考
- Primary CTA: Brand Indigo (`#5e6ad2`)
- Page Background: Marketing Black (`#08090a`)
- Panel Background: Panel Dark (`#0f1011`)
- Surface: Level 3 (`#191a1b`)
- Heading text: Primary White (`#f7f8f8`)
- Body text: Silver Gray (`#d0d6e0`)
- Muted text: Tertiary Gray (`#8a8f98`)
- Subtle text: Quaternary Gray (`#62666d`)
- Accent: Violet (`#7170ff`)
- Accent Hover: Light Violet (`#828fff`)
- Border (default): `rgba(255,255,255,0.08)`
- Border (subtle): `rgba(255,255,255,0.05)`

## 字体
- Primary: Inter Variable (with `cv01`, `ss03` features)
- Mono: JetBrains Mono
- Signature weight: 510 (between regular and medium)

## 快速组件模板

### Ghost Button
```css
background: rgba(255,255,255,0.02);
border: 1px solid rgba(255,255,255,0.08);
border-radius: 6px;
```

### Card
```css
background: rgba(255,255,255,0.02);
border: 1px solid rgba(255,255,255,0.08);
border-radius: 8px;
```

## 关键原则
- 不要使用纯白色 `#ffffff` 作为主文本，使用 `#f7f8f8`
- 按钮背景保持近乎透明 (rgba white at 0.02-0.05)
- 品牌靛蓝色只用于主要 CTA 和交互强调
- 边框总是半透明白色，不要在深色背景上用实色深色边框

完整设计系统见 `popular-web-designs` 技能的 `templates/linear.app.md`
