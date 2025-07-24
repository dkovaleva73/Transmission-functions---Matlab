function debug_o4_issue()
    % Focused diagnostic test to isolate the O4 scaling issue
    
    fprintf('=== O4 SCALING DIAGNOSTIC ===\n\n');
    
    % Test parameters
    Z_ = 30;
    Tair = 15;
    Pressure = 1013.25;
    
    % Create wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Testing O4 scaling with %d wavelength points\n\n', length(Lam));
    
    % Test 1: Original readGasData function
    fprintf('1. Testing original readGasData function:\n');
    try
        % This simulates what the original umgTransmittance does
        file_path = sprintf('/home/dana/matlab/data_Transmission_Fitter/Templates/Abs_%s.dat', 'O4');
        if exist(file_path, 'file')
            data = readtable(file_path, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
            gas_wavelength = data.Var1;
            gas_absorption = data.Var2;
            o4_original = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
            
            fprintf('  Raw O4 data range: [%.6f, %.6f]\n', min(o4_original), max(o4_original));
            
            % Apply the scaling that original function does
            o4_scaled_original = o4_original * 1e-46;
            fprintf('  After 1e-46 scaling: [%.6e, %.6e]\n', min(o4_scaled_original), max(o4_scaled_original));
        else
            fprintf('  ✗ O4 file not found\n');
        end
    catch ME
        fprintf('  ✗ Error: %s\n', ME.message);
    end
    
    % Test 2: Optimized data loading
    fprintf('\n2. Testing optimized data loading:\n');
    try
        % Load using the optimized data loader
        abs_data = transmission.data.loadAbsorptionData('/home/dana/matlab/data_Transmission_Fitter/Templates', {'O4'}, false);
        
        if isfield(abs_data, 'O4')
            o4_data = abs_data.O4;
            gas_wavelength = o4_data.wavelength;
            gas_absorption = o4_data.absorption;
            o4_optimized = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
            
            fprintf('  Optimized O4 data range: [%.6f, %.6f]\n', min(o4_optimized), max(o4_optimized));
            
            % Apply the scaling that optimized function does
            o4_scaled_optimized = o4_optimized * 1e-46;
            fprintf('  After 1e-46 scaling: [%.6e, %.6e]\n', min(o4_scaled_optimized), max(o4_scaled_optimized));
        else
            fprintf('  ✗ O4 not found in loaded data\n');
        end
    catch ME
        fprintf('  ✗ Error: %s\n', ME.message);
    end
    
    % Test 3: Direct comparison
    if exist('o4_original', 'var') && exist('o4_optimized', 'var')
        fprintf('\n3. Direct O4 data comparison:\n');
        
        raw_diff = abs(o4_original - o4_optimized);
        fprintf('  Raw data max difference: %.6e\n', max(raw_diff));
        
        if max(raw_diff) > 1e-10
            fprintf('  ⚠️  SIGNIFICANT RAW DATA DIFFERENCE!\n');
            
            % Find where the largest differences occur
            [~, max_idx] = max(raw_diff);
            fprintf('  Largest difference at wavelength %.1f nm:\n', Lam(max_idx));
            fprintf('    Original: %.6f\n', o4_original(max_idx));
            fprintf('    Optimized: %.6f\n', o4_optimized(max_idx));
            fprintf('    Difference: %.6e\n', raw_diff(max_idx));
        else
            fprintf('  ✓ Raw O4 data identical\n');
        end
        
        scaled_diff = abs(o4_scaled_original - o4_scaled_optimized);
        fprintf('  Scaled data max difference: %.6e\n', max(scaled_diff));
        
        if max(scaled_diff) > 1e-60
            fprintf('  ⚠️  SIGNIFICANT SCALED DATA DIFFERENCE!\n');
        else
            fprintf('  ✓ Scaled O4 data identical\n');
        end
    end
    
    % Test 4: Check abundance and airmass calculations
    fprintf('\n4. Testing O4 abundance and airmass:\n');
    
    % Constants and calculations (same as in both functions)
    NLOSCHMIDT = 2.6867811e19;
    Tair_kelvin = Tair + 273.15;
    Pp0 = Pressure / 1013.25;
    Tt0 = Tair_kelvin / 273.15;
    
    % O4 abundance calculation
    O4_abundance = 1.8171e4 * (NLOSCHMIDT^2) * (Pp0^1.7984) / (Tt0^0.344);
    fprintf('  O4 abundance: %.6e\n', O4_abundance);
    
    % O4 airmass (uses O2 airmass)
    import transmission.utils.*
    Am_o4 = airmassFromSMARTS(Z_, 'o2');
    fprintf('  O4 airmass (from O2): %.6f\n', Am_o4);
    
    % Test 5: Full O4 contribution comparison
    if exist('o4_scaled_original', 'var') && exist('o4_scaled_optimized', 'var')
        fprintf('\n5. Full O4 contribution to optical depth:\n');
        
        tau_o4_original = o4_scaled_original .* O4_abundance .* Am_o4;
        tau_o4_optimized = o4_scaled_optimized .* O4_abundance .* Am_o4;
        
        fprintf('  Original O4 tau range: [%.6e, %.6e]\n', min(tau_o4_original), max(tau_o4_original));
        fprintf('  Optimized O4 tau range: [%.6e, %.6e]\n', min(tau_o4_optimized), max(tau_o4_optimized));
        
        tau_diff = abs(tau_o4_original - tau_o4_optimized);
        fprintf('  Max tau difference: %.6e\n', max(tau_diff));
        
        if max(tau_diff) > 1e-50
            fprintf('  ⚠️  SIGNIFICANT O4 TAU DIFFERENCE!\n');
            
            % This difference will propagate to transmission as exp(-tau_diff)
            trans_diff_approx = max(tau_diff);  % For small tau, exp(-tau) ≈ 1-tau
            fprintf('  Approximate transmission difference: %.6f\n', trans_diff_approx);
            
            if trans_diff_approx > 0.5
                fprintf('  💥 THIS EXPLAINS THE ~0.68 DIFFERENCE!\n');
            end
        else
            fprintf('  ✓ O4 tau contributions identical\n');
        end
    end
    
    fprintf('\n=== DIAGNOSTIC COMPLETE ===\n');
end