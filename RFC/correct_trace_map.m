function corrected_matrix = correct_trace_map(original_matrix, method, noise_level, kernel_size, sigma, visual)
    % CORRECT_ACTIVITY_MATRIX Corrects neural activity matrix by handling zero values
    %
    % Inputs:
    %   original_matrix - NxM matrix of neural activity with zeros for unexplored areas
    %   method - string specifying correction method:
    %       'median_noise' - replace zeros with median + noise (default)
    %       'interp' - use bilinear interpolation
    %       'gaussian' - Gaussian blurring of existing data
    %   noise_level - standard deviation of noise to add (for 'median_noise' method)
    %
    % Output:
    %   corrected_matrix - matrix with corrected zero values
    
    % debugging
%     original_matrix = data{i}.cellmaps(ind).trace_refined;
    
    if nargin < 2
        method = 'median_noise';
    end
    
    if nargin < 3
        noise_level = 0.1; % default noise level
    end
    
    % Create mask of explored areas (non-zero values)
    explored_mask = original_matrix ~= 0;
    
    switch method
        case 'median_noise'
            % Calculate median of non-zero values
            median_val = median(original_matrix(explored_mask));
            
            % Create noise matrix
            noise_matrix = noise_level * median_val * randn(size(original_matrix));
            
            % Replace zeros with median + noise
            corrected_matrix = original_matrix;
            corrected_matrix(~explored_mask) = median_val + noise_matrix(~explored_mask);
            
            % Ensure no negative values (activity can't be negative)
            corrected_matrix = max(corrected_matrix, 0);
            
        case 'interp'
            % Create grid for interpolation
            [X, Y] = meshgrid(1:size(original_matrix, 2), 1:size(original_matrix, 1));
            
            % Get coordinates of known points
            known_x = X(explored_mask);
            known_y = Y(explored_mask);
            known_values = original_matrix(explored_mask);
            
            % Interpolate unknown points
            corrected_matrix = griddata(known_x, known_y, known_values, X, Y, 'linear');
            
            % For points outside convex hull (if any), use nearest neighbor
            if any(isnan(corrected_matrix(:)))
                corrected_matrix = griddata(known_x, known_y, known_values, X, Y, 'nearest');
            end
            
        case 'gaussian'
            % First, create matrix with NaN for unexplored areas
            temp_matrix = original_matrix;
%             temp_matrix(~explored_mask) = NaN;
            
            % Default parameters for 15x15 matrix with ~3x3 signal size
            if ~exist('kernel_size', 'var') || isempty(kernel_size)
                kernel_size = 3; % default kernel size (should be odd)
            end
            if ~exist('sigma', 'var') || isempty(sigma)
                sigma = 0.5; % default sigma for Gaussian kernel
            end
            
            % Create Gaussian kernel
            gauss_kernel = fspecial('gaussian', kernel_size, sigma);
            
            % 1) First fill NaNs with nearest neighbor to avoid edge artifacts
%             filled_matrix = fillmissing(temp_matrix, 'nearest');
            
            % 2) Apply Gaussian smoothing
            smoothed_matrix = imfilter(temp_matrix, gauss_kernel, 'replicate', 'same');
            
%             % 3) Restore original known values to preserve data fidelity
            corrected_matrix = smoothed_matrix;
%             corrected_matrix(explored_mask) = original_matrix(explored_mask);
%             
%             % 4) Optional: Light smoothing of the whole matrix to blend edges
%             light_kernel = fspecial('gaussian', 3, 0.3);
%             corrected_matrix = imfilter(corrected_matrix, light_kernel, 'replicate', 'same');
            
        otherwise
            error('Unknown correction method');
    end
    
    % For visualization
    if visual
        figure;
        subplot(1,2,1);
        imagesc(original_matrix);
        title('Original Matrix');
        colorbar;
        axis image;
        
        subplot(1,2,2);
        imagesc(corrected_matrix);
        title('Corrected Matrix');
        colorbar;
        axis image;
    end
end