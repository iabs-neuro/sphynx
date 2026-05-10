function thrCm = autoRearThresholdCm(sumDistCm, varargin)
% AUTOREARTHRESHOLDCM  Pick a per-session rear threshold from the
% distribution of (tailbase -> hindlimb_left) + (tailbase ->
% hindlimb_right) distances, in cm.
%
%   thrCm = sphynx.acts.autoRearThresholdCm(sumDistCm)
%
% The distribution is essentially unimodal (one big "walking on four
% paws" mode at ~4 cm) with a small left tail when the mouse rears
% and the hindlimbs come up under the tailbase. A 2-component GMM
% chronically splits the main mode itself — useless. A robust stat
% does what we want.
%
%   thr = min( prctile(s, 7),  median(s) - 1.5*std(s) )
%
% Both rules tend to land ~3 cm for a well-tracked adult mouse. The
% min() bias picks whichever cuts more aggressively — this matters
% on sessions with a narrow distribution where the percentile is
% unreasonably tight, and on sessions with a wide distribution where
% the percentile is too generous.
%
% Optional name-value:
%   'Pctl'        default 7      lower-tail percentile to consider
%   'StdK'        default 1.5    median-k*std bound
%   'ClampMinCm'  default 1.5    hard floor on threshold
%   'ClampMaxCm'  default 3.5    hard ceiling on threshold
%
% Returns NaN if input is empty / all NaN.

    p = inputParser;
    p.addRequired('sumDistCm');
    p.addParameter('Pctl', 7, @(v) isnumeric(v) && v > 0 && v < 100);
    p.addParameter('StdK', 1.5, @(v) isnumeric(v) && v > 0);
    p.addParameter('ClampMinCm', 1.5, @isnumeric);
    p.addParameter('ClampMaxCm', 3.5, @isnumeric);
    parse(p, sumDistCm, varargin{:});

    s = sumDistCm(:);
    s = s(isfinite(s));
    if isempty(s); thrCm = NaN; return; end

    pctlThr = prctile(s, p.Results.Pctl);
    stdThr  = median(s, 'omitnan') - p.Results.StdK * std(s, 'omitnan');
    thrCm = min(pctlThr, stdThr);
    thrCm = max(p.Results.ClampMinCm, min(p.Results.ClampMaxCm, thrCm));
end
