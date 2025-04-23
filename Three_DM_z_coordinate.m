
% load workspace
load('w:\Projects\3DM\BehaviorData\5_Behavior\3DM_D14_1D_1T\01-Apr-2025_1\3DM_D14_1D_1T_WorkSpace.mat', 'Options','Point','BodyPartsTracesMainX','BodyPartsTracesMainY', 'Acts');

% load corner table
corners_3D = [
    0 0 570; 700 0 570; 700 700 570; 25 680 470; 25 45 370; 663 40 470; 663 642 570; 65 642 570; ...
    65 80 570; 624 83 470; 623 603 370; 103 604 370; 103 123 290; 589 127 230; 583 567 170; ...
    142 558 270; 142 158 370; 550 158 370; 550 527 270; 179 527 170; 179 196 170; 510 196 130; 510 495 100; ...
    217 495 70; 217 232 120; 472 234 170; 472 452 170; 253 452 110; 253 273 70; 435 273 30; 435 412 0];

tunnels.corner = zeros(size(corners_3D,1),2);
tunnels.border = cell(size(corners_3D,1)-1,1);
tunnels.mask = cell(size(corners_3D,1)-1,1);
tunnels.binarized = [0,0,1,1,1,1,0,0,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0];
tunnels.discreted = [0,0,-1,-1,1,1,0,0,-1,-1,0,-1,-1,-1,1,1,0,-1,-1,0,-1,-1,-1,-1,1,0,-1,-1,-1,-1,0];
tunnels.zscored = [1,1,2,3,3,2,1,1,2,3,4,5,6,7,7,5,4,5,7,8,9,10,11,11,9,8,9,11,12,13,13];

offset = 20;

%% main part

for corner = 1:size(corners_3D,1)
    
    prmt = 0;
    while prmt==0
        h=figure;
        imshow(Options.GoodVideoFrame);hold on;
        plot(BodyPartsTracesMainX(Point.Center,logical(Acts(3).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(3).ActArrayRefine)), 'b.');
        plot(BodyPartsTracesMainX(Point.Center,logical(Acts(2).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(2).ActArrayRefine)), 'b.');
        plot(BodyPartsTracesMainX(Point.Center,logical(Acts(1).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(1).ActArrayRefine)), 'b.');
        plot(tunnels.corner(:,1),tunnels.corner(:,2), 'r.', 'MarkerSize', 30);
        for rect = 1:corner-2
            plot(tunnels.border{rect}(:,1),tunnels.border{rect}(:,2), 'g-', 'LineWidth', 2);
        end
        
        [x_ar, y_ar] = ginput(1);
        plot(x_ar,y_ar, 'r.', 'MarkerSize', 30);hold on;
        
        if corner ~= 1
            
            % Создаем прямоугольник
            [rect_x, rect_y] = create_rectangle_around_line(tunnels.corner(corner-1,1), tunnels.corner(corner-1,2), x_ar, y_ar, offset);
            
            % Визуализизация
            plot([tunnels.corner(corner,1), tunnels.corner(corner,2)], [x_ar, y_ar], 'b-', 'LineWidth', 2);hold on;
            plot(rect_x, rect_y, 'g-', 'LineWidth', 2);
            
        end
        
        answer = questdlg('Is it correct?', 'Arena with borders', 'Yes','No','Yes');        
        switch answer
            case 'Yes'
                prmt = 1;
                tunnels.corner(corner,1) = x_ar;
                tunnels.corner(corner,2) = y_ar;
                if corner ~= 1
                    tunnels.border{corner-1} = [rect_x rect_y];
                    tunnels.mask{corner-1} = imfill(MaskCreator(zeros(Options.Height,Options.Width), rect_x/Options.x_kcorr, rect_y));
                end
            case 'No'
                prmt = 0;
        end
        delete(h);        
    end
end

%%
for corner = 1:size(corners_3D,1)
    
%     prmt = 0;
%     while prmt==0
%         h=figure;
%         imshow(Options.GoodVideoFrame);hold on;
%         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(3).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(3).ActArrayRefine)), 'b.');
%         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(2).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(2).ActArrayRefine)), 'b.');
%         plot(BodyPartsTracesMainX(Point.Center,logical(Acts(1).ActArrayRefine))/Options.x_kcorr,BodyPartsTracesMainY(Point.Center,logical(Acts(1).ActArrayRefine)), 'b.');
%         plot(tunnels.corner(:,1),tunnels.corner(:,2), 'r.', 'MarkerSize', 30);
%         for rect = 1:corner-2
%             plot(tunnels.border{rect}(:,1),tunnels.border{rect}(:,2), 'g-', 'LineWidth', 2);
%         end
% %         
%         [x_ar, y_ar] = ginput(1);
%         plot(x_ar,y_ar, 'r.', 'MarkerSize', 30);hold on;
        
        if corner ~= 1
            
            % Создаем прямоугольник
            [rect_x, rect_y] = create_rectangle_around_line(tunnels.corner(corner-1,1), tunnels.corner(corner-1,2), tunnels.corner(corner,1), tunnels.corner(corner,2), offset);
            
            % Визуализизация
%             plot([tunnels.corner(corner,1), tunnels.corner(corner,2)], [tunnels.corner(corner,1), tunnels.corner(corner,2)], 'b-', 'LineWidth', 2);hold on;
%             plot(rect_x, rect_y, 'g-', 'LineWidth', 2);
            
        end
        
%         answer = questdlg('Is it correct?', 'Arena with borders', 'Yes','No','Yes');        
%         switch answer
%             case 'Yes'
%                 prmt = 1;
%                 tunnels.corner(corner,1) = x_ar;
%                 tunnels.corner(corner,2) = y_ar;
                if corner ~= 1
                    rect_x(rect_x<1) = 1;
                    rect_y(rect_y<1) = 1;
                    rect_x(rect_x>Options.Width) = Options.Width;
                    rect_y(rect_y>Options.Height) = Options.Height;
                    tunnels.border{corner-1} = [rect_x rect_y];
                    tunnels.mask{corner-1} = imfill(MaskCreator(zeros(Options.Height,Options.Width), rect_x/Options.x_kcorr, rect_y));
                end
%             case 'No'
%                 prmt = 0;
%         end
%         delete(h);        
%     end
end

tunnels.corner3D = corners_3D;

