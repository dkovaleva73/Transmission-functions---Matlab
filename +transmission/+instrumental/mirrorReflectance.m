function Ref_mirror = mirrorReflectance(Data_file, Lam, Args)
    % Calculate mirror reflectance from (a) polynomial fitting of
    % instrumental data or (b) linear interpolation of instrumental data
    %  Input :  - Data_file - Custom path to data file
    %                         (default: StarBrightXLT data, fixed)
    %           - Lam (double array): Wavelength array in nm
    %           - Degr (integer): degree of Legendre polynom
    %  Output : - Ref_mirror (double array): Mirror reflectance values (0-1)
    %          * ...,key,val,... 
    %         'Meth' - 'polyfit_'|'piecewise_' (fitting and extrapolation by
    %         2nd order polynom | piecewise linear interpolation and
    %         extrapolation)
    % Author : D. Kovaleva (Jul 2025)
    % Reference:  Garrappa et al. 2025, A&A 699, A50.
    % Example: % Basic usage with default StarBrightXLT data and polyfit method
    %          Ref = transmission.instrumental.mirrorReflectance();
    %          % Custom wavelength array
    %          Lam = linspace(350, 950, 301)';
    %          Ref = transmission.instrumental.mirrorReflectance([], Lam);
    %          % Use piecewise linear interpolation instead of polyfit
    %          Ref = transmission.instrumental.mirrorReflectance([], Lam, 'Meth', 'piecewise_');
    %          % Custom mirror reflectance data file
    %          Ref = transmission.instrumental.mirrorReflectance('/path/to/mirror_data.csv', Lam);
    
    arguments
        Data_file = '/home/dana/matlab/data/transmission_fitter/StarBrightXLT_Mirror_Reflectivity.csv'
        Lam = transmission.utils.makeWavelengthArray()
        Args.Meth = 'polyfit_'
    end
    
    % Handle empty Data_file argument
    if isempty(Data_file)
        Data_file = '/home/dana/matlab/data/transmission_fitter/StarBrightXLT_Mirror_Reflectivity.csv';
    end
    
    if exist(Data_file, 'file')
        Data = readmatrix(Data_file);
        Mirror_wavelength = Data(:, 1);
        Mirror_transmission = Data(:, 2) / 100;  % Convert percentage to fraction
        
        % adjusting transmission function to wavelength array
       if Args.Meth == 'polyfit_'
          Ci = polyfit(Mirror_wavelength, Mirror_transmission,2);
          Ref_mirror = polyval(Ci, Lam);
       elseif Args.Meth == 'piecewise_'
          Ref_mirror = interp1(Mirror_wavelength, Mirror_transmission, Lam, 'linear', 'extrap');
       end    
    else
        error('transmission:mirrorReflectance:fileNotFound', ...
              'Mirror reflectance data file not found: %s', Data_file);
    end
end



