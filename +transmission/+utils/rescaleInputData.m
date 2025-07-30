function Re_data = rescaleInputData(Dat, Min_dat, Max_dat, Min_resc, Max_resc)
    % Normalize input data (wavelength array / coordinate array) to target range 
    % for orthogonal polynomial basis functions (Jakobi, including Legendre, Chebyshev)
    % Input  : - Dat (double array): Wavelength array in nm
    %          - Min_dat (double): Minimum wavelength of the array (default from makeWavelengthArray)
    %          - Max_dat (double): Maximum wavelength of the array (default from makeWavelengthArray)
    %          - Min_resc (double): Minimum value for rescalized data (default: -1, for Legendre/Chebyshev polynoms)
    %          - Max_resc (double): Maximum value for rescalized data (default: +1, for Legendre/Chebyshev polynoms)
    % Output :   Re_data (double array): Rescaled data array
    % Author : D. Kovaleva (Jul 2025)
    % Example : % Basic usage with defaults (rescales to [-1,+1] for Legendre polynomials)
    %           Data_resc = transmission.utils.rescaleInputData();
    %           % Custom data range
    %           Data_resc = transmission.utils.rescaleInputData(Dat, 400, 800);
    %           % Default rescalization for X, Y coordinates for the photometry zero-point fitting 
    %           Data_resc = transmission.utils.rescaleInputData(Dat, 0, 1726, -1, 1);

arguments
     Dat  = transmission.utils.makeWavelengthArray() % case data = wavelengths
     Min_dat = min(Dat)
     Max_dat = max(Dat)
     Min_resc = -1
     Max_resc = 1
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