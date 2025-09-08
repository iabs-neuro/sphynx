function [N_ideal, mask] = convolution_with_holes(N_orig, mask_orig, kernel_size, kernel_sigma)
% Performs 2D Gaussian convolution while handling borders and holes (zero values)
% Redistributes values from holes to valid neighbors using a Gaussian kernel
% 
% Inputs:
%   N_orig: Input matrix
%   mask_orig: Binary mask (1 = valid, 0 = hole) OR 0 (if no mask provided)
%   kernel_size: Size of Gaussian kernel (must be odd)
%   kernel_sigma: Sigma for Gaussian kernel
%
% Outputs:
%   N_ideal: Smoothed matrix with corrected borders
%   mask: Mask of holes in the original data

%%
% N_orig = [
%     1,  2,  3,  4,  5, 6, 7;
%     6,  10,  8,  10, 10, 11 ,12;
%     11, 12, 13, 14, 15, 13, 15;
%     16,  10, 18,  10, 20, 21, 24;
%     21, 22, 23, 24, 25, 26, 27;
%     21, 0, 23, 24, 25, 0, 27;
%     21, 22, 23, 24, 25, 26, 27
%     ];
% mask_orig = 0;
% kernel_size = 5;
% kernel_sigma = 2;

% N_orig = mouse.ocuppancy_map.time_smoothed;
% mask_orig = 0;
% kernel_size = mouse.params_main.kernel_opt.small.size;
% kernel_sigma = mouse.params_main.kernel_opt.small.sigma;

% Validate kernel size (must be odd)
if mod(kernel_size, 2) ~= 1
    kernel_size = kernel_size + 1;
    warning('kernel_size adjusted to %d (must be odd)', kernel_size);
end

% Pad the input matrix to handle borders
pad_size = floor(kernel_size / 2);
N_padded = padarray(N_orig, [pad_size pad_size], 0, 'both');

% Initialize masks
if isscalar(mask_orig)
    % If mask_orig = 0, treat all zeros in N_orig as holes
    mask_holes = (N_padded == 0);
else
    % If mask_orig is a matrix, use it directly (with padding)
    mask_holes = padarray(mask_orig, [pad_size pad_size], 0, 'both');
end

% Detect border pixels (non-zero pixels adjacent to holes)
mask_border = false(size(N_padded));
[rows, cols] = size(N_padded);

for ii = 1 : rows
    for jj = 1 : cols
        if N_padded(ii, jj) ~= 0
            
            % Check all 8 neighbors for holes
            neighborhood = N_padded(max(1,ii-pad_size):min(rows,ii+pad_size), max(1,jj-pad_size):min(cols,jj+pad_size));
            if any(neighborhood(:) == 0)
                mask_border(ii, jj) = true;
            end
        end
    end
end

% Gaussian smoothing
gauss_kernel = fspecial('gaussian', kernel_size, kernel_sigma);
N_smoothed = conv2(N_padded, single(gauss_kernel), 'same');

% Redistribute values from holes to borders
holes_values = mask_holes .* N_smoothed;
N_corrected = N_smoothed - holes_values;

for ii = 1 : rows
    for jj = 1 : cols
        if holes_values(ii, jj) > 0            
            
            gauss_kernel_restricted = gauss_kernel(max(1,pad_size+2-ii):min(kernel_size,rows+pad_size+1-ii), ...
                max(1,pad_size+2-jj):min(kernel_size,cols+pad_size+1-jj));
            
            % Extract the neighborhood kernel weights
            kernel_weights = gauss_kernel_restricted .* mask_border(max(1,ii-pad_size):min(rows,ii+pad_size), max(1,jj-pad_size):min(cols,jj+pad_size));
            sum_weights = sum(kernel_weights(:));
            
            if sum_weights > 0  % Avoid division by zero
                redistribution = kernel_weights / sum_weights * holes_values(ii, jj);
                N_corrected(max(1,ii-pad_size):min(rows,ii+pad_size), max(1,jj-pad_size):min(cols,jj+pad_size)) = ...
                    N_corrected(max(1,ii-pad_size):min(rows,ii+pad_size), max(1,jj-pad_size):min(cols,jj+pad_size)) + redistribution;
            end
        end
    end
end

% Remove padding and return results
N_ideal = N_corrected(pad_size+1:end-pad_size, pad_size+1:end-pad_size);
mask = mask_holes(pad_size+1:end-pad_size, pad_size+1:end-pad_size);

% sum(N_orig(:))
% sum(N_smoothed(:))
% sum(N_corrected(:))
end