% Compare trace gas absorption coefficients between MATLAB and Python
% Focus on 350 nm and 450 nm wavelengths

% Configuration
Config = transmission.inputConfig('default');
Config.Atmospheric.Components.Molecular_absorption.With_trace_gases = true;

% Test wavelengths
test_wavelengths = [350, 450];

% Standard conditions
Z_ = 0;  % Zenith angle
Tair = 15;  % Temperature C
Pressure = 1013.25;  % mbar
Pp0 = Pressure / 1013.25;
Co2_ppm = 395;

% Load absorption data for trace gases
trace_species = {'NO2', 'SO2U', 'SO2I', 'HNO3', 'NO3', 'NO', 'NH3', 'BrO', 'CH2O', 'HNO2', 'ClNO'};
Abs_data = transmission.data.loadAbsorptionData([], trace_species, false);

% Loschmidt number
NLOSCHMIDT_python = 2.6868e19;  % From Python
NLOSCHMIDT_matlab = constant.Loschmidt;  % From MATLAB

fprintf('\n=== LOSCHMIDT NUMBER COMPARISON ===\n');
fprintf('Python NLOSCHMIDT: %.4e\n', NLOSCHMIDT_python);
fprintf('MATLAB constant.Loschmidt: %.4e\n', NLOSCHMIDT_matlab);
fprintf('Ratio (Python/MATLAB): %.6f\n\n', NLOSCHMIDT_python/NLOSCHMIDT_matlab);

% Calculate airmass
Am_no2 = transmission.utils.airmassFromSMARTS('no2', Config);
fprintf('Airmass for NO2 at zenith: %.6f\n\n', Am_no2);

% Process each wavelength
for wvl = test_wavelengths
    fprintf('=== WAVELENGTH: %d nm ===\n\n', wvl);
    
    % NO2 - Main UV absorber
    if isfield(Abs_data, 'NO2')
        sigma_and_b0 = interp1(Abs_data.NO2.wavelength, Abs_data.NO2.absorption, wvl, 'linear', 0);
        fprintf('NO2:\n');
        fprintf('  Data columns available: %d\n', size(Abs_data.NO2.absorption, 2));
        
        if size(Abs_data.NO2.absorption, 2) >= 2
            sigma = sigma_and_b0(1);
            b0 = sigma_and_b0(2);
            fprintf('  Raw sigma: %.4e\n', sigma);
            fprintf('  Raw b0: %.4e\n', b0);
            fprintf('  Temperature term b0*(228.7-220): %.4e\n', b0 * (228.7 - 220));
            
            % Python calculation
            No2_abs_python = NLOSCHMIDT_python * (sigma + b0 * (228.7 - 220));
            fprintf('  Python NO2 abs coeff: %.4e\n', No2_abs_python);
            
            % MATLAB calculation
            No2_abs_matlab = NLOSCHMIDT_matlab * (sigma + b0 * (228.7 - 220));
            fprintf('  MATLAB NO2 abs coeff: %.4e\n', No2_abs_matlab);
        else
            % Single column - no temperature coefficient
            sigma = sigma_and_b0;
            fprintf('  Raw sigma (no temp coeff): %.4e\n', sigma);
            fprintf('  WARNING: Missing temperature coefficient column!\n');
            
            % Without temperature correction
            No2_abs_matlab = sigma;  % Already has units, don't multiply by Loschmidt
            fprintf('  NO2 abs coeff (no temp correction): %.4e\n', No2_abs_matlab);
        end
        
        % Abundance
        No2_abundance = 1e-4 * min(1.8599 + 0.18453 * Pp0, 41.771 * Pp0);
        fprintf('  NO2 abundance: %.4e\n', No2_abundance);
        
        % Optical depth contribution
        tau_no2 = No2_abs_matlab * No2_abundance * Am_no2;
        fprintf('  NO2 optical depth contribution: %.4e\n', tau_no2);
        fprintf('  NO2 transmission: %.6f\n\n', exp(-tau_no2));
    end
    
    % SO2 - Strong UV absorber
    So2_abs = 0;
    if isfield(Abs_data, 'SO2U')
        sigma_and_b0 = interp1(Abs_data.SO2U.wavelength, Abs_data.SO2U.absorption, wvl, 'linear', 0);
        if size(Abs_data.SO2U.absorption, 2) >= 2
            sigma = sigma_and_b0(1);
            b0 = sigma_and_b0(2);
            fprintf('SO2U:\n');
            fprintf('  Raw sigma: %.4e\n', sigma);
            fprintf('  Raw b0: %.4e\n', b0);
            fprintf('  Temperature term b0*(247-213): %.4e\n', b0 * (247 - 213));
            So2_abs = So2_abs + NLOSCHMIDT_matlab * (sigma + b0 * (247 - 213));
        end
    end
    if isfield(Abs_data, 'SO2I')
        So2i_abs = interp1(Abs_data.SO2I.wavelength, Abs_data.SO2I.absorption, wvl, 'linear', 0);
        fprintf('  SO2I contribution: %.4e\n', So2i_abs);
        So2_abs = So2_abs + So2i_abs;
    end
    if So2_abs > 0
        So2_abundance = 1e-4 * 0.11133 * (Pp0^0.812) * exp(0.81319 + 3.0557 * (Pp0^2) - 1.578 * (Pp0^3));
        fprintf('  Total SO2 abs coeff: %.4e\n', So2_abs);
        fprintf('  SO2 abundance: %.4e\n', So2_abundance);
        Am_so2 = transmission.utils.airmassFromSMARTS('so2', Config);
        tau_so2 = So2_abs * So2_abundance * Am_so2;
        fprintf('  SO2 optical depth contribution: %.4e\n', tau_so2);
        fprintf('  SO2 transmission: %.6f\n\n', exp(-tau_so2));
    end
    
    % Check HNO3
    if isfield(Abs_data, 'HNO3')
        xs_and_b0 = interp1(Abs_data.HNO3.wavelength, Abs_data.HNO3.absorption, wvl, 'linear', 0);
        if size(Abs_data.HNO3.absorption, 2) >= 2
            xs = xs_and_b0(1);
            b0 = xs_and_b0(2);
            fprintf('HNO3:\n');
            fprintf('  Raw xs: %.4e\n', xs);
            fprintf('  Raw b0: %.4e\n', b0);
            fprintf('  Temp factor exp(1e-3*b0*(234.2-298)): %.4e\n', exp(1e-3 * b0 * (234.2 - 298)));
            Hno3_abs = 1e-20 * NLOSCHMIDT_matlab * xs * exp(1e-3 * b0 * (234.2 - 298));
            fprintf('  HNO3 abs coeff: %.4e\n', Hno3_abs);
        end
    end
    
    fprintf('\n');
end

% Also check what files were actually loaded
fprintf('\n=== LOADED ABSORPTION DATA FILES ===\n');
fields = fieldnames(Abs_data);
for i = 1:length(fields)
    gas = fields{i};
    if isfield(Abs_data.(gas), 'wavelength')
        wvl_range = [min(Abs_data.(gas).wavelength), max(Abs_data.(gas).wavelength)];
        n_columns = size(Abs_data.(gas).absorption, 2);
        fprintf('%s: wavelength range [%.1f, %.1f] nm, %d data columns\n', ...
                gas, wvl_range(1), wvl_range(2), n_columns);
    end
end