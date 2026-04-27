function h = progress(action, varargin)
% PROGRESS  Waitbar wrapper that no-ops in headless/test mode.
%
%   h = sphynx.util.progress('open', total, msg)
%   sphynx.util.progress('update', h, current, msg)
%   sphynx.util.progress('close', h)
%
%   When env var SPHYNX_HEADLESS=1, all calls are no-ops and 'open'
%   returns []. This is what tests and batch jobs set so they don't
%   spawn waitbar windows.

    headless = strcmp(getenv('SPHYNX_HEADLESS'), '1');

    switch action
        case 'open'
            total = varargin{1};
            msg = varargin{2};
            if headless || total <= 0
                h = [];
                return;
            end
            h = waitbar(0, sprintf('%s (0/%d)', msg, total));
            ud = struct('total', total);
            set(h, 'UserData', ud);

        case 'update'
            h = varargin{1};
            current = varargin{2};
            msg = varargin{3};
            if isempty(h) || ~isvalid(h)
                return;
            end
            ud = get(h, 'UserData');
            if isempty(ud) || ~isfield(ud, 'total') || ud.total <= 0
                ud = struct('total', max(current, 1));
                set(h, 'UserData', ud);
            end
            waitbar(min(current / ud.total, 1), h, ...
                sprintf('%s (%d/%d)', msg, current, ud.total));

        case 'close'
            h = varargin{1};
            if ~isempty(h) && isvalid(h)
                close(h);
            end

        otherwise
            error('sphynx:progress:unknownAction', ...
                'Unknown action "%s"; valid: open|update|close', action);
    end
end
