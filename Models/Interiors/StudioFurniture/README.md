# Worn studio furniture

Seventeen requested furniture assets plus a separate kitchenette cabinet/counter
unit. Every asset has its own editable native file, packed maps and metre-scale
Y-up GLB. Front is Blender -Y; up is Z. Origins are bottom-centred, except the sink
which inserts at countertop height and extends below that plane.

| Asset | Editable Blender source | Engine export | Blender bounds (X × Y × Z) |
| --- | --- | --- | --- |
| Bookshelf | [bookshelf.blend](Bookshelf/Source/bookshelf.blend) | [bookshelf.glb](Bookshelf/bookshelf.glb) | 0.915 × 0.35 × 1.84 m |
| Armchair | [chair.blend](Chair/Source/chair.blend) | [chair.glb](Chair/chair.glb) | 0.9356 × 0.9756 × 1.0051 m |
| Coffee pot / drip maker | [coffee_pot.blend](CoffeePot/Source/coffee_pot.blend) | [coffee_pot.glb](CoffeePot/coffee_pot.glb) | 0.2319 × 0.255 × 0.36 m |
| Couch | [couch.blend](Couch/Source/couch.blend) | [couch.glb](Couch/couch.glb) | 2.1356 × 0.9756 × 1.0051 m |
| Entertainment center | [entertainment_center.blend](EntertainmentCenter/Source/entertainment_center.blend) | [entertainment_center.glb](EntertainmentCenter/entertainment_center.glb) | 1.417 × 0.47 × 0.656 m |
| Family photo | [family_photo.blend](FamilyPhoto/Source/family_photo.blend) | [family_photo.glb](FamilyPhoto/family_photo.glb) | 0.266 × 0.1301 × 0.26 m |
| Fridge | [fridge.blend](Fridge/Source/fridge.blend) | [fridge.glb](Fridge/fridge.glb) | 0.66 × 0.7775 × 1.64 m |
| Kitchenette cabinetry and counter | [kitchenette.blend](Kitchenette/Source/kitchenette.blend) | [kitchenette.glb](Kitchenette/kitchenette.glb) | 1.82 × 0.651 × 2.3 m |
| Landline phone | [landline_phone.blend](LandlinePhone/Source/landline_phone.blend) | [landline_phone.glb](LandlinePhone/landline_phone.glb) | 0.2721 × 0.3208 × 0.1627 m |
| Microwave | [microwave.blend](Microwave/Source/microwave.blend) | [microwave.glb](Microwave/microwave.glb) | 0.483 × 0.4255 × 0.315 m |
| Pile of mail | [pile_of_mail.blend](PileOfMail/Source/pile_of_mail.blend) | [pile_of_mail.glb](PileOfMail/pile_of_mail.glb) | 0.2754 × 0.1752 × 0.0206 m |
| Potted plant | [potted_plant.blend](PottedPlant/Source/potted_plant.blend) | [potted_plant.glb](PottedPlant/potted_plant.glb) | 0.7488 × 0.7515 × 0.8024 m |
| Sink | [sink.blend](Sink/Source/sink.blend) | [sink.glb](Sink/sink.glb) | 0.5 × 0.47 × 0.6991 m |
| Stove | [stove.blend](Stove/Source/stove.blend) | [stove.glb](Stove/stove.glb) | 0.608 × 0.7256 × 1.106 m |
| Table and two dining chairs | [table_and_chairs.blend](TableAndChairs/Source/table_and_chairs.blend) | [table_and_chairs.glb](TableAndChairs/table_and_chairs.glb) | 1.15 × 1.9835 × 0.9932 m |
| Trash can | [trash_can.blend](TrashCan/Source/trash_can.blend) | [trash_can.glb](TrashCan/trash_can.glb) | 0.4873 × 0.4 × 0.525 m |
| TV | [t_v.blend](TV/Source/t_v.blend) | [t_v.glb](TV/t_v.glb) | 0.66 × 0.5905 × 0.9812 m |
| VCR | [v_c_r.blend](VCR/Source/v_c_r.blend) | [v_c_r.glb](VCR/v_c_r.glb) | 0.43 × 0.293 × 0.0965 m |

The [linked furnished preview](../FurnishedStudio/studio_apartment_furnished.blend)
instances all 18 items and the independent architectural shell. Preserve the
repository directory layout so relative Blender library links resolve. Furniture
is never joined into the room. Presentation lights/cameras/floor/dust are excluded
from the individual GLBs. Doors, the telephone receiver and frame stand retain
local pivots for later animation; no runtime animations or collisions are added.

Materials use original albedo, tangent-normal and roughness PNGs in Textures/,
packed into each native source and embedded into GLB. Metal and glass have deliberate
Principled PBR settings. Mail print and product labels are original typography.
family_photo.png is an AI-generated fictional photograph, used only as the framed
picture texture. No external licensed models or downloaded texture libraries.

Rebuild with Tools/make_studio_furniture_textures.py (Python/Pillow/NumPy), then
Tools/model_studio_furniture.py in Blender. --assets all, --samples 64 and --width
1000 reproduce the delivered assets and three view PNGs per item. --no-render is
available for export-only rebuilds. Tools/assemble_worn_studio.py ages the room
shell and links the furniture into its native preview, then renders four room views
at 1800 pixels wide. Rebuild the room shell first with model_studio_apartment.py
when structural changes are desired. The assembly ageing pass is idempotent.

Before first engine import, run Tools/configure_studio_imports.py to keep embedded
maps inside the imported resources and preserve existing sidecars and UIDs.
Run Tools/verify_studio_furniture.py for file/GLB/UV/material/render checks and
Tools/verify_studio_native.py through Blender for packed-source, pivot/library and
complete-visibility checks. Tests/studio_asset_import_test.gd checks imported mesh
counts, textured surfaces and metre-scale bounds after the Y-up conversion.
Godot editor import and Windows release/startup checks
are also part of delivery. Successful import does not make these props physics-ready.

Reports/StudioFurniture/index.html is a self-contained responsive gallery of every
item and all four room angles. Full PNGs are under Reports/StudioFurniture/<Asset>/
and Reports/FurnishedStudio/. Earlier Reports/StudioApartment renders retain the
unfurnished newspaper-window study as development history.
