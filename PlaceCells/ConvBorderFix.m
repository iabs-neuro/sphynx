function [N_ideal, mask] = ConvBorderFix(N_orig, mask_orig, kernel_size, kernel_sigma)
% Two dimensional convolution with Gauss kernel and constant summ of matrix
% 27.04.24 kernel size and sigma added
% TO DO make for different sizes correct, now only for 3x3

% for debugging
% N_orig = N_freq;
% mask_orig = mask_t;
% kernel_size = kernel_opt.big.size;
% kernel_sigma = kernel_opt.big.sigma;

size_add = kernel_size-1;
kernel_size_half = round((kernel_size-1)/2);

% making extended matrix for convolution
N = zeros(size(N_orig,1)+2*size_add,size(N_orig,2)+2*size_add);
N(size_add+1:size_add+size(N_orig,1),size_add+1:size_add+size(N_orig,2)) = N_orig;

% making masks for holes and border
mask_holes = zeros(size(N,1),size(N,2));
if sum(sum(mask_orig))
    mask_holes = ones(size(N,1),size(N,2));
    mask_holes(size_add+1:size_add+size(N_orig,1),size_add+1:size_add+size(N_orig,2)) = mask_orig;
end

mask_border = zeros(size(N,1),size(N,2));
for ii=1:size(N,1)
    for jj=1:size(N,2)
        
        if N(ii,jj) == 0 && sum(sum(mask_orig))==0
            mask_holes(ii,jj) = 1;
        end
        
        % Проверяем всех 8 соседей для границ
        if N(ii,jj) ~= 0
            neighborhood = N(ii-1:ii+1, jj-1:jj+1);
            if any(neighborhood(:) == 0  % Любой сосед == 0
                mask_border(ii,jj) = 1;
            end
        end
    end
end

% main part
ts = fspecial('gaussian', kernel_size, kernel_sigma);
N_sm = conv2(N, single(ts), 'same');
value_holes = mask_holes.*N_sm;
N_sm2 = N_sm-value_holes;

for ii=1:size(N,1)
    for jj=1:size(N,2)
        if value_holes(ii,jj)>0
            ts2 = ts.*mask_border(ii-kernel_size_half:ii+kernel_size_half,jj-kernel_size_half:jj+kernel_size_half);
            ts3 = ts2./sum(sum(ts2))*value_holes(ii,jj);
            N_sm2(ii-kernel_size_half:ii+kernel_size_half,jj-kernel_size_half:jj+kernel_size_half) = N_sm2(ii-kernel_size_half:ii+kernel_size_half,jj-kernel_size_half:jj+kernel_size_half)+ts3;
        end
    end
end

N_ideal = N_sm2(size_add+1:size_add+size(N_orig,1),size_add+1:size_add+size(N_orig,2));
mask = mask_holes(size_add+1:size_add+size(N_orig,1),size_add+1:size_add+size(N_orig,2));
end