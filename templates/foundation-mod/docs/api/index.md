 api \[Foundation - Modding Documentation\]                      

-   [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

-   [Log In](/foundation/modding/api?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In\>

-   [Recent Changes](/foundation/modding/api?do=recent "Recent Changes [r]")
-   [Media Manager](/foundation/modding/api?do=media&ns= "Media Manager")
-   [Sitemap](/foundation/modding/api?do=index "Sitemap [x]")

Trace: • [api](/foundation/modding/api "api")

---

### Sidebar

-   [Home](/foundation/modding/start "start")
    
-   [Scripting API](/foundation/modding/api "api")
    
-   [Assets](/foundation/modding/assets "assets")
    
-   [Changelog](/foundation/modding/changelog "changelog")
    
-   [Migration notes](/foundation/modding/migration "migration")
    
-   [Community Guides](/foundation/modding/guides "guides")
    
-   [Community API](/foundation/modding/communityapi "communityapi")
    
-   [Texture Pack](/foundation/modding/texture-pack "texture-pack")
    

api

### Table of Contents

-   [API](#api)
    
    -   [Engine Core](#engine_core)
        
    -   [Assets Classes](#assets_classes)
        
    -   [Component Classes](#component_classes)
        
    -   [Asset Processor Classes](#asset_processor_classes)
        
    -   [Behavior Tree Node Classes](#behavior_tree_node_classes)
        
    -   [Behavior Tree Data Classes](#behavior_tree_data_classes)
        
    -   [Data Classes](#data_classes)
        
    -   [Data Structures](#data_structures)
        
    -   [Enumerations](#enumerations)
        

# API

## Engine Core

-   [COMPONENT](/foundation/modding/api/component "api:component")
    
-   [COMPONENT\_MANAGER](/foundation/modding/api/component_manager "api:component_manager")
    
-   [GAME](/foundation/modding/api/game "api:game")
    
-   [GAME\_OBJECT](/foundation/modding/api/game_object "api:game_object")
    
-   [LEVEL](/foundation/modding/api/level "api:level")
    

## Assets Classes

-   [ABSTRACT\_QUEST](/foundation/modding/api/abstract_quest "api:abstract_quest")
    
-   [AGENT\_NEED\_TYPE](/foundation/modding/api/agent_need_type "api:agent_need_type")
    
-   [AGENT\_NEED\_TYPE\_HOUSING](/foundation/modding/api/agent_need_type_housing "api:agent_need_type_housing")
    
-   [AGENT\_NEED\_TYPE\_LODGING](/foundation/modding/api/agent_need_type_lodging "api:agent_need_type_lodging")
    
-   [AGENT\_NEED\_TYPE\_RESOURCE](/foundation/modding/api/agent_need_type_resource "api:agent_need_type_resource")
    
-   [AGENT\_NEED\_TYPE\_SOLDIER\_EQUIPMENT](/foundation/modding/api/agent_need_type_soldier_equipment "api:agent_need_type_soldier_equipment")
    
-   [AGENT\_NEED\_TYPE\_SOLDIER\_HEALING](/foundation/modding/api/agent_need_type_soldier_healing "api:agent_need_type_soldier_healing")
    
-   [AGENT\_NEED\_TYPE\_SOLDIER\_TRAINING](/foundation/modding/api/agent_need_type_soldier_training "api:agent_need_type_soldier_training")
    
-   [AGENT\_NEED\_TYPE\_VISIT\_BUILDING](/foundation/modding/api/agent_need_type_visit_building "api:agent_need_type_visit_building")
    
-   [AGENT\_PORTRAIT](/foundation/modding/api/agent_portrait "api:agent_portrait")
    
-   [AGENT\_PROFILE](/foundation/modding/api/agent_profile "api:agent_profile")
    
-   [ASSET](/foundation/modding/api/asset "api:asset")
    
-   [ASSIGNABLE\_BUILDING\_FUNCTION\_LIST](/foundation/modding/api/assignable_building_function_list "api:assignable_building_function_list")
    
-   [ATLAS\_CELL](/foundation/modding/api/atlas_cell "api:atlas_cell")
    
-   [AUDIO\_EVENT](/foundation/modding/api/audio_event "api:audio_event")
    
-   [BALANCING](/foundation/modding/api/balancing "api:balancing")
    
-   [BEHAVIOR\_TREE](/foundation/modding/api/behavior_tree "api:behavior_tree")
    
-   [BIOME\_LAYER](/foundation/modding/api/biome_layer "api:biome_layer")
    
-   [BLUEPRINT](/foundation/modding/api/blueprint "api:blueprint")
    
-   [BLUEPRINT\_MANDATE\_TYPE](/foundation/modding/api/blueprint_mandate_type "api:blueprint_mandate_type")
    
-   [BUILDING](/foundation/modding/api/building "api:building")
    
-   [BUILDING\_FUNCTION](/foundation/modding/api/building_function "api:building_function")
    
-   [BUILDING\_FUNCTION\_ACCOMMODATION](/foundation/modding/api/building_function_accommodation "api:building_function_accommodation")
    
-   [BUILDING\_FUNCTION\_ASSIGNABLE](/foundation/modding/api/building_function_assignable "api:building_function_assignable")
    
-   [BUILDING\_FUNCTION\_BAILIFF\_OFFICE](/foundation/modding/api/building_function_bailiff_office "api:building_function_bailiff_office")
    
-   [BUILDING\_FUNCTION\_BELFRY](/foundation/modding/api/building_function_belfry "api:building_function_belfry")
    
-   [BUILDING\_FUNCTION\_BRIDGE](/foundation/modding/api/building_function_bridge "api:building_function_bridge")
    
-   [BUILDING\_FUNCTION\_BUILDER\_WORKSHOP](/foundation/modding/api/building_function_builder_workshop "api:building_function_builder_workshop")
    
-   [BUILDING\_FUNCTION\_CHURCH](/foundation/modding/api/building_function_church "api:building_function_church")
    
-   [BUILDING\_FUNCTION\_CRAFTING\_WORKSHOP](/foundation/modding/api/building_function_crafting_workshop "api:building_function_crafting_workshop")
    
-   [BUILDING\_FUNCTION\_ENCAMPMENT](/foundation/modding/api/building_function_encampment "api:building_function_encampment")
    
-   [BUILDING\_FUNCTION\_FARM](/foundation/modding/api/building_function_farm "api:building_function_farm")
    
-   [BUILDING\_FUNCTION\_FISHING](/foundation/modding/api/building_function_fishing "api:building_function_fishing")
    
-   [BUILDING\_FUNCTION\_FORESTER](/foundation/modding/api/building_function_forester "api:building_function_forester")
    
-   [BUILDING\_FUNCTION\_GREAT\_HALL](/foundation/modding/api/building_function_great_hall "api:building_function_great_hall")
    
-   [BUILDING\_FUNCTION\_HEALING\_HOUSE](/foundation/modding/api/building_function_healing_house "api:building_function_healing_house")
    
-   [BUILDING\_FUNCTION\_HOUSE](/foundation/modding/api/building_function_house "api:building_function_house")
    
-   [BUILDING\_FUNCTION\_INN](/foundation/modding/api/building_function_inn "api:building_function_inn")
    
-   [BUILDING\_FUNCTION\_INTERACTIVE\_LOCATION](/foundation/modding/api/building_function_interactive_location "api:building_function_interactive_location")
    
-   [BUILDING\_FUNCTION\_KITCHEN](/foundation/modding/api/building_function_kitchen "api:building_function_kitchen")
    
-   [BUILDING\_FUNCTION\_KNIGHT\_STATUE](/foundation/modding/api/building_function_knight_statue "api:building_function_knight_statue")
    
-   [BUILDING\_FUNCTION\_LIVESTOCK\_FARM](/foundation/modding/api/building_function_livestock_farm "api:building_function_livestock_farm")
    
-   [BUILDING\_FUNCTION\_LODGING](/foundation/modding/api/building_function_lodging "api:building_function_lodging")
    
-   [BUILDING\_FUNCTION\_MARKET](/foundation/modding/api/building_function_market "api:building_function_market")
    
-   [BUILDING\_FUNCTION\_MARKET\_TENT](/foundation/modding/api/building_function_market_tent "api:building_function_market_tent")
    
-   [BUILDING\_FUNCTION\_MONASTERY](/foundation/modding/api/building_function_monastery "api:building_function_monastery")
    
-   [BUILDING\_FUNCTION\_MUSICAL\_PART](/foundation/modding/api/building_function_musical_part "api:building_function_musical_part")
    
-   [BUILDING\_FUNCTION\_POINT\_OF\_INTEREST](/foundation/modding/api/building_function_point_of_interest "api:building_function_point_of_interest")
    
-   [BUILDING\_FUNCTION\_PUBLIC\_LOUNGE](/foundation/modding/api/building_function_public_lounge "api:building_function_public_lounge")
    
-   [BUILDING\_FUNCTION\_PUBLIC\_LOUNGE\_ROOM](/foundation/modding/api/building_function_public_lounge_room "api:building_function_public_lounge_room")
    
-   [BUILDING\_FUNCTION\_QUARRY](/foundation/modding/api/building_function_quarry "api:building_function_quarry")
    
-   [BUILDING\_FUNCTION\_RESOURCE\_DEPOT](/foundation/modding/api/building_function_resource_depot "api:building_function_resource_depot")
    
-   [BUILDING\_FUNCTION\_RESOURCE\_GENERATOR](/foundation/modding/api/building_function_resource_generator "api:building_function_resource_generator")
    
-   [BUILDING\_FUNCTION\_RESOURCE\_STOCKPILE](/foundation/modding/api/building_function_resource_stockpile "api:building_function_resource_stockpile")
    
-   [BUILDING\_FUNCTION\_TAX\_OFFICE](/foundation/modding/api/building_function_tax_office "api:building_function_tax_office")
    
-   [BUILDING\_FUNCTION\_TRAINING\_SITE](/foundation/modding/api/building_function_training_site "api:building_function_training_site")
    
-   [BUILDING\_FUNCTION\_TREASURY](/foundation/modding/api/building_function_treasury "api:building_function_treasury")
    
-   [BUILDING\_FUNCTION\_UNIQUE\_RESOURCE\_DEPOT](/foundation/modding/api/building_function_unique_resource_depot "api:building_function_unique_resource_depot")
    
-   [BUILDING\_FUNCTION\_VILLAGE\_CENTER](/foundation/modding/api/building_function_village_center "api:building_function_village_center")
    
-   [BUILDING\_FUNCTION\_WAREHOUSE](/foundation/modding/api/building_function_warehouse "api:building_function_warehouse")
    
-   [BUILDING\_FUNCTION\_WATCHPOST](/foundation/modding/api/building_function_watchpost "api:building_function_watchpost")
    
-   [BUILDING\_FUNCTION\_WORKER\_CAPACITY\_EXTENDER](/foundation/modding/api/building_function_worker_capacity_extender "api:building_function_worker_capacity_extender")
    
-   [BUILDING\_FUNCTION\_WORKPLACE](/foundation/modding/api/building_function_workplace "api:building_function_workplace")
    
-   [BUILDING\_FUNCTION\_WORKPLACE\_GUARD](/foundation/modding/api/building_function_workplace_guard "api:building_function_workplace_guard")
    
-   [BUILDING\_GAME\_CONDITION\_CONFIG](/foundation/modding/api/building_game_condition_config "api:building_game_condition_config")
    
-   [BUILDING\_LIST](/foundation/modding/api/building_list "api:building_list")
    
-   [BUILDING\_PART](/foundation/modding/api/building_part "api:building_part")
    
-   [BUILD\_MENU\_CONFIG](/foundation/modding/api/build_menu_config "api:build_menu_config")
    
-   [CHANGE\_EDICT\_MANDATE\_TYPE](/foundation/modding/api/change_edict_mandate_type "api:change_edict_mandate_type")
    
-   [CHANGE\_PRIVILEGE\_MANDATE\_TYPE](/foundation/modding/api/change_privilege_mandate_type "api:change_privilege_mandate_type")
    
-   [CUSTOM\_MAP](/foundation/modding/api/custom_map "api:custom_map")
    
-   [DESIRABILITY](/foundation/modding/api/desirability "api:desirability")
    
-   [DESIRABILITY\_HOUSE\_SELECTION\_FACTOR](/foundation/modding/api/desirability_house_selection_factor "api:desirability_house_selection_factor")
    
-   [DESIRABILITY\_MODIFIER](/foundation/modding/api/desirability_modifier "api:desirability_modifier")
    
-   [DYNAMIC\_BERRIES\_MANAGER\_DATA](/foundation/modding/api/dynamic_berries_manager_data "api:dynamic_berries_manager_data")
    
-   [EDICT](/foundation/modding/api/edict "api:edict")
    
-   [ESTATE](/foundation/modding/api/estate "api:estate")
    
-   [ESTATE\_SETTING](/foundation/modding/api/estate_setting "api:estate_setting")
    
-   [EVENT](/foundation/modding/api/event "api:event")
    
-   [EXECUTE\_ACTION\_LIST\_MANDATE\_TYPE](/foundation/modding/api/execute_action_list_mandate_type "api:execute_action_list_mandate_type")
    
-   [FARM\_FIELD\_CONFIG](/foundation/modding/api/farm_field_config "api:farm_field_config")
    
-   [FOREST\_BERRIES\_CLUSTER\_DATA](/foundation/modding/api/forest_berries_cluster_data "api:forest_berries_cluster_data")
    
-   [FOREST\_BERRIES\_DATA](/foundation/modding/api/forest_berries_data "api:forest_berries_data")
    
-   [GAME\_RULE](/foundation/modding/api/game_rule "api:game_rule")
    
-   [GAME\_RULE\_MANDATE](/foundation/modding/api/game_rule_mandate "api:game_rule_mandate")
    
-   [GAME\_RULE\_MASTERPIECE](/foundation/modding/api/game_rule_masterpiece "api:game_rule_masterpiece")
    
-   [GAME\_RULE\_MINERAL](/foundation/modding/api/game_rule_mineral "api:game_rule_mineral")
    
-   [GAME\_RULE\_MODIFIER\_RANGE\_PAIR](/foundation/modding/api/game_rule_modifier_range_pair "api:game_rule_modifier_range_pair")
    
-   [GAME\_RULE\_MOVE\_HOUSE](/foundation/modding/api/game_rule_move_house "api:game_rule_move_house")
    
-   [GAME\_RULE\_STATUS\_PROMOTION](/foundation/modding/api/game_rule_status_promotion "api:game_rule_status_promotion")
    
-   [GAME\_RULE\_TRADE](/foundation/modding/api/game_rule_trade "api:game_rule_trade")
    
-   [GAME\_STEP\_LIST](/foundation/modding/api/game_step_list "api:game_step_list")
    
-   [GAME\_STEP\_LIST\_BUILDING\_SPLENDOR](/foundation/modding/api/game_step_list_building_splendor "api:game_step_list_building_splendor")
    
-   [GAME\_STEP\_LIST\_ESTATE\_SPLENDOR](/foundation/modding/api/game_step_list_estate_splendor "api:game_step_list_estate_splendor")
    
-   [GAME\_STEP\_LIST\_PROSPERITY](/foundation/modding/api/game_step_list_prosperity "api:game_step_list_prosperity")
    
-   [GUEST](/foundation/modding/api/guest "api:guest")
    
-   [GUEST\_REQUIREMENT](/foundation/modding/api/guest_requirement "api:guest_requirement")
    
-   [HAIR\_LIST](/foundation/modding/api/hair_list "api:hair_list")
    
-   [HAPPINESS\_FACTOR](/foundation/modding/api/happiness_factor "api:happiness_factor")
    
-   [HAPPINESS\_FACTOR\_STATUS\_DEMOTE](/foundation/modding/api/happiness_factor_status_demote "api:happiness_factor_status_demote")
    
-   [HELP](/foundation/modding/api/help "api:help")
    
-   [HERALDRY\_COLOR](/foundation/modding/api/heraldry_color "api:heraldry_color")
    
-   [HERALDRY\_MASK](/foundation/modding/api/heraldry_mask "api:heraldry_mask")
    
-   [HERALDRY\_PATTERN](/foundation/modding/api/heraldry_pattern "api:heraldry_pattern")
    
-   [HERALDRY\_SETTINGS](/foundation/modding/api/heraldry_settings "api:heraldry_settings")
    
-   [HERALDRY\_SHADING](/foundation/modding/api/heraldry_shading "api:heraldry_shading")
    
-   [HERALDRY\_SYMBOL](/foundation/modding/api/heraldry_symbol "api:heraldry_symbol")
    
-   [HERALDRY\_SYMBOL\_COMPOSITION](/foundation/modding/api/heraldry_symbol_composition "api:heraldry_symbol_composition")
    
-   [HOUSE\_MANAGER\_DATA](/foundation/modding/api/house_manager_data "api:house_manager_data")
    
-   [HOUSE\_REQUIREMENT](/foundation/modding/api/house_requirement "api:house_requirement")
    
-   [HOUSE\_REQUIREMENT\_IN\_LAYER](/foundation/modding/api/house_requirement_in_layer "api:house_requirement_in_layer")
    
-   [HOUSE\_REQUIREMENT\_PATROL](/foundation/modding/api/house_requirement_patrol "api:house_requirement_patrol")
    
-   [HOUSE\_REQUIREMENT\_PAVED\_ROAD](/foundation/modding/api/house_requirement_paved_road "api:house_requirement_paved_road")
    
-   [HOUSE\_REQUIREMENT\_VILLAGER\_STATUS](/foundation/modding/api/house_requirement_villager_status "api:house_requirement_villager_status")
    
-   [HOUSE\_REQUIREMENT\_ZONE](/foundation/modding/api/house_requirement_zone "api:house_requirement_zone")
    
-   [HOUSE\_SELECTION\_FACTOR](/foundation/modding/api/house_selection_factor "api:house_selection_factor")
    
-   [HOUSE\_SETUP](/foundation/modding/api/house_setup "api:house_setup")
    
-   [HUNT\_FOREST\_MANAGER\_DATA](/foundation/modding/api/hunt_forest_manager_data "api:hunt_forest_manager_data")
    
-   [IMMIGRATION\_FACTOR](/foundation/modding/api/immigration_factor "api:immigration_factor")
    
-   [IMMIGRATION\_FACTOR\_HAPPINESS](/foundation/modding/api/immigration_factor_happiness "api:immigration_factor_happiness")
    
-   [IMMIGRATION\_FACTOR\_RESIDENTIAL](/foundation/modding/api/immigration_factor_residential "api:immigration_factor_residential")
    
-   [IMMIGRATION\_FACTOR\_UNEMPLOYMENT](/foundation/modding/api/immigration_factor_unemployment "api:immigration_factor_unemployment")
    
-   [IMMIGRATION\_SETTINGS](/foundation/modding/api/immigration_settings "api:immigration_settings")
    
-   [INFLUENCE\_MANDATE\_TYPE](/foundation/modding/api/influence_mandate_type "api:influence_mandate_type")
    
-   [INFORMATION\_LAYER](/foundation/modding/api/information_layer "api:information_layer")
    
-   [INTERACTIVE\_LOCATION\_SETUP](/foundation/modding/api/interactive_location_setup "api:interactive_location_setup")
    
-   [JOB](/foundation/modding/api/job "api:job")
    
-   [JOB\_PROGRESSION](/foundation/modding/api/job_progression "api:job_progression")
    
-   [JOB\_PROXIMITY\_HOUSE\_SELECTION\_FACTOR](/foundation/modding/api/job_proximity_house_selection_factor "api:job_proximity_house_selection_factor")
    
-   [MANDATE\_TYPE](/foundation/modding/api/mandate_type "api:mandate_type")
    
-   [MASTERPIECE](/foundation/modding/api/masterpiece "api:masterpiece")
    
-   [MASTERPIECE\_LIST](/foundation/modding/api/masterpiece_list "api:masterpiece_list")
    
-   [MATERIAL](/foundation/modding/api/material "api:material")
    
-   [MATERIAL\_SET\_LIST](/foundation/modding/api/material_set_list "api:material_set_list")
    
-   [MILITARY\_CAMPAIGN](/foundation/modding/api/military_campaign "api:military_campaign")
    
-   [MILITARY\_CAMPAIGN\_SETTINGS](/foundation/modding/api/military_campaign_settings "api:military_campaign_settings")
    
-   [MILITARY\_COMPANY](/foundation/modding/api/military_company "api:military_company")
    
-   [MILITARY\_COMPANY\_BEHAVIOR](/foundation/modding/api/military_company_behavior "api:military_company_behavior")
    
-   [MILITARY\_COMPANY\_SETTINGS](/foundation/modding/api/military_company_settings "api:military_company_settings")
    
-   [MILITARY\_COMPANY\_WARNING](/foundation/modding/api/military_company_warning "api:military_company_warning")
    
-   [MILITARY\_COMPANY\_WARNING\_LOW\_HAPPINESS](/foundation/modding/api/military_company_warning_low_happiness "api:military_company_warning_low_happiness")
    
-   [MILITARY\_COMPANY\_WARNING\_MISSING\_WEAPON](/foundation/modding/api/military_company_warning_missing_weapon "api:military_company_warning_missing_weapon")
    
-   [MILITARY\_COMPANY\_WARNING\_UNTRAINED](/foundation/modding/api/military_company_warning_untrained "api:military_company_warning_untrained")
    
-   [MILITARY\_COMPANY\_WARNING\_WOUNDED](/foundation/modding/api/military_company_warning_wounded "api:military_company_warning_wounded")
    
-   [MILITARY\_GRADE](/foundation/modding/api/military_grade "api:military_grade")
    
-   [MILITARY\_WEAPON\_TYPE](/foundation/modding/api/military_weapon_type "api:military_weapon_type")
    
-   [NAME\_LIST](/foundation/modding/api/name_list "api:name_list")
    
-   [NARRATIVE\_PANEL](/foundation/modding/api/narrative_panel "api:narrative_panel")
    
-   [NOTIFICATION](/foundation/modding/api/notification "api:notification")
    
-   [OUTCOME\_PANEL\_DATA](/foundation/modding/api/outcome_panel_data "api:outcome_panel_data")
    
-   [PARTICLE\_SYSTEM](/foundation/modding/api/particle_system "api:particle_system")
    
-   [PAVED\_ROAD\_MANAGER\_CONFIG](/foundation/modding/api/paved_road_manager_config "api:paved_road_manager_config")
    
-   [PLANTABLE](/foundation/modding/api/plantable "api:plantable")
    
-   [POINT\_OF\_INTEREST](/foundation/modding/api/point_of_interest "api:point_of_interest")
    
-   [PREFAB](/foundation/modding/api/prefab "api:prefab")
    
-   [PRIVILEGE](/foundation/modding/api/privilege "api:privilege")
    
-   [PROGRESS\_PATH](/foundation/modding/api/progress_path "api:progress_path")
    
-   [PROGRESS\_TIER\_DATA](/foundation/modding/api/progress_tier_data "api:progress_tier_data")
    
-   [PROMOTE\_VILLAGER\_MANDATE\_TYPE](/foundation/modding/api/promote_villager_mandate_type "api:promote_villager_mandate_type")
    
-   [PROMOTION\_COST\_LIST](/foundation/modding/api/promotion_cost_list "api:promotion_cost_list")
    
-   [PROSPECT\_MANDATE\_TYPE](/foundation/modding/api/prospect_mandate_type "api:prospect_mandate_type")
    
-   [QUEST](/foundation/modding/api/quest "api:quest")
    
-   [QUEST\_HOSTING\_MISSION](/foundation/modding/api/quest_hosting_mission "api:quest_hosting_mission")
    
-   [QUEST\_MILITARY\_HOSTING\_MISSION](/foundation/modding/api/quest_military_hosting_mission "api:quest_military_hosting_mission")
    
-   [QUEST\_REWARD\_GENERATOR](/foundation/modding/api/quest_reward_generator "api:quest_reward_generator")
    
-   [RANGE\_FLOAT](/foundation/modding/api/range_float "api:range_float")
    
-   [RESOURCE](/foundation/modding/api/resource "api:resource")
    
-   [RESOURCE\_COLLECTION](/foundation/modding/api/resource_collection "api:resource_collection")
    
-   [RESOURCE\_CONTAINER\_CONFIG](/foundation/modding/api/resource_container_config "api:resource_container_config")
    
-   [RESOURCE\_LAYOUT\_SETUP](/foundation/modding/api/resource_layout_setup "api:resource_layout_setup")
    
-   [RESOURCE\_TYPE\_COST\_LIST](/foundation/modding/api/resource_type_cost_list "api:resource_type_cost_list")
    
-   [RULER\_TITLE](/foundation/modding/api/ruler_title "api:ruler_title")
    
-   [RULER\_TITLE\_LIST](/foundation/modding/api/ruler_title_list "api:ruler_title_list")
    
-   [SAFETY\_FUNCTION](/foundation/modding/api/safety_function "api:safety_function")
    
-   [SAFETY\_FUNCTION\_HOUSE](/foundation/modding/api/safety_function_house "api:safety_function_house")
    
-   [SAFETY\_SETTINGS](/foundation/modding/api/safety_settings "api:safety_settings")
    
-   [SCORE\_TRACKER\_BEAUTIFICATION\_DATA](/foundation/modding/api/score_tracker_beautification_data "api:score_tracker_beautification_data")
    
-   [SCORE\_TRACKER\_DATA](/foundation/modding/api/score_tracker_data "api:score_tracker_data")
    
-   [SCORE\_TRACKER\_DATA\_PROFIT](/foundation/modding/api/score_tracker_data_profit "api:score_tracker_data_profit")
    
-   [SCORE\_TRACKER\_SPLENDOR](/foundation/modding/api/score_tracker_splendor "api:score_tracker_splendor")
    
-   [SCORE\_TRACKER\_TERRITORY](/foundation/modding/api/score_tracker_territory "api:score_tracker_territory")
    
-   [SCORE\_TRACKER\_TRADE\_ROUTE](/foundation/modding/api/score_tracker_trade_route "api:score_tracker_trade_route")
    
-   [SCORE\_TRACKER\_VILLAGER\_COUNT](/foundation/modding/api/score_tracker_villager_count "api:score_tracker_villager_count")
    
-   [SCORE\_TRACKER\_VILLAGER\_STATUS](/foundation/modding/api/score_tracker_villager_status "api:score_tracker_villager_status")
    
-   [SHOW\_NARRATIVE\_PANEL\_MANDATE\_TYPE](/foundation/modding/api/show_narrative_panel_mandate_type "api:show_narrative_panel_mandate_type")
    
-   [TAXATION\_FUNCTION](/foundation/modding/api/taxation_function "api:taxation_function")
    
-   [TAXATION\_FUNCTION\_BRACKET](/foundation/modding/api/taxation_function_bracket "api:taxation_function_bracket")
    
-   [TAXATION\_FUNCTION\_CHURCH](/foundation/modding/api/taxation_function_church "api:taxation_function_church")
    
-   [TAXATION\_FUNCTION\_HOUSING](/foundation/modding/api/taxation_function_housing "api:taxation_function_housing")
    
-   [TAXATION\_FUNCTION\_MARKET](/foundation/modding/api/taxation_function_market "api:taxation_function_market")
    
-   [TAXATION\_FUNCTION\_RESOURCE\_PRODUCTION](/foundation/modding/api/taxation_function_resource_production "api:taxation_function_resource_production")
    
-   [TAXATION\_SETTINGS](/foundation/modding/api/taxation_settings "api:taxation_settings")
    
-   [TEXTURE](/foundation/modding/api/texture "api:texture")
    
-   [TRADING\_VILLAGE](/foundation/modding/api/trading_village "api:trading_village")
    
-   [TRADING\_VILLAGE\_LIST](/foundation/modding/api/trading_village_list "api:trading_village_list")
    
-   [UNLOCKABLE](/foundation/modding/api/unlockable "api:unlockable")
    
-   [UNLOCKABLE\_EDICT](/foundation/modding/api/unlockable_edict "api:unlockable_edict")
    
-   [UNLOCKABLE\_PRIVILEGE](/foundation/modding/api/unlockable_privilege "api:unlockable_privilege")
    
-   [UNLOCKABLE\_TECHNOLOGY](/foundation/modding/api/unlockable_technology "api:unlockable_technology")
    
-   [UNLOCK\_FUNCTION](/foundation/modding/api/unlock_function "api:unlock_function")
    
-   [UNLOCK\_FUNCTION\_BUILDING](/foundation/modding/api/unlock_function_building "api:unlock_function_building")
    
-   [UNLOCK\_FUNCTION\_BUILDING\_FUNCTION](/foundation/modding/api/unlock_function_building_function "api:unlock_function_building_function")
    
-   [UNLOCK\_FUNCTION\_ESTATE\_SYSTEM](/foundation/modding/api/unlock_function_estate_system "api:unlock_function_estate_system")
    
-   [UNLOCK\_FUNCTION\_SYSTEM](/foundation/modding/api/unlock_function_system "api:unlock_function_system")
    
-   [UNLOCK\_FUNCTION\_TAXATION](/foundation/modding/api/unlock_function_taxation "api:unlock_function_taxation")
    
-   [UNLOCK\_FUNCTION\_TRADE\_ROUTE](/foundation/modding/api/unlock_function_trade_route "api:unlock_function_trade_route")
    
-   [UPGRADE\_TRADE\_ROUTE\_MANDATE\_TYPE](/foundation/modding/api/upgrade_trade_route_mandate_type "api:upgrade_trade_route_mandate_type")
    
-   [VEHICLE](/foundation/modding/api/vehicle "api:vehicle")
    
-   [VILLAGER\_STATUS](/foundation/modding/api/villager_status "api:villager_status")
    
-   [VILLAGER\_STATUS\_QUOTA](/foundation/modding/api/villager_status_quota "api:villager_status_quota")
    
-   [VILLAGE\_POLICY\_DATA](/foundation/modding/api/village_policy_data "api:village_policy_data")
    
-   [VILLAGE\_TITLE](/foundation/modding/api/village_title "api:village_title")
    
-   [VILLAGE\_TITLE\_LIST](/foundation/modding/api/village_title_list "api:village_title_list")
    
-   [WEAPON](/foundation/modding/api/weapon "api:weapon")
    
-   [WEATHER\_SETTING](/foundation/modding/api/weather_setting "api:weather_setting")
    
-   [ZONE](/foundation/modding/api/zone "api:zone")
    

## Component Classes

-   [COMP\_ABSTRACT\_BUILDABLE](/foundation/modding/api/comp_abstract_buildable "api:comp_abstract_buildable")
    
-   [COMP\_ACCOMMODATION](/foundation/modding/api/comp_accommodation "api:comp_accommodation")
    
-   [COMP\_AGENT](/foundation/modding/api/comp_agent "api:comp_agent")
    
-   [COMP\_AGENT\_NEED\_PROCESSOR](/foundation/modding/api/comp_agent_need_processor "api:comp_agent_need_processor")
    
-   [COMP\_BAILIFF\_OFFICE](/foundation/modding/api/comp_bailiff_office "api:comp_bailiff_office")
    
-   [COMP\_BELFRY](/foundation/modding/api/comp_belfry "api:comp_belfry")
    
-   [COMP\_BUILDER\_WORKSHOP](/foundation/modding/api/comp_builder_workshop "api:comp_builder_workshop")
    
-   [COMP\_BUILDING](/foundation/modding/api/comp_building "api:comp_building")
    
-   [COMP\_BUILDING\_ATTACH\_NODE](/foundation/modding/api/comp_building_attach_node "api:comp_building_attach_node")
    
-   [COMP\_BUILDING\_MANAGER](/foundation/modding/api/comp_building_manager "api:comp_building_manager")
    
-   [COMP\_BUILDING\_PART](/foundation/modding/api/comp_building_part "api:comp_building_part")
    
-   [COMP\_BUILDING\_ZONE](/foundation/modding/api/comp_building_zone "api:comp_building_zone")
    
-   [COMP\_CHARACTER\_SETUPER](/foundation/modding/api/comp_character_setuper "api:comp_character_setuper")
    
-   [COMP\_CONSTRUCTION\_STEPS\_VISUAL](/foundation/modding/api/comp_construction_steps_visual "api:comp_construction_steps_visual")
    
-   [COMP\_CROP\_FIELD\_ELEMENT](/foundation/modding/api/comp_crop_field_element "api:comp_crop_field_element")
    
-   [COMP\_DIRT\_CIRCLE](/foundation/modding/api/comp_dirt_circle "api:comp_dirt_circle")
    
-   [COMP\_DIRT\_RECTANGLE](/foundation/modding/api/comp_dirt_rectangle "api:comp_dirt_rectangle")
    
-   [COMP\_ENCAMPMENT](/foundation/modding/api/comp_encampment "api:comp_encampment")
    
-   [COMP\_ENVIRONMENT\_SYSTEM](/foundation/modding/api/comp_environment_system "api:comp_environment_system")
    
-   [COMP\_FALLING\_TREE](/foundation/modding/api/comp_falling_tree "api:comp_falling_tree")
    
-   [COMP\_FARM](/foundation/modding/api/comp_farm "api:comp_farm")
    
-   [COMP\_FARM\_LIVESTOCK](/foundation/modding/api/comp_farm_livestock "api:comp_farm_livestock")
    
-   [COMP\_GROUNDED](/foundation/modding/api/comp_grounded "api:comp_grounded")
    
-   [COMP\_GUEST](/foundation/modding/api/comp_guest "api:comp_guest")
    
-   [COMP\_HAPPINESS\_GIVER](/foundation/modding/api/comp_happiness_giver "api:comp_happiness_giver")
    
-   [COMP\_HEALING\_HOUSE](/foundation/modding/api/comp_healing_house "api:comp_healing_house")
    
-   [COMP\_IMMIGRATION\_MANAGER](/foundation/modding/api/comp_immigration_manager "api:comp_immigration_manager")
    
-   [COMP\_INTERACTIVE\_LOCATION](/foundation/modding/api/comp_interactive_location "api:comp_interactive_location")
    
-   [COMP\_INVENTORY](/foundation/modding/api/comp_inventory "api:comp_inventory")
    
-   [COMP\_KNIGHT\_STATUE](/foundation/modding/api/comp_knight_statue "api:comp_knight_statue")
    
-   [COMP\_LIVESTOCK](/foundation/modding/api/comp_livestock "api:comp_livestock")
    
-   [COMP\_LODGING](/foundation/modding/api/comp_lodging "api:comp_lodging")
    
-   [COMP\_MAIN\_GAME\_LOOP](/foundation/modding/api/comp_main_game_loop "api:comp_main_game_loop")
    
-   [COMP\_MANDATE\_MANAGER](/foundation/modding/api/comp_mandate_manager "api:comp_mandate_manager")
    
-   [COMP\_MANDATE\_OFFICE](/foundation/modding/api/comp_mandate_office "api:comp_mandate_office")
    
-   [COMP\_MARKET\_TENT](/foundation/modding/api/comp_market_tent "api:comp_market_tent")
    
-   [COMP\_PARTICLE\_EMITTER](/foundation/modding/api/comp_particle_emitter "api:comp_particle_emitter")
    
-   [COMP\_PARTICLE\_EMITTER\_TOGGLE](/foundation/modding/api/comp_particle_emitter_toggle "api:comp_particle_emitter_toggle")
    
-   [COMP\_PATROL\_WATCHPOST](/foundation/modding/api/comp_patrol_watchpost "api:comp_patrol_watchpost")
    
-   [COMP\_PLANTABLE](/foundation/modding/api/comp_plantable "api:comp_plantable")
    
-   [COMP\_QUOTABLE](/foundation/modding/api/comp_quotable "api:comp_quotable")
    
-   [COMP\_RESOURCE\_CONTAINER](/foundation/modding/api/comp_resource_container "api:comp_resource_container")
    
-   [COMP\_RESOURCE\_CONTAINER\_DEPLETER](/foundation/modding/api/comp_resource_container_depleter "api:comp_resource_container_depleter")
    
-   [COMP\_RESOURCE\_DEPOT](/foundation/modding/api/comp_resource_depot "api:comp_resource_depot")
    
-   [COMP\_RESOURCE\_GENERATOR](/foundation/modding/api/comp_resource_generator "api:comp_resource_generator")
    
-   [COMP\_RESOURCE\_STOCKPILE](/foundation/modding/api/comp_resource_stockpile "api:comp_resource_stockpile")
    
-   [COMP\_RESOURCE\_TO\_PICKUP](/foundation/modding/api/comp_resource_to_pickup "api:comp_resource_to_pickup")
    
-   [COMP\_RIGID\_BODY](/foundation/modding/api/comp_rigid_body "api:comp_rigid_body")
    
-   [COMP\_SELF\_DESTROY](/foundation/modding/api/comp_self_destroy "api:comp_self_destroy")
    
-   [COMP\_SOLDIER](/foundation/modding/api/comp_soldier "api:comp_soldier")
    
-   [COMP\_TAXATION\_MANAGER](/foundation/modding/api/comp_taxation_manager "api:comp_taxation_manager")
    
-   [COMP\_TAX\_COLLECTABLE](/foundation/modding/api/comp_tax_collectable "api:comp_tax_collectable")
    
-   [COMP\_TRADER](/foundation/modding/api/comp_trader "api:comp_trader")
    
-   [COMP\_TREE](/foundation/modding/api/comp_tree "api:comp_tree")
    
-   [COMP\_VEHICLE](/foundation/modding/api/comp_vehicle "api:comp_vehicle")
    
-   [COMP\_VILLAGER](/foundation/modding/api/comp_villager "api:comp_villager")
    
-   [COMP\_VILLAGER\_MANAGER](/foundation/modding/api/comp_villager_manager "api:comp_villager_manager")
    
-   [COMP\_VISITOR](/foundation/modding/api/comp_visitor "api:comp_visitor")
    
-   [COMP\_WAREHOUSE\_SETUPER](/foundation/modding/api/comp_warehouse_setuper "api:comp_warehouse_setuper")
    
-   [COMP\_WORKPLACE](/foundation/modding/api/comp_workplace "api:comp_workplace")
    
-   [COMP\_WORKPLACE\_FORESTER](/foundation/modding/api/comp_workplace_forester "api:comp_workplace_forester")
    
-   [COMP\_WORKPLACE\_GUARD](/foundation/modding/api/comp_workplace_guard "api:comp_workplace_guard")
    
-   [COMP\_WORKPLACE\_KITCHEN](/foundation/modding/api/comp_workplace_kitchen "api:comp_workplace_kitchen")
    
-   [COMP\_WORKPLACE\_TAX\_OFFICE](/foundation/modding/api/comp_workplace_tax_office "api:comp_workplace_tax_office")
    

## Asset Processor Classes

-   [BUILDING\_ASSET\_PROCESSOR](/foundation/modding/api/building_asset_processor "api:building_asset_processor")
    

## Behavior Tree Node Classes

-   [ADD\_TO\_INVENTORY](/foundation/modding/api/add_to_inventory "api:add_to_inventory")
    
-   [AGENT\_NODE\_PATROL\_GO\_TO](/foundation/modding/api/agent_node_patrol_go_to "api:agent_node_patrol_go_to")
    
-   [BEHAVIOR\_BAILIFF](/foundation/modding/api/behavior_bailiff "api:behavior_bailiff")
    
-   [BEHAVIOR\_BUILDER](/foundation/modding/api/behavior_builder "api:behavior_builder")
    
-   [BEHAVIOR\_BUILDER\_CRAFTING](/foundation/modding/api/behavior_builder_crafting "api:behavior_builder_crafting")
    
-   [BEHAVIOR\_FARMER](/foundation/modding/api/behavior_farmer "api:behavior_farmer")
    
-   [BEHAVIOR\_FORESTER](/foundation/modding/api/behavior_forester "api:behavior_forester")
    
-   [BEHAVIOR\_GATHER](/foundation/modding/api/behavior_gather "api:behavior_gather")
    
-   [BEHAVIOR\_GUEST](/foundation/modding/api/behavior_guest "api:behavior_guest")
    
-   [BEHAVIOR\_LEAVE\_VILLAGE](/foundation/modding/api/behavior_leave_village "api:behavior_leave_village")
    
-   [BEHAVIOR\_LIVESTOCK](/foundation/modding/api/behavior_livestock "api:behavior_livestock")
    
-   [BEHAVIOR\_MARKET\_TENDING](/foundation/modding/api/behavior_market_tending "api:behavior_market_tending")
    
-   [BEHAVIOR\_PLANT](/foundation/modding/api/behavior_plant "api:behavior_plant")
    
-   [BEHAVIOR\_PROCESS\_HOUSE](/foundation/modding/api/behavior_process_house "api:behavior_process_house")
    
-   [BEHAVIOR\_PROCESS\_HOUSE\_MONK](/foundation/modding/api/behavior_process_house_monk "api:behavior_process_house_monk")
    
-   [BEHAVIOR\_PROCESS\_NEEDS](/foundation/modding/api/behavior_process_needs "api:behavior_process_needs")
    
-   [BEHAVIOR\_PRODUCE\_WITH\_GATHER](/foundation/modding/api/behavior_produce_with_gather "api:behavior_produce_with_gather")
    
-   [BEHAVIOR\_SOLDIER](/foundation/modding/api/behavior_soldier "api:behavior_soldier")
    
-   [BEHAVIOR\_SOLDIER\_BACK](/foundation/modding/api/behavior_soldier_back "api:behavior_soldier_back")
    
-   [BEHAVIOR\_SOLDIER\_GUARD](/foundation/modding/api/behavior_soldier_guard "api:behavior_soldier_guard")
    
-   [BEHAVIOR\_SOLDIER\_LEAVE](/foundation/modding/api/behavior_soldier_leave "api:behavior_soldier_leave")
    
-   [BEHAVIOR\_SOLDIER\_REGROUP](/foundation/modding/api/behavior_soldier_regroup "api:behavior_soldier_regroup")
    
-   [BEHAVIOR\_SOLDIER\_TRAINING](/foundation/modding/api/behavior_soldier_training "api:behavior_soldier_training")
    
-   [BEHAVIOR\_STUDY](/foundation/modding/api/behavior_study "api:behavior_study")
    
-   [BEHAVIOR\_TAX\_COLLECTION](/foundation/modding/api/behavior_tax_collection "api:behavior_tax_collection")
    
-   [BEHAVIOR\_TRANSPORT](/foundation/modding/api/behavior_transport "api:behavior_transport")
    
-   [BEHAVIOR\_TRANSPORTER](/foundation/modding/api/behavior_transporter "api:behavior_transporter")
    
-   [BEHAVIOR\_UPGRADE\_TRADE\_ROUTE](/foundation/modding/api/behavior_upgrade_trade_route "api:behavior_upgrade_trade_route")
    
-   [BEHAVIOR\_VILLAGER](/foundation/modding/api/behavior_villager "api:behavior_villager")
    
-   [BEHAVIOR\_VISITOR](/foundation/modding/api/behavior_visitor "api:behavior_visitor")
    
-   [BEHAVIOR\_VISIT\_BUILDING](/foundation/modding/api/behavior_visit_building "api:behavior_visit_building")
    
-   [BEHAVIOR\_WORK](/foundation/modding/api/behavior_work "api:behavior_work")
    
-   [BOARD\_BOAT](/foundation/modding/api/board_boat "api:board_boat")
    
-   [CHANGE\_EDICT](/foundation/modding/api/change_edict "api:change_edict")
    
-   [CHANGE\_PRIVILEGE](/foundation/modding/api/change_privilege "api:change_privilege")
    
-   [CHECK\_FARM\_STATE](/foundation/modding/api/check_farm_state "api:check_farm_state")
    
-   [CHECK\_IF\_NOT\_NULL](/foundation/modding/api/check_if_not_null "api:check_if_not_null")
    
-   [CHECK\_IF\_TRUE](/foundation/modding/api/check_if_true "api:check_if_true")
    
-   [COMPLETE\_MANDATE](/foundation/modding/api/complete_mandate "api:complete_mandate")
    
-   [DESTROY\_OBJECT](/foundation/modding/api/destroy_object "api:destroy_object")
    
-   [DISABLE\_PATH\_TRACING](/foundation/modding/api/disable_path_tracing "api:disable_path_tracing")
    
-   [DOCK\_BOAT](/foundation/modding/api/dock_boat "api:dock_boat")
    
-   [DROP\_STUFF\_TO\_DEPOT](/foundation/modding/api/drop_stuff_to_depot "api:drop_stuff_to_depot")
    
-   [ENABLE\_PATH\_TRACING](/foundation/modding/api/enable_path_tracing "api:enable_path_tracing")
    
-   [EXECUTE\_ACTION\_LIST\_WAIT](/foundation/modding/api/execute_action_list_wait "api:execute_action_list_wait")
    
-   [EXECUTE\_PLANNED\_PATH](/foundation/modding/api/execute_planned_path "api:execute_planned_path")
    
-   [FETCH\_NEXT\_GATHERABLE](/foundation/modding/api/fetch_next_gatherable "api:fetch_next_gatherable")
    
-   [FETCH\_NEXT\_PLANTABLE](/foundation/modding/api/fetch_next_plantable "api:fetch_next_plantable")
    
-   [FIND\_OR\_ASSIGN\_WORKPLACE](/foundation/modding/api/find_or_assign_workplace "api:find_or_assign_workplace")
    
-   [FIND\_RESOURCE\_FOR\_ROAD\_PAVING](/foundation/modding/api/find_resource_for_road_paving "api:find_resource_for_road_paving")
    
-   [FIND\_RESOURCE\_FOR\_WORKPLACE](/foundation/modding/api/find_resource_for_workplace "api:find_resource_for_workplace")
    
-   [FINISH\_WORK\_SHIFT](/foundation/modding/api/finish_work_shift "api:finish_work_shift")
    
-   [GAIN\_INFLUENCE](/foundation/modding/api/gain_influence "api:gain_influence")
    
-   [GATHER\_REQUEST](/foundation/modding/api/gather_request "api:gather_request")
    
-   [GATHER\_RESOURCE](/foundation/modding/api/gather_resource "api:gather_resource")
    
-   [GENERATE\_GATHERED\_RESOURCES](/foundation/modding/api/generate_gathered_resources "api:generate_gathered_resources")
    
-   [GIVE\_JOB\_XP](/foundation/modding/api/give_job_xp "api:give_job_xp")
    
-   [GO\_TO](/foundation/modding/api/go_to "api:go_to")
    
-   [INFLUENCE\_ESTATE](/foundation/modding/api/influence_estate "api:influence_estate")
    
-   [INVERTER](/foundation/modding/api/inverter "api:inverter")
    
-   [IS\_NEEDING\_RESOURCE\_FOR\_ROAD\_PAVING](/foundation/modding/api/is_needing_resource_for_road_paving "api:is_needing_resource_for_road_paving")
    
-   [IS\_RESOURCE\_READY\_TO\_PICKUP](/foundation/modding/api/is_resource_ready_to_pickup "api:is_resource_ready_to_pickup")
    
-   [IS\_WORKPLACE\_AVAILABLE](/foundation/modding/api/is_workplace_available "api:is_workplace_available")
    
-   [IS\_WORKPLACE\_NEED\_RESOURCE](/foundation/modding/api/is_workplace_need_resource "api:is_workplace_need_resource")
    
-   [LOOK\_AT](/foundation/modding/api/look_at "api:look_at")
    
-   [NEGOTIATING\_TRADES](/foundation/modding/api/negotiating_trades "api:negotiating_trades")
    
-   [NODE](/foundation/modding/api/node "api:node")
    
-   [NODE\_BRANCH](/foundation/modding/api/node_branch "api:node_branch")
    
-   [NODE\_COMPOSITE](/foundation/modding/api/node_composite "api:node_composite")
    
-   [NODE\_DECORATOR](/foundation/modding/api/node_decorator "api:node_decorator")
    
-   [NODE\_LEAF](/foundation/modding/api/node_leaf "api:node_leaf")
    
-   [NODE\_SET\_BOOL](/foundation/modding/api/node_set_bool "api:node_set_bool")
    
-   [PLANT](/foundation/modding/api/plant "api:plant")
    
-   [PLANT\_REQUEST](/foundation/modding/api/plant_request "api:plant_request")
    
-   [PLAN\_PATH](/foundation/modding/api/plan_path "api:plan_path")
    
-   [PRODUCE\_RESOURCE](/foundation/modding/api/produce_resource "api:produce_resource")
    
-   [PROSPECT](/foundation/modding/api/prospect "api:prospect")
    
-   [REPEAT](/foundation/modding/api/repeat "api:repeat")
    
-   [REPEAT\_UNTIL\_FAIL](/foundation/modding/api/repeat_until_fail "api:repeat_until_fail")
    
-   [REPEAT\_UNTIL\_SUCCESS](/foundation/modding/api/repeat_until_success "api:repeat_until_success")
    
-   [SELECTOR](/foundation/modding/api/selector "api:selector")
    
-   [SEQUENCER](/foundation/modding/api/sequencer "api:sequencer")
    
-   [SETUP\_CHANGE\_EDICT](/foundation/modding/api/setup_change_edict "api:setup_change_edict")
    
-   [SETUP\_CHANGE\_PRIVILEGE](/foundation/modding/api/setup_change_privilege "api:setup_change_privilege")
    
-   [SETUP\_FISHING](/foundation/modding/api/setup_fishing "api:setup_fishing")
    
-   [SETUP\_GATHERING\_WORK](/foundation/modding/api/setup_gathering_work "api:setup_gathering_work")
    
-   [SETUP\_GOTO\_WORKPLACE](/foundation/modding/api/setup_goto_workplace "api:setup_goto_workplace")
    
-   [SETUP\_GROWING\_WORK](/foundation/modding/api/setup_growing_work "api:setup_growing_work")
    
-   [SETUP\_PLANTING\_WORK](/foundation/modding/api/setup_planting_work "api:setup_planting_work")
    
-   [SETUP\_STUDY](/foundation/modding/api/setup_study "api:setup_study")
    
-   [SETUP\_TRAVELING\_FOR\_MANDATE](/foundation/modding/api/setup_traveling_for_mandate "api:setup_traveling_for_mandate")
    
-   [SETUP\_WORK](/foundation/modding/api/setup_work "api:setup_work")
    
-   [SETUP\_WORKPLACE\_TRANSPORT](/foundation/modding/api/setup_workplace_transport "api:setup_workplace_transport")
    
-   [SET\_ACTIVITY\_MESSAGE](/foundation/modding/api/set_activity_message "api:set_activity_message")
    
-   [SET\_AGENT\_UNAVAILABLE](/foundation/modding/api/set_agent_unavailable "api:set_agent_unavailable")
    
-   [SET\_INTERACTIVE\_LOCATION\_SETUP](/foundation/modding/api/set_interactive_location_setup "api:set_interactive_location_setup")
    
-   [SET\_OBJECT\_AS\_DESTINATION](/foundation/modding/api/set_object_as_destination "api:set_object_as_destination")
    
-   [SET\_ORIENTATION](/foundation/modding/api/set_orientation "api:set_orientation")
    
-   [SET\_WORKPLACE\_AS\_DESTINATION](/foundation/modding/api/set_workplace_as_destination "api:set_workplace_as_destination")
    
-   [START\_WORK\_SHIFT](/foundation/modding/api/start_work_shift "api:start_work_shift")
    
-   [STUDY\_BLUEPRINT](/foundation/modding/api/study_blueprint "api:study_blueprint")
    
-   [SUCCEEDER](/foundation/modding/api/succeeder "api:succeeder")
    
-   [WAIT](/foundation/modding/api/wait "api:wait")
    
-   [WAIT\_GROUP\_FOR\_PATROL](/foundation/modding/api/wait_group_for_patrol "api:wait_group_for_patrol")
    

## Behavior Tree Data Classes

-   [BEHAVIOR\_TREE\_DATA](/foundation/modding/api/behavior_tree_data "api:behavior_tree_data")
    
-   [BEHAVIOR\_TREE\_DATA\_ACTIVITY\_TYPE](/foundation/modding/api/behavior_tree_data_activity_type "api:behavior_tree_data_activity_type")
    
-   [BEHAVIOR\_TREE\_DATA\_AGENT](/foundation/modding/api/behavior_tree_data_agent "api:behavior_tree_data_agent")
    
-   [BEHAVIOR\_TREE\_DATA\_AGENT\_NEED](/foundation/modding/api/behavior_tree_data_agent_need "api:behavior_tree_data_agent_need")
    
-   [BEHAVIOR\_TREE\_DATA\_ANIMATION\_DATA](/foundation/modding/api/behavior_tree_data_animation_data "api:behavior_tree_data_animation_data")
    
-   [BEHAVIOR\_TREE\_DATA\_BOOL](/foundation/modding/api/behavior_tree_data_bool "api:behavior_tree_data_bool")
    
-   [BEHAVIOR\_TREE\_DATA\_BUILDING\_PATH\_TYPE](/foundation/modding/api/behavior_tree_data_building_path_type "api:behavior_tree_data_building_path_type")
    
-   [BEHAVIOR\_TREE\_DATA\_CHECK\_FARM\_STATE](/foundation/modding/api/behavior_tree_data_check_farm_state "api:behavior_tree_data_check_farm_state")
    
-   [BEHAVIOR\_TREE\_DATA\_FLOAT](/foundation/modding/api/behavior_tree_data_float "api:behavior_tree_data_float")
    
-   [BEHAVIOR\_TREE\_DATA\_GATHERING](/foundation/modding/api/behavior_tree_data_gathering "api:behavior_tree_data_gathering")
    
-   [BEHAVIOR\_TREE\_DATA\_HAPPINESS\_FACTOR](/foundation/modding/api/behavior_tree_data_happiness_factor "api:behavior_tree_data_happiness_factor")
    
-   [BEHAVIOR\_TREE\_DATA\_INTERACTIVE\_LOCATION\_PURPOSE](/foundation/modding/api/behavior_tree_data_interactive_location_purpose "api:behavior_tree_data_interactive_location_purpose")
    
-   [BEHAVIOR\_TREE\_DATA\_INTERACTIVE\_LOCATION\_SETUP](/foundation/modding/api/behavior_tree_data_interactive_location_setup "api:behavior_tree_data_interactive_location_setup")
    
-   [BEHAVIOR\_TREE\_DATA\_LOCATION](/foundation/modding/api/behavior_tree_data_location "api:behavior_tree_data_location")
    
-   [BEHAVIOR\_TREE\_DATA\_LOOP](/foundation/modding/api/behavior_tree_data_loop "api:behavior_tree_data_loop")
    
-   [BEHAVIOR\_TREE\_DATA\_PATH\_FLAG](/foundation/modding/api/behavior_tree_data_path_flag "api:behavior_tree_data_path_flag")
    
-   [BEHAVIOR\_TREE\_DATA\_PLANTABLE](/foundation/modding/api/behavior_tree_data_plantable "api:behavior_tree_data_plantable")
    
-   [BEHAVIOR\_TREE\_DATA\_PLANTABLE\_TARGET\_LIST](/foundation/modding/api/behavior_tree_data_plantable_target_list "api:behavior_tree_data_plantable_target_list")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE](/foundation/modding/api/behavior_tree_data_resource "api:behavior_tree_data_resource")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE\_CONSUMPTION](/foundation/modding/api/behavior_tree_data_resource_consumption "api:behavior_tree_data_resource_consumption")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE\_FETCHING\_ACTIVITY\_MESSAGE](/foundation/modding/api/behavior_tree_data_resource_fetching_activity_message "api:behavior_tree_data_resource_fetching_activity_message")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE\_PRODUCTION](/foundation/modding/api/behavior_tree_data_resource_production "api:behavior_tree_data_resource_production")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE\_QUANTITY\_PAIR](/foundation/modding/api/behavior_tree_data_resource_quantity_pair "api:behavior_tree_data_resource_quantity_pair")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE\_TRANSPORT](/foundation/modding/api/behavior_tree_data_resource_transport "api:behavior_tree_data_resource_transport")
    
-   [BEHAVIOR\_TREE\_DATA\_RESOURCE\_TYPE](/foundation/modding/api/behavior_tree_data_resource_type "api:behavior_tree_data_resource_type")
    
-   [BEHAVIOR\_TREE\_DATA\_STRING](/foundation/modding/api/behavior_tree_data_string "api:behavior_tree_data_string")
    
-   [BEHAVIOR\_TREE\_DATA\_VEC3F](/foundation/modding/api/behavior_tree_data_vec3f "api:behavior_tree_data_vec3f")
    
-   [BEHAVIOR\_TREE\_DATA\_VOID\_OBJECT](/foundation/modding/api/behavior_tree_data_void_object "api:behavior_tree_data_void_object")
    
-   [BEHAVIOR\_TREE\_DATA\_WAIT](/foundation/modding/api/behavior_tree_data_wait "api:behavior_tree_data_wait")
    

## Data Classes

-   [AGENT\_ACTIVITY\_MESSAGE](/foundation/modding/api/agent_activity_message "api:agent_activity_message")
    
-   [AGENT\_ACTIVITY\_MESSAGE\_PARAMETER](/foundation/modding/api/agent_activity_message_parameter "api:agent_activity_message_parameter")
    
-   [AGENT\_ACTIVITY\_MESSAGE\_PARAMETER\_BUILDABLE](/foundation/modding/api/agent_activity_message_parameter_buildable "api:agent_activity_message_parameter_buildable")
    
-   [AGENT\_ACTIVITY\_MESSAGE\_PARAMETER\_RESOURCE](/foundation/modding/api/agent_activity_message_parameter_resource "api:agent_activity_message_parameter_resource")
    
-   [AGENT\_PROFILE\_FUNCTION](/foundation/modding/api/agent_profile_function "api:agent_profile_function")
    
-   [AGENT\_PROFILE\_FUNCTION\_SOLDIER](/foundation/modding/api/agent_profile_function_soldier "api:agent_profile_function_soldier")
    
-   [AGENT\_PROFILE\_FUNCTION\_VISITOR](/foundation/modding/api/agent_profile_function_visitor "api:agent_profile_function_visitor")
    
-   [AGENT\_PROFILE\_GENDER\_USAGE\_PAIR](/foundation/modding/api/agent_profile_gender_usage_pair "api:agent_profile_gender_usage_pair")
    
-   [AGENT\_PROFILE\_STATUS\_PAIR](/foundation/modding/api/agent_profile_status_pair "api:agent_profile_status_pair")
    
-   [ASSEMBLAGE\_CUSTOM\_SET](/foundation/modding/api/assemblage_custom_set "api:assemblage_custom_set")
    
-   [ASSOCIATION\_JOB\_BEHAVIOR](/foundation/modding/api/association_job_behavior "api:association_job_behavior")
    
-   [BAILIFF\_INSTANCE](/foundation/modding/api/bailiff_instance "api:bailiff_instance")
    
-   [BAILIFF\_PROFILE](/foundation/modding/api/bailiff_profile "api:bailiff_profile")
    
-   [BEHAVIOR\_TREE\_INSTANCE](/foundation/modding/api/behavior_tree_instance "api:behavior_tree_instance")
    
-   [BUILDING\_ASSET\_TAXATION\_FUNCTION\_PAIR](/foundation/modding/api/building_asset_taxation_function_pair "api:building_asset_taxation_function_pair")
    
-   [BUILDING\_CONSTRUCTOR](/foundation/modding/api/building_constructor "api:building_constructor")
    
-   [BUILDING\_CONSTRUCTOR\_ASSEMBLAGE](/foundation/modding/api/building_constructor_assemblage "api:building_constructor_assemblage")
    
-   [BUILDING\_CONSTRUCTOR\_BASEMENT](/foundation/modding/api/building_constructor_basement "api:building_constructor_basement")
    
-   [BUILDING\_CONSTRUCTOR\_BRIDGE](/foundation/modding/api/building_constructor_bridge "api:building_constructor_bridge")
    
-   [BUILDING\_CONSTRUCTOR\_DEFAULT](/foundation/modding/api/building_constructor_default "api:building_constructor_default")
    
-   [BUILDING\_CONSTRUCTOR\_GATE](/foundation/modding/api/building_constructor_gate "api:building_constructor_gate")
    
-   [BUILDING\_CONSTRUCTOR\_PART\_SWITCHER](/foundation/modding/api/building_constructor_part_switcher "api:building_constructor_part_switcher")
    
-   [BUILDING\_CONSTRUCTOR\_RANDOM\_PART](/foundation/modding/api/building_constructor_random_part "api:building_constructor_random_part")
    
-   [BUILDING\_CONSTRUCTOR\_SCALER](/foundation/modding/api/building_constructor_scaler "api:building_constructor_scaler")
    
-   [BUILDING\_CONSTRUCTOR\_SCALER\_CONFIG](/foundation/modding/api/building_constructor_scaler_config "api:building_constructor_scaler_config")
    
-   [BUILDING\_CONSTRUCTOR\_SLOPE](/foundation/modding/api/building_constructor_slope "api:building_constructor_slope")
    
-   [BUILDING\_CONSTRUCTOR\_WALL](/foundation/modding/api/building_constructor_wall "api:building_constructor_wall")
    
-   [BUILDING\_ENTRANCE\_DATA](/foundation/modding/api/building_entrance_data "api:building_entrance_data")
    
-   [BUILDING\_FUNCTION\_STATS](/foundation/modding/api/building_function_stats "api:building_function_stats")
    
-   [BUILDING\_FUNCTION\_UINT\_STATS](/foundation/modding/api/building_function_uint_stats "api:building_function_uint_stats")
    
-   [BUILDING\_FUNCTION\_WAREHOUSE\_ALLOWED\_RESOURCE\_TYPE\_INFO](/foundation/modding/api/building_function_warehouse_allowed_resource_type_info "api:building_function_warehouse_allowed_resource_type_info")
    
-   [BUILDING\_INFORMATION](/foundation/modding/api/building_information "api:building_information")
    
-   [BUILDING\_ISSUE\_LIST\_ENTRY](/foundation/modding/api/building_issue_list_entry "api:building_issue_list_entry")
    
-   [BUILDING\_MINIATURE\_CONFIG](/foundation/modding/api/building_miniature_config "api:building_miniature_config")
    
-   [BUILDING\_PART\_CATEGORY\_CONFIG](/foundation/modding/api/building_part_category_config "api:building_part_category_config")
    
-   [BUILDING\_PART\_COST](/foundation/modding/api/building_part_cost "api:building_part_cost")
    
-   [BUILDING\_PART\_COST\_PAIR](/foundation/modding/api/building_part_cost_pair "api:building_part_cost_pair")
    
-   [BUILDING\_PART\_SET](/foundation/modding/api/building_part_set "api:building_part_set")
    
-   [BUILDING\_PATH](/foundation/modding/api/building_path "api:building_path")
    
-   [BUILDING\_PATH\_DATA](/foundation/modding/api/building_path_data "api:building_path_data")
    
-   [BUILDING\_PROGRESS](/foundation/modding/api/building_progress "api:building_progress")
    
-   [BUILDING\_TYPE\_CONFIG](/foundation/modding/api/building_type_config "api:building_type_config")
    
-   [BUILDING\_WAYPOINT\_DATA](/foundation/modding/api/building_waypoint_data "api:building_waypoint_data")
    
-   [BUILDING\_ZONE](/foundation/modding/api/building_zone "api:building_zone")
    
-   [BUILDING\_ZONE\_ENTRY](/foundation/modding/api/building_zone_entry "api:building_zone_entry")
    
-   [CHARACTER\_SETUP](/foundation/modding/api/character_setup "api:character_setup")
    
-   [CHARACTER\_SETUP\_DATA](/foundation/modding/api/character_setup_data "api:character_setup_data")
    
-   [CONDENSED\_HELP\_ITEM](/foundation/modding/api/condensed_help_item "api:condensed_help_item")
    
-   [CURVE\_FLOAT](/foundation/modding/api/curve_float "api:curve_float")
    
-   [CURVE\_VALUE](/foundation/modding/api/curve_value "api:curve_value")
    
-   [DATA\_HOUSE\_DENSITY](/foundation/modding/api/data_house_density "api:data_house_density")
    
-   [DATA\_NOTIFICATION\_ON\_CLICK](/foundation/modding/api/data_notification_on_click "api:data_notification_on_click")
    
-   [DATA\_NOTIFICATION\_ON\_CLICK\_BOOK](/foundation/modding/api/data_notification_on_click_book "api:data_notification_on_click_book")
    
-   [DATA\_NOTIFICATION\_ON\_CLICK\_BUILDING](/foundation/modding/api/data_notification_on_click_building "api:data_notification_on_click_building")
    
-   [DATA\_NOTIFICATION\_ON\_CLICK\_MANDATE\_WINDOW](/foundation/modding/api/data_notification_on_click_mandate_window "api:data_notification_on_click_mandate_window")
    
-   [DATA\_NOTIFICATION\_ON\_CLICK\_PROGRESSION](/foundation/modding/api/data_notification_on_click_progression "api:data_notification_on_click_progression")
    
-   [DATA\_WALL\_CRENELATION](/foundation/modding/api/data_wall_crenelation "api:data_wall_crenelation")
    
-   [DATA\_WALL\_PROCEDURAL\_MESH](/foundation/modding/api/data_wall_procedural_mesh "api:data_wall_procedural_mesh")
    
-   [DATA\_WALL\_SEGMENT](/foundation/modding/api/data_wall_segment "api:data_wall_segment")
    
-   [DECEASED\_VILLAGER\_DATA](/foundation/modding/api/deceased_villager_data "api:deceased_villager_data")
    
-   [DELAYED\_QUEST](/foundation/modding/api/delayed_quest "api:delayed_quest")
    
-   [DESIRABILITY\_LEVEL\_ITEM](/foundation/modding/api/desirability_level_item "api:desirability_level_item")
    
-   [DESIRABILITY\_MODIFIER\_ITEM](/foundation/modding/api/desirability_modifier_item "api:desirability_modifier_item")
    
-   [ESTATE\_MANDATE\_PAIR](/foundation/modding/api/estate_mandate_pair "api:estate_mandate_pair")
    
-   [ESTATE\_QUANTITY\_PAIR](/foundation/modding/api/estate_quantity_pair "api:estate_quantity_pair")
    
-   [ESTATE\_STRING\_ASSOCIATION](/foundation/modding/api/estate_string_association "api:estate_string_association")
    
-   [EVENT\_CALLBACK](/foundation/modding/api/event_callback "api:event_callback")
    
-   [EVENT\_CALLBACK\_SIMPLE\_PANEL](/foundation/modding/api/event_callback_simple_panel "api:event_callback_simple_panel")
    
-   [EVENT\_CALLBACK\_TRIGGER\_EVENT](/foundation/modding/api/event_callback_trigger_event "api:event_callback_trigger_event")
    
-   [EVENT\_CHOICE](/foundation/modding/api/event_choice "api:event_choice")
    
-   [EVENT\_CHOICE\_MANDATE\_STATE\_PAIR](/foundation/modding/api/event_choice_mandate_state_pair "api:event_choice_mandate_state_pair")
    
-   [EXTRACTED\_RESOURCE\_CONFIG](/foundation/modding/api/extracted_resource_config "api:extracted_resource_config")
    
-   [FARM\_SIZE\_FEEDBACK\_CONFIG](/foundation/modding/api/farm_size_feedback_config "api:farm_size_feedback_config")
    
-   [FLOAT\_VALUE\_PAIR](/foundation/modding/api/float_value_pair "api:float_value_pair")
    
-   [FORTIFICATION\_PARAMETERS](/foundation/modding/api/fortification_parameters "api:fortification_parameters")
    
-   [GAME\_ACTION](/foundation/modding/api/game_action "api:game_action")
    
-   [GAME\_ACTION\_ADD\_EVENT](/foundation/modding/api/game_action_add_event "api:game_action_add_event")
    
-   [GAME\_ACTION\_ADD\_MANDATE\_TYPE](/foundation/modding/api/game_action_add_mandate_type "api:game_action_add_mandate_type")
    
-   [GAME\_ACTION\_ADD\_TAXATION](/foundation/modding/api/game_action_add_taxation "api:game_action_add_taxation")
    
-   [GAME\_ACTION\_ADD\_TRADE\_ROUTE](/foundation/modding/api/game_action_add_trade_route "api:game_action_add_trade_route")
    
-   [GAME\_ACTION\_APPLY\_GAME\_RULE](/foundation/modding/api/game_action_apply_game_rule "api:game_action_apply_game_rule")
    
-   [GAME\_ACTION\_APPLY\_HAPPINESS\_FACTOR](/foundation/modding/api/game_action_apply_happiness_factor "api:game_action_apply_happiness_factor")
    
-   [GAME\_ACTION\_AUDIO](/foundation/modding/api/game_action_audio "api:game_action_audio")
    
-   [GAME\_ACTION\_CHANGE\_WEATHER](/foundation/modding/api/game_action_change_weather "api:game_action_change_weather")
    
-   [GAME\_ACTION\_CONDITIONAL\_ACTION\_LIST](/foundation/modding/api/game_action_conditional_action_list "api:game_action_conditional_action_list")
    
-   [GAME\_ACTION\_DELAY\_MANDATE](/foundation/modding/api/game_action_delay_mandate "api:game_action_delay_mandate")
    
-   [GAME\_ACTION\_DELIVER\_RESOURCE](/foundation/modding/api/game_action_deliver_resource "api:game_action_deliver_resource")
    
-   [GAME\_ACTION\_DICE\_ROLLER](/foundation/modding/api/game_action_dice_roller "api:game_action_dice_roller")
    
-   [GAME\_ACTION\_DICE\_ROLLER\_BOOLEAN\_OUTCOME](/foundation/modding/api/game_action_dice_roller_boolean_outcome "api:game_action_dice_roller_boolean_outcome")
    
-   [GAME\_ACTION\_DICE\_ROLLER\_ESTATE\_OPTION](/foundation/modding/api/game_action_dice_roller_estate_option "api:game_action_dice_roller_estate_option")
    
-   [GAME\_ACTION\_DICE\_ROLLER\_INFLUENCE](/foundation/modding/api/game_action_dice_roller_influence "api:game_action_dice_roller_influence")
    
-   [GAME\_ACTION\_DICE\_ROLLER\_PERCENTAGE](/foundation/modding/api/game_action_dice_roller_percentage "api:game_action_dice_roller_percentage")
    
-   [GAME\_ACTION\_DICE\_ROLLER\_PERCENTAGE\_OPTION](/foundation/modding/api/game_action_dice_roller_percentage_option "api:game_action_dice_roller_percentage_option")
    
-   [GAME\_ACTION\_EXECUTE\_ACTION\_BY\_GAME\_STEP](/foundation/modding/api/game_action_execute_action_by_game_step "api:game_action_execute_action_by_game_step")
    
-   [GAME\_ACTION\_GENERATE\_REWARD](/foundation/modding/api/game_action_generate_reward "api:game_action_generate_reward")
    
-   [GAME\_ACTION\_GIVE\_BLUEPRINT](/foundation/modding/api/game_action_give_blueprint "api:game_action_give_blueprint")
    
-   [GAME\_ACTION\_GIVE\_INFLUENCE](/foundation/modding/api/game_action_give_influence "api:game_action_give_influence")
    
-   [GAME\_ACTION\_GIVE\_QUEST](/foundation/modding/api/game_action_give_quest "api:game_action_give_quest")
    
-   [GAME\_ACTION\_GIVE\_RANDOM\_RESOURCE](/foundation/modding/api/game_action_give_random_resource "api:game_action_give_random_resource")
    
-   [GAME\_ACTION\_GIVE\_RESOURCE\_LIST](/foundation/modding/api/game_action_give_resource_list "api:game_action_give_resource_list")
    
-   [GAME\_ACTION\_GIVE\_RESOURCE\_LIST\_PER\_VILLAGER\_STATUS](/foundation/modding/api/game_action_give_resource_list_per_villager_status "api:game_action_give_resource_list_per_villager_status")
    
-   [GAME\_ACTION\_GIVE\_REWARD](/foundation/modding/api/game_action_give_reward "api:game_action_give_reward")
    
-   [GAME\_ACTION\_GIVE\_TERRITORY](/foundation/modding/api/game_action_give_territory "api:game_action_give_territory")
    
-   [GAME\_ACTION\_IGNORE](/foundation/modding/api/game_action_ignore "api:game_action_ignore")
    
-   [GAME\_ACTION\_IMMIGRATE](/foundation/modding/api/game_action_immigrate "api:game_action_immigrate")
    
-   [GAME\_ACTION\_KICK\_UNEMPLOYED\_VILLAGERS](/foundation/modding/api/game_action_kick_unemployed_villagers "api:game_action_kick_unemployed_villagers")
    
-   [GAME\_ACTION\_MILITARY\_CAMPAIGN\_ACTION](/foundation/modding/api/game_action_military_campaign_action "api:game_action_military_campaign_action")
    
-   [GAME\_ACTION\_PAUSE\_RECURRING\_EVENT](/foundation/modding/api/game_action_pause_recurring_event "api:game_action_pause_recurring_event")
    
-   [GAME\_ACTION\_RANDOM\_ACTION](/foundation/modding/api/game_action_random_action "api:game_action_random_action")
    
-   [GAME\_ACTION\_REMOVE\_MANDATE\_TYPE](/foundation/modding/api/game_action_remove_mandate_type "api:game_action_remove_mandate_type")
    
-   [GAME\_ACTION\_REMOVE\_TAXATION](/foundation/modding/api/game_action_remove_taxation "api:game_action_remove_taxation")
    
-   [GAME\_ACTION\_REMOVE\_TRADE\_ROUTE](/foundation/modding/api/game_action_remove_trade_route "api:game_action_remove_trade_route")
    
-   [GAME\_ACTION\_RESUME\_RECURRING\_EVENT](/foundation/modding/api/game_action_resume_recurring_event "api:game_action_resume_recurring_event")
    
-   [GAME\_ACTION\_SET\_VILLAGE\_LEVEL](/foundation/modding/api/game_action_set_village_level "api:game_action_set_village_level")
    
-   [GAME\_ACTION\_SHOW\_NARRATIVE\_PANEL](/foundation/modding/api/game_action_show_narrative_panel "api:game_action_show_narrative_panel")
    
-   [GAME\_ACTION\_SHOW\_OUTCOME\_PANEL](/foundation/modding/api/game_action_show_outcome_panel "api:game_action_show_outcome_panel")
    
-   [GAME\_ACTION\_SNOOZE\_RECURING\_EVENT](/foundation/modding/api/game_action_snooze_recuring_event "api:game_action_snooze_recuring_event")
    
-   [GAME\_ACTION\_STUB](/foundation/modding/api/game_action_stub "api:game_action_stub")
    
-   [GAME\_ACTION\_TRIGGER\_EVENT\_CALLBACK](/foundation/modding/api/game_action_trigger_event_callback "api:game_action_trigger_event_callback")
    
-   [GAME\_ACTION\_TRIGGER\_IMMIGRATION\_WAVE](/foundation/modding/api/game_action_trigger_immigration_wave "api:game_action_trigger_immigration_wave")
    
-   [GAME\_ACTION\_TRIGGER\_IMPORTANT\_HELP](/foundation/modding/api/game_action_trigger_important_help "api:game_action_trigger_important_help")
    
-   [GAME\_ACTION\_TRIGGER\_MILITARY\_CAMPAIGN](/foundation/modding/api/game_action_trigger_military_campaign "api:game_action_trigger_military_campaign")
    
-   [GAME\_ACTION\_UNLOCK\_BUILDING\_LIST](/foundation/modding/api/game_action_unlock_building_list "api:game_action_unlock_building_list")
    
-   [GAME\_ACTION\_UNLOCK\_EDICT](/foundation/modding/api/game_action_unlock_edict "api:game_action_unlock_edict")
    
-   [GAME\_ACTION\_UNLOCK\_EDICT\_SLOT](/foundation/modding/api/game_action_unlock_edict_slot "api:game_action_unlock_edict_slot")
    
-   [GAME\_ACTION\_UNLOCK\_PRIVILEGE](/foundation/modding/api/game_action_unlock_privilege "api:game_action_unlock_privilege")
    
-   [GAME\_ACTION\_UNLOCK\_PRIVILEGE\_SLOT](/foundation/modding/api/game_action_unlock_privilege_slot "api:game_action_unlock_privilege_slot")
    
-   [GAME\_ACTION\_UNLOCK\_SYSTEM](/foundation/modding/api/game_action_unlock_system "api:game_action_unlock_system")
    
-   [GAME\_ACTION\_UPGRADE\_TRADE\_ROUTE](/foundation/modding/api/game_action_upgrade_trade_route "api:game_action_upgrade_trade_route")
    
-   [GAME\_ACTION\_USE\_INFLUENCE](/foundation/modding/api/game_action_use_influence "api:game_action_use_influence")
    
-   [GAME\_ACTION\_VISIT](/foundation/modding/api/game_action_visit "api:game_action_visit")
    
-   [GAME\_CONDITION](/foundation/modding/api/game_condition "api:game_condition")
    
-   [GAME\_CONDITION\_ABOVE\_SURROUNDINGS](/foundation/modding/api/game_condition_above_surroundings "api:game_condition_above_surroundings")
    
-   [GAME\_CONDITION\_ACCUMULATE\_IN\_STORAGE](/foundation/modding/api/game_condition_accumulate_in_storage "api:game_condition_accumulate_in_storage")
    
-   [GAME\_CONDITION\_AGENT\_KILLED](/foundation/modding/api/game_condition_agent_killed "api:game_condition_agent_killed")
    
-   [GAME\_CONDITION\_ASSIGN\_JOB\_TO\_ALL\_VILLAGERS](/foundation/modding/api/game_condition_assign_job_to_all_villagers "api:game_condition_assign_job_to_all_villagers")
    
-   [GAME\_CONDITION\_ASSIGN\_TRADE\_RESOURCE](/foundation/modding/api/game_condition_assign_trade_resource "api:game_condition_assign_trade_resource")
    
-   [GAME\_CONDITION\_AVAILABLE\_VILLAGER\_FOR\_PROMOTION](/foundation/modding/api/game_condition_available_villager_for_promotion "api:game_condition_available_villager_for_promotion")
    
-   [GAME\_CONDITION\_BUILDING](/foundation/modding/api/game_condition_building "api:game_condition_building")
    
-   [GAME\_CONDITION\_BUILDING\_AVAILABLE](/foundation/modding/api/game_condition_building_available "api:game_condition_building_available")
    
-   [GAME\_CONDITION\_BUILDING\_BUILT](/foundation/modding/api/game_condition_building_built "api:game_condition_building_built")
    
-   [GAME\_CONDITION\_BUILDING\_FUNCTION\_ASSIGNED](/foundation/modding/api/game_condition_building_function_assigned "api:game_condition_building_function_assigned")
    
-   [GAME\_CONDITION\_BUILDING\_INVENTORY](/foundation/modding/api/game_condition_building_inventory "api:game_condition_building_inventory")
    
-   [GAME\_CONDITION\_BUILDING\_IN\_LAYER](/foundation/modding/api/game_condition_building_in_layer "api:game_condition_building_in_layer")
    
-   [GAME\_CONDITION\_BUILDING\_NOT\_BUILT](/foundation/modding/api/game_condition_building_not_built "api:game_condition_building_not_built")
    
-   [GAME\_CONDITION\_BUILDING\_PART\_COUNT](/foundation/modding/api/game_condition_building_part_count "api:game_condition_building_part_count")
    
-   [GAME\_CONDITION\_BUILDING\_REACHABLE](/foundation/modding/api/game_condition_building_reachable "api:game_condition_building_reachable")
    
-   [GAME\_CONDITION\_BUILDING\_SPLENDOR\_AMOUNT\_REACHED](/foundation/modding/api/game_condition_building_splendor_amount_reached "api:game_condition_building_splendor_amount_reached")
    
-   [GAME\_CONDITION\_BUILDING\_WORKER\_CAPACITY](/foundation/modding/api/game_condition_building_worker_capacity "api:game_condition_building_worker_capacity")
    
-   [GAME\_CONDITION\_COMPANY\_FORMED](/foundation/modding/api/game_condition_company_formed "api:game_condition_company_formed")
    
-   [GAME\_CONDITION\_COMPANY\_STRENGTH\_ATTAINED](/foundation/modding/api/game_condition_company_strength_attained "api:game_condition_company_strength_attained")
    
-   [GAME\_CONDITION\_CONSTRUCTION\_STEPS\_COMPLETED](/foundation/modding/api/game_condition_construction_steps_completed "api:game_condition_construction_steps_completed")
    
-   [GAME\_CONDITION\_DAY\_COUNT](/foundation/modding/api/game_condition_day_count "api:game_condition_day_count")
    
-   [GAME\_CONDITION\_DECORATIVE\_PART\_COUNT](/foundation/modding/api/game_condition_decorative_part_count "api:game_condition_decorative_part_count")
    
-   [GAME\_CONDITION\_EDICT\_ACTIVATED](/foundation/modding/api/game_condition_edict_activated "api:game_condition_edict_activated")
    
-   [GAME\_CONDITION\_ENCLOSED\_AREA](/foundation/modding/api/game_condition_enclosed_area "api:game_condition_enclosed_area")
    
-   [GAME\_CONDITION\_ENCLOSED\_AREA\_SIZE](/foundation/modding/api/game_condition_enclosed_area_size "api:game_condition_enclosed_area_size")
    
-   [GAME\_CONDITION\_EXECUTE\_ACTION\_LIST](/foundation/modding/api/game_condition_execute_action_list "api:game_condition_execute_action_list")
    
-   [GAME\_CONDITION\_FAR\_FROM\_OTHER\_BUILDINGS](/foundation/modding/api/game_condition_far_from_other_buildings "api:game_condition_far_from_other_buildings")
    
-   [GAME\_CONDITION\_FILL\_GUEST\_REQUIREMENTS](/foundation/modding/api/game_condition_fill_guest_requirements "api:game_condition_fill_guest_requirements")
    
-   [GAME\_CONDITION\_FOREST\_SURROUNDED](/foundation/modding/api/game_condition_forest_surrounded "api:game_condition_forest_surrounded")
    
-   [GAME\_CONDITION\_GAME\_STEP\_CONDITION\_LIST](/foundation/modding/api/game_condition_game_step_condition_list "api:game_condition_game_step_condition_list")
    
-   [GAME\_CONDITION\_HAS\_ZONE](/foundation/modding/api/game_condition_has_zone "api:game_condition_has_zone")
    
-   [GAME\_CONDITION\_HOUSE\_HAS\_HOUSE\_OF\_DENSITY\_AND\_QUALITY](/foundation/modding/api/game_condition_house_has_house_of_density_and_quality "api:game_condition_house_has_house_of_density_and_quality")
    
-   [GAME\_CONDITION\_INFLUENCE\_AMOUNT\_REACHED](/foundation/modding/api/game_condition_influence_amount_reached "api:game_condition_influence_amount_reached")
    
-   [GAME\_CONDITION\_INSIDE\_ZONE](/foundation/modding/api/game_condition_inside_zone "api:game_condition_inside_zone")
    
-   [GAME\_CONDITION\_IN\_LAYER](/foundation/modding/api/game_condition_in_layer "api:game_condition_in_layer")
    
-   [GAME\_CONDITION\_JOB\_STATUS\_REQUIRED](/foundation/modding/api/game_condition_job_status_required "api:game_condition_job_status_required")
    
-   [GAME\_CONDITION\_LODGING\_OPENED](/foundation/modding/api/game_condition_lodging_opened "api:game_condition_lodging_opened")
    
-   [GAME\_CONDITION\_MANDATE\_STATE](/foundation/modding/api/game_condition_mandate_state "api:game_condition_mandate_state")
    
-   [GAME\_CONDITION\_MAXIMUM\_COIN\_CAPACITY](/foundation/modding/api/game_condition_maximum_coin_capacity "api:game_condition_maximum_coin_capacity")
    
-   [GAME\_CONDITION\_MILITARY\_CAMPAIGN\_COMPLETED](/foundation/modding/api/game_condition_military_campaign_completed "api:game_condition_military_campaign_completed")
    
-   [GAME\_CONDITION\_MILITARY\_CAMPAIGN\_ONGOING](/foundation/modding/api/game_condition_military_campaign_ongoing "api:game_condition_military_campaign_ongoing")
    
-   [GAME\_CONDITION\_MILITARY\_COMPANY\_BEHAVIOR](/foundation/modding/api/game_condition_military_company_behavior "api:game_condition_military_company_behavior")
    
-   [GAME\_CONDITION\_MULTIPLE\_CONDITION](/foundation/modding/api/game_condition_multiple_condition "api:game_condition_multiple_condition")
    
-   [GAME\_CONDITION\_NON\_DECORATIVE\_PART\_COUNT](/foundation/modding/api/game_condition_non_decorative_part_count "api:game_condition_non_decorative_part_count")
    
-   [GAME\_CONDITION\_PART\_OF\_BUILDING](/foundation/modding/api/game_condition_part_of_building "api:game_condition_part_of_building")
    
-   [GAME\_CONDITION\_POPULATION\_COUNT](/foundation/modding/api/game_condition_population_count "api:game_condition_population_count")
    
-   [GAME\_CONDITION\_PRIVILEGE\_ACTIVATED](/foundation/modding/api/game_condition_privilege_activated "api:game_condition_privilege_activated")
    
-   [GAME\_CONDITION\_PROBABILITY](/foundation/modding/api/game_condition_probability "api:game_condition_probability")
    
-   [GAME\_CONDITION\_QUEST\_STATE](/foundation/modding/api/game_condition_quest_state "api:game_condition_quest_state")
    
-   [GAME\_CONDITION\_RESOURCE\_LIST\_PRODUCED](/foundation/modding/api/game_condition_resource_list_produced "api:game_condition_resource_list_produced")
    
-   [GAME\_CONDITION\_RESOURCE\_PRODUCED](/foundation/modding/api/game_condition_resource_produced "api:game_condition_resource_produced")
    
-   [GAME\_CONDITION\_RESOURCE\_PRODUCED\_FOR\_NEED](/foundation/modding/api/game_condition_resource_produced_for_need "api:game_condition_resource_produced_for_need")
    
-   [GAME\_CONDITION\_RESOURCE\_QUANTITY\_NUMBER](/foundation/modding/api/game_condition_resource_quantity_number "api:game_condition_resource_quantity_number")
    
-   [GAME\_CONDITION\_RESOURCE\_UNLOCKED](/foundation/modding/api/game_condition_resource_unlocked "api:game_condition_resource_unlocked")
    
-   [GAME\_CONDITION\_RESSOURCE\_ASSIGNED](/foundation/modding/api/game_condition_ressource_assigned "api:game_condition_ressource_assigned")
    
-   [GAME\_CONDITION\_REVENUE](/foundation/modding/api/game_condition_revenue "api:game_condition_revenue")
    
-   [GAME\_CONDITION\_SCORE](/foundation/modding/api/game_condition_score "api:game_condition_score")
    
-   [GAME\_CONDITION\_SPLENDOR\_CHANGE](/foundation/modding/api/game_condition_splendor_change "api:game_condition_splendor_change")
    
-   [GAME\_CONDITION\_SPLENDOR\_REACHED](/foundation/modding/api/game_condition_splendor_reached "api:game_condition_splendor_reached")
    
-   [GAME\_CONDITION\_SURVIVE\_BAD\_WEATHER](/foundation/modding/api/game_condition_survive_bad_weather "api:game_condition_survive_bad_weather")
    
-   [GAME\_CONDITION\_TAX\_ACTIVATED](/foundation/modding/api/game_condition_tax_activated "api:game_condition_tax_activated")
    
-   [GAME\_CONDITION\_TAX\_METER\_CHANGED](/foundation/modding/api/game_condition_tax_meter_changed "api:game_condition_tax_meter_changed")
    
-   [GAME\_CONDITION\_TERRITORY\_BOUGHT](/foundation/modding/api/game_condition_territory_bought "api:game_condition_territory_bought")
    
-   [GAME\_CONDITION\_TIER\_UNLOCKED](/foundation/modding/api/game_condition_tier_unlocked "api:game_condition_tier_unlocked")
    
-   [GAME\_CONDITION\_TRADE\_AMOUNT](/foundation/modding/api/game_condition_trade_amount "api:game_condition_trade_amount")
    
-   [GAME\_CONDITION\_TRADE\_RESOURCE\_QUANTITY](/foundation/modding/api/game_condition_trade_resource_quantity "api:game_condition_trade_resource_quantity")
    
-   [GAME\_CONDITION\_TRADE\_ROUTE\_LEVEL](/foundation/modding/api/game_condition_trade_route_level "api:game_condition_trade_route_level")
    
-   [GAME\_CONDITION\_TRADE\_ROUTE\_READY\_TO\_BE\_UPGRADED](/foundation/modding/api/game_condition_trade_route_ready_to_be_upgraded "api:game_condition_trade_route_ready_to_be_upgraded")
    
-   [GAME\_CONDITION\_UNLOCKABLE\_BOUGHT](/foundation/modding/api/game_condition_unlockable_bought "api:game_condition_unlockable_bought")
    
-   [GAME\_CONDITION\_UNLOCK\_FUNCTION\_UNLOCKED](/foundation/modding/api/game_condition_unlock_function_unlocked "api:game_condition_unlock_function_unlocked")
    
-   [GAME\_CONDITION\_UNLOCK\_TRADE\_ROUTE](/foundation/modding/api/game_condition_unlock_trade_route "api:game_condition_unlock_trade_route")
    
-   [GAME\_CONDITION\_VILLAGER\_HAPPINESS\_COUNT](/foundation/modding/api/game_condition_villager_happiness_count "api:game_condition_villager_happiness_count")
    
-   [GAME\_CONDITION\_VILLAGER\_HAPPINESS\_GLOBAL](/foundation/modding/api/game_condition_villager_happiness_global "api:game_condition_villager_happiness_global")
    
-   [GAME\_CONDITION\_VILLAGER\_NEED\_FILLED](/foundation/modding/api/game_condition_villager_need_filled "api:game_condition_villager_need_filled")
    
-   [GAME\_CONDITION\_VILLAGER\_PROMOTED](/foundation/modding/api/game_condition_villager_promoted "api:game_condition_villager_promoted")
    
-   [GAME\_CONDITION\_VILLAGER\_STATUS\_REACHED](/foundation/modding/api/game_condition_villager_status_reached "api:game_condition_villager_status_reached")
    
-   [GAME\_CONDITION\_VISIT](/foundation/modding/api/game_condition_visit "api:game_condition_visit")
    
-   [GAME\_CONDITION\_WALL\_SIZE](/foundation/modding/api/game_condition_wall_size "api:game_condition_wall_size")
    
-   [GAME\_CONDITION\_WORKER\_ASSIGNED](/foundation/modding/api/game_condition_worker_assigned "api:game_condition_worker_assigned")
    
-   [GAME\_CONDITION\_WORKPLACE\_RECIPE\_YIELD](/foundation/modding/api/game_condition_workplace_recipe_yield "api:game_condition_workplace_recipe_yield")
    
-   [GAME\_CONDITION\_WOUNDED\_COUNT](/foundation/modding/api/game_condition_wounded_count "api:game_condition_wounded_count")
    
-   [GAME\_RULE\_MODIFIER](/foundation/modding/api/game_rule_modifier "api:game_rule_modifier")
    
-   [GAME\_RULE\_MODIFIER\_AGENT\_HAPPINESS](/foundation/modding/api/game_rule_modifier_agent_happiness "api:game_rule_modifier_agent_happiness")
    
-   [GAME\_RULE\_MODIFIER\_APPLY\_ACTION](/foundation/modding/api/game_rule_modifier_apply_action "api:game_rule_modifier_apply_action")
    
-   [GAME\_RULE\_MODIFIER\_BLOCK\_TRADE\_ROUTE](/foundation/modding/api/game_rule_modifier_block_trade_route "api:game_rule_modifier_block_trade_route")
    
-   [GAME\_RULE\_MODIFIER\_BUILDABLE\_AS\_POINT\_OF\_INTEREST](/foundation/modding/api/game_rule_modifier_buildable_as_point_of_interest "api:game_rule_modifier_buildable_as_point_of_interest")
    
-   [GAME\_RULE\_MODIFIER\_BUILDING\_BEAUTIFICATION](/foundation/modding/api/game_rule_modifier_building_beautification "api:game_rule_modifier_building_beautification")
    
-   [GAME\_RULE\_MODIFIER\_BUILDING\_MAINTENANCE\_COST](/foundation/modding/api/game_rule_modifier_building_maintenance_cost "api:game_rule_modifier_building_maintenance_cost")
    
-   [GAME\_RULE\_MODIFIER\_BUILDING\_SPLENDOR](/foundation/modding/api/game_rule_modifier_building_splendor "api:game_rule_modifier_building_splendor")
    
-   [GAME\_RULE\_MODIFIER\_CONCURRING\_TAXES\_BONUS](/foundation/modding/api/game_rule_modifier_concurring_taxes_bonus "api:game_rule_modifier_concurring_taxes_bonus")
    
-   [GAME\_RULE\_MODIFIER\_CONDITIONAL\_GAME\_RULE](/foundation/modding/api/game_rule_modifier_conditional_game_rule "api:game_rule_modifier_conditional_game_rule")
    
-   [GAME\_RULE\_MODIFIER\_CONSTRUCTION\_REFUND](/foundation/modding/api/game_rule_modifier_construction_refund "api:game_rule_modifier_construction_refund")
    
-   [GAME\_RULE\_MODIFIER\_CROP\_YIELDS](/foundation/modding/api/game_rule_modifier_crop_yields "api:game_rule_modifier_crop_yields")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR](/foundation/modding/api/game_rule_modifier_descriptor "api:game_rule_modifier_descriptor")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_BUILDABLE](/foundation/modding/api/game_rule_modifier_descriptor_buildable "api:game_rule_modifier_descriptor_buildable")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_EDICT](/foundation/modding/api/game_rule_modifier_descriptor_edict "api:game_rule_modifier_descriptor_edict")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_EVENT](/foundation/modding/api/game_rule_modifier_descriptor_event "api:game_rule_modifier_descriptor_event")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_HOUSE\_MOVE](/foundation/modding/api/game_rule_modifier_descriptor_house_move "api:game_rule_modifier_descriptor_house_move")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_JOB\_STATUS](/foundation/modding/api/game_rule_modifier_descriptor_job_status "api:game_rule_modifier_descriptor_job_status")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_NEED\_TYPE](/foundation/modding/api/game_rule_modifier_descriptor_need_type "api:game_rule_modifier_descriptor_need_type")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_PRIVILEGE](/foundation/modding/api/game_rule_modifier_descriptor_privilege "api:game_rule_modifier_descriptor_privilege")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_STATUS](/foundation/modding/api/game_rule_modifier_descriptor_status "api:game_rule_modifier_descriptor_status")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_STRING](/foundation/modding/api/game_rule_modifier_descriptor_string "api:game_rule_modifier_descriptor_string")
    
-   [GAME\_RULE\_MODIFIER\_DESCRIPTOR\_UNLOCKABLE](/foundation/modding/api/game_rule_modifier_descriptor_unlockable "api:game_rule_modifier_descriptor_unlockable")
    
-   [GAME\_RULE\_MODIFIER\_DISALLOW\_OPTIONAL\_EVENTS](/foundation/modding/api/game_rule_modifier_disallow_optional_events "api:game_rule_modifier_disallow_optional_events")
    
-   [GAME\_RULE\_MODIFIER\_ESTATE\_BUILDING\_MAINTENANCE\_COST](/foundation/modding/api/game_rule_modifier_estate_building_maintenance_cost "api:game_rule_modifier_estate_building_maintenance_cost")
    
-   [GAME\_RULE\_MODIFIER\_ESTATE\_DEFAULT\_INFLUENCE](/foundation/modding/api/game_rule_modifier_estate_default_influence "api:game_rule_modifier_estate_default_influence")
    
-   [GAME\_RULE\_MODIFIER\_ESTATE\_INFLUENCE](/foundation/modding/api/game_rule_modifier_estate_influence "api:game_rule_modifier_estate_influence")
    
-   [GAME\_RULE\_MODIFIER\_ESTATE\_SPLENDOR\_IMPACT](/foundation/modding/api/game_rule_modifier_estate_splendor_impact "api:game_rule_modifier_estate_splendor_impact")
    
-   [GAME\_RULE\_MODIFIER\_FREE\_TERRITORY](/foundation/modding/api/game_rule_modifier_free_territory "api:game_rule_modifier_free_territory")
    
-   [GAME\_RULE\_MODIFIER\_HAPPINESS](/foundation/modding/api/game_rule_modifier_happiness "api:game_rule_modifier_happiness")
    
-   [GAME\_RULE\_MODIFIER\_IMMIGRATION\_IGNORE\_FACTOR](/foundation/modding/api/game_rule_modifier_immigration_ignore_factor "api:game_rule_modifier_immigration_ignore_factor")
    
-   [GAME\_RULE\_MODIFIER\_IMMIGRATION\_RATE](/foundation/modding/api/game_rule_modifier_immigration_rate "api:game_rule_modifier_immigration_rate")
    
-   [GAME\_RULE\_MODIFIER\_IMPROVE\_AREA\_DESIRABILITY](/foundation/modding/api/game_rule_modifier_improve_area_desirability "api:game_rule_modifier_improve_area_desirability")
    
-   [GAME\_RULE\_MODIFIER\_INFINITE\_GOLD\_COINS](/foundation/modding/api/game_rule_modifier_infinite_gold_coins "api:game_rule_modifier_infinite_gold_coins")
    
-   [GAME\_RULE\_MODIFIER\_INSTANT\_BUILD](/foundation/modding/api/game_rule_modifier_instant_build "api:game_rule_modifier_instant_build")
    
-   [GAME\_RULE\_MODIFIER\_INVINCIBLE\_ARMY](/foundation/modding/api/game_rule_modifier_invincible_army "api:game_rule_modifier_invincible_army")
    
-   [GAME\_RULE\_MODIFIER\_JOB\_LEARNING\_SPEED](/foundation/modding/api/game_rule_modifier_job_learning_speed "api:game_rule_modifier_job_learning_speed")
    
-   [GAME\_RULE\_MODIFIER\_JOB\_STATUS](/foundation/modding/api/game_rule_modifier_job_status "api:game_rule_modifier_job_status")
    
-   [GAME\_RULE\_MODIFIER\_MANDATE\_COST](/foundation/modding/api/game_rule_modifier_mandate_cost "api:game_rule_modifier_mandate_cost")
    
-   [GAME\_RULE\_MODIFIER\_MANDATE\_TIME](/foundation/modding/api/game_rule_modifier_mandate_time "api:game_rule_modifier_mandate_time")
    
-   [GAME\_RULE\_MODIFIER\_MILITARY\_MISSSION\_IMPAIRMENT\_CHANCE](/foundation/modding/api/game_rule_modifier_military_misssion_impairment_chance "api:game_rule_modifier_military_misssion_impairment_chance")
    
-   [GAME\_RULE\_MODIFIER\_MILITARY\_TRAINING](/foundation/modding/api/game_rule_modifier_military_training "api:game_rule_modifier_military_training")
    
-   [GAME\_RULE\_MODIFIER\_MINIMUM\_HAPPINESS\_FOR\_LEAVING](/foundation/modding/api/game_rule_modifier_minimum_happiness_for_leaving "api:game_rule_modifier_minimum_happiness_for_leaving")
    
-   [GAME\_RULE\_MODIFIER\_NATURAL\_RESOURCES\_REGROWTH\_DURATION](/foundation/modding/api/game_rule_modifier_natural_resources_regrowth_duration "api:game_rule_modifier_natural_resources_regrowth_duration")
    
-   [GAME\_RULE\_MODIFIER\_NEED\_PERMANENTLY\_FILLED](/foundation/modding/api/game_rule_modifier_need_permanently_filled "api:game_rule_modifier_need_permanently_filled")
    
-   [GAME\_RULE\_MODIFIER\_NEED\_TYPE\_DEPLETE\_RATE](/foundation/modding/api/game_rule_modifier_need_type_deplete_rate "api:game_rule_modifier_need_type_deplete_rate")
    
-   [GAME\_RULE\_MODIFIER\_OVERRIDE\_VILLAGER\_HAPPINESS](/foundation/modding/api/game_rule_modifier_override_villager_happiness "api:game_rule_modifier_override_villager_happiness")
    
-   [GAME\_RULE\_MODIFIER\_PRODUCTION\_CYCLE\_DURATION\_MULTIPLIER](/foundation/modding/api/game_rule_modifier_production_cycle_duration_multiplier "api:game_rule_modifier_production_cycle_duration_multiplier")
    
-   [GAME\_RULE\_MODIFIER\_PROSPECT\_ALL\_MINERAL\_DEPOSIT](/foundation/modding/api/game_rule_modifier_prospect_all_mineral_deposit "api:game_rule_modifier_prospect_all_mineral_deposit")
    
-   [GAME\_RULE\_MODIFIER\_RESIDENTIAL\_MAX\_TAX\_REVENUE](/foundation/modding/api/game_rule_modifier_residential_max_tax_revenue "api:game_rule_modifier_residential_max_tax_revenue")
    
-   [GAME\_RULE\_MODIFIER\_RESOURCE\_DEPOT\_CAPACITY](/foundation/modding/api/game_rule_modifier_resource_depot_capacity "api:game_rule_modifier_resource_depot_capacity")
    
-   [GAME\_RULE\_MODIFIER\_SCALE\_EVENT\_INFLUENCE\_REWARD\_AMOUNT](/foundation/modding/api/game_rule_modifier_scale_event_influence_reward_amount "api:game_rule_modifier_scale_event_influence_reward_amount")
    
-   [GAME\_RULE\_MODIFIER\_SCALE\_EVENT\_RESOURCE\_REWARD\_AMOUNT](/foundation/modding/api/game_rule_modifier_scale_event_resource_reward_amount "api:game_rule_modifier_scale_event_resource_reward_amount")
    
-   [GAME\_RULE\_MODIFIER\_SOLDIER\_RECOVERY\_SPEED](/foundation/modding/api/game_rule_modifier_soldier_recovery_speed "api:game_rule_modifier_soldier_recovery_speed")
    
-   [GAME\_RULE\_MODIFIER\_SOLDIER\_STRENGTH\_FROM\_HAPPINESS](/foundation/modding/api/game_rule_modifier_soldier_strength_from_happiness "api:game_rule_modifier_soldier_strength_from_happiness")
    
-   [GAME\_RULE\_MODIFIER\_TAXATION\_CUMULATION\_BONUS](/foundation/modding/api/game_rule_modifier_taxation_cumulation_bonus "api:game_rule_modifier_taxation_cumulation_bonus")
    
-   [GAME\_RULE\_MODIFIER\_TAXATION\_HOUSING\_HAPPINESS\_FACTOR\_MULTIPLIER](/foundation/modding/api/game_rule_modifier_taxation_housing_happiness_factor_multiplier "api:game_rule_modifier_taxation_housing_happiness_factor_multiplier")
    
-   [GAME\_RULE\_MODIFIER\_TERRITORY\_UPKEEP](/foundation/modding/api/game_rule_modifier_territory_upkeep "api:game_rule_modifier_territory_upkeep")
    
-   [GAME\_RULE\_MODIFIER\_TRADER\_VISIT\_DELAY\_MULTIPLIER](/foundation/modding/api/game_rule_modifier_trader_visit_delay_multiplier "api:game_rule_modifier_trader_visit_delay_multiplier")
    
-   [GAME\_RULE\_MODIFIER\_TRADE\_BONUS](/foundation/modding/api/game_rule_modifier_trade_bonus "api:game_rule_modifier_trade_bonus")
    
-   [GAME\_RULE\_MODIFIER\_TRADE\_COMPLETED\_INFLUENCE](/foundation/modding/api/game_rule_modifier_trade_completed_influence "api:game_rule_modifier_trade_completed_influence")
    
-   [GAME\_RULE\_MODIFIER\_TRADE\_RESOURCE\_PRICE\_BONUS](/foundation/modding/api/game_rule_modifier_trade_resource_price_bonus "api:game_rule_modifier_trade_resource_price_bonus")
    
-   [GAME\_RULE\_MODIFIER\_TRADE\_SCALING\_FACTOR](/foundation/modding/api/game_rule_modifier_trade_scaling_factor "api:game_rule_modifier_trade_scaling_factor")
    
-   [GAME\_RULE\_MODIFIER\_UNLIMITED\_SMALL\_MINERAL\_DEPOSIT](/foundation/modding/api/game_rule_modifier_unlimited_small_mineral_deposit "api:game_rule_modifier_unlimited_small_mineral_deposit")
    
-   [GAME\_RULE\_MODIFIER\_UNLOCK\_ALL\_TERRITORIES](/foundation/modding/api/game_rule_modifier_unlock_all_territories "api:game_rule_modifier_unlock_all_territories")
    
-   [GAME\_RULE\_MODIFIER\_UNLOCK\_ALL\_UNLOCKABLES](/foundation/modding/api/game_rule_modifier_unlock_all_unlockables "api:game_rule_modifier_unlock_all_unlockables")
    
-   [GAME\_RULE\_MODIFIER\_UNLOCK\_AND\_UPGRADE\_TRADE\_ROUTE](/foundation/modding/api/game_rule_modifier_unlock_and_upgrade_trade_route "api:game_rule_modifier_unlock_and_upgrade_trade_route")
    
-   [GAME\_RULE\_MODIFIER\_UPKEEP\_BUILDING\_PARTS](/foundation/modding/api/game_rule_modifier_upkeep_building_parts "api:game_rule_modifier_upkeep_building_parts")
    
-   [GAME\_RULE\_MODIFIER\_VILLAGER\_HAPPINESS](/foundation/modding/api/game_rule_modifier_villager_happiness "api:game_rule_modifier_villager_happiness")
    
-   [GAME\_RULE\_MODIFIER\_WORKPLACE\_RECIPE](/foundation/modding/api/game_rule_modifier_workplace_recipe "api:game_rule_modifier_workplace_recipe")
    
-   [GAME\_STEP\_ACTION\_LIST\_PAIR](/foundation/modding/api/game_step_action_list_pair "api:game_step_action_list_pair")
    
-   [GAME\_STEP\_CONDITION\_LIST\_PAIR](/foundation/modding/api/game_step_condition_list_pair "api:game_step_condition_list_pair")
    
-   [GATE\_SNAPPING\_SETTINGS](/foundation/modding/api/gate_snapping_settings "api:gate_snapping_settings")
    
-   [GRADIENT](/foundation/modding/api/gradient "api:gradient")
    
-   [GRADIENT\_ALPHA\_VALUE](/foundation/modding/api/gradient_alpha_value "api:gradient_alpha_value")
    
-   [GRADIENT\_COLOR\_VALUE](/foundation/modding/api/gradient_color_value "api:gradient_color_value")
    
-   [GUEST\_QUANTITY\_PAIR](/foundation/modding/api/guest_quantity_pair "api:guest_quantity_pair")
    
-   [HAIRCUT](/foundation/modding/api/haircut "api:haircut")
    
-   [HAND\_OBJECT](/foundation/modding/api/hand_object "api:hand_object")
    
-   [HELP\_CATEGORY](/foundation/modding/api/help_category "api:help_category")
    
-   [HELP\_INSTANCE](/foundation/modding/api/help_instance "api:help_instance")
    
-   [HELP\_TOPIC](/foundation/modding/api/help_topic "api:help_topic")
    
-   [HERALDRY](/foundation/modding/api/heraldry "api:heraldry")
    
-   [HERALDRY\_CONFIG](/foundation/modding/api/heraldry_config "api:heraldry_config")
    
-   [HOSTING\_MISSION\_FEEDBACK](/foundation/modding/api/hosting_mission_feedback "api:hosting_mission_feedback")
    
-   [HOSTING\_MISSION\_FEEDBACK\_HAPPINESS\_PAIR](/foundation/modding/api/hosting_mission_feedback_happiness_pair "api:hosting_mission_feedback_happiness_pair")
    
-   [HOUSE\_DENSITY\_PATROL\_PARAMETERS](/foundation/modding/api/house_density_patrol_parameters "api:house_density_patrol_parameters")
    
-   [HOUSE\_STATUS](/foundation/modding/api/house_status "api:house_status")
    
-   [IMMIGRATION\_PROBABILITY\_SETTING](/foundation/modding/api/immigration_probability_setting "api:immigration_probability_setting")
    
-   [INCOMING\_RESERVED\_RESOURCE\_LIST](/foundation/modding/api/incoming_reserved_resource_list "api:incoming_reserved_resource_list")
    
-   [INST\_TAXATION\_COLLECT\_INFO](/foundation/modding/api/inst_taxation_collect_info "api:inst_taxation_collect_info")
    
-   [INST\_TAXATION\_COLLECT\_INFO\_BUILDING](/foundation/modding/api/inst_taxation_collect_info_building "api:inst_taxation_collect_info_building")
    
-   [INST\_TAXATION\_FUNCTION](/foundation/modding/api/inst_taxation_function "api:inst_taxation_function")
    
-   [INST\_TAXATION\_FUNCTION\_BRACKET](/foundation/modding/api/inst_taxation_function_bracket "api:inst_taxation_function_bracket")
    
-   [INST\_UNLOCKABLE\_COST](/foundation/modding/api/inst_unlockable_cost "api:inst_unlockable_cost")
    
-   [JOB\_INSTANCE](/foundation/modding/api/job_instance "api:job_instance")
    
-   [JOB\_PROGRESSION\_ELEMENT](/foundation/modding/api/job_progression_element "api:job_progression_element")
    
-   [MANDATE](/foundation/modding/api/mandate "api:mandate")
    
-   [MAP\_DENSITY\_PREFAB\_CONFIG](/foundation/modding/api/map_density_prefab_config "api:map_density_prefab_config")
    
-   [MAP\_DENSITY\_SPAWN\_INFO](/foundation/modding/api/map_density_spawn_info "api:map_density_spawn_info")
    
-   [MAP\_SPAWN\_INFO](/foundation/modding/api/map_spawn_info "api:map_spawn_info")
    
-   [MAP\_VILLAGE\_PATH](/foundation/modding/api/map_village_path "api:map_village_path")
    
-   [MASTERPIECE\_EFFECT\_CONDITION](/foundation/modding/api/masterpiece_effect_condition "api:masterpiece_effect_condition")
    
-   [MATERIAL\_SET](/foundation/modding/api/material_set "api:material_set")
    
-   [MILITARY\_CAMPAIGN\_DURATION\_STRING\_RANGE](/foundation/modding/api/military_campaign_duration_string_range "api:military_campaign_duration_string_range")
    
-   [MILITARY\_CAMPAIGN\_INSTANCE](/foundation/modding/api/military_campaign_instance "api:military_campaign_instance")
    
-   [MILITARY\_CAMPAIGN\_PROBABILITY](/foundation/modding/api/military_campaign_probability "api:military_campaign_probability")
    
-   [MILITARY\_CAMPAIGN\_STEP](/foundation/modding/api/military_campaign_step "api:military_campaign_step")
    
-   [MILITARY\_CAMPAIGN\_SUCCESS\_RANGE](/foundation/modding/api/military_campaign_success_range "api:military_campaign_success_range")
    
-   [MILITARY\_MISSION](/foundation/modding/api/military_mission "api:military_mission")
    
-   [MILITARY\_MISSION\_COMPANY\_SLOT](/foundation/modding/api/military_mission_company_slot "api:military_mission_company_slot")
    
-   [MILITARY\_MISSION\_CYCLE](/foundation/modding/api/military_mission_cycle "api:military_mission_cycle")
    
-   [MINERAL\_CATEGORY](/foundation/modding/api/mineral_category "api:mineral_category")
    
-   [MINERAL\_TYPE\_DATA](/foundation/modding/api/mineral_type_data "api:mineral_type_data")
    
-   [MONUMENT\_REQUIRED\_PART\_PAIR](/foundation/modding/api/monument_required_part_pair "api:monument_required_part_pair")
    
-   [NUMBER\_RULE\_MODIFIER\_LIST\_PAIR](/foundation/modding/api/number_rule_modifier_list_pair "api:number_rule_modifier_list_pair")
    
-   [NUMERIC\_RANGE\_GAME\_STEP](/foundation/modding/api/numeric_range_game_step "api:numeric_range_game_step")
    
-   [OUTCOME\_PANEL\_EXTRA\_GUI](/foundation/modding/api/outcome_panel_extra_gui "api:outcome_panel_extra_gui")
    
-   [OUTCOME\_PANEL\_EXTRA\_GUI\_MILITARY](/foundation/modding/api/outcome_panel_extra_gui_military "api:outcome_panel_extra_gui_military")
    
-   [OUTGOING\_RESERVED\_RESOURCE\_LIST](/foundation/modding/api/outgoing_reserved_resource_list "api:outgoing_reserved_resource_list")
    
-   [PARTICLE\_BURST\_DATA](/foundation/modding/api/particle_burst_data "api:particle_burst_data")
    
-   [PARTICLE\_DEFAULT\_VISUAL](/foundation/modding/api/particle_default_visual "api:particle_default_visual")
    
-   [PARTICLE\_EMITER\_ANIMATOR\_TRIGGER](/foundation/modding/api/particle_emiter_animator_trigger "api:particle_emiter_animator_trigger")
    
-   [PARTICLE\_EMITTER\_SHAPE](/foundation/modding/api/particle_emitter_shape "api:particle_emitter_shape")
    
-   [PARTICLE\_EMITTER\_SHAPE\_BOX](/foundation/modding/api/particle_emitter_shape_box "api:particle_emitter_shape_box")
    
-   [PARTICLE\_EMITTER\_SHAPE\_CONE](/foundation/modding/api/particle_emitter_shape_cone "api:particle_emitter_shape_cone")
    
-   [PARTICLE\_EMITTER\_SHAPE\_CYLINDER](/foundation/modding/api/particle_emitter_shape_cylinder "api:particle_emitter_shape_cylinder")
    
-   [PARTICLE\_EMITTER\_SHAPE\_SPHERE](/foundation/modding/api/particle_emitter_shape_sphere "api:particle_emitter_shape_sphere")
    
-   [PARTICLE\_FLOAT3\_VALUE](/foundation/modding/api/particle_float3_value "api:particle_float3_value")
    
-   [PARTICLE\_FLOAT3\_VALUE\_CONSTANT](/foundation/modding/api/particle_float3_value_constant "api:particle_float3_value_constant")
    
-   [PARTICLE\_FLOAT3\_VALUE\_CONSTANT\_RANDOM](/foundation/modding/api/particle_float3_value_constant_random "api:particle_float3_value_constant_random")
    
-   [PARTICLE\_FLOAT3\_VALUE\_CURVE](/foundation/modding/api/particle_float3_value_curve "api:particle_float3_value_curve")
    
-   [PARTICLE\_FLOAT3\_VALUE\_CURVE\_RANDOM](/foundation/modding/api/particle_float3_value_curve_random "api:particle_float3_value_curve_random")
    
-   [PARTICLE\_NO\_VISUAL](/foundation/modding/api/particle_no_visual "api:particle_no_visual")
    
-   [PARTICLE\_OBJECT\_VISUAL](/foundation/modding/api/particle_object_visual "api:particle_object_visual")
    
-   [PARTICLE\_SUB\_EMITTER\_DATA](/foundation/modding/api/particle_sub_emitter_data "api:particle_sub_emitter_data")
    
-   [PARTICLE\_VISUAL](/foundation/modding/api/particle_visual "api:particle_visual")
    
-   [PART\_PROBABILITY](/foundation/modding/api/part_probability "api:part_probability")
    
-   [PROBABILITY\_BONUS](/foundation/modding/api/probability_bonus "api:probability_bonus")
    
-   [PROBABILITY\_BONUS\_ESTATE](/foundation/modding/api/probability_bonus_estate "api:probability_bonus_estate")
    
-   [PROBABILITY\_BONUS\_JOB\_LEVEL](/foundation/modding/api/probability_bonus_job_level "api:probability_bonus_job_level")
    
-   [PROCEDURAL\_COLOR](/foundation/modding/api/procedural_color "api:procedural_color")
    
-   [PROCEDURAL\_FLOAT](/foundation/modding/api/procedural_float "api:procedural_float")
    
-   [PROCEDURAL\_INTEGER](/foundation/modding/api/procedural_integer "api:procedural_integer")
    
-   [PROCEDURAL\_ORIENTATION](/foundation/modding/api/procedural_orientation "api:procedural_orientation")
    
-   [PROCEDURAL\_VECTOR2](/foundation/modding/api/procedural_vector2 "api:procedural_vector2")
    
-   [PROCEDURAL\_VECTOR3](/foundation/modding/api/procedural_vector3 "api:procedural_vector3")
    
-   [PROGRESS\_UNLOCK\_BUILDING\_FUNCTION](/foundation/modding/api/progress_unlock_building_function "api:progress_unlock_building_function")
    
-   [PROGRESS\_UNLOCK\_BUILDING\_PART](/foundation/modding/api/progress_unlock_building_part "api:progress_unlock_building_part")
    
-   [PROGRESS\_UNLOCK\_ESTATE\_DECORATION](/foundation/modding/api/progress_unlock_estate_decoration "api:progress_unlock_estate_decoration")
    
-   [QUEST\_REWARD\_PROBABILITY](/foundation/modding/api/quest_reward_probability "api:quest_reward_probability")
    
-   [QUEST\_REWARD\_QUALITY\_SETUP](/foundation/modding/api/quest_reward_quality_setup "api:quest_reward_quality_setup")
    
-   [RESERVED\_RESOURCE\_ELEMENT](/foundation/modding/api/reserved_resource_element "api:reserved_resource_element")
    
-   [RESOURCE\_COLLECTION\_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")
    
-   [RESOURCE\_FETCHING\_ACTIVITY\_MESSAGE](/foundation/modding/api/resource_fetching_activity_message "api:resource_fetching_activity_message")
    
-   [RESOURCE\_FLOAT\_QUANTITY\_PAIR](/foundation/modding/api/resource_float_quantity_pair "api:resource_float_quantity_pair")
    
-   [RESOURCE\_QUANTITY\_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")
    
-   [RESOURCE\_REMOVAL](/foundation/modding/api/resource_removal "api:resource_removal")
    
-   [RESOURCE\_TYPE\_FLOAT\_PAIR](/foundation/modding/api/resource_type_float_pair "api:resource_type_float_pair")
    
-   [SCORE\_TRACKER](/foundation/modding/api/score_tracker "api:score_tracker")
    
-   [SCORE\_TRACKER\_BEAUTIFICATION](/foundation/modding/api/score_tracker_beautification "api:score_tracker_beautification")
    
-   [SCORE\_TRACKER\_WEALTH](/foundation/modding/api/score_tracker_wealth "api:score_tracker_wealth")
    
-   [SPLENDOR\_RANGE](/foundation/modding/api/splendor_range "api:splendor_range")
    
-   [STRING\_FLOAT\_PAIR](/foundation/modding/api/string_float_pair "api:string_float_pair")
    
-   [STRING\_FLOAT\_PAIR\_LIST](/foundation/modding/api/string_float_pair_list "api:string_float_pair_list")
    
-   [STRING\_PAIR](/foundation/modding/api/string_pair "api:string_pair")
    
-   [STRING\_UINT\_PAIR](/foundation/modding/api/string_uint_pair "api:string_uint_pair")
    
-   [STRING\_UINT\_PAIR\_LIST](/foundation/modding/api/string_uint_pair_list "api:string_uint_pair_list")
    
-   [TAXATION\_BRACKET](/foundation/modding/api/taxation_bracket "api:taxation_bracket")
    
-   [TAXATION\_PER\_HOUSE\_STATUS](/foundation/modding/api/taxation_per_house_status "api:taxation_per_house_status")
    
-   [TAXATION\_PER\_VILLAGER\_STATUS](/foundation/modding/api/taxation_per_villager_status "api:taxation_per_villager_status")
    
-   [TIME\_SYSTEM](/foundation/modding/api/time_system "api:time_system")
    
-   [UNLOCKABLE\_COST](/foundation/modding/api/unlockable_cost "api:unlockable_cost")
    
-   [UNLOCKABLE\_MANDATE](/foundation/modding/api/unlockable_mandate "api:unlockable_mandate")
    
-   [UNLOCK\_FUNCTION\_INSTANCE](/foundation/modding/api/unlock_function_instance "api:unlock_function_instance")
    
-   [VEHICLE\_ANIMATION](/foundation/modding/api/vehicle_animation "api:vehicle_animation")
    
-   [VILLAGER\_ASSIGN\_WORKPLACE\_FUNCTION](/foundation/modding/api/villager_assign_workplace_function "api:villager_assign_workplace_function")
    
-   [VILLAGER\_ASSIGN\_WORKPLACE\_FUNCTION\_AUTO\_ASSIGN\_JOB](/foundation/modding/api/villager_assign_workplace_function_auto_assign_job "api:villager_assign_workplace_function_auto_assign_job")
    
-   [VILLAGER\_ASSIGN\_WORKPLACE\_FUNCTION\_DEFAULT](/foundation/modding/api/villager_assign_workplace_function_default "api:villager_assign_workplace_function_default")
    
-   [VILLAGER\_ASSIGN\_WORKPLACE\_MANUAL\_ASSIGN](/foundation/modding/api/villager_assign_workplace_manual_assign "api:villager_assign_workplace_manual_assign")
    
-   [VILLAGER\_STATUS\_GENDER\_USAGE\_PAIR](/foundation/modding/api/villager_status_gender_usage_pair "api:villager_status_gender_usage_pair")
    
-   [VILLAGER\_STATUS\_QUANTITY\_PAIR](/foundation/modding/api/villager_status_quantity_pair "api:villager_status_quantity_pair")
    
-   [VILLAGER\_STATUS\_RATIO](/foundation/modding/api/villager_status_ratio "api:villager_status_ratio")
    
-   [VILLAGER\_STATUS\_RESOURCE\_LIST\_PAIR](/foundation/modding/api/villager_status_resource_list_pair "api:villager_status_resource_list_pair")
    
-   [VILLAGER\_STATUS\_SCORE\_VALUE](/foundation/modding/api/villager_status_score_value "api:villager_status_score_value")
    
-   [VILLAGER\_STATUS\_WAGE](/foundation/modding/api/villager_status_wage "api:villager_status_wage")
    
-   [VILLAGER\_VALUE\_PAIR](/foundation/modding/api/villager_value_pair "api:villager_value_pair")
    
-   [WAREHOUSE\_SLOT\_SETUP](/foundation/modding/api/warehouse_slot_setup "api:warehouse_slot_setup")
    
-   [WAREHOUSE\_SLOT\_SETUP\_ELEMENT](/foundation/modding/api/warehouse_slot_setup_element "api:warehouse_slot_setup_element")
    
-   [WORK\_AGENT\_ACTIVITY\_MESSAGE](/foundation/modding/api/work_agent_activity_message "api:work_agent_activity_message")
    

## Data Structures

-   [LINE](/foundation/modding/api/line "api:line")
    
-   [PHYSICS\_RAY\_RESULT](/foundation/modding/api/physics_ray_result "api:physics_ray_result")
    
-   [color](/foundation/modding/api/color "api:color")
    
-   [matrix](/foundation/modding/api/matrix "api:matrix")
    
-   [polygon](/foundation/modding/api/polygon "api:polygon")
    
-   [quaternion](/foundation/modding/api/quaternion "api:quaternion")
    
-   [vec2d](/foundation/modding/api/vec2d "api:vec2d")
    
-   [vec2f](/foundation/modding/api/vec2f "api:vec2f")
    
-   [vec2i](/foundation/modding/api/vec2i "api:vec2i")
    
-   [vec3d](/foundation/modding/api/vec3d "api:vec3d")
    
-   [vec3f](/foundation/modding/api/vec3f "api:vec3f")
    
-   [vec3i](/foundation/modding/api/vec3i "api:vec3i")
    

## Enumerations

-   [ACTIVITY\_TYPE](/foundation/modding/api/activity_type "api:activity_type")
    
-   [AGENT\_ANIMATION\_STATE](/foundation/modding/api/agent_animation_state "api:agent_animation_state")
    
-   [AGENT\_ISSUE](/foundation/modding/api/agent_issue "api:agent_issue")
    
-   [AGENT\_WORK\_ACTIVITY\_MESSAGE\_PARAMETERS](/foundation/modding/api/agent_work_activity_message_parameters "api:agent_work_activity_message_parameters")
    
-   [ATTACH\_NODE\_ORIENTATION\_TYPE](/foundation/modding/api/attach_node_orientation_type "api:attach_node_orientation_type")
    
-   [ATTACH\_NODE\_TYPE](/foundation/modding/api/attach_node_type "api:attach_node_type")
    
-   [BEAUTIFICATION\_CATEGORY](/foundation/modding/api/beautification_category "api:beautification_category")
    
-   [BEHAVIOR\_TREE\_NODE\_RESULT](/foundation/modding/api/behavior_tree_node_result "api:behavior_tree_node_result")
    
-   [BUDGET\_CATEGORY](/foundation/modding/api/budget_category "api:budget_category")
    
-   [BUILDING\_PART\_TYPE](/foundation/modding/api/building_part_type "api:building_part_type")
    
-   [BUILDING\_PATH\_RANDOM\_SHAPE](/foundation/modding/api/building_path_random_shape "api:building_path_random_shape")
    
-   [BUILDING\_PATH\_TYPE](/foundation/modding/api/building_path_type "api:building_path_type")
    
-   [BUILDING\_PREVIEW\_TYPE](/foundation/modding/api/building_preview_type "api:building_preview_type")
    
-   [BUILDING\_STATUS](/foundation/modding/api/building_status "api:building_status")
    
-   [BUILDING\_TYPE](/foundation/modding/api/building_type "api:building_type")
    
-   [BUILDING\_ZONE\_TYPE](/foundation/modding/api/building_zone_type "api:building_zone_type")
    
-   [BUTTON\_STATE](/foundation/modding/api/button_state "api:button_state")
    
-   [CHARACTER\_ATTACH\_SLOT](/foundation/modding/api/character_attach_slot "api:character_attach_slot")
    
-   [CHARACTER\_PART](/foundation/modding/api/character_part "api:character_part")
    
-   [CHARACTER\_SETUP\_PRIORITY](/foundation/modding/api/character_setup_priority "api:character_setup_priority")
    
-   [COMPARISON\_OPERATOR](/foundation/modding/api/comparison_operator "api:comparison_operator")
    
-   [CONSTRUCTION\_STEP\_MODE](/foundation/modding/api/construction_step_mode "api:construction_step_mode")
    
-   [DESIRABILITY\_EFFECT\_TYPE](/foundation/modding/api/desirability_effect_type "api:desirability_effect_type")
    
-   [DESIRABILITY\_LEVEL](/foundation/modding/api/desirability_level "api:desirability_level")
    
-   [EASING](/foundation/modding/api/easing "api:easing")
    
-   [ESTATE\_VALUE\_TYPE](/foundation/modding/api/estate_value_type "api:estate_value_type")
    
-   [EXECUTE\_ACTION\_LIST\_MANDATE\_STATE](/foundation/modding/api/execute_action_list_mandate_state "api:execute_action_list_mandate_state")
    
-   [FARM\_STATE](/foundation/modding/api/farm_state "api:farm_state")
    
-   [FORTIFICATION\_TYPE](/foundation/modding/api/fortification_type "api:fortification_type")
    
-   [GAMEPLAY\_SYSTEM\_NAME](/foundation/modding/api/gameplay_system_name "api:gameplay_system_name")
    
-   [GAME\_CONDITION\_ON\_MET\_ACTION](/foundation/modding/api/game_condition_on_met_action "api:game_condition_on_met_action")
    
-   [GAME\_CONDITION\_STATE](/foundation/modding/api/game_condition_state "api:game_condition_state")
    
-   [GAME\_CONDITION\_VILLAGER\_NEED\_FILLED\_VILLAGER\_COUNT\_TYPE](/foundation/modding/api/game_condition_villager_need_filled_villager_count_type "api:game_condition_villager_need_filled_villager_count_type")
    
-   [GAME\_STATE\_FLAG](/foundation/modding/api/game_state_flag "api:game_state_flag")
    
-   [GAME\_STEP](/foundation/modding/api/game_step "api:game_step")
    
-   [GENDER](/foundation/modding/api/gender "api:gender")
    
-   [GENDER\_USAGE](/foundation/modding/api/gender_usage "api:gender_usage")
    
-   [GENDER\_USAGE\_TEXT](/foundation/modding/api/gender_usage_text "api:gender_usage_text")
    
-   [GROUND\_ORIENTATION\_TYPE](/foundation/modding/api/ground_orientation_type "api:ground_orientation_type")
    
-   [HOUSE\_DENSITY](/foundation/modding/api/house_density "api:house_density")
    
-   [HOUSE\_QUALITY](/foundation/modding/api/house_quality "api:house_quality")
    
-   [IMAGE\_ASSET\_TYPE](/foundation/modding/api/image_asset_type "api:image_asset_type")
    
-   [IMMIGRATION\_PROBABILITY](/foundation/modding/api/immigration_probability "api:immigration_probability")
    
-   [INTERACTIVE\_LOCATION\_PRIVACY](/foundation/modding/api/interactive_location_privacy "api:interactive_location_privacy")
    
-   [INTERACTIVE\_LOCATION\_PURPOSE](/foundation/modding/api/interactive_location_purpose "api:interactive_location_purpose")
    
-   [LUA\_INPUT\_OUTPUT\_MODE](/foundation/modding/api/lua_input_output_mode "api:lua_input_output_mode")
    
-   [MANDATE\_SHOW\_NARRATIVE\_PANEL\_CHOICE](/foundation/modding/api/mandate_show_narrative_panel_choice "api:mandate_show_narrative_panel_choice")
    
-   [MANDATE\_STATE](/foundation/modding/api/mandate_state "api:mandate_state")
    
-   [MATERIAL\_RENDER\_MODE](/foundation/modding/api/material_render_mode "api:material_render_mode")
    
-   [MILITARY\_CAMPAIGN\_STATE](/foundation/modding/api/military_campaign_state "api:military_campaign_state")
    
-   [MINERAL\_DEPOSIT\_STATE](/foundation/modding/api/mineral_deposit_state "api:mineral_deposit_state")
    
-   [NAVMESH\_LOCK\_CATEGORY](/foundation/modding/api/navmesh_lock_category "api:navmesh_lock_category")
    
-   [NOTIFICATION\_TYPE](/foundation/modding/api/notification_type "api:notification_type")
    
-   [OBJECT\_FLAG](/foundation/modding/api/object_flag "api:object_flag")
    
-   [OUTCOME\_PANEL\_RESULT](/foundation/modding/api/outcome_panel_result "api:outcome_panel_result")
    
-   [PARTICLE\_BILLBOARD\_BEHAVIOR](/foundation/modding/api/particle_billboard_behavior "api:particle_billboard_behavior")
    
-   [PARTICLE\_QUALITY](/foundation/modding/api/particle_quality "api:particle_quality")
    
-   [PARTICLE\_SPACE](/foundation/modding/api/particle_space "api:particle_space")
    
-   [PARTICLE\_SUB\_SYSTEM\_TYPE](/foundation/modding/api/particle_sub_system_type "api:particle_sub_system_type")
    
-   [PARTICLE\_TIME\_SCALE\_TYPE](/foundation/modding/api/particle_time_scale_type "api:particle_time_scale_type")
    
-   [PATH\_FLAG](/foundation/modding/api/path_flag "api:path_flag")
    
-   [PROCEDURAL\_VALUE\_TYPE](/foundation/modding/api/procedural_value_type "api:procedural_value_type")
    
-   [QUEST\_STATE](/foundation/modding/api/quest_state "api:quest_state")
    
-   [RESOURCE\_COLLECTION\_USAGE](/foundation/modding/api/resource_collection_usage "api:resource_collection_usage")
    
-   [RESOURCE\_FETCHING\_ACTIVITY\_MESSAGE\_PARAMETERS](/foundation/modding/api/resource_fetching_activity_message_parameters "api:resource_fetching_activity_message_parameters")
    
-   [RESOURCE\_LAYOUT\_TYPE](/foundation/modding/api/resource_layout_type "api:resource_layout_type")
    
-   [RESOURCE\_LOCATION\_TYPE](/foundation/modding/api/resource_location_type "api:resource_location_type")
    
-   [RESOURCE\_STOCKPILE\_VISUAL\_MODE](/foundation/modding/api/resource_stockpile_visual_mode "api:resource_stockpile_visual_mode")
    
-   [RESOURCE\_TYPE](/foundation/modding/api/resource_type "api:resource_type")
    
-   [SOLDIER\_TRAINING\_STATE](/foundation/modding/api/soldier_training_state "api:soldier_training_state")
    
-   [TERRAIN\_STATIC\_LAYER\_ZONE\_TYPE](/foundation/modding/api/terrain_static_layer_zone_type "api:terrain_static_layer_zone_type")
    
-   [TEXTURE\_FILTER](/foundation/modding/api/texture_filter "api:texture_filter")
    
-   [TEXTURE\_WRAP](/foundation/modding/api/texture_wrap "api:texture_wrap")
    
-   [TIME\_SYSTEM\_TYPE](/foundation/modding/api/time_system_type "api:time_system_type")
    
-   [TOOL\_HAND](/foundation/modding/api/tool_hand "api:tool_hand")
    
-   [TRADE\_AMOUNT\_TYPE](/foundation/modding/api/trade_amount_type "api:trade_amount_type")
    
-   [TRADE\_BONUS\_TYPE](/foundation/modding/api/trade_bonus_type "api:trade_bonus_type")
    
-   [TRADE\_STATE](/foundation/modding/api/trade_state "api:trade_state")
    
-   [TRADE\_TYPE](/foundation/modding/api/trade_type "api:trade_type")
    
-   [VILLAGER\_BEHAVIOR\_STATE](/foundation/modding/api/villager_behavior_state "api:villager_behavior_state")
    
-   [WALL\_CONTOUR\_TYPE](/foundation/modding/api/wall_contour_type "api:wall_contour_type")
    
-   [WORKPLACE\_STATUS](/foundation/modding/api/workplace_status "api:workplace_status")
    
-   [WORLD\_GUI\_INFO\_TYPE](/foundation/modding/api/world_gui_info_type "api:world_gui_info_type")
    
-   [ZONING\_CATEGORY](/foundation/modding/api/zoning_category "api:zoning_category")
    

api.txt · Last modified: 2026/04/15 10:39 by 127.0.0.1

---

### Page Tools

-   [Show pagesource](/foundation/modding/api?do=edit "Show pagesource [v]")
-   [Old revisions](/foundation/modding/api?do=revisions "Old revisions [o]")
-   [Backlinks](/foundation/modding/api?do=backlink "Backlinks")
-   [Back to top](#dokuwiki__top "Back to top [t]")

[![Donate](/foundation/modding/lib/tpl/dokuwiki/images/button-donate.gif)](https://www.dokuwiki.org/donate "Donate") [![Powered by PHP](/foundation/modding/lib/tpl/dokuwiki/images/button-php.gif)](https://php.net "Powered by PHP") [![Valid HTML5](/foundation/modding/lib/tpl/dokuwiki/images/button-html5.png)](//validator.w3.org/check/referer "Valid HTML5") [![Valid CSS](/foundation/modding/lib/tpl/dokuwiki/images/button-css.png)](//jigsaw.w3.org/css-validator/check/referer?profile=css3 "Valid CSS") [![Driven by DokuWiki](/foundation/modding/lib/tpl/dokuwiki/images/button-dw.png)](https://dokuwiki.org/ "Driven by DokuWiki")

![](/foundation/modding/lib/exe/taskrunner.php?id=api&1782145945)