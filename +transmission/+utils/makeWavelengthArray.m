function Lam = makeWavelengthArray(Min_wvl, Max_wvl, Num_points, Args)
    % Generate wavelength array for photometric calculations
    %
    % Input :  - Min_wvl (double): Minimum wavelength (default: 300)
    %          - Max_wvl (double): Maximum wavelength (default: 1100)  
    %          - Num_points (int): Number of points (default: 401)
    %          * ...,key,val,... 
    %         'WaveUnits' - 'A','Ang'|'nm'
    % Output : - Lam (double array): Wavelength array 
    % Notes :  Num_points = 401 points mimics Gaia sampling (dLambda = 2nm)
    %          Num_points = 81 points gives dLambda = 10nm 
    % Author : D. Kovaleva (Jul 2025)
    % Example: Lam = transmission.utils.make_wavelength_array();
    %          Lam_coarse = transmission.utils.make_wavelength_array(400, 800, 81);
    arguments
        Min_wvl  = 300.0; 
        Max_wvl  = 1100.0;
        Num_points = 401;
        Args.WaveUnits = 'nm';
    end
    
    LamIni = linspace(Min_wvl, Max_wvl, Num_points);

    % Convert wavelength if needed
    Lam = convert.energy('nm',Args.WaveUnits,LamIni);
end