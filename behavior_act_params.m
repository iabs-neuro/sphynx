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
... % 'centertrue',                   ["ActNumber" "ActPercent" "Distance"], ...      % центральная зона:         [кол-во, процент, дистанция]
'center',                       ["ActNumber" "ActPercent" "Distance"], ...      % пристеночная зона:        [кол-во, процент, дистанция]
'corners',                      ["ActPercent" "Distance"], ...                  % зона углов:               [процент, дистанция]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% UNSPECIFIC ACTS %%%%%%%%%%%%%%%%%%%%
'freezing',                     "ActPercent", ...                               % замирания:                [процент]
'rear',                         "ActNumber", ...                                % стойки:                   [кол-во]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:BOF %%%%%%%%%%%%% 
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
...
'objectinside',              	["ActDuration" "ActPercent"], ...              	% мышь в объекте:                                       [длительность, процент]
'objectinteraction',         	["ActDuration" "ActPercent"], ...              	% любое взаимодействие с объектом:                      [длительность, процент]
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
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:2DM %%%%%%%%%%%%%
'rest_in_walls',             	"ActNumber", ...                                % остановка в пристеночной зоне:                        [кол-во]
'loc_in_walls',                 "ActNumber", ...                                % быстрая побежка в пристеночной зоне:                 	[кол-во]
'rest_in_middle_zone',          "ActNumber", ...                                % остановка в промежуточной зоне:                       [кол-во]
'loc_in_middle_zone',           "ActNumber", ...                                % быстрая побежка в промежуточной зоне:                 [кол-во]
'rest_in_center',               "ActNumber", ...                                % остановка в центральной зоне:                         [кол-во]
'loc_in_center',                "ActNumber" ...                                 % быстрая побежка в центральной зоне:                   [кол-во]
    );


end