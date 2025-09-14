function stats = getAirmassCacheStats()
    % Get statistics about airmass cache usage
    % Returns information about cache hits, size, and efficiency
    %
    % Usage: stats = transmissionFast.utils.getAirmassCacheStats()
    %
    % Output: stats - Structure with cache statistics:
    %         .cacheSize - Number of cached entries
    %         .totalCalls - Total function calls (estimated)
    %         .cacheHits - Estimated cache hits
    %         .hitRate - Cache hit rate (hits/calls)
    %         .cachedKeys - Cell array of cached keys
    %
    % Author: D. Kovaleva (Sep 2025)
    
    % Access the cache by calling with special inspection mode
    % We'll modify airmassFromSMARTS to support this
    try
        % Create dummy config for cache inspection
        dummyConfig = struct();
        dummyConfig.Atmospheric = struct();
        dummyConfig.Atmospheric.Zenith_angle_deg = 0;
        
        % Call with special 'getCacheStats' constituent
        cacheInfo = transmissionFast.utils.airmassFromSMARTS('getCacheStats', dummyConfig);
        
        if isstruct(cacheInfo)
            stats = cacheInfo;
        else
            % Fallback if cache stats not implemented
            stats = struct();
            stats.cacheSize = NaN;
            stats.totalCalls = NaN;
            stats.cacheHits = NaN;
            stats.hitRate = NaN;
            stats.cachedKeys = {};
            stats.message = 'Cache statistics not available';
        end
        
    catch ME
        % Fallback in case of error
        stats = struct();
        stats.error = ME.message;
        stats.cacheSize = NaN;
        stats.message = 'Error accessing cache statistics';
    end
end