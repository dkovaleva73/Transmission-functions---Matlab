function debug_umg_differences()
    % Debug script to identify and fix the differences between umgTransmittance
    % and umgTransmittanceOptimized functions
    %
    % This script creates detailed comparisons to isolate the exact source
    % of the 0.68 difference in results between the two functions.
    
    fprintf('=== UMG TRANSMITTANCE DEBUG ANALYSIS ===\n\n');
    
    % Test parameters
    Z_ = 30;          % zenith angle (degrees)
    Tair = 15;        % air temperature (°C) 
    Pressure = 1013.25; % atmospheric pressure (hPa)
    Co2_ppm = 415;    % CO2 concentration (ppm)
    With_trace_gases = true;
    
    % Create wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Test parameters:\n');
    fprintf('  Zenith angle: %.1f degrees\n', Z_);
    fprintf('  Air temperature: %.1f °C\n', Tair);
    fprintf('  Pressure: %.1f hPa\n', Pressure);
    fprintf('  CO2 concentration: %.1f ppm\n', Co2_ppm);
    fprintf('  Include trace gases: %s\n', string(With_trace_gases));
    fprintf('  Wavelength points: %d\n\n', length(Lam));
    
    %% CRITICAL ISSUE 1: Data path discrepancy
    fprintf('=== ISSUE 1: DATA PATH ANALYSIS ===\n');
    
    % Check original data path
    original_path = '/home/dana/matlab/data_Transmission_Fitter/Templates/';
    optimized_default_path = '/home/dana/matlab/data/transmission_fitter/';
    
    fprintf('Original function data path: %s\n', original_path);
    fprintf('Optimized default path: %s\n', optimized_default_path);
    fprintf('Path exists (original): %s\n', string(exist(original_path, 'dir') == 7));
    fprintf('Path exists (optimized): %s\n\n', string(exist(optimized_default_path, 'dir') == 7));
    
    %% CRITICAL ISSUE 2: Loading method comparison  
    fprintf('=== ISSUE 2: DATA LOADING METHOD COMPARISON ===\n');
    
    % Test original loading method
    fprintf('Testing original readGasData method:\n');
    try
        test_species = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4'};
        original_data = struct();
        
        for i = 1:length(test_species)
            species = test_species{i};
            fprintf('  Loading %s... ', species);
            
            % Use original method (direct file reading)
            file_path = sprintf('/home/dana/matlab/data_Transmission_Fitter/Templates/Abs_%s.dat', species);
            if exist(file_path, 'file')
                data = readtable(file_path, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
                gas_wavelength = data.Var1;
                gas_absorption = data.Var2;
                abs_data = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
                original_data.(species) = abs_data;
                fprintf('✓ (%d points, range: [%.6f, %.6f])\n', length(abs_data), min(abs_data), max(abs_data));
            else
                fprintf('✗ File not found\n');
                original_data.(species) = zeros(size(Lam));
            end
        end
    catch ME
        fprintf('✗ Error: %s\n', ME.message);
    end
    
    % Test optimized loading method
    fprintf('\nTesting optimized data loading method:\n');
    try
        % Force the optimized function to load data using correct path
        UMG_species = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4'};
        optimized_data_struct = transmission.data.loadAbsorptionData('/home/dana/matlab/data_Transmission_Fitter/Templates', UMG_species, true);
        
        optimized_data = struct();
        for i = 1:length(test_species)
            species = test_species{i};
            fprintf('  Loading %s... ', species);
            
            if isfield(optimized_data_struct, species)
                gas_data = optimized_data_struct.(species);
                gas_wavelength = gas_data.wavelength;
                gas_absorption = gas_data.absorption;
                abs_data = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
                optimized_data.(species) = abs_data;
                fprintf('✓ (%d points, range: [%.6f, %.6f])\n', length(abs_data), min(abs_data), max(abs_data));
            else
                fprintf('✗ Not found in loaded data\n');
                optimized_data.(species) = zeros(size(Lam));
            end
        end
    catch ME
        fprintf('✗ Error: %s\n', ME.message);
    end
    
    %% CRITICAL ISSUE 3: Data value comparison
    fprintf('\n=== ISSUE 3: DETAILED DATA COMPARISON ===\n');
    
    if exist('original_data', 'var') && exist('optimized_data', 'var')
        for i = 1:length(test_species)
            species = test_species{i};
            if isfield(original_data, species) && isfield(optimized_data, species)
                orig_vals = original_data.(species);
                opt_vals = optimized_data.(species);
                
                % Compare data arrays
                max_diff = max(abs(orig_vals - opt_vals));
                rel_diff = max(abs((orig_vals - opt_vals) ./ (orig_vals + eps)));
                
                fprintf('%s: Max abs diff = %.2e, Max rel diff = %.2e%%\n', ...
                        species, max_diff, rel_diff * 100);
                
                if max_diff > 1e-10
                    fprintf('  ⚠️  SIGNIFICANT DIFFERENCE DETECTED!\n');
                end
            end
        end
    end
    
    %% CRITICAL ISSUE 4: Abundance and airmass calculations
    fprintf('\n=== ISSUE 4: ABUNDANCE AND AIRMASS CALCULATIONS ===\n');
    
    % Import required functions
    import transmission.utils.*
    
    % Convert temperature and pressure (common calculations)
    Tair_kelvin = Tair + 273.15;
    Pp0 = Pressure / 1013.25;
    Tt0 = Tair_kelvin / 273.15;
    NLOSCHMIDT = 2.6867811e19;
    
    fprintf('Common parameters:\n');
    fprintf('  Tair_kelvin = %.2f K\n', Tair_kelvin);
    fprintf('  Pp0 = %.6f\n', Pp0);
    fprintf('  Tt0 = %.6f\n', Tt0);
    fprintf('  NLOSCHMIDT = %.4e cm⁻³\n\n', NLOSCHMIDT);
    
    % Test airmass calculations
    gas_types = {'o2', 'ch4', 'co', 'n2o', 'co2', 'n2'};
    fprintf('Airmass calculations:\n');
    for i = 1:length(gas_types)
        gas_type = gas_types{i};
        try
            am_value = airmassFromSMARTS(Z_, gas_type);
            fprintf('  %s: %.6f\n', upper(gas_type), am_value);
        catch ME
            fprintf('  %s: ERROR - %s\n', upper(gas_type), ME.message);
        end
    end
    
    % Test abundance calculations
    fprintf('\nAbundance calculations:\n');
    O2_abundance = 1.67766e5 * Pp0;
    Ch4_abundance = 1.3255 * (Pp0 ^ 1.0574);
    Co_abundance = 0.29625 * (Pp0^2.4480) * exp(0.54669 - 2.4114 * Pp0 + 0.65756 * (Pp0^2));
    N2o_abundance = 0.24730 * (Pp0^1.0791);
    Co2_abundance = 0.802685 * Co2_ppm * Pp0;
    N2_abundance = 3.8269 * (Pp0^1.8374);
    O4_abundance = 1.8171e4 * (NLOSCHMIDT^2) * (Pp0^1.7984) / (Tt0^0.344);
    
    fprintf('  O2: %.6e\n', O2_abundance);
    fprintf('  CH4: %.6e\n', Ch4_abundance);
    fprintf('  CO: %.6e\n', Co_abundance);
    fprintf('  N2O: %.6e\n', N2o_abundance);
    fprintf('  CO2: %.6e\n', Co2_abundance);
    fprintf('  N2: %.6e\n', N2_abundance);
    fprintf('  O4: %.6e\n', O4_abundance);
    
    %% CRITICAL ISSUE 5: Full function comparison test
    fprintf('\n=== ISSUE 5: FULL FUNCTION COMPARISON ===\n');
    
    % Test original function
    fprintf('Running original umgTransmittance...\n');
    try
        tic;
        trans_original = transmission.atmospheric.umgTransmittance(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases);
        time_original = toc;
        fprintf('✓ Original completed in %.3f seconds\n', time_original);
        fprintf('  Range: [%.6f, %.6f]\n', min(trans_original), max(trans_original));
        fprintf('  Mean: %.6f, Std: %.6f\n', mean(trans_original), std(trans_original));
    catch ME
        fprintf('✗ Original failed: %s\n', ME.message);
        trans_original = [];
    end
    
    % Test optimized function with corrected data path
    fprintf('\nRunning optimized umgTransmittanceOptimized with corrected data path...\n');
    try
        tic;
        % Load data with correct path
        abs_data_corrected = transmission.data.loadAbsorptionData('/home/dana/matlab/data_Transmission_Fitter/Templates', {}, false);
        trans_optimized = transmission.atmospheric.umgTransmittanceOptimized(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases, 'AbsData', abs_data_corrected);
        time_optimized = toc;
        fprintf('✓ Optimized completed in %.3f seconds\n', time_optimized);
        fprintf('  Range: [%.6f, %.6f]\n', min(trans_optimized), max(trans_optimized));
        fprintf('  Mean: %.6f, Std: %.6f\n', mean(trans_optimized), std(trans_optimized));
    catch ME
        fprintf('✗ Optimized failed: %s\n', ME.message);
        trans_optimized = [];
    end
    
    % Compare results
    if ~isempty(trans_original) && ~isempty(trans_optimized)
        fprintf('\n=== FINAL COMPARISON ===\n');
        
        abs_diff = abs(trans_original - trans_optimized);
        rel_diff = abs_diff ./ (trans_original + eps);
        
        fprintf('Absolute differences:\n');
        fprintf('  Max: %.6e\n', max(abs_diff));
        fprintf('  Mean: %.6e\n', mean(abs_diff));
        fprintf('  Std: %.6e\n', std(abs_diff));
        
        fprintf('Relative differences (%):\n');
        fprintf('  Max: %.4f%%\n', max(rel_diff) * 100);
        fprintf('  Mean: %.4f%%\n', mean(rel_diff) * 100);
        fprintf('  Std: %.4f%%\n', std(rel_diff) * 100);
        
        % Find wavelengths with largest differences
        [~, max_idx] = max(abs_diff);
        fprintf('\nLargest difference at:\n');
        fprintf('  Wavelength: %.1f nm\n', Lam(max_idx));
        fprintf('  Original: %.6f\n', trans_original(max_idx));
        fprintf('  Optimized: %.6f\n', trans_optimized(max_idx));
        fprintf('  Difference: %.6e\n', abs_diff(max_idx));
        
        % Check if differences are now acceptable
        if max(abs_diff) < 1e-12
            fprintf('\n✅ SUCCESS: Functions now produce numerically identical results!\n');
        elseif max(abs_diff) < 1e-6
            fprintf('\n⚠️  IMPROVED: Differences significantly reduced but still present\n');
        else
            fprintf('\n❌ PROBLEM: Significant differences remain\n');
        end
    end
    
    %% ISSUE SUMMARY AND RECOMMENDATIONS
    fprintf('\n=== ISSUES IDENTIFIED AND FIXES NEEDED ===\n');
    fprintf('1. ❌ DATA PATH MISMATCH:\n');
    fprintf('   Original uses: /home/dana/matlab/data_Transmission_Fitter/Templates/\n');
    fprintf('   Optimized defaults to: /home/dana/matlab/data/transmission_fitter/\n');
    fprintf('   → FIX: Update optimized function default path OR pass correct path\n\n');
    
    fprintf('2. ❌ CONSTANT REFERENCE ERROR:\n');
    fprintf('   loadAbsorptionData*.m uses undefined "constant.Loschmidt"\n');
    fprintf('   → FIX: Replace with NLOSCHMIDT = 2.6867811e19 or define constant module\n\n');
    
    fprintf('3. ❌ SCALING FACTOR INCONSISTENCY:\n');
    fprintf('   Original applies O4 scaling (1e-46) INSIDE readGasData\n');
    fprintf('   Optimized may apply it elsewhere\n');
    fprintf('   → FIX: Ensure identical scaling factor application\n\n');
    
    fprintf('4. ❌ IMPORT/NAMESPACE ISSUES:\n');
    fprintf('   Different import statements may cause function resolution issues\n');
    fprintf('   → FIX: Align import statements between functions\n\n');
    
    fprintf('=== END DEBUG ANALYSIS ===\n');
end