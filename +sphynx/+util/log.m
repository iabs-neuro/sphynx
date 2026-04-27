function log(level, fmt, varargin)
% LOG  Verbose-aware logger for sphynx.
%
%   sphynx.util.log(LEVEL, FMT, ARGS...) prints a formatted message
%   to stdout, prefixed with the upper-cased LEVEL, when LEVEL meets
%   the current threshold.
%
%   Levels (low to high): 'debug', 'info', 'warn', 'error'.
%   Default threshold is 'info' (debug is silent).
%   Override threshold via env var SPHYNX_LOG_LEVEL.
%
%   Examples:
%     sphynx.util.log('info', 'Loaded %d frames', n);
%     sphynx.util.log('warn', 'BodyPart %s missing', name);

    levels = {'debug', 'info', 'warn', 'error'};
    levelIdx = find(strcmp(level, levels), 1);
    if isempty(levelIdx)
        error('sphynx:log:unknownLevel', ...
            'Unknown log level "%s"; valid: debug|info|warn|error', level);
    end

    threshold = getenv('SPHYNX_LOG_LEVEL');
    if isempty(threshold)
        threshold = 'info';
    end
    thresholdIdx = find(strcmp(threshold, levels), 1);
    if isempty(thresholdIdx)
        thresholdIdx = 2; % info
    end

    if levelIdx < thresholdIdx
        return;
    end

    msg = sprintf(fmt, varargin{:});
    fprintf('[%s] %s\n', upper(level), msg);
end
