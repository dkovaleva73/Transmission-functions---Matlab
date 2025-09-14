function Ref_mirror = mirrorReflectance(Lam, Config)
    % Calculate mirror reflectance from (a) polynomial fitting of
    % instrumental data or (b) linear interpolation of instrumental data
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Instrumental.Components.Mirror.Data_file
    %            Uses Config.Instrumental.Components.Mirror.Method
    % Output : - Ref_mirror (double array): Mirror reflectance values (0-1)
    % Author : D. Kovaleva (Jul 2025)
    % Reference:  Garrappa et al. 2025, A&A 699, A50.
    % Example: Config = transmissionFast.inputConfig('default');
    %          Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %          Ref = transmissionFast.instrumental.mirrorReflectance(Lam, Config);
    %          % Use piecewise method
    %          Config.Instrumental.Components.Mirror.Method = 'piecewise_';
    %          Ref = transmissionFast.instrumental.mirrorReflectance(Lam, Config);
    
    arguments
        Lam = []  % Will use cached wavelength array from Config if empty
        Config = transmissionFast.inputConfig()
    end
    
    % Use cached wavelength array if Lam not provided
    if isempty(Lam)
        if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
            Lam = Config.WavelengthArray;
        else
            % Fallback to calculation if cached array not available
            Lam = transmissionFast.utils.makeWavelengthArray(Config);
        end
    end
    
    % Persistent variables for caching computed mirror reflectance
    persistent mirrorCache lastMethod lastDataFile lastLam
    
    % Extract parameters from Config
    Method = Config.Instrumental.Components.Mirror.Method;
    DataFile = Config.Instrumental.Components.Mirror.Data_file;
    
    % Create cache key based on wavelength array, method, and data file
    cacheKey = struct('wavelength', Lam, 'method', Method, 'datafile', DataFile);
    
    % Check if we can use persistent cached result
    if ~isempty(mirrorCache) && isequal(lastLam, Lam) && strcmp(lastMethod, Method) && strcmp(lastDataFile, DataFile)
        Ref_mirror = mirrorCache;
        return;
    end
    
    % Need to calculate - not in persistent cache or cache invalid
    % ALWAYS try to use cached data from inputConfig first (avoids file I/O)
    if isfield(Config, 'InstrumentalData') && isfield(Config.InstrumentalData, 'Mirror')
        mirrorData = Config.InstrumentalData.Mirror;
        
        % Check if data loaded successfully
        if isfield(mirrorData, 'error')
            error('transmission:mirrorReflectance:cachedDataError', ...
                  'Cached mirror data has error: %s', mirrorData.error);
        end
        
        if isempty(mirrorData.wavelength) || isempty(mirrorData.reflectance)
            error('transmission:mirrorReflectance:emptyCachedData', ...
                  'Cached mirror data is empty');
        end
        
        Mirror_wavelength = mirrorData.wavelength;
        Mirror_transmission = mirrorData.reflectance;  % Already converted to fraction in cache
        
        % Adjust transmission function to wavelength array
        if strcmp(Method, 'polyfit_')
            Ci = polyfit(Mirror_wavelength, Mirror_transmission, 2);
            Ref_mirror = polyval(Ci, Lam);
        elseif strcmp(Method, 'piecewise_')
            Ref_mirror = interp1(Mirror_wavelength, Mirror_transmission, Lam, 'linear', 'extrap');
        else
            error('transmission:mirrorReflectance:invalidMethod', ...
                  'Invalid method: %s. Use ''polyfit_'' or ''piecewise_''', Method);
        end
        
    else
        % ONLY use file I/O as absolute fallback if cached data not available
        Data_file = Config.Instrumental.Components.Mirror.Data_file;
        
        warning('transmission:mirrorReflectance:usingFileIO', ...
                'Using file I/O fallback - cached data not available in inputConfig');
        
        if exist(Data_file, 'file')
            Data = readmatrix(Data_file);
            Mirror_wavelength = Data(:, 1);
            Mirror_transmission = Data(:, 2) / 100;  % Convert percentage to fraction
            
            % Adjust transmission function to wavelength array
            if strcmp(Method, 'polyfit_')
                Ci = polyfit(Mirror_wavelength, Mirror_transmission, 2);
                Ref_mirror = polyval(Ci, Lam);
            elseif strcmp(Method, 'piecewise_')
                Ref_mirror = interp1(Mirror_wavelength, Mirror_transmission, Lam, 'linear', 'extrap');
            else
                error('transmission:mirrorReflectance:invalidMethod', ...
                      'Invalid method: %s. Use ''polyfit_'' or ''piecewise_''', Method);
            end    
        else
            error('transmission:mirrorReflectance:fileNotFound', ...
                  'Mirror reflectance data file not found: %s', Data_file);
        end
    end
    
    % Cache the result for future calls in persistent variables
    mirrorCache = Ref_mirror;
    lastMethod = Method;
    lastDataFile = DataFile;
    lastLam = Lam;
end



