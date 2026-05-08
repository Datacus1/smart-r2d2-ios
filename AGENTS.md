# Agent Guidance

## iPhone UI Target

- Primary test device: regular iPhone 16.
- Native display resolution: 2556 x 1179 pixels.
- Treat the landscape SwiftUI layout as roughly 852 x 393 points at 3x scale.
- All main remote UI work should be checked against that landscape point canvas before delivery.

## Layout Rules

- Keep interactive controls out of the iPhone safe areas.
- Do not place top controls at the physical screen top; use safe-area-aware layout.
- Prioritize the main physical controls in this order: drive, head, lights, connection state.
- R2-D2 artwork may be used as a muted background layer, but controls must remain clearly legible over it.
- Keep primary touch targets at least 44 x 44 points.
- Avoid overlapping controls, especially in the head, drive, light, and action dock areas.
- Advanced controls should live in sheets or drawers when possible so the main remote stays uncluttered.
