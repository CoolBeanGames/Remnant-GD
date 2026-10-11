# Linked hospital assembly

[hospital_assembly.blend](hospital_assembly.blend) contains **50 relative
collection instances**: the independent hospital shell, eight medical prop
libraries and three reused furniture libraries. The architecture, loose props
and presentation rig remain separate. Source edits update every linked use.

Six wards each have two beds, two bedside cabinets and an IV stand. The
treatment room has an examination bed, IV stand and instrument trolley. The
nursing station has its own counter, supply trolley and stored wheelchair,
plus the separately linked telephone, mail and bin. Seven open hinged doors,
a corridor wheelchair and two waiting benches complete the layout.

The saved native model retains all walls and ceiling panels, with the long
corridor camera active at 1800 × 1200. The overhead render uses a temporary
cutaway only. `.gdignore` keeps the combined native preview out of automatic
Godot imports. Individual GLBs live beside their independent sources.

`assembly_manifest.json` records all source paths, collection names and
placement transforms. `verification.json` contains export/native/render
evidence and SHA-256 records. Preserve relative source directories when moving
the asset set. The [architecture authoring guide](../../Architecture/DilapidatedHospital/README.md)
documents reproduction, meaningful geometry checks and engine limits.

[The gallery](../../../Reports/Hospital/index.html) contains eight actual room
views and three angles for each new prop. Godot integration still requires
gameplay placement, collision, navigation and lighting setup.
