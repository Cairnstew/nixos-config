# Tips on Quaternions

Assuming the local axis Y of the building is vertical, compute cosinus (`cosp`) and sinus (`sinp`) of the rotation angle around the vertical:

```lua
local q = self:getOwner():getGlobalOrientation()
local sinp = 2 * q[4] * q[2]
local cosp = q[4] * q[4] - q[2] * q[2]
```

Notes:
- `cosp*cosp + sinp*sinp` should be near 1
- Can be used to convert local direction on XZ plane to global direction for rayCast

guides/tips-on-quaternion.txt · Last modified: 2021/02/23 11:57 by 127.0.0.1
