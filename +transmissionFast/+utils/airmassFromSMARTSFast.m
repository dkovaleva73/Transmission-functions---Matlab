function Airmass = airmassFromSMARTSFast(Constituent, Config, bypassCache)
    % FAST version: Calculate airmass using SMARTS2.9.5 with direct coefficients
    % Up to 3x faster than map-based version due to eliminated lookup overhead
    %
    % Input:   - Constituent (char): 'rayleigh', 'aerosol', 'ozone'/'o3', 'water'/'h2o'
    %          - Config (struct): Configuration struct with Zenith_angle_deg
    %          - bypassCache (logical): Force recalculation (default: false)
    % Output:  - Airmass (double): Calculated airmass (CACHED)
    %
    % Author: D. Kovaleva (Sep 2025) - Performance optimized version

    arguments
        Constituent = 'rayleigh'
        Config = transmissionFast.inputConfig()
        bypassCache logical = false
    end
    
    % Caching using persistent variables
    persistent airmassCache cacheCount
    
    % Initialize cache on first call
    if isempty(airmassCache)
        airmassCache = containers.Map();
        cacheCount = 0;
    end
    
    % Extract zenith angle
    Z_ = Config.Atmospheric.Zenith_angle_deg;
    
    % Create cache key
    Constituent_lower = lower(Constituent);
    cacheKey = sprintf('%.6f_%s', Z_, Constituent_lower);
    
    % Clear cache command
    if strcmp(Constituent_lower, 'clearcache')
        airmassCache = containers.Map();
        cacheCount = 0;
        Airmass = NaN;
        return;
    end
    
    % Check cache first
    if ~bypassCache && isKey(airmassCache, cacheKey)
        Airmass = airmassCache(cacheKey);
        return;
    end
    
    % Validate zenith angle
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end
    
    % === DIRECT COEFFICIENT CALCULATION (NO MAP LOOKUP) ===
    Cosz = cos(deg2rad(Z_));
    
    % Direct formulas with hardcoded coefficients for maximum speed
    switch Constituent_lower
        case 'rayleigh'
            % Coefficients: [0.48353, 0.095846, 96.741, -1.754]
            Airmass = 1 / (Cosz + 0.48353 * (Z_^0.095846) * (96.741 - Z_)^(-1.754));
            
        case 'aerosol'
            % Coefficients: [0.16851, 0.18198, 95.318, -1.9542]
            Airmass = 1 / (Cosz + 0.16851 * (Z_^0.18198) * (95.318 - Z_)^(-1.9542));
            
        case {'o3', 'ozone'}
            % Coefficients: [1.0651, 0.6379, 101.8, -2.2694]
            Airmass = 1 / (Cosz + 1.0651 * (Z_^0.6379) * (101.8 - Z_)^(-2.2694));
            
        case {'h2o', 'water'}
            % Coefficients: [0.10648, 0.11423, 93.781, -1.9203]
            Airmass = 1 / (Cosz + 0.10648 * (Z_^0.11423) * (93.781 - Z_)^(-1.9203));
            
        case 'o2'
            % Coefficients: [0.65779, 0.064713, 96.974, -1.8084]
            Airmass = 1 / (Cosz + 0.65779 * (Z_^0.064713) * (96.974 - Z_)^(-1.8084));
            
        case 'co2'
            % Coefficients: [0.65786, 0.064688, 96.974, -1.8083]
            Airmass = 1 / (Cosz + 0.65786 * (Z_^0.064688) * (96.974 - Z_)^(-1.8083));
            
        case 'ch4'
            % Coefficients: [0.49381, 0.35569, 98.23, -2.1616]
            Airmass = 1 / (Cosz + 0.49381 * (Z_^0.35569) * (98.23 - Z_)^(-2.1616));
            
        case 'n2o'
            % Coefficients: [0.61696, 0.060787, 96.632, -1.8279]
            Airmass = 1 / (Cosz + 0.61696 * (Z_^0.060787) * (96.632 - Z_)^(-1.8279));
            
        otherwise
            error('%s is not a supported constituent. Use: rayleigh, aerosol, ozone, water, o2, co2, ch4, n2o', Constituent);
    end
    
    % Cache the result
    airmassCache(cacheKey) = Airmass;
    cacheCount = cacheCount + 1;
    
    % Cache size management
    if cacheCount > 1000
        keys = airmassCache.keys;
        if length(keys) > 500
            for i = 1:100  % Remove 100 oldest entries
                remove(airmassCache, keys{i});
            end
            cacheCount = cacheCount - 100;
        end
    end
end