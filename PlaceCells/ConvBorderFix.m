function [N_ideal, mask] = ConvBorderFix(N_orig,mask_orig)
% Two dimensional convolution with Gauss kernel and constant summ of matrix
% N_orig = N;
% mask_orig = mask_t;
% making extended matrix for comvolution
N(1:size(N_orig,1)+4,1:size(N_orig,2)+4) = 0;
N(3:size(N_orig,1)+2,3:size(N_orig,2)+2) = N_orig;

% making masks for holes and border
mask_holes(1:size(N,1),1:size(N,2)) = 0;
if sum(sum(mask_orig))
    mask_holes(1:size(N,1),1:size(N,2)) = 1;
    mask_holes(3:size(N_orig,1)+2,3:size(N_orig,2)+2) = mask_orig;
end
mask_border(1:size(N,1),1:size(N,2)) = 0;
for ii=1:size(N,1)
    for jj=1:size(N,2)
        if N(ii,jj) == 0 && sum(sum(mask_orig))==0
            mask_holes(ii,jj) = 1;
        end         
        if N(ii,jj) ~= 0 && (N(ii+1,jj+1) == 0 ||  N(ii+1,jj-1) == 0 ||  N(ii-1,jj+1) == 0 ||  N(ii-1,jj-1) == 0)
            mask_border(ii,jj)= 1;
        end
    end
end

ts = fspecial('gaussian', 3, 1.5);
N_sm = conv2(N, single(ts), 'same');
value_holes = mask_holes.*N_sm;
N_sm2 = N_sm-value_holes;

for ii=1:size(N,1)
    for jj=1:size(N,2)
        if value_holes(ii,jj)>0
            ts2 = ts.*mask_border(ii-1:ii+1,jj-1:jj+1);
            ts3 = ts2./sum(sum(ts2))*value_holes(ii,jj);
            N_sm2(ii-1:ii+1,jj-1:jj+1) = N_sm2(ii-1:ii+1,jj-1:jj+1)+ts3;
        end
    end
end

N_ideal = N_sm2(3:size(N_orig,1)+2,3:size(N_orig,2)+2);
mask = mask_holes(3:size(N_orig,1)+2,3:size(N_orig,2)+2);
end