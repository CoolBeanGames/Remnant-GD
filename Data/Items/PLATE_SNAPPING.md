# Steel plate edge snapping

Ghost-build a held plate with **B**, aim near a placed plate's **left, right, top or bottom edge**, then press **B** again. The new sheet aligns to that edge. Aim at the centre to retain ordinary bottom-to-surface anchoring. Floor, wall and ceiling placement remain available. **F** cancels and restores the held angle; **Q** retrieves a placed plate through the usual pickup system.

**Wheel / R** retain local-axis rotation. For a folded side join use Y; for a folded top/bottom join use X. R cycles axes. The joining edge must remain parallel to the host edge; a twisted or obstructed join shows a red ghost. Quarter-turns in the sheet's plane can change which incoming edge connects. Normal and legacy upgraded plate scenes share this behavior.

## Configuration and API

`Scripts/Actors/steel_plate.gd` defines `steel_plate`, extending `rotatable_item` (UID `uid://cf1dhjmiefxo5`). It is the root script on `Scenes/Actors/steel_plate.tscn`; `upgraded_steel_plate.tscn` inherits it. No autoload or additional signals.

| Export | Default | Meaning |
| --- | --- | --- |
| edge_snap_enabled | true | Allows edge snapping on both incoming and target plates. |
| edge_snap_distance | 0.55 m | Band measured inward from each physical edge; the smaller value of the two plates applies. |
| edge_gap | 0.015 m | Minimum solid clearance at a join; the larger value of the two plates applies. |

The on-ready `plate_collision` references **PlateCollision**. Its `BoxShape3D.size` and local transform supply the physical sheet's XY edges and Z thickness. Resizing or offsetting this collider moves the snap geometry automatically. Keep it a thin box; other shape types fall back to ordinary surface placement. The imported art and materials are unchanged.

`get_placement_pose(host, hit_position, normal, rotation) -> Dictionary` plugs into the existing `prop_placement` provider. Empty means ordinary anchoring. A valid result supplies the new Transform3D and host plate; `valid=false` rejects a join. `from_collider(Node3D) -> steel_plate` resolves child colliders. Runtime state otherwise comes from `rotatable_item`: held/placed, rotation axis/basis, weak support and relative support pose.

Geometry is calculated only while the build preview queries it. The pose aligns edge centres/tangents and keeps the entire incoming collision box outside the host edge, including the thickness exposed by 90-degree folds. Existing shape clearance queries reject occupied edges and scenery. Carried/removed targets and circular support chains cannot accept joins.

## Carry, save and removal

Edge joins use the host plate as their support. They therefore follow it when moved and ride with its entire assembly when picked up; attached physics turn off and carry transparency follows the shared pickup system. Dropping restores collision without removing joins. Q detaches the selected plate and its own descendants. Removing a support releases its remaining attachments.

Existing `WorldState`/`SaveGame` records retain original actors, transforms and support IDs. Continue resolves all supports after loading the actors. No separate connection registry or duplicated plate is saved. Existing plate saves load the new root script while retaining their placements and upgrades.

## Verification

`Tests/plate_edges_test.tscn` exercises production ray hits and B events on all four edges, wheel-driven folds, occupied-edge rejection, assembly pickup/drop, real disk save/restore, Q retrieval, host removal, translated/tilted hosts, collider resize/offset, 45/90-degree folds and circular/twisted join rejection. Optional `capture_directory` produces actual rendered joins/ghost and the initial in-world Store; it stays empty in ordinary tests. Related checks: prop_placement, carry_attachment, computer, approved_upgrades and issue_batch.
