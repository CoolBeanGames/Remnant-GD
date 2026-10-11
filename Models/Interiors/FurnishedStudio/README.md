# Linked furnished studio preview

studio_apartment_furnished.blend instances the architectural shell and 18 independent furniture collections. Keep this repository’s directory layout when opening it: native library paths are relative. Open each source file to edit its asset; reload libraries to refresh a running Blender session.

assembly_manifest.json records every source, transform, render camera and sampling/device configuration. The preview contains presentation lights, cameras, a backdrop and dust; these are not part of the individual GLBs. The source opens with complete walls/ceiling and the living view at 1800 × 1200. Cutaway visibility is temporary during rendering and never saved into the final file.

verification.json records the completed native/export/import/render checks and SHA-256 hashes for 98 delivered source, export and render files. All 59 delivered PNGs were visually opened. HTML links, embedded images and filtering were checked; browser preview was unavailable on this host.

Rebuild with Tools/assemble_worn_studio.py after the furniture builder. Reports/FurnishedStudio has five actual Cycles PNGs; Reports/StudioFurniture/index.html is the complete responsive room/prop gallery. See ../StudioFurniture/README.md for sources, pivots, maps and exports. This preview has no Godot physics, gameplay scripts, autoloads, UIDs, signals or save state.

The current newspaper revision adds the camera Furnished / torn newsprint detail. The room shell has 48 independent clippings; the preview still links the same 19 room/furniture collections.
