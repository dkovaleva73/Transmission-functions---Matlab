function Trans_corrector = correctorTransmission(Lam, Config)
    % Calculate corrector transmission from data file using
    % (a) polynomial fitting of instrumental data or (b) piecewise linear
    % interpolation of instrumental data
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Instrumental.Components.Corrector.Data_file
    %            Uses Config.Instrumental.Components.Corrector.Method
    % Output : - Trans_corrector (double array): Corrector transmission values (0-1)
    % Author : D. Kovaleva (Jul 2025)
    % Reference:  Garrappa et al. 2025, A&A 699, A50.
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Trans = transmission.instrumental.correctorTransmission(Lam, Config);
    %          % Use piecewise method
    %          Config.Instrumental.Components.Corrector.Method = 'piecewise_';
    %          Trans = transmission.instrumental.correctorTransmission(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Data_file = Config.Instrumental.Components.Corrector.Data_file;
    Method = Config.Instrumental.Components.Corrector.Method;
    
    if exist(Data_file, 'file')
        % Read corrector transmission data
        Data = readmatrix(Data_file);
        Corrector_wavelength = Data(:, 1);
        Corrector_transmission = Data(:, 2) / 100;  % Convert percentage to fraction
        
        % Adjust transmission function to wavelength array
        if strcmp(Method, 'polyfit_')
            Ci = polyfit(Corrector_wavelength, Corrector_transmission, 2);
            Trans_corrector = polyval(Ci, Lam);
        elseif strcmp(Method, 'piecewise_')
            Trans_corrector = interp1(Corrector_wavelength, Corrector_transmission, Lam, 'linear', 'extrap');
        else
            error('transmission:correctorTransmission:invalidMethod', ...
                  'Invalid method: %s. Use ''polyfit_'' or ''piecewise_''', Method);
        end    
    else
        error('transmission:correctorTransmission:fileNotFound', ...
              'Corrector transmission data file not found: %s', Data_file);
    end
    
