# Behavior Trees

## Register new behavior trees

Custom behavior tree assets with `mod:registerBehaviorTree`.

A behavior tree is defined as a table containing an ID (`Id`), a list of variable (`VariableList`) and an execution tree (`Root`).

### VariableList

Each variable must contain at least a unique `Name` and a `DataType` inheriting `BEHAVIOR_TREE_DATA`. You can also specify `IsPublic` and `DefaultValue`.

### Node tree

Composed of multiple nodes. Branch nodes (`NODE_BRANCH`) are decorators or composites. Leaf nodes (`NODE_LEAF`) cannot have children.

## Custom behavior tree nodes

Custom behavior tree nodes with `foundation.registerBehaviorTreeNode`.

### VariableList

Key-value pairs with variable name as key and type (inheriting `BEHAVIOR_TREE_DATA`) as value.

### Functions

A leaf node has three basic functions:

- **Init**(*instance*): called first
- **Update**(*level*, *instance*): called until it doesn't return `PROCESSING`
- **Finish**(*instance*): called last

```lua
myMod:registerBehaviorTreeNode({
    Id = "MY_CUSTOM_BEHAVIOR_TREE_NODE",
    VariableList = { ... },
    Init = function(self, instance) ... end,
    Update = function(self, level, instance)
        ...
        return BEHAVIOR_TREE_NODE_RESULT.TRUE
    end,
    Finish = function(self, instance) ... end
})
```

behavior-trees.txt · Last modified: 2021/07/29 11:56 by 127.0.0.1
