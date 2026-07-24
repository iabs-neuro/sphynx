function root = repoRoot()
% REPOROOT  Absolute path to the sphynx repository root.
%
%   root = sphynx.util.repoRoot() returns the absolute path of the
%   repository root, derived from the location of this file.
%
%   This is used by tests, snapshot builders, and the golden test
%   loader to locate fixture data without depending on the current
%   working directory.

    here = fileparts(mfilename('fullpath'));
    % here == <repo>/+sphynx/+util ; go up two levels
    root = fileparts(fileparts(here));
end
