# Approved manual automation and lighting

Implementation follows the green approvals on [Item Ideas](https://app.notion.com/p/3f606a7c5a6481e2ad48cc5e67ece82f), plus the user's simpler rail/carriage request. The approved vacuum head, fan swivel mount and broom side skirt are Mechanics upgrades on normal tools. Unmarked complex mechanisms and the flagged spawner batch idea are outside this change.

## Buying upgrades

The catalog remains Data/Computer/default_catalog.tres. Mechanics effects apply only to tools purchased afterward; existing props retain their purchase-time capabilities. Air placement is now a one-time unlock, not another store item. Legacy upgraded_fan/upgraded_steel_plate scenes remain loadable for old saves and existing authoring references.

| Mechanics entry | Cost | Effect on future tools |
| --- | --- | --- |
| fan_air_placement | 600 score | Existing fan supports both B ghost placement and V air locking |
| plate_air_placement | 450 score | Existing plate supports both B ghost placement and V air locking |
| vacuum_head | 200 score | Fan includes switchable suction head and finite catch bag |
| fan_swivel | 150 score | Fan includes optional local-axis sweep |
| broom_side_skirt | 75 score | Broom side guards gather items and reduce sideways scattering |
| light_beam_hood | 100 score | Light illuminates a directional patch |
| light_coloured_lens | 80 score | L cycles the light's colour |

All seven unlocks have one tier. Mechanics presets use target fan/plate/broom/light and bool SET effects. Normal store rows retain their names. No separate Air Fan/Air Plate deliveries remain in the catalog. Train Rail costs 90 score and Rail Slider 65; each purchase increases its own next price by 1.8. Edit these resources to tune costs.

## Controls and assemblies

F/RMB/B/B/F/Q and wheel/R retain normal pickup, throw, ghost placement/retrieval and local-axis rotation. V is shown dynamically when air placement is available. Upgraded fans add H for blow/suction, G for downward bag emptying, J to start/stop sweep. These actions work while holding or looking at the fan, but are suppressed during ghosting and modal menus. Lights with the lens upgrade show L while held or looked at; E still turns them on/off.

Place the straight rail with B, then aim at the rail while ghost-placing the slider. Its preview centres on the rail and aligns with its direction. Aim another rail at a free track end to extend it using the same B/B/F controls. The carriage passes between aligned sections in both directions; connected ends open, while exposed ends retain their stops. A powered fan built onto the slider drives it opposite its airflow, including fans attached indirectly through another prop. Only the rail-axis component creates travel. Held assemblies do not self-propel. Resting deck cargo and placed attachments follow the slider; a basket also preserves its actual contained items and can empty downward. Players standing on the carriage ride with it and can walk or jump off. See Data/Items/RAILS.md.

Light upgrades provide illumination/customisation rather than trigger logic. The beam hood substitutes a SpotLight3D for the ordinary omni light. The coloured lens changes the emitted colour and preserves its choice across saves. No Light Gate sensor or control network is added.

## APIs and persistence

| Script / inheritance | Identity and state | Public API / dependencies |
| --- | --- | --- |
| Scripts/Actors/work_light.gd / switchable_prop | UID uid://41vpi4kluaya; no autoload/signals. Exports beam_hood_enabled, coloured_lens_enabled, lens_index, beam_angle and hood_mount. Runtime beam. | cycle_lens(), get_carry_prompts(), get_look_prompts(); power inherited. Creates HoodBeam/BeamHood on upgraded lights. Scene light.tscn, Settings-independent actual Light3D colour, WorldState, player ray/pickup, prompt resources. |
| Scripts/Actors/rotatable_item.gd / RigidBody3D | UID uid://dc3n6qssprqkg; air_placeable, carry_prompts retained. | get_carry_prompts adds V without replacing configured hints or duplicating a V entry; existing placement/support APIs remain. |
| Scripts/Player/prop_placement.gd / Node | Existing class prop_placement; preview, host and queries. | Optional get_placement_pose(host, hit_position, normal, rotation) hook returns valid/transform/host for rail centring; ordinary placement uses existing clearance. |
| Global/world_state.gd / WorldState autoload / Node | Existing session/item/cache fields. Records tool_state, rail_state, lens/mode/sweep, rail dimensions and cargo links alongside existing data. | capture() and _restore() resolve container IDs only after all actors and placed supports exist. Runtime containment freeze is excluded from permanent body freeze. No object copies are produced. |
| Scripts/Player/player_pickup.gd / player_pickup | Existing held visual/collision/attachment snapshots. | pickup_object releases rail cargo ownership first; new contained meshes get carry transparency once. teleport_held recursively maps attached containers/cargo and remaps their original collider snapshots. |
| Scripts/Computer/upgrade_effect.gd / Resource | Existing class/UID; target adds broom/light. | Bool SET unlocks use existing apply_value(). |
| Scripts/Computer/computer_entry.gd / Resource | Existing class/UID; delivery_kind adds broom/light. | Existing cost() and finite upgrade handling. Progression delivery applies saved mechanics baseline before scene setup. |

Fan/broom authoring, exports and container APIs: Data/Items/TOOL_UPGRADES.md. Rail/carriage authoring, exports and save APIs: Data/Items/RAILS.md. Graphics options and rendering API: Data/OPTIONS.md.

Tests/approved_upgrades_test.tscn covers one-time spending, removal of separate air stock, future-only tool capabilities, live V prompts, directional/coloured lighting, full disk save and restored attachments. Physical fan/broom, carriage/cargo, graphics and existing purchase/placement/carry/portal/save scenes provide complementary checks.
