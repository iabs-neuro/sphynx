%% paths and names

pathMatched = 'w:\Projects\RFC\CalciumData\7_Matched\';
pathMat = 'w:\Projects\RFC\ActivityData\PC_mat\';
pathout = 'w:\Projects\RFC\ActivityData\CogMap\';

Filenames = {
    'F28', 'F30', 'F40', 'F32', 'F37', 'F35', ...         % BL_SL
    'F26', 'F34', 'F38', 'F31', 'F41', 'F53', 'F54',...   % BL_MK
    'F20', 'F07', 'F14', 'F09',...                        % FAD-SL
    'F01', 'F12', 'F19', 'F11'                            % FAD-MK
    };

% local parameters
cage_size = [29 24];

% variables

matched_percent_g_cell_1   = zeros(1,length(Filenames));            % процент нейронов сохранивших активность в день теста
unmatched_percent_g_cell_2 = zeros(1,length(Filenames));            % процент нейронов включившихся в день теста
matched_percent_g_cell     = zeros(1,length(Filenames));            % процент нейронов активных в обе сессии

matched_percent_i_cell_1   = zeros(1,length(Filenames));            % процент информативных нейронов сохранивших информативность в день теста
unmatched_percent_i_cell_2 = zeros(1,length(Filenames));            % процент информативных нейронов включившихся в день теста
matched_percent_i_cell     = zeros(1,length(Filenames));            % процент информативных нейронов в обе сессии

inform_percent_m_cell_1 = zeros(1,length(Filenames));               % процент информативных нейронов 1D от сметченных
inform_percent_m_cell_2 = zeros(1,length(Filenames));               % процент информативных нейронов 3D от сметченных
inform_percent_m_cell   = zeros(1,length(Filenames));               % процент информативных нейронов в обеих сессиях от сметченных

chance_level_abs     = zeros(1,length(Filenames));                  % уровень случайной коллокилазиции информативных нейронов (абсолютный)
chance_level_percent = zeros(1,length(Filenames));                  % уровень случайной коллокилазиции информативных нейронов (процент)
inform_percent_m_cell_norm_chance = zeros(1,length(Filenames));     % процент информативных нейронов в обеих сессиях от сметченных нормированный на случайный уровень
inform_percent_m_cell_norm2_chance = zeros(1,length(Filenames));    % процент информативных нейронов в обеих сессиях от сметченных нормированный на случайный уровень (z-scored)
inform_percent_m_cell_norm3_chance = zeros(1,length(Filenames));    % процент информативных нейронов в обеих сессиях от сметченных нормированный на случайный уровень (абсолютный)

matched_informed_stable_cell_abs     = zeros(1,length(Filenames));  % сметченные информативные нейроны со стабильной картой (абсолютное)
matched_informed_stable_cell_percent = zeros(1,length(Filenames));  % сметченные информативные нейроны со стабильной картой (процент)

r_cells = zeros(1,length(Filenames));                               % средняя корреляция Пирсона сметченных информативных карт

I_Matched_cells_number = zeros(1,length(Filenames));                % количество информативных клеток среди сметченных

%% main part

for file = 1:length(Filenames)
    
    % downloading data
    disp(Filenames{file});
    %     mkdir(pathout, Filenames{file});
    
    pathin_1D = sprintf('%s\\WorkSpace_RFC_%s_1D.mat',pathMat,Filenames{file});
    [data1D] = load(pathin_1D,'file_TR_bad','x_int_sm','y_int_sm','bin_size','N_time_sm','n_cells','g_cell', 'Cell_IC');
    
    pathin_3D = sprintf('%s\\WorkSpace_RFC_%s_3D.mat',pathMat,Filenames{file});
    [data3D] = load(pathin_3D,'file_TR_bad','x_int_sm','y_int_sm','bin_size','N_time_sm','n_cells','g_cell', 'Cell_IC');
    
    MatchedTable = table2array(readtable(sprintf('%s\\RFC_%s.csv', pathMatched, Filenames{file})));
    non_zero_rows = all(MatchedTable ~= 0, 2);
    indices = find(non_zero_rows);
    
    data1D.i_cell = data1D.Cell_IC(1,data1D.Cell_IC(2,:)>0);
    data3D.i_cell = data3D.Cell_IC(1,data3D.Cell_IC(2,:)>0);
    
    matched_percent_g_cell_1(file) = round(length(indices)/data1D.n_cells*100,1);
    unmatched_percent_g_cell_2(file) = round((data3D.n_cells - length(indices))/data3D.n_cells*100,1);
    matched_percent_g_cell(file) = round(length(indices)/(data1D.n_cells + data3D.n_cells - length(indices))*100,1);
    
    I_Matched_cells = [];
    data1D.i_matched_cell = [];
    data3D.i_matched_cell = [];
    for cell = 1:length(indices)
        if ismember(MatchedTable(indices(cell),1), data1D.i_cell) && ismember(MatchedTable(indices(cell),2), data3D.i_cell)
            I_Matched_cells = [I_Matched_cells indices(cell)];
            data1D.i_matched_cell = [data1D.i_matched_cell MatchedTable(indices(cell),1)];
            data3D.i_matched_cell = [data3D.i_matched_cell MatchedTable(indices(cell),2)];
        end
    end
    
    I_Matched_cells_number(file) = length(I_Matched_cells);
    matched_percent_i_cell_1(file) = round(length(I_Matched_cells)/length(data1D.i_cell)*100,1);
    unmatched_percent_i_cell_2(file) = round((length(data3D.i_cell) - length(I_Matched_cells))/length(data3D.i_cell)*100,1);
    matched_percent_i_cell(file) = round(length(I_Matched_cells)/(length(data1D.i_cell) + length(data3D.i_cell) - length(I_Matched_cells))*100,1);
    
    [~, i_cell_1, ~] = intersect(data1D.i_cell, MatchedTable(indices,1));
    [~, i_cell_2, ~] = intersect(data3D.i_cell, MatchedTable(indices,2));
    
    inform_percent_m_cell_1(file) =  round(length(i_cell_1)/length(indices)*100,1);
    inform_percent_m_cell_2(file) =  round(length(i_cell_2)/length(indices)*100,1);
    inform_percent_m_cell(file)   =  length(I_Matched_cells)/length(indices)*100;
    
    chance_level_abs(file) = (length(i_cell_1)/length(indices))*(length(i_cell_2)/length(indices))*length(indices);
    chance_level_percent(file) = (length(i_cell_1)/length(indices))*(length(i_cell_2)/length(indices))*100;
    inform_percent_m_cell_norm_chance(file) = inform_percent_m_cell(file)/chance_level_percent(file);
    inform_percent_m_cell_norm2_chance(file) = (inform_percent_m_cell(file)-chance_level_percent(file))/chance_level_percent(file)*100;
    inform_percent_m_cell_norm3_chance(file) = (I_Matched_cells_number(file)-chance_level_abs(file));
    
    % making trace matrix and plot for all matched cells
    r = zeros(1,length(indices));
    p = zeros(1,length(indices));
    for cell = 1:length(indices)
        % %     for cell = 1:10
        [N_trace_1D] = computeMatrices(data1D.x_int_sm, data1D.y_int_sm, data1D.file_TR_bad(:,MatchedTable(indices(cell),1)), cage_size, data1D.bin_size);
        [N_trace_3D] = computeMatrices(data3D.x_int_sm, data3D.y_int_sm, data3D.file_TR_bad(:,MatchedTable(indices(cell),2)), cage_size, data3D.bin_size);
        
        [r(cell), p(cell)] = computePearsonCorrelation(N_trace_1D, N_trace_3D);
        
        %         if p(cell) < 0.05 && r(cell) > 0
        %             plotMatrices(N_trace_1D, N_trace_3D, cell, r(cell), p(cell), sprintf('%s\\%s\\%s_ActivityMap_Cell_%d.png',pathout,Filenames{file},Filenames{file},cell));
        %         end
        
    end
    
    StabilityMap_cell = indices(p<0.05 & r>0);
    
    data1D.StabilityMap_cell = MatchedTable(StabilityMap_cell,1);
    data3D.StabilityMap_cell = MatchedTable(StabilityMap_cell,2);
    
    [~, stable_cell, ~] = intersect(I_Matched_cells, StabilityMap_cell);
    
    matched_informed_stable_cell_abs(file) = length(stable_cell);
    matched_informed_stable_cell_percent(file) = length(stable_cell)/length(I_Matched_cells)*100;
    
    %     h = histogram(r(p<0.05),50);
    %     title(sprintf('Гистограмма корреляции Пирсона. %d нейронов', sum(p<0.05)));
    %     xlabel('Корреляция Пирсона');
    %     ylabel('Частота');
    %     saveas(h, sprintf('%s\\%s\\%s_PearsonHist.png',pathout,Filenames{file},Filenames{file}));
    %     delete(h);
    
    % analysis of Pearson's correlations
    r_cells(file) = mean(r(p<0.05 & r>0));
    
end

