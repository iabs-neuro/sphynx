function behavior_act_params = behavior_act_params()

% behavior_act_params_name = {
%     "ActNumber"     "ActPercent"          "ActMeanTime" ...    
%     "Distance"      "ActMeanDistance"     "ActVelocity" ...  
% };

behavior_act_params = struct(...
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% VELOCITY ACTS %%%%%%%%%%%%%%%%%%%%%%%   
'rest',                         ["ActNumber" "ActPercent"], ...                 % остановки:                [кол-во, процент]
'walk',                         ["ActNumber" "ActPercent"], ...                 % медленные побежки:        [кол-во, процент]
'locomotion',                   ["ActNumber" "ActPercent"], ...                 % быстрые побежки:          [кол-во, процент]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SPACE ACTS %%%%%%%%%%%%%%%%%%%%%%%%%%
'walls',                        ["ActPercent" "Distance"], ...                  % пристеночная зона:        [процент, дистанция]
'middle_zone',                  ["ActPercent" "Distance"], ...                  % промежуточная зона:       [процент, дистанция]
'center',                       ["ActNumber" "ActPercent" "Distance"], ...      % пристеночная зона:        [кол-во, процент, дистанция]
'corners',                      "ActPercent", ...                               % зона углов:               [процент, дистанция]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% UNSPECIFIC ACTS %%%%%%%%%%%%%%%%%%%%
'freezing',                     "ActPercent", ...                               % замирания:                [процент]
'rear',                         "ActNumber", ...                                % стойки:                   [кол-во]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:BOF - bowl acts (old names) %%%%%%%%%%%%% 
'bowlinside',                   ["ActDuration" "ActPercent"], ...               % мышь в миске:                                         [длительность, процент]
'bowlinteraction',              ["ActDuration" "ActPercent"], ...               % любое взаимодействие с миской:                        [длительность, процент]
'bowlinteractreal',             ["ActDuration" "ActPercent"], ...               % контакт с миской:                                     [длительность, процент]
'entryInBowlInside',        	"ActNumber", ...                                % целенаправленный подход к миске на посидеть:          [кол-во]
'entryInBowlInteract',          "ActNumber", ...                                % целенаправленный подход к миске на контакт:           [кол-во]
'entryInBowlInsideAll',         "ActNumber", ...                                % любой подход к миске на посидеть:                     [кол-во]
'entryInBowlInteractAll',   	"ActNumber", ...                                % любой подход к миске на контакт:                      [кол-во]
'entryOutBowlInside',           "ActNumber", ...                                % целенаправленный выход из миски после сидения:        [кол-во]
'entryOutBowlInteract',         "ActNumber", ...                                % целенаправленный выход из миски после контакта:       [кол-во]
'entryOutBowlInsideAll',        "ActNumber", ...                                % любой выход из миски после сидения:                   [кол-во]
'entryOutBowlInteractAll',      "ActNumber", ...                                % любой выход из миски после контакта:                  [кол-во]
'bowlInView',                   "ActPercent", ...                               % миска в области зрения:                               [процент]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:BOF - object acts (old names) %%%%%%%%%%%%% 
'objectinside',              	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"], ...              	% мышь в объекте:                                       [длительность, процент]
'objectinteraction',         	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"], ...              	% любое взаимодействие с объектом:                      [длительность, процент]
'objectinteractreal',        	["ActDuration" "ActPercent"], ...              	% контакт с объектом:                                   [длительность, процент]
'entryInObjectInside',       	"ActNumber", ...                                % целенаправленный подход к объекту на посидеть:        [кол-во]
'entryInObjectInteract',     	"ActNumber", ...                                % целенаправленный подход к объекту на контакт:         [кол-во]
'entryInObjectInsideAll',    	"ActNumber", ...                                % любой подход к объекту на посидеть:                   [кол-во]
'entryInObjectInteractAll',  	"ActNumber", ...                                % любой подход к объекту на контакт:                    [кол-во]
'entryOutObjectInside',      	"ActNumber", ...                                % целенаправленный выход из объекта после сидения:      [кол-во]
'entryOutObjectInteract',    	"ActNumber", ...                                % целенаправленный выход из объекта после контакта:     [кол-во]
'entryOutObjectInsideAll',  	"ActNumber", ...                                % любой выход из объекта после сидения:                 [кол-во]
'entryOutObjectnteractAll',     "ActNumber", ...                                % любой выход из объекта после контакта:                [кол-во]
'objectInView',              	"ActPercent", ...                               % объект в области зрения:                              [процент]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:BOWL (new names) %%%%%%%%%%%%% 
'bowl_interaction',           	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"], ...  	% любое взаимодействие с миской:       	[кол-во, длительность, процент, среднее время на акт]               
'object1_interaction',         	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"], ...  	% любое взаимодействие с объектом №1:   [кол-во, длительность, процент, среднее время на акт]
'object2_interaction',         	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"], ...  	% любое взаимодействие с объектом №2:   [кол-во, длительность, процент, среднее время на акт]
... 
'entry_in_bowl',                "ActNumber", ...                                % целенаправленный подход к миске:                    	[кол-во]
'entry_in_object1',             "ActNumber", ...                                % целенаправленный подход к объекту №1:             	[кол-во]
'entry_in_object2',             "ActNumber", ...                                % целенаправленный подход к объекту №2:                 [кол-во]
... 
'bowl_in_view',              	"ActPercent", ...                               % миска в области зрения:                             	[процент]
'object1_in_view',             	"ActPercent", ...                               % объект 1 в области зрения:                           	[процент]
'object2_in_view',             	"ActPercent", ...                               % объект 2 в области зрения:                          	[процент]
... 
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:2DM %%%%%%%%%%%%%
'rest_in_walls',             	"ActNumber", ...                                % остановка в пристеночной зоне:                        [кол-во]
'loc_in_walls',                 "ActNumber", ...                                % быстрая побежка в пристеночной зоне:                 	[кол-во]
'rest_in_middle_zone',          "ActNumber", ...                                % остановка в промежуточной зоне:                       [кол-во]
'loc_in_middle_zone',           "ActNumber", ...                                % быстрая побежка в промежуточной зоне:                 [кол-во]
'rest_in_center',               "ActNumber", ...                                % остановка в центральной зоне:                         [кол-во]
'loc_in_center',                "ActNumber", ...                                % быстрая побежка в центральной зоне:                   [кол-во]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:3DM %%%%%%%%%%%%%
'start_box',                  	["ActNumber" "ActPercent"], ...                 % стартовая зона:                                       [кол-во, процент]
'arms',                       	["ActNumber" "ActPercent" "Distance"], ...     	% все рукава:                                          	[кол-во, процент, дистанция]
'straight_arms',               	["ActNumber" "ActPercent" "Distance"], ...     	% прямые рукава:                                       	[процент, дистанция]
'sloping_arms',                	["ActNumber" "ActPercent" "Distance"], ...     	% наклонные рукава:                                   	[процент, дистанция]
'slope_down_arms',             	["ActNumber" "ActPercent" "Distance"], ...     	% наклонные вниз рукава:                               	[процент, дистанция]
'slope_up_arms',              	["ActNumber" "ActPercent" "Distance"], ...     	% наклонные вверх рукава:                              	[процент, дистанция]
... 
'rest_in_straight_arms',       	"ActNumber", ...                                % остановка в прямых рукавах:                           [кол-во]
'loc_in_straight_arms',       	"ActNumber", ...                                % быстрая побежка в прямых рукавах:                    	[кол-во]
'walk_in_straight_arms',       	"ActNumber", ...                                % медленная побежка в прямых рукавах:                  	[кол-во]
'freez_in_straight_arms',      	"ActNumber", ...                                % замирания в прямых рукавах:                           [кол-во]
... 
'rest_in_sloping_arms',       	"ActNumber", ...                                % остановка в наклонных рукавах:                       	[кол-во]
'loc_in_sloping_arms',       	"ActNumber", ...                                % быстрая побежка в наклонных рукавах:                 	[кол-во]
'walk_in_sloping_arms',       	"ActNumber", ...                                % медленная побежка в наклонных рукавах:               	[кол-во]
'freez_in_sloping_arms',      	"ActNumber", ...                                % замирания в наклонных рукавах:                       	[кол-во]
... 
'rest_in_slope_down_arms',     	"ActNumber", ...                                % остановка в наклонных вниз рукавах:                  	[кол-во]
'loc_in_slope_down_arms',      	"ActNumber", ...                                % быстрая побежка в наклонных вниз рукавах:            	[кол-во]
'walk_in_slope_down_arms',     	"ActNumber", ...                                % медленная побежка в наклонных вниз рукавах:          	[кол-во]
'freez_in_slope_down_arms',    	"ActNumber", ...                                % замирания в наклонных вниз рукавах:                  	[кол-во]
...
'rest_in_slope_up_arms',       	"ActNumber", ...                                % остановка в наклонных вверх рукавах:                 	[кол-во]
'loc_in_slope_up_arms',       	"ActNumber", ...                                % быстрая побежка в наклонных вверх рукавах:           	[кол-во]
'walk_in_slope_up_arms',       	"ActNumber", ...                                % медленная побежка в наклонных вверх рукавах:         	[кол-во]
'freez_in_slope_up_arms',      	"ActNumber", ...                                % замирания в наклонных вверх рукавах:                	[кол-во]
... 
'mouse_goes_straight',        	["ActPercent" "Distance"], ...                  % животное перемещается в плоскости (X,Y):             	[процент, дистанция]
'mouse_goes_up',                ["ActPercent" "Distance"], ...                  % животное перемещается с набором высоты:             	[процент, дистанция]
'mouse_goes_down',              ["ActPercent" "Distance"], ...                   % животное перемещается со снижением высоты:          	[процент, дистанция]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:NOL %%%%%%%%%%%%%
'object_control_inside',     	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"], ...              	% мышь в объекте:                                       [длительность, процент]
'object_control_interaction',  	["ActNumber" "ActDuration" "ActPercent" "ActMeanTime"] ...              	% любое взаимодействие с объектом:                      [длительность, процент]
    );


end