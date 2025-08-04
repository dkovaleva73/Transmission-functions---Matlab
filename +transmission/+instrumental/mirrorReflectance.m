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
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Ref = transmission.instrumental.mirrorReflectance(Lam, Config);
    %          % Use piecewise method
    %          Config.Instrumental.Components.Mirror.Method = 'piecewise_';
    %          Ref = transmission.instrumental.mirrorReflectance(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Data_file = Config.Instrumental.Components.Mirror.Data_file;
    Method = Config.Instrumental.Components.Mirror.Method;
    
    % Data_file path comes from Config
    
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



