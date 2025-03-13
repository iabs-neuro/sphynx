function behavior_act_params = behavior_act_params()

% behavior_act_params_name = {
%     "ActNumber"     "ActPercent"          "ActMeanTime" ...    
%     "Distance"      "ActMeanDistance"     "ActVelocity" ...  
% };

behavior_act_params = struct(...
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% VELOCITY ACTS %%%%%%%%%%%%%%%%%%%%%%%   
'rest',                         ["ActNumber", "ActPercent"], ...                % остановки:                {кол-во, процент]
'walk',                         ["ActNumber", "ActPercent"], ...                % медленные побежки:        {кол-во, процент]
'locomotion',                   ["ActNumber", "ActPercent"], ...                % быстрые побежки:          {кол-во, процент]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SPACE ACTS %%%%%%%%%%%%%%%%%%%%%%%%%%
'walls',                        ["ActNumber" "ActPercent" "Distance"], ...      % пристеночная зона:        [кол-во, процент, дистанция]
'centermiddle',                 ["ActNumber" "ActPercent" "Distance"], ...      % промежуточная зона:       [кол-во, процент, дистанция]
'centertrue',                   ["ActNumber" "ActPercent" "Distance"], ...      % центральная зона:         [кол-во, процент, дистанция]
'center',                       ["ActNumber" "ActPercent" "Distance"], ...      % пристеночная зона:        [кол-во, процент, дистанция]
'corners',                      ["ActNumber" "ActPercent" "Distance"], ...      % зона углов:               [кол-во, процент, дистанция]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% UNSPECIFIC ACTS %%%%%%%%%%%%%%%%%%%%
'freezing',                     ["ActNumber" "ActPercent" 'ActMeanTime'], ...   % замирания:                [кол-во, процент, среднее время]
'rear',                         "ActNumber", ...                                % стойки:                   [кол-во]
... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TASK-SPECIFIC ACTS:BOF %%%%%%%%%%%%% 
'bowlinside',                   ["ActNumber" "ActPercent"], ...                 % мышь в миске:                                         [кол-во, процент]
'bowlinteraction',              ["ActNumber" "ActPercent"], ...                	% любое взаимодействие с миской:                        [кол-во, процент]
'bowlinteractreal',             ["ActNumber" "ActPercent"], ...                 % контакт с миской:                                     [кол-во, процент]
'entryInBowlInside',        	["ActNumber" "ActPercent"], ...                 % целенаправленный подход к миске на посидеть:          [кол-во, процент]
'entryInBowlInteract',          ["ActNumber" "ActPercent"], ...                 % целенаправленный подход к миске на контакт:           [кол-во, процент]
'entryInBowlInsideAll',         ["ActNumber" "ActPercent"], ...                 % любой подход к миске на посидеть:                     [кол-во, процент]
'entryInBowlInteractAll',   	["ActNumber" "ActPercent"], ...                 % любой подход к миске на контакт:                      [кол-во, процент]
'entryOutBowlInside',           ["ActNumber" "ActPercent"], ...                 % целенаправленный выход из миски после сидения:        [кол-во, процент]
'entryOutBowlInteract',         ["ActNumber" "ActPercent"], ...                 % целенаправленный выход из миски после контакта:       [кол-во, процент]
'entryOutBowlInsideAll',        ["ActNumber" "ActPercent"], ...                 % любой выход из миски после сидения:                   [кол-во, процент]
'entryOutBowlInteractAll',      ["ActNumber" "ActPercent"], ...                 % любой выход из миски после контакта:                  [кол-во, процент]
'bowlInView',                   ["ActNumber" "ActPercent"], ...                 % миска в области зрения:                               [кол-во, процент]
...
'objectinside',              	["ActNumber" "ActPercent"], ...                 % мышь в объекте:                                       [кол-во, процент]
'objectinteraction',         	["ActNumber" "ActPercent"], ...                	% любое взаимодействие с объектом:                      [кол-во, процент]
'objectinteractreal',        	["ActNumber" "ActPercent"], ...                 % контакт с объектом:                                   [кол-во, процент]
'entryInObjectInside',       	["ActNumber" "ActPercent"], ...                 % целенаправленный подход к объекту на посидеть:        [кол-во, процент]
'entryInObjectInteract',     	["ActNumber" "ActPercent"], ...                 % целенаправленный подход к объекту на контакт:         [кол-во, процент]
'entryInObjectInsideAll',    	["ActNumber" "ActPercent"], ...                 % любой подход к объекту на посидеть:                   [кол-во, процент]
'entryInObjectInteractAll',  	["ActNumber" "ActPercent"], ...                 % любой подход к объекту на контакт:                    [кол-во, процент]
'entryOutObjectInside',      	["ActNumber" "ActPercent"], ...                 % целенаправленный выход из объекта после сидения:      [кол-во, процент]
'entryOutObjectInteract',    	["ActNumber" "ActPercent"], ...                 % целенаправленный выход из объекта после контакта:     [кол-во, процент]
'entryOutObjectInsideAll',  	["ActNumber" "ActPercent"], ...                 % любой выход из объекта после сидения:                 [кол-во, процент]
'entryOutObjectnteractAll',     ["ActNumber" "ActPercent"], ...                 % любой выход из объекта после контакта:                [кол-во, процент]
'objectInView',              	["ActNumber" "ActPercent"] ...                  % объект в области зрения:                              [кол-во, процент]
    );


end