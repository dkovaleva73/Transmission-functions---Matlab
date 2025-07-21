function transmission = umgTransmittance(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases)
    % Calculate Uniformly Mixed Gases (UMG) transmission.
    %
    % Parameters:
    %   Z_ (double): The zenith angle in degrees.
    %   Tair (double): Air temperature in degrees Celsius.
    %   Pressure (double): Atmospheric pressure in hPa.
    %   Lam (double array): Wavelength array in nm.
    %   Co2_ppm (double): CO2 concentration in ppm (default: 395).
    %   With_trace_gases (logical): Include trace gases (default: true).
    %
    % Returns:
    %   transmission (double array): The calculated transmission values (0-1).
    %
    % Example:
    %   Lam = transmission.utils.makeWavelengthArray();
    %   Trans = transmission.atmospheric.umgTransmittance(30, 15, 1013.25, Lam, 415, true);
    
    % Set default values
    if nargin < 5
        Co2_ppm = 395.0;
    end
    if nargin < 6
        With_trace_gases = true;
    end
    
    % Constants
    NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
    
    % Import airmass function
    import transmission.utils.*
    
    % Convert temperature to absolute scale
    Tair_kelvin = Tair + 273.15;
    
    % Normalized pressure and temperature
    Pp0 = Pressure / 1013.25;
    Tt0 = Tair_kelvin / 273.15;
    
    % Initialize total optical depth
    Tau_total = zeros(size(Lam));
    
    % UNIFORMLY MIXED GASES
    fprintf('Loading uniformly mixed gases data...\n');
    
    % 1. Oxygen (O2)
    O2_abs = readGasData('O2', Lam);
    O2_abundance = 1.67766e5 * Pp0;
    Am_o2 = airmassFromSMARTS(Z_, 'o2');
    Tau_total = Tau_total + O2_abs .* O2_abundance .* Am_o2;
    
    % 2. Methane (CH4)
    Ch4_abs = readGasData('CH4', Lam);
    Ch4_abundance = 1.3255 * (Pp0 ^ 1.0574);
    Am_ch4 = airmassFromSMARTS(Z_, 'ch4');
    Tau_total = Tau_total + Ch4_abs .* Ch4_abundance .* Am_ch4;
    
    % 3. Carbon Monoxide (CO)
    Co_abs = readGasData('CO', Lam);
    Co_abundance = 0.29625 * (Pp0^2.4480) * exp(0.54669 - 2.4114 * Pp0 + 0.65756 * (Pp0^2));
    Am_co = airmassFromSMARTS(Z_, 'co');
    Tau_total = Tau_total + Co_abs .* Co_abundance .* Am_co;
    
    % 4. Nitrous Oxide (N2O)
    N2o_abs = readGasData('N2O', Lam);
    N2o_abundance = 0.24730 * (Pp0^1.0791);
    Am_n2o = airmassFromSMARTS(Z_, 'n2o');
    Tau_total = Tau_total + N2o_abs .* N2o_abundance .* Am_n2o;
    
    % 5. Carbon Dioxide (CO2)
    Co2_abs = readGasData('CO2', Lam);
    Co2_abundance = 0.802685 * Co2_ppm * Pp0;
    Am_co2 = airmassFromSMARTS(Z_, 'co2');
    Tau_total = Tau_total + Co2_abs .* Co2_abundance .* Am_co2;
    
    % 6. Nitrogen (N2)
    N2_abs = readGasData('N2', Lam);
    N2_abundance = 3.8269 * (Pp0^1.8374);
    Am_n2 = airmassFromSMARTS(Z_, 'n2');
    Tau_total = Tau_total + N2_abs .* N2_abundance .* Am_n2;
    
    % 7. Oxygen-Oxygen collision complex (O4)
    O4_abs = readGasData('O4', Lam) * 1e-46;  % Special scaling factor
    O4_abundance = 1.8171e4 * (NLOSCHMIDT^2) * (Pp0^1.7984) / (Tt0^0.344);
    Am_o4 = airmassFromSMARTS(Z_, 'o2');  % Use O2 airmass for O4
    Tau_total = Tau_total + O4_abs .* O4_abundance .* Am_o4;
    
    % TRACE GASES (optional) - Simplified version for now
    if With_trace_gases
        fprintf('Loading trace gases data...\n');
        
        % For now, add a simple approximation for major trace gases
        % NH3 (simple case)
        try
            Nh3_abs = readGasData('NH3', Lam);
            Log_pp0 = log(Pp0);
            Nh3_abundance = exp(-8.6499 + 2.1947 * Log_pp0 - 2.5936 * (Log_pp0^2) - ...
                               1.819 * (Log_pp0^3) - 0.65854 * (Log_pp0^4));
            Am_nh3 = airmassFromSMARTS(Z_, 'nh3');
            Tau_total = Tau_total + Nh3_abs .* Nh3_abundance .* Am_nh3;
        catch ME
            warning('NH3 trace gas calculation failed: %s', ME.message);
        end
        
        % Additional trace gases can be added here individually
        % For now, keeping it simple to ensure the main function works
    end
    
    % Calculate transmission and clip to [0,1]
    transmission = exp(-Tau_total);
    transmission = max(0, min(1, transmission));
end

function abs_data = readGasData(gas_name, Lam)
    % Read simple gas absorption data (single column)
    
    try
        Data_file = getGasDataPath(gas_name);
        if ~isempty(Data_file) && exist(Data_file, 'file')
            Data = readtable(Data_file, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
            Gas_wavelength = Data.Var1;
            Gas_absorption = Data.Var2;
            abs_data = interp1(Gas_wavelength, Gas_absorption, Lam, 'linear', 0);
        else
            warning('Gas data file not found for %s, using zeros', gas_name);
            abs_data = zeros(size(Lam));
        end
    catch ME
        warning('Error reading gas data for %s: %s', gas_name, ME.message);
        abs_data = zeros(size(Lam));
    end
end

function file_path = getGasDataPath(gas_name)
    % Get the file path for gas absorption data
    
     file_path = sprintf('/home/dana/matlab/data_Transmission_Fitter/Templates/Abs_%s.dat', gas_name);
    
    % Primary data location provided by user
%    Primary_path = sprintf('/home/dana/matlab/data_Transmission_Fitter/Templates/Abs_%s.dat', gas_name);
    
    % Backup search locations
%    Possible_paths = {
%        Primary_path, ...
%        sprintf('/home/dana/Documents/MATLAB/inwork/data/Templates/Abs_%s.dat', gas_name), ...
%        sprintf('/home/dana/anaconda3/lib/python3.12/site-packages/transmission_fitter/data/Templates/Abs_%s.dat', gas_name)
%    };
    
%    file_path = '';
%    for I = 1:length(Possible_paths)
%        if exist(Possible_paths{I}, 'file')
%            file_path = Possible_paths{I};
%            return;
%        end
%   end
    
    % If not found, return empty - will trigger warning in calling function
%    file_path = '';
end
