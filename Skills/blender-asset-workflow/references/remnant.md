# Remnant Blender authoring

Use only when working in Remnant-GD. Read the current AGENTS.md, guide.txt, README and relevant asset guide; those remain authoritative. Inspect .issues/inbox at the start and actually view screenshots of pending F1 reports.

The existing studio apartment is a standalone unfurnished art test under Models/Architecture/StudioApartment, with Source/studio_apartment.blend, a metre-scale Y-up GLB, packed original textures, manifest and four actual renders in Reports/StudioApartment. It is not installed in testing_level and has no Godot physics colliders. Read its README before editing.

Tools/model_studio_apartment.py is a reproducible Blender authoring example with named architecture/presentation collections, real apertures, portable PBR maps, selectable render views and architecture-only export. Tools/make_apartment_newspaper.py authors original print textures using Pillow and NumPy. Source/, Textures/ and render folders use .gdignore to avoid duplicate authoring imports; preserve the existing GLB import UID and compression settings.

For new rooms with props, use separate room and item sources/exports, then link or instance them into an assembly for rendering. The old unfurnished shell is an example to extend within scope; this skill alone is not a request to rebuild existing assets or add furniture.

Actual Blender renders use a separate light/backdrop/dust rig. The newspaper gaps are geometry; reproducing the shafts in Godot needs engine lighting and volumetrics. Preserve that distinction in summaries.

The project's configured Godot workflow covers README, offline wiki content/sidebar/search, timestamped guide, HTML/Notion summaries, Windows builds and verified GitHub pushes after meaningful work. Follow Skills/godot-project-workflow/SKILL.md and its delivery reference when performing those steps. Keep the established owner-private summary audience and local issue/save data private. Other projects must not reuse these destinations.
