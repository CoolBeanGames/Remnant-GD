"""Wire prepared spreadsheet art into existing actor identities and memory scenes."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Models/Imported/Trip'


def write(path, value):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(value, encoding='utf8')


def art(name, target=None, offset=0):
    write(target or f'Scenes/Art/Trip/{name}.tscn', f'''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://Models/Imported/Trip/{name}/{name}.glb" id="art"]
[node name="Model" type="Node3D"]
metadata/source_model = "res://Models/Imported/Trip/{name}/{name}.glb"
[node name="Art" parent="." instance=ExtResource("art")]
position = Vector3(0, {offset}, 0)
''')


def item(name, title, mass, mulch, sound):
    info = json.loads((BASE / name / 'asset_manifest.json').read_text())
    x, depth, height = info['dimensions_m']
    art(name, f'Scenes/Art/{name}.tscn', -height / 2)
    prompt = f'Data/Prompts/pickup_{name}.tres'
    if not (ROOT / prompt).exists():
        write(prompt, f'''[gd_resource type="Resource" script_class="prompt_set" format=3]
[ext_resource type="Script" path="res://Scripts/UI/prompt_entry.gd" id="entry"]
[ext_resource type="Script" path="res://Scripts/UI/prompt_set.gd" id="set"]
[sub_resource type="Resource" id="Pickup"]
script = ExtResource("entry")
text = "Pickup {title}"
action = &"pickup"
[resource]
script = ExtResource("set")
entries = Array[ExtResource("entry")]([SubResource("Pickup")])
''')
    write(f'Scenes/Items/{name}.tscn', f'''[gd_scene format=3]
[ext_resource type="Script" path="res://Scripts/Actors/object_manager.gd" id="manager"]
[ext_resource type="Script" path="res://Scripts/Actors/collision_sound_matrix.gd" id="matrix"]
[ext_resource type="Script" path="res://Scripts/Actors/CollisionSoundEntry.gd" id="entry"]
[ext_resource type="Resource" path="res://Data/Collision Sounds/{sound}_all.tres" id="sounds"]
[ext_resource type="Script" path="res://Scripts/UI/object_prompts.gd" id="prompts"]
[ext_resource type="Resource" path="res://{prompt}" id="look"]
[ext_resource type="Script" path="res://Scripts/Actors/score_object.gd" id="score"]
[ext_resource type="PackedScene" path="res://Scenes/Art/{name}.tscn" id="model"]
[ext_resource type="PackedScene" path="res://Scenes/Actors/pickup_target.tscn" id="pickup_target"]
[sub_resource type="BoxShape3D" id="Collision"]
size = Vector3({x + .004:.6f}, {height + .004:.6f}, {depth + .004:.6f})
[sub_resource type="PhysicsMaterial" id="Physics"]
friction = 0.35
bounce = 0.05
[node name="{title.replace(' ', '')}" type="Node3D" node_paths=PackedStringArray("rb") groups=["grindable", "pick-up"]]
script = ExtResource("manager")
start_force = 0.0
rb = NodePath("RigidBody3D")
[node name="Prompts" type="Node" parent="."]
script = ExtResource("prompts")
prompts = ExtResource("look")
[node name="RigidBody3D" type="RigidBody3D" parent="." groups=["pick-up", "score"]]
mass = {mass}
physics_material_override = SubResource("Physics")
continuous_cd = true
contact_monitor = true
max_contacts_reported = 10
script = ExtResource("matrix")
sound_matrix = Array[ExtResource("entry")]([ExtResource("sounds")])
[node name="Model" parent="RigidBody3D" instance=ExtResource("model")]
[node name="CollisionShape3D" type="CollisionShape3D" parent="RigidBody3D"]
shape = SubResource("Collision")
[node name="score_object" type="Node" parent="."]
script = ExtResource("score")
score = 1
mulch_value = {mulch}
[node name="PickupTarget" parent="RigidBody3D" instance=ExtResource("pickup_target")]
[connection signal="body_entered" from="RigidBody3D" to="RigidBody3D" method="collide"]
''')


def replace_ext(path, replacements):
    target = ROOT / path
    value = target.read_text(encoding='utf8')
    for old, name in replacements.items():
        value = re.sub(r'\[ext_resource type="PackedScene"[^\n]*path="res://' + re.escape(old) + r'"([^\n]*)\]', lambda m: '[ext_resource type="PackedScene" path="res://Scenes/Environments/Art/Trip_' + name + '.tscn"' + m[1] + ']', value)
    write(path, value)


def add_instance(path, name, asset, position, rotation=0):
    target = ROOT / path
    value = target.read_text(encoding='utf8')
    if f'[node name="{name}"' in value:
        return
    resource = f'[ext_resource type="PackedScene" path="res://Scenes/Environments/Art/Trip_{asset}.tscn" id="trip_{asset}"]\n'
    if resource not in value:
        value = value.replace('[sub_resource', resource + '\n[sub_resource', 1)
    value += f'\n[node name="{name}" parent="Art" instance=ExtResource("trip_{asset}")]\nposition = Vector3({position[0]}, {position[1]}, {position[2]})\nrotation = Vector3(0, {rotation}, 0)\n'
    write(path, value)


if __name__ == '__main__':
    items = [('baby_bottle', 'Baby Bottle', .12, 1, 'plastic'), ('beer_bottle', 'Beer Bottle', .35, 2, 'glass'), ('clipboard', 'Clipboard', .3, 2, 'book'), ('meat_slab_a', 'Meat Slab', .6, 4, 'book'), ('meat_slab_b', 'Meat Slab', .65, 4, 'book'), ('meat_block', 'Meat Block', .7, 5, 'book'), ('syringe', 'Syringe', .04, 1, 'plastic'), ('book', 'Book', .8, 3, 'book'), ('teddy_bear', 'Teddy Bear', .18, 2, 'teddy_bear')]
    for entry in items:
        item(*entry)
    pool = '[gd_resource type="Resource" script_class="item_spawn_pool" format=3 uid="uid://dudfdiaoxtybp"]\n[ext_resource type="Script" path="res://Scripts/Actors/item_spawn_pool.gd" id="pool"]\n'
    for name, *_ in items:
        pool += f'[ext_resource type="PackedScene" path="res://Scenes/Items/{name}.tscn" id="{name}"]\n'
    pool += '\n[resource]\nscript = ExtResource("pool")\nitems = Array[PackedScene]([' + ', '.join(f'ExtResource("{entry[0]}")' for entry in items) + '])\n'
    write('Data/Items/default_spawn_pool.tres', pool)
    # Keep these actor scene paths for existing saves and inherited air upgrades.
    art('steel_plate', 'Scenes/Art/plate.tscn')
    art('computer')
    art('computer_cart')
    art('mulcher')
    art('mulch_bin')
    art('mulch_pellet')
    replace_ext('Scenes/Environments/furnished_apartment.tscn', {'Scenes/Environments/Art/Couch_couch.tscn': 'couch', 'Scenes/Environments/Art/Chair_chair.tscn': 'lounger', 'Scenes/Environments/Art/TV_t_v.tscn': 'television', 'Scenes/Environments/Art/PileOfMail_pile_of_mail.tscn': 'paper_stack'})
    replace_ext('Scenes/Environments/dilapidated_warehouse.tscn', {'Scenes/Environments/Art/HydraulicPress_hydraulic_press.tscn': 'industrial_machine_a', 'Scenes/Environments/Art/IndustrialLathe_industrial_lathe.tscn': 'industrial_machine_b', 'Scenes/Environments/Art/AirCompressor_air_compressor.tscn': 'industrial_machine_c', 'Scenes/Environments/Art/ControlCabinet_control_cabinet.tscn': 'industrial_machine_c', 'Scenes/Environments/Art/OfficeDesk_office_desk.tscn': 'desk', 'Scenes/Environments/Art/Chair_chair.tscn': 'office_chair', 'Scenes/Environments/Art/PileOfMail_pile_of_mail.tscn': 'paper_stack'})
    replace_ext('Scenes/Environments/dilapidated_hospital.tscn', {'Scenes/Environments/Art/HospitalBed_hospital_bed.tscn': 'hospital_bed', 'Scenes/Environments/Art/Wheelchair_wheelchair.tscn': 'wheelchair', 'Scenes/Environments/Art/WaitingBench_waiting_bench.tscn': 'waiting_chairs', 'Scenes/Environments/Art/HospitalDoor_hospital_door.tscn': 'ward_door', 'Scenes/Environments/Art/PileOfMail_pile_of_mail.tscn': 'paper_stack'})
    add_instance('Scenes/Environments/furnished_apartment.tscn', 'CoffeeTable', 'coffee_table', (0, 0, 1.55))
    add_instance('Scenes/Environments/furnished_apartment.tscn', 'BedroomDesk', 'desk', (6.2, 0, 2.4))
    add_instance('Scenes/Environments/furnished_apartment.tscn', 'EntranceDoor', 'entrance_door', (1.76, 0, 3.15))
    add_instance('Scenes/Environments/furnished_apartment.tscn', 'BathroomDoor', 'bathroom_door', (-2.64, 0, -.75))
    for room, positions in [('warehouse', [(-8, 0, 8), (9, 0, -11), (-9.5, 0, -9), (3, 0, 15)]), ('hospital', [(-7.5, 0, 5), (7.5, 0, -8), (1.6, 0, 9.5), (-1.7, 0, -9)])]:
        for i, pos in enumerate(positions):
            add_instance(f'Scenes/Environments/dilapidated_{room}.tscn', f'GarbageBag {i + 1}', 'garbage_bag_a' if i % 2 == 0 else 'garbage_bag_b', pos, i * .73)
    print('Trip actors and nine-entry random pool wired; test item excluded')
