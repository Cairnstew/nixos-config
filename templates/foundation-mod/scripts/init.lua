local myMod = ...

myMod:log("Running init script.")

-- Register custom enumerations here if needed
-- foundation.registerEnumValue("MY_ENUM_TYPE", "MY_NEW_VALUE")

-- Register custom classes
-- mod:registerClass(MY_CUSTOM_CLASS)

-- Register events
-- myMod:registerEvent(EVENT.RESOURCE_GAINED, "myResourceGainedHandler")

-- Example: custom class registration
-- local MY_CUSTOM_MANDATE = {
--     TypeName = "MY_CUSTOM_MANDATE",
--     ParentType = "MANDATE",
--     Properties = {
--         { Name = "SomeValue", Type = "float", Default = 1.0 },
--     }
-- }
-- function MY_CUSTOM_MANDATE:init() end
-- myMod:registerClass(MY_CUSTOM_MANDATE)
