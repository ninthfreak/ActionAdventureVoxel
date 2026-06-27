# Voxel Action RPG — Prototype Slice 1: Movement + Camera

The foundation everything else sits on: a stand-in character moving on a
constrained plane, viewed through an orthographic camera that reads as 2D,
with the camera angle exposed so you can find the look by feel.

## Run it

1. Open Godot 4.x → Import → select the `project.godot` in this folder.
   (If Godot offers to update the project to your version, that's fine — accept.)
2. Press Play (F5). The main scene runs automatically.

## Controls

- Move: WASD or arrow keys.
- The little amber block on the character marks its facing — it turns to point
  the way you move. (That's the future "front" of the character — where a sword
  swing or interaction will aim.)

## The thing to actually play with

Open `scenes/main.tscn`, click the **CameraRig** node, and look at the inspector.
With the scene open you can scrub these and watch the view change live:

- **Camera pitch degrees** — `90` is classic top-down (most Zelda-like, hides the
  voxel depth); around `55–65` is the tilted 3/4 view that shows off the 3D forms
  and lighting. This is the design lever we talked about. Find your number.
- **Camera view size** — orthographic zoom. Smaller = more zoomed in.
- **Camera distance** — how far back the camera sits. With an orthographic camera
  this mostly affects clipping/feel, not apparent size.

Controls stay consistent at every angle: "up" always moves toward the top of the
screen, whether you're top-down or tilted.

## What this slice deliberately is NOT yet

No combat, no survival systems, no NPCs, no capture loop — and the "voxel"
character is a placeholder box, not a real model. This slice exists to lock the
feel of moving through the world and the camera framing, because those decisions
ripple into everything after them (combat readability, how captivity scenes get
framed, the whole look).

## Next slices, roughly in build order

1. **(this)** movement + camera feel
2. real voxel character model + simple animation
3. Zelda-style combat (one clear action at a time)
4. the defeat → capture state transition
5. one captivity scenario end-to-end (the shared "captivity spine")
6. generalize the spine into prison / slavery / ransom configurations

Each is meant to be something you can run and react to before moving on.
