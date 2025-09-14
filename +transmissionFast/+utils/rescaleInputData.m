function Re_data = rescaleInputData(Dat, Min_dat, Max_dat, Min_resc, Max_resc, Config)
    % Normalize input data (wavelength array / coordinate array) to target range 
    % for orthogonal polynomial basis functions (Jakobi, including Legendre, Chebyshev)
    % Input  : - Dat (double array): Input data array
    %          - Min_dat (double): Minimum value of the input data range
    %          - Max_dat (double): Maximum value of the input data range
    %          - Min_resc (double): Minimum value for rescaled data (optional, uses Config if not provided)
    %          - Max_resc (double): Maximum value for rescaled data (optional, uses Config if not provided)
    %          - Config (struct): Configuration struct from inputConfig() (optional)
    % Output :   Re_data (double array): Rescaled data array
    % Author : D. Kovaleva (Jul 2025)
    % Example : % Basic usage with Config defaults
    %           Config = transmissionFast.inputConfig('default');
    %           Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %           Data_resc = transmissionFast.utils.rescaleInputData(Lam, min(Lam), max(Lam));
    %           % Explicit rescale range
    %           Data_resc = transmissionFast.utils.rescaleInputData(Dat, 400, 800, -1, 1);

arguments
     Dat = transmissionFast.utils.makeWavelengthArray(transmissionFast.inputConfig())
     Min_dat = min(Dat)
     Max_dat = max(Dat)
     Min_resc = []  % Will use Config if empty
     Max_resc = []  % Will use Config if empty  
     Config = transmissionFast.inputConfig()
end

    % Use Config values if rescale range not explicitly provided
    if isempty(Min_resc)
        Min_resc = Config.Utils.RescaleInputData.Target_min;
    end
    if isempty(Max_resc)
        Max_resc = Config.Utils.RescaleInputData.Target_max;
    end
    
    % Validate wavelength bounds
    if Min_dat >= Max_dat
        error('transmission:rescInputData:invalidBounds', ...
              'Min_dat must be less than Max_dat');
    end
%    if Min_dat < min(Dat) || Max_dat > max(Dat)
%        error('transmission:rescInputData:boundsOutOfRange', ...
%              'Normalization bounds [%.1f, %.1f] exceed wavelength array range [%.1f, %.1f]', ...
%              Min_dat, Max_dat, min(Dat), max(Dat));
%    end
    
    % Linear transformation to map [Min_dat, Max_dat] to [Min_resc, Max_resc]
    Re_data = (Max_resc - Min_resc) ./ (Max_dat - Min_dat) .* (Dat - Max_dat) + Max_resc;
end