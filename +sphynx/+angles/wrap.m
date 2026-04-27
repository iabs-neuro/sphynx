function out = wrap(angles)
% WRAP  Wrap angles into (-pi, pi].
%
%   out = sphynx.angles.wrap(angles) returns angles wrapped into the
%   half-open interval (-pi, pi]. Vectorized; preserves shape.
%
%   Convention: pi maps to pi (not -pi). 2*pi*N maps to 0.
%   -3*pi wraps to +pi (not -pi) to keep the half-open convention.
%
%   Use this instead of MATLAB's wrapToPi (Mapping Toolbox dependency)
%   or hand-rolled mod expressions scattered through the legacy code.
%
%   See also: sphynx.angles.unwrapForSmooth, sphynx.angles.headDirection

    out = angles - 2*pi * floor((angles + pi) / (2*pi));
    % Map exactly -pi to pi for symmetric convention
    out(out == -pi) = pi;
end
