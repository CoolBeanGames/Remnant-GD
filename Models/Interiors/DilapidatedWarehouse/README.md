# Linked warehouse presentation

[warehouse_assembly.blend](warehouse_assembly.blend) assembles the independent
warehouse shell, six new prop sources and four reused furniture sources with
**17 relative collection instances**. The architecture, machines, office props
and presentation rig remain separate. Editing a linked source updates its uses.

The floor includes two presses, two lathes, a failed compressor, two electrical
cabinets and four scattered pallet/barrel/rubble arrangements. The upper office
has its separate desk plus the existing armchair, telephone, mail and trash bin.
The office deck, support columns, stairs and catwalk are architecture.

Keep the repository directory structure when moving the source. This folder has
.gdignore: the combined native preview is not an automatically imported gameplay
scene. Individual engine GLBs live beside their independent architecture/prop
sources. Presentation dust, paving, cameras and lighting stay outside exports.

assembly_manifest.json lists every instance, source collection, transform and
view. verification.json records structural export checks and SHA-256 hashes of
all delivered native files, GLBs and final PNGs. The saved scene is complete with
the production-hall camera active at 1800 × 1200; no cutaway visibility is saved.

The [architecture authoring guide](../../Architecture/DilapidatedWarehouse/README.md)
documents reproduction, portable/native checks and actual Godot import tests.
[The gallery](../../../Reports/Warehouse/index.html) includes six room views and
three independent angles for each new prop. These are actual Blender Cycles
renders, with every final image visually reviewed.
