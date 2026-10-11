# Independent hospital props

Eight textured metre-scale assets; Blender Z up, local front -Y, floor-contact pivots. GLBs use engine Y up. Each native source packs its used original hospital PBR maps and retains a useful default camera.

| Asset | Editable source | Separate engine export | Blender X × Y × Z |
| --- | --- | --- | --- |
| Bedside cabinet | [bedside_cabinet.blend](BedsideCabinet/Source/bedside_cabinet.blend) | [bedside_cabinet.glb](BedsideCabinet/bedside_cabinet.glb) | 0.69 × 0.891 × 0.925 m |
| Rusted ward bed | [hospital_bed.blend](HospitalBed/Source/hospital_bed.blend) | [hospital_bed.glb](HospitalBed/hospital_bed.glb) | 1.2809 × 2.1468 × 1.3692 m |
| Open hospital door | [hospital_door.blend](HospitalDoor/Source/hospital_door.blend) | [hospital_door.glb](HospitalDoor/hospital_door.glb) | 1.49 × 1.318 × 2.285 m |
| Empty IV stand | [iv_stand.blend](IVStand/Source/iv_stand.blend) | [iv_stand.glb](IVStand/iv_stand.glb) | 0.619 × 0.6556 × 2.1 m |
| Instrument trolley | [medical_trolley.blend](MedicalTrolley/Source/medical_trolley.blend) | [medical_trolley.glb](MedicalTrolley/medical_trolley.glb) | 0.852 × 0.629 × 1.137 m |
| Nursing station counter | [nursing_counter.blend](NursingCounter/Source/nursing_counter.blend) | [nursing_counter.glb](NursingCounter/nursing_counter.glb) | 3.74 × 1.74 × 1.375 m |
| Three-seat waiting bench | [waiting_bench.blend](WaitingBench/Source/waiting_bench.blend) | [waiting_bench.glb](WaitingBench/waiting_bench.glb) | 2.07 × 0.59 × 0.9273 m |
| Abandoned wheelchair | [wheelchair.blend](Wheelchair/Source/wheelchair.blend) | [wheelchair.glb](Wheelchair/wheelchair.glb) | 0.822 × 1.292 × 0.9869 m |

HospitalDoor has a named hinge with ten child parts, open 78 degrees by default. Frame and leaf remain independent meshes. Set the hinge rotation to zero for a closed door. The door is art; gameplay interaction and collision are not attached. Wheelchairs use actual tyre/rim/spoke geometry; bed frames and IV bases have separate casters and tubing. NursingCounter keeps the register and chart rack as local parts. Phone, loose mail and bin are linked separately in the assembled hospital.

Rebuild original maps with Tools/make_hospital_textures.py, then author with Blender Tools/model_hospital_props.py. Defaults: --assets all --samples 80 --width 1000. --assets accepts a comma-separated subset; --no-render writes sources and exports only. Reports/Hospital/<Key>/ contains front/rear/detail PNGs. Preserve sibling source folders for the relative linked hospital_assembly.blend.
