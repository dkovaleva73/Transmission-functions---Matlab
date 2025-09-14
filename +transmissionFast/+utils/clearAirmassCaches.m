function clearAirmassCaches()
    % Clear all cached airmass calculations
    % This forces recalculation on next airmassFromSMARTS call
    %
    % Usage: transmissionFast.utils.clearAirmassCaches()
    %
    % Author: D. Kovaleva (Sep 2025)
    
    % Use dummy config (zenith angle doesn't matter for cache clearing)
    dummyConfig = struct();
    dummyConfig.Atmospheric = struct();
    dummyConfig.Atmospheric.Zenith_angle_deg = 0;
    
    % Call with special 'clearCache' constituent to clear the cache
    transmissionFast.utils.airmassFromSMARTS('clearCache', dummyConfig);
    fprintf('Airmass cache cleared successfully\n');
end