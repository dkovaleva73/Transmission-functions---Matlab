function Trans_corrector = correctorTransmission(Data_file, Lam, Args)
    %  Calculate corrector transmission from 
    %  (a) polynomial fitting of instrumental data or (b) piecewise linear
    %  interpolation of instrumental data
    %  Input :  - Data_file - Custom path to data file
    %                         (default: StarBrightXLT data, fixed)
    %           - Lam (double array): Wavelength array in nm
    %           - Degr (integer): degree of Legendre polynom
    %  Output : - Trans_corrector (double array): Corrector transmission values (0-1)
    %          * ...,key,val,... 
    %         'Meth' - 'polyfit_'|'piecewise_' (fitting and extrapolation by
    %         2nd order polynom | piecewise linear interpolation and
    %         extrapolation)
    % Author : D. Kovaleva (Jul 2025)
    % Reference:  Garrappa et al. 2025, A&A 699, A50.
    % Example: % Basic usage with default StarBrightXLT data and polyfit method
    %          Trans = transmission.instrumental.correctorTransmission();
    %          % Custom wavelength array
    %          Lam = linspace(350, 950, 301)';
    %          Trans = transmission.instrumental.correctorTransmission([], Lam);
    %          % Use piecewise linear interpolation instead of polyfit
    %          Trans = transmission.instrumental.correctorTransmission([], Lam, 'Meth', 'piecewise_');
    %          % Custom corrector data file
    %          Trans = transmission.instrumental.correctorTransmission('/path/to/corrector_data.csv', Lam);
    
    arguments
        Data_file = '/home/dana/matlab/data/transmission_fitter/StarBrightXLT_Corrector_Trasmission.csv'
        Lam = transmission.utils.makeWavelengthArray()
        Args.Meth = 'polyfit_'
    end
    
    % Handle empty Data_file argument
    if isempty(Data_file)
        Data_file = '/home/dana/matlab/data/transmission_fitter/StarBrightXLT_Corrector_Trasmission.csv';
    end
    
    if exist(Data_file, 'file')
        % Read corrector transmission data
        Data = readmatrix(Data_file);
        Corrector_wavelength = Data(:, 1);
        Corrector_transmission = Data(:, 2) / 100;  % Convert percentage to fraction
        
        % adjusting transmission function to wavelength array
       if Args.Meth == 'polyfit_'
          Ci = polyfit(Corrector_wavelength, Corrector_transmission,2);
          Trans_corrector = polyval(Ci,Lam);
       elseif Args.Meth == 'piecewise_'
          Trans_corrector = interp1(Corrector_wavelength, Corrector_transmission, Lam, 'linear', 'extrap');
       end    
    else
        error('transmission:correctorTransmission:fileNotFound', ...
              'Corrector transmission data file not found: %s', Data_file);
    end
    
