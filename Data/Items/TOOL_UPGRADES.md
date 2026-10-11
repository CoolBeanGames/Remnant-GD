# Fan and broom attachments

These are Mechanics upgrades applied to future ordinary store fans and push brooms, not extra standalone tools. Delivery captures upgrade booleans in the item's `upgrade_base_values`; older tools retain their purchase-time capabilities. Progression/catalog prices are authored in `Data/Computer`.

## Fan

`Scripts/Actors/fan.gd` extends `switchable_prop` and retains the existing fan scene, mesh/blade animation, optional pooled spatial audio, ghost placement, wheel/R held rotation, E power toggle and normal player airflow. `vacuum_enabled` and `swivel_enabled` default false. Upgrading does not turn suction or automatic sweep on by itself.

- **H / `toggle_fan_mode`** switches an upgraded fan between blowing and suction, while held or looked at. `vacuum_mode` is saved independently from `powered`.
- **G / `empty_tool`** drops the catch bag's actual contents from the underside, with zero launch velocity. Items keep their wrapper, score component, materials, note identity and persistent item ID. The bag has a configurable eight-item capacity.
- **J / `toggle_fan_swivel`** starts/stops an upgraded fan's sweep. Sweep runs only when placed, powered, and outside a carried assembly. `swivel_axis`, `swivel_stop_degrees` and `swivel_period` author its local axis, stops and cycle duration. Default sweep is Y, ±35 degrees over six seconds. Held rotation remains on its selected local axis.

`Scripts/Actors/fan_vacuum.gd` (`fan_vacuum`, Node3D) is instanced as `Vacuum` through `Scenes/Actors/fan_vacuum.tscn`. It contains the visible primitive nozzle/open-bottom catch bag and an `Intake` Area3D. Exports: `suction_force`, `reach`, `capture_distance`, `capacity`. Heavier objects have shorter effective reach, and ray occlusion prevents suction through walls. Only loose processable items fit the bag; machine-immune tools are excluded. Small bottles and notes remain intact and can be read normally after release. Full bags stop pulling.

Captured bodies stay under their original parents, temporarily freeze and disable their own colliders. Their saved original collider masks are remapped when crossing a portal. Carry discovery applies the existing transparency treatment to them. Emptying or deleting/culling the fan restores normal physics. Recently emptied objects temporarily ignore the fan body and cannot immediately be recaptured until they leave its clearance radius.

Public fan APIs: `get_carried_bodies()`, `portal_transform_contents(pose_map, inside)`, `get_tool_state() -> Dictionary`, `restore_tool_state(state, actor_resolver)`. Tool state includes persistent actor ID/body path/local pose for each contained object plus swivel phase/base/support pose. Restore after all WorldState actors and placed supports exist; the resolver returns the tracked actor for an ID. Restoration ignores missing actors and never instantiates copies. Save the `vacuum_enabled`, `vacuum_mode`, `swivel_enabled`, `swivel_active` properties as well.

When mounted on an attachment chain containing a host with `apply_drive_impulse(Vector3)`, a powered blower supplies an opposite airflow reaction impulse (`reaction_force`, default 8). A rail slider projects this onto its rail direction. Free fans do not gain recoil; held/carried and suction-mode fans do not drive sliders.

## Push broom

`Scripts/Actors/push_broom.gd` remains an equippable RigidBody3D: F equip/drop, LMB push, no throwing or building. `side_skirt_enabled` reveals `SideSkirts` and enables direct-body `LeftGuard`/`RightGuard` collision shapes in `Scenes/Actors/push_broom.tscn`. While pushing, `gathering_acceleration` dampens outward lateral velocity and gently gathers items toward the head centre. Base push strength and speed cap remain unchanged.

## Verification

Script identities: `fan.gd` uid://ixf0wp2jrttr (extends switchable_prop), `fan_vacuum.gd` uid://cqx4qes4goel7 (class fan_vacuum, Node3D), `push_broom.gd` uid://r4obti7uqlw6 (RigidBody3D). None is an autoload; no new signals. Runtime vacuum state is contents/released weak-body snapshots; fan state adds phase/base pose; broom retains held/stroke state and adds gathering_acceleration. New scene dependencies are fan_vacuum.tscn plus the updated fan/push_broom prefabs.

Run `Tests/approved_tools_test.tscn` for real suction/capture, original wrapper and score preservation, idempotent restore, zero-impulse emptying, portal masks, fan removal release, opposite rail reaction and carry suppression, single-axis swivel stops/power pause, and physical visible broom guards/lateral gathering. Existing manual props, carry attachments, prop placement and manual expansion suites cover normal fan/plate/basket controls.
