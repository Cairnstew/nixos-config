# Events

Some core types use events. These events can be used to run a function when a certain trigger happens on a specific object.

## Triggering events

To trigger an event on an object, call this event from the chosen object. Events are designed to be triggered by their owner, and listened to by other objects.

## Registering to events

### register

Register to an event triggered on a specific target object.

```lua
event.register(self, compMainGameLoop.ON_NEW_DAY, function()
    myMod:log("New day!")
end)
```

### unregister

Stops listening to an event registered on a specific target object.

```lua
event.unregister(self, compMainGameLoop.ON_NEW_DAY)
```

### clear

Stops listening to all events registered on the target object.

```lua
event.clear(target)
```

events.txt · Last modified: 2020/05/22 12:23 by 127.0.0.1
