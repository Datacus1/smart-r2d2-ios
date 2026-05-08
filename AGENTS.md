# Agent Guidance

## iPhone UI Target

- Primary test device: regular iPhone 16.
- Native display resolution: 2556 x 1179 pixels.
- Treat the portrait SwiftUI layout as roughly 393 x 852 points at 3x scale.
- Treat the landscape SwiftUI layout as roughly 852 x 393 points at 3x scale.
- All main remote UI work should be checked against both portrait and landscape point canvases before delivery.

## Layout Rules

- Keep interactive controls out of the iPhone safe areas.
- Do not place top controls at the physical screen top; use safe-area-aware layout.
- Prioritize the main physical controls in this order: drive, head, lights, connection state.
- R2-D2 artwork may be used as a muted background layer, but controls must remain clearly legible over it.
- Keep primary touch targets at least 44 x 44 points.
- Avoid overlapping controls, especially in the head, drive, light, and action dock areas.
- Advanced controls should live in sheets or drawers when possible so the main remote stays uncluttered.

## Lessons Learned

### 2026-05-08 Portrait Remote Regression

- The polished remote redesign was reviewed against the iPhone 16 landscape canvas, but the app also renders a portrait path. Portrait must be treated as a first-class layout, not as a fallback.
- Do not reuse landscape-only fixed widths in portrait. The failed layout combined a 448-point drive pad, a 238-point light dock, and a roughly 430-point horizontal action dock inside a 393-point portrait canvas, which caused horizontal clipping and partial off-screen buttons.
- Do not center the full portrait control stack by accident. A centered stack created a large empty band under the safe-area top bar and pushed the actual controls into the middle/lower screen.
- Muted R2-D2 artwork can sit behind controls, but translucent panels over bright artwork reduce legibility. Add a stronger local scrim or move artwork away from active controls when readability drops.
- Before grading or shipping UI changes, capture screenshots for regular iPhone 16 portrait and landscape, then check all four edges, the safe area, touch target size, label readability, and whether every control is fully visible.
- Prefer responsive layouts for primary controls: geometry-aware widths, compact portrait variants, `ViewThatFits`, adaptive grids, or clamped frames based on available width. Avoid any main-screen component wider than the current safe-area content width.
