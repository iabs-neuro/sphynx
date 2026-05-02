function txt = actToDescription(act)
% ACTTODESCRIPTION  Human-readable description of an act for the GUI.
    lines = {};
    lines{end+1} = sprintf('Name: %s', act.name);
    lines{end+1} = sprintf('Type: %s', act.type);
    switch act.type
        case 'simple'
            if ~isempty(act.zones)
                lines{end+1} = sprintf('Zones (%s): %s', act.zoneOp, ...
                    strjoin(act.zones, ', '));
            else
                lines{end+1} = 'Zones: <any>';
            end
            lines{end+1} = sprintf('Body part: %s', act.bodyPart);
            lines{end+1} = sprintf('Speed: [%g, %g] cm/s', act.speedMin, act.speedMax);
        case 'complex'
            lines{end+1} = sprintf('Operation: %s', act.operation);
            lines{end+1} = sprintf('Components: %s', strjoin(act.components, ', '));
            if strcmp(act.operation, 'sequence')
                lines{end+1} = sprintf('Sequence delay: %g s', act.seqDelaySec);
            end
        case 'special'
            lines{end+1} = sprintf('Special: %s', act.specialKind);
            if ~isempty(act.bodyParts)
                lines{end+1} = sprintf('Body parts: %s', strjoin(act.bodyParts, ', '));
            end
            if ~isnan(act.thresholdCm)
                lines{end+1} = sprintf('Threshold: %g cm', act.thresholdCm);
            end
    end
    txt = lines(:);
end
