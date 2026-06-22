# Construction steps

Buildings and building parts are built step by step. The construction system is based on naming.

You can specify a prefab to be used as construction visual.

The system will parse the prefab and search for objects with a name starting with `step_`.

All nodes called `step_0` (or `step_0_anythingelse`) will be visible as soon as the building is placed.

The rest of the nodes (`step_X` / `step_X_anythingelse`) will become visible in order, during the construction.

If more than one node have the same order number, their inner order will be randomized. All children of a node starting with `step_` will be shown with their parent, no matter their name.

construction-steps.txt · Last modified: 2021/10/21 13:28 by 127.0.0.1
