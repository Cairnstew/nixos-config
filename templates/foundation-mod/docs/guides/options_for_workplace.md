# Options for Workplaces

## Basics

Simple workplace producing from input resources:

```lua
myMod:register({
    DataType = "BUILDING_FUNCTION_WORKPLACE",
    Id = "MY_BUILDING_FUNCTION",
    WorkerCapacity = 1,
    RelatedJob = { Job = "MY_BUILDING_JOB", Behavior = "WORK_BEHAVIOR" },
    InputInventoryCapacity = {
        { Resource = "MY_BUILDING_INPUT_RESOURCE", Quantity = 10 }
    },
    ResourceListNeeded = {
        { Resource = "MY_BUILDING_INPUT_RESOURCE", Quantity = 1 }
    },
    ResourceProduced = {
        { Resource = "MY_BUILDING_OUTPUT_RESOURCE", Quantity = 1 }
    }
})
```

## Same building for producing and selling

Use BUILDING_FUNCTION_MARKET with TypeList.

## Workplace with several recipes

Use BUILDING_FUNCTION_ASSIGNABLE with a BUILDING_FUNCTION_LIST.

## Several workplaces per building

Use a monument with different buildingParts, each with its own workplace.

guides/options_for_workplace.txt · Last modified: 2021/02/23 11:56 by 127.0.0.1
