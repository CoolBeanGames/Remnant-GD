---
name: blender-asset-workflow
description: Create or edit realistic textured environments and props in Blender, keep room and item assets separate, and finish with reviewed renders from multiple angles. Use for actual 3D modelling and Blender asset work, rather than raster concept images.
---

# Blender asset workflow

Create editable, textured 3D assets and show the finished result through actual Blender renders. The user's defaults are realistic environments, textures on every new model, separate room and item assets, and multiple rendered angles at completion. Current explicit art direction takes precedence.

## Start from the project and source

Read the project's instructions, asset guides and relevant source before modelling. Follow any local issue-report workflow, including viewing submitted screenshots. Discover the installed Blender version and available renderer/device; use that installation through scripting or an available Blender connector. Preserve existing source, materials, dimensions and designer transforms when extending a model.

Determine the intended scale, use and art direction from the request and surrounding project. Make routine design choices without stopping for approval. Keep the task's output in its own asset directory and preserve unrelated scene content.

For Remnant-GD, read [references/remnant.md](references/remnant.md). Other projects use their own folders and delivery instructions.

## Model rooms and items separately

- When creating a room, author its shell in its own .blend asset: floor, walls, ceiling, structural openings and architectural trim. Use real window/door openings, plausible thicknesses, human scale and usable clearances.
- Author each distinct item or prop as an independent asset in its own .blend file, with a named collection, local origin/pivot, materials and export. Furniture, machines, movable doors and objects placed inside a room remain reusable independently of the room.
- Assemble the presentation scene with linked assets or collection instances. Keep the room, each prop and the presentation rig in separate named collections. Store item placement on instances; retain each item's local coordinates for reuse.
- Export the room and props separately when exports are part of the task. A combined preview scene is useful alongside those assets. Joining room geometry must not bake loose props into the shell.
- Keep movable subparts separate with useful pivots, such as a door hinge or fan blade centre. A functional or animated part needs more than a visually correct silhouette.

## Finish surfaces and materials

Texture every new model. Finish UVs and a coherent material setup before delivery; avoid untextured grey placeholders. Use scale-correct base colour maps and the normal, roughness or metallic detail needed for the intended surface. Glass, polished metal and other simple surfaces can use deliberate physically based material settings within the finished textured asset.

Use believable proportions, small edge bevels, material variation and restrained wear. Wood grain, tiles, paper print and other directional details must have sensible scale and orientation. Keep imperfections consistent with the environment instead of covering every surface with the same noise.

Preserve supplied textures and material assignments; inspect embedded or nearby image maps before replacing them. Use original maps or appropriately licensed assets and record external sources. Pack textures into native deliverables or provide a complete portable texture directory. A procedural shader must be baked to supported maps when the target export cannot reproduce it.

Read [references/textures-and-export.md](references/textures-and-export.md) for procedural image generation, portable PBR export or game-engine delivery.

## Render and review multiple angles at completion

Use actual renders of the final model. Finish with at least three distinct useful views, typically four for a room: a complete overview or temporary cutaway, two complementary views at human eye height, and a detail/interior view that exposes important materials or geometry. For a prop, show front/three-quarter, opposite/rear, and another angle that reveals its construction. Cover every newly created asset; assembling props into a room does not replace an independent prop view when its shape is obscured.

Set up plausible light sources, appropriate exposure and colour management. Use Cycles for realistic presentation when available, with a supported GPU or CPU fallback. Iterate with quick previews, then render final images at a useful resolution and sufficient samples/denoising. Keep cameras, presentation lights, backdrop and atmospheric effects separate from exported assets.

Open and visually inspect **every final image**. Check framing, hidden or intersecting geometry, mirrored print/UVs, texture scale, missing/black materials, light leaks, noise and excessive haze. Refine observed problems and re-render affected views. Successful command exit or finding an image file does not count as visual review.

Use temporary visibility changes for cutaways and restore the full model. Save the editable source with the intended complete scene, a useful default camera, and matching render aspect. Preserve named cameras so the views can be reproduced. Screenshots or AI concept images cannot stand in for final Blender renders.

## Deliver portable, reviewable assets

Provide the editable native model and its textures, separate files for the room and any props created, requested exports, and the reviewed multi-angle images. Preserve reproducible authoring scripts when used. Summarise scale, asset separation, material setup, verification and relevant limits; distinguish Blender presentation lighting from engine-rendered appearance.

When targeting an engine, verify import, bounds, origins, UVs, materials and movable pivots. Keep presentation-only objects out of exports. Collision, gameplay placement and engine volumetric lighting require their own setup and checks.

Follow the current project's documentation, HTML/Notion summary, build and Git preferences where configured. Preserve publication access and report actual outcomes. Standalone Blender work does not authorize importing the room into a game, pushing another project's repository or publishing to Remnant's destinations.
