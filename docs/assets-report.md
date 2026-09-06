# Original asset generation report

All assets in this set are original procedural constructions. The models use Blender primitives and custom materials; the WAV files are entirely synthesized by `tools/create_assets.py` with Python's standard library. No external or copyrighted asset data is used.

## Models

Blender 5.2.1 LTS generated the source `.blend` files and exported binary glTF with `export_yup=True`. Geometry is authored Z-up. Character facial details are placed on Blender −Y, and the gameplay locomotion axis is Godot +X. Origins are at ground level in the exported scenes; character limb object origins are moved to shoulder/hip pivots before parenting.

| Asset | GLB size | Imported bounds (X × Y × Z) | Imported minimum | Mesh objects |
|---|---:|---:|---:|---:|
| `doll.glb` | 208,100 B | 0.674 × 0.502 × 1.250 | -0.337, -0.262, -0.000 | 24 |
| `keeper.glb` | 250,808 B | 1.130 × 0.802 × 3.580 | -0.565, -0.520, 0.000 | 29 |
| `crate.glb` | 101,204 B | 1.000 × 1.000 × 1.050 | -0.500, -0.500, 0.000 | 13 |
| `fuse.glb` | 41,900 B | 0.230 × 0.230 × 0.300 | -0.115, -0.115, 0.000 | 4 |
| `toy_train.glb` | 150,056 B | 1.800 × 0.830 × 0.840 | -0.670, -0.415, -0.010 | 19 |
| `spool.glb` | 120,620 B | 0.780 × 0.780 × 0.703 | -0.390, -0.390, 0.000 | 11 |

Object names verified after importing each GLB:

- **doll:** `ArmL`, `ArmR`, `Body`, `ButtonEyeL`, `ButtonEyeR`, `ButtonHoleL`, `ButtonHoleL.001`, `ButtonHoleR`, `ButtonHoleR.001`, `FaceSeam0`, `FaceSeam1`, `FaceSeam2`, `FootL`, `FootR`, `HandL`, `HandR`, `Head`, `LegL`, `LegR`, `MouthStitch0`, `MouthStitch1`, `MouthStitch2`, `ScarfKnot`, `ScarfTail`
- **keeper:** `ApronBar0`, `ApronBar1`, `ApronBar2`, `ApronBar3`, `ApronBar4`, `ArmL`, `ArmR`, `Body`, `ChestCage`, `ClawL`, `ClawR`, `CrownGear`, `DarkApron`, `EyeSocketL`, `EyeSocketR`, `FootL`, `FootR`, `Head`, `KneeL`, `KneeR`, `LampEyeL`, `LampEyeR`, `LegL`, `LegR`, `MaskBrow`, `MaskJaw`, `MaskNose`, `ShoulderL`, `ShoulderR`
- **crate:** `Body`, `Corner_-0.445_-0.445`, `Corner_-0.445_0.445`, `Corner_0.445_-0.445`, `Corner_0.445_0.445`, `CrossBackA`, `CrossBackB`, `CrossFrontA`, `CrossFrontB`, `Frame0`, `Frame1`, `Frame2`, `Frame3`
- **fuse:** `Body`, `BrassCap`, `Core`, `GripRing`
- **toy_train:** `Body`, `Boiler`, `Cab`, `CabRoof`, `Chimney`, `Cowcatcher`, `HubL0`, `HubL1`, `HubL2`, `HubR0`, `HubR1`, `HubR2`, `Smokebox`, `WheelL0`, `WheelL1`, `WheelL2`, `WheelR0`, `WheelR1`, `WheelR2`
- **spool:** `Body`, `BottomFlange`, `BrassPeg`, `ThreadCoil0`, `ThreadCoil1`, `ThreadCoil2`, `ThreadCoil3`, `ThreadCoil4`, `ThreadCoil5`, `ThreadCoil6`, `TopFlange`

## Audio

| Asset | Duration | Format | Size |
|---|---:|---|---:|
| `ambient.wav` | 12.00 s | mono, 16-bit PCM, 44,100 Hz | 1,058,444 B |
| `chase.wav` | 8.00 s | mono, 16-bit PCM, 44,100 Hz | 705,644 B |
| `step.wav` | 0.34 s | mono, 16-bit PCM, 44,100 Hz | 30,032 B |
| `push.wav` | 0.80 s | mono, 16-bit PCM, 44,100 Hz | 70,604 B |
| `pickup.wav` | 0.58 s | mono, 16-bit PCM, 44,100 Hz | 51,200 B |
| `switch.wav` | 0.42 s | mono, 16-bit PCM, 44,100 Hz | 37,088 B |
| `caught.wav` | 1.55 s | mono, 16-bit PCM, 44,100 Hz | 136,754 B |
| `win.wav` | 2.50 s | mono, 16-bit PCM, 44,100 Hz | 220,544 B |

The 12-second ambient and 8-second chase beds use periodic low machinery tones whose frequencies complete whole cycles at the loop boundary. Bell events and mechanical ticks decay before the boundary. One-shots begin and end under controlled envelopes. Every file is peak-normalized below full scale and soft-clipped to avoid harsh digital peaks.

## Verification

- Blender completed all six `.blend` saves and six GLB exports without errors.
- Every GLB was cleared from the scene, re-imported, and inspected independently.
- `doll.glb` and `keeper.glb` contain `Body`, `Head`, `ArmL`, `ArmR`, `LegL`, and `LegR` mesh nodes.
- Imported bounds have their lowest point at or near Z=0; decorative bevels may extend a few millimetres below the nominal floor.
- WAV headers, channel count, sample rate, durations, and non-empty sizes were read back with the standard `wave` module.

## Concerns

Godot may uniquify a node name only if an importer or inherited scene adds a collision; the raw GLBs import with the names listed above. Animation pivots are stored on character limb nodes, but no armature or baked animation is included because gameplay drives the limbs procedurally. Emission appearance depends on the Godot environment's glow settings.
