%% paths

Exp = '3DM';
folder_path = 'c:\Users\User\YandexDisk\_Projects\3DM\CalciumData\MatchData\';
OutPath = 'c:\Users\User\YandexDisk\_Projects\3DM\CalciumData\MatchTables\';

if ~exist(OutPath, 'dir')
    mkdir(OutPath);
end

% get list of subfolders
D = dir(folder_path);
D = D([D.isdir]);                       % only folders
D = D(~ismember({D.name},{'.','..'}));  % remove . and ..

% storage for global statistics
All_match_global = [];

%% main loop over folders
for f = 9:length(D)
    
    folder_name = D(f).name;
    current_path = fullfile(folder_path, folder_name);
    
    % find cellRegistered*.mat
    mat_files = dir(fullfile(current_path, 'cellRegistered*.mat'));
    
    if isempty(mat_files)
        warning('Folder %s: no cellRegistered*.mat found', folder_name);
        continue
    elseif length(mat_files) > 1
        warning('Folder %s: more than one cellRegistered*.mat found', folder_name);
        continue
    end
    
    % load file
    load(fullfile(current_path, mat_files(1).name));
    
    %% ===== main part (unchanged logic) =====
    Cell_table = cell_registered_struct.cell_to_index_map ./ ...
        cell_registered_struct.cell_to_index_map;
    Cell_table(isnan(Cell_table)) = 0;
    Cell_info = sum(Cell_table, 2);
    
    %% ===== automatic statistics =====
    max_sessions = size(Cell_table, 2);
    
    All_match = zeros(1, max_sessions + 1);
    All_match(1) = length(Cell_info);   % total cells
    
    for k = 1:max_sessions
        All_match(k+1) = sum(Cell_info == k);
    end
    
    disp([folder_name ' : ' num2str(All_match)])
    
    %% save cell_to_index_map
    csvwrite(fullfile(OutPath, [folder_name '.csv']), ...
        cell_registered_struct.cell_to_index_map);
    
    %% store global statistics
    % === pad with zeros if needed ===
    n_cols_global = size(All_match_global, 2);
    n_cols_current = length(All_match);
    
    if isempty(All_match_global)
        All_match_global = All_match;
    else
        if n_cols_current > n_cols_global
            All_match_global(:, end+1:n_cols_current) = 0;
        elseif n_cols_current < n_cols_global
            All_match(end+1:n_cols_global) = 0;
        end
        
        All_match_global = [All_match_global; All_match];
    end
    
end

% ===== save global statistics table =====
writematrix(All_match_global, fullfile(OutPath, sprintf('%s_match_statistics.csv',Exp)));

