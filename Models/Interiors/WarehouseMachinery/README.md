# Warehouse machinery and props

Six independent editable assets for the dilapidated warehouse. Blender Z up,
front -Y, metre scale and contact pivots at floor Z=0. GLBs convert to engine Y up.
All used PBR images are packed into the native sources and embedded into exports.

| Asset | Editable source | Separate engine export | Blender X × Y × Z |
| --- | --- | --- | --- |
| Failed air compressor | [air_compressor.blend](AirCompressor/Source/air_compressor.blend) | [air_compressor.glb](AirCompressor/air_compressor.glb) | 2.2564 × 1.5553 × 1.95 m |
| Open electrical cabinet | [control_cabinet.blend](ControlCabinet/Source/control_cabinet.blend) | [control_cabinet.glb](ControlCabinet/control_cabinet.glb) | 1.343 × 1.8248 × 2.2075 m |
| Pallet, barrel and scattered debris | [debris_kit.blend](DebrisKit/Source/debris_kit.blend) | [debris_kit.glb](DebrisKit/debris_kit.glb) | 2.2506 × 1.7231 × 0.923 m |
| Broken hydraulic press | [hydraulic_press.blend](HydraulicPress/Source/hydraulic_press.blend) | [hydraulic_press.glb](HydraulicPress/hydraulic_press.glb) | 3.0522 × 1.975 × 3.68 m |
| Abandoned industrial lathe | [industrial_lathe.blend](IndustrialLathe/Source/industrial_lathe.blend) | [industrial_lathe.glb](IndustrialLathe/industrial_lathe.glb) | 3.8 × 1.3775 × 2.06 m |
| Production office desk | [office_desk.blend](OfficeDesk/Source/office_desk.blend) | [office_desk.glb](OfficeDesk/office_desk.glb) | 1.86 × 0.8215 × 1.06 m |

ControlCabinet retains a five-child door assembly under a named hinge pivot.
Machines have separately modelled rams, chucks, rails, motors and damaged hoses;
these are art subparts, not runtime simulations. DebrisKit keeps its pallet,
barrel, rubble and timber separately selectable within its own reusable collection.
OfficeDesk includes fixed stationery; phone, chair, mail and bin remain separate
existing assets in the linked preview. No lights/backdrop/cameras enter the GLBs.

Run Tools/make_warehouse_textures.py using Python/Pillow/NumPy, then run
Tools/model_warehouse_machinery.py with Blender --background --python-exit-code 1.
Defaults: --assets all --samples 80 --width 1000. --assets accepts comma-separated
keys; --no-render rebuilds sources/exports without PNGs. Every new asset has
front/rear/detail PNGs in Reports/Warehouse/<Key>/ and the responsive gallery.

Tools/model_dilapidated_warehouse.py builds the separate shell and links these
assets into ../DilapidatedWarehouse/warehouse_assembly.blend. Preserve relative
folders. See the architecture README for structure, verification and engine limits.
