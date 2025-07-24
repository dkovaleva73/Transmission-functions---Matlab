function debug_gas_by_gas()
    % Comprehensive gas-by-gas debugging to find the exact source of difference
    
    fprintf('=== GAS-BY-GAS ANALYSIS ===\n\n');
    
    % Test parameters
    Z_ = 30;
    Tair = 15;
    Pressure = 1013.25;
    Co2_ppm = 415;
    With_trace_gases = true;
    
    % Create wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Parameters: Z=%.1f°, T=%.1f°C, P=%.1f hPa, CO2=%.1f ppm, trace_gases=%s\n', ...
            Z_, Tair, Pressure, Co2_ppm, string(With_trace_gases));
    fprintf('Wavelength points: %d\n\n', length(Lam));
    
    % Constants (same in both functions)
    NLOSCHMIDT = 2.6867811e19;
    Tair_kelvin = Tair + 273.15;
    Pp0 = Pressure / 1013.25;
    Tt0 = Tair_kelvin / 273.15;
    
    % Import utils
    import transmission.utils.*
    
    % Pre-compute all airmass values
    Am_o2 = airmassFromSMARTS(Z_, 'o2');
    Am_ch4 = airmassFromSMARTS(Z_, 'ch4');
    Am_co = airmassFromSMARTS(Z_, 'co');
    Am_n2o = airmassFromSMARTS(Z_, 'n2o');
    Am_co2 = airmassFromSMARTS(Z_, 'co2');
    Am_n2 = airmassFromSMARTS(Z_, 'n2');
    Am_o4 = Am_o2;  % O4 uses O2 airmass
    Am_nh3 = airmassFromSMARTS(Z_, 'nh3');
    
    % Pre-compute all abundance factors
    Abundance_o2 = 1.67766e5 * Pp0;
    Abundance_ch4 = 1.3255 * (Pp0 ^ 1.0574);
    Abundance_co = 0.29625 * (Pp0^2.4480) * exp(0.54669 - 2.4114 * Pp0 + 0.65756 * (Pp0^2));
    Abundance_n2o = 0.24730 * (Pp0^1.0791);
    Abundance_co2 = 0.802685 * Co2_ppm * Pp0;
    Abundance_n2 = 3.8269 * (Pp0^1.8374);
    Abundance_o4 = 1.8171e4 * (NLOSCHMIDT^2) * (Pp0^1.7984) / (Tt0^0.344);
    
    fprintf('Abundances and airmasses:\n');
    fprintf('  O2:  abundance=%.3e, airmass=%.6f\n', Abundance_o2, Am_o2);
    fprintf('  CH4: abundance=%.3e, airmass=%.6f\n', Abundance_ch4, Am_ch4);
    fprintf('  CO:  abundance=%.3e, airmass=%.6f\n', Abundance_co, Am_co);
    fprintf('  N2O: abundance=%.3e, airmass=%.6f\n', Abundance_n2o, Am_n2o);
    fprintf('  CO2: abundance=%.3e, airmass=%.6f\n', Abundance_co2, Am_co2);
    fprintf('  N2:  abundance=%.3e, airmass=%.6f\n', Abundance_n2, Am_n2);
    fprintf('  O4:  abundance=%.3e, airmass=%.6f\n', Abundance_o4, Am_o4);
    fprintf('  NH3: airmass=%.6f\n', Am_nh3);
    fprintf('\n');
    
    % Test gas-by-gas contributions
    gases = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4'};
    abundances = [Abundance_o2, Abundance_ch4, Abundance_co, Abundance_n2o, Abundance_co2, Abundance_n2, Abundance_o4];
    airmasses = [Am_o2, Am_ch4, Am_co, Am_n2o, Am_co2, Am_n2, Am_o4];
    
    % Load data for both methods
    fprintf('Loading absorption data:\n');
    
    % Method 1: Original-style loading (what original function does)
    fprintf('  Original method...\n');
    original_data = struct();
    for i = 1:length(gases)
        gas = gases{i};
        file_path = sprintf('/home/dana/matlab/data_Transmission_Fitter/Templates/Abs_%s.dat', gas);
        if exist(file_path, 'file')
            data = readtable(file_path, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
            gas_wavelength = data.Var1;
            gas_absorption = data.Var2;
            abs_data = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
            original_data.(gas) = abs_data;
        else
            original_data.(gas) = zeros(size(Lam));
        end
    end
    
    % Method 2: Optimized loading (what optimized function uses)
    fprintf('  Optimized method...\n');
    abs_data_struct = transmission.data.loadAbsorptionData('/home/dana/matlab/data_Transmission_Fitter/Templates', gases, false);
    optimized_data = struct();
    for i = 1:length(gases)
        gas = gases{i};
        if isfield(abs_data_struct, gas)
            gas_data = abs_data_struct.(gas);
            gas_wavelength = gas_data.wavelength;
            gas_absorption = gas_data.absorption;
            abs_data = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
            optimized_data.(gas) = abs_data;
        else
            optimized_data.(gas) = zeros(size(Lam));
        end
    end
    
    % Compare gas-by-gas
    fprintf('\nGas-by-gas absorption data comparison:\n');
    for i = 1:length(gases)
        gas = gases{i};
        orig_abs = original_data.(gas);
        opt_abs = optimized_data.(gas);
        
        max_diff = max(abs(orig_abs - opt_abs));
        fprintf('  %s: max difference = %.6e', gas, max_diff);
        
        if max_diff > 1e-12
            fprintf(' ⚠️  DIFFERENT!');
        else
            fprintf(' ✓');
        end
        fprintf('\n');
    end
    
    % Calculate optical depth contributions
    fprintf('\nOptical depth contributions:\n');
    Tau_original = zeros(size(Lam));
    Tau_optimized = zeros(size(Lam));
    
    for i = 1:length(gases)
        gas = gases{i};
        abundance = abundances(i);
        airmass = airmasses(i);
        
        % Apply O4 scaling if needed
        if strcmp(gas, 'O4')
            orig_contribution = original_data.(gas) * 1e-46 * abundance * airmass;
            opt_contribution = optimized_data.(gas) * 1e-46 * abundance * airmass;
        else
            orig_contribution = original_data.(gas) * abundance * airmass;
            opt_contribution = optimized_data.(gas) * abundance * airmass;
        end
        
        Tau_original = Tau_original + orig_contribution;
        Tau_optimized = Tau_optimized + opt_contribution;
        
        contrib_diff = max(abs(orig_contribution - opt_contribution));
        fprintf('  %s: max tau difference = %.6e', gas, contrib_diff);
        
        if contrib_diff > 1e-12
            fprintf(' ⚠️  DIFFERENT!');
        else
            fprintf(' ✓');
        end
        fprintf('\n');
    end
    
    % Check trace gases separately
    if With_trace_gases
        fprintf('\nTrace gases analysis:\n');
        
        % NH3 calculation
        try
            fprintf('  Loading NH3...\n');
            
            % Original method
            file_path = '/home/dana/matlab/data_Transmission_Fitter/Templates/Abs_NH3.dat';
            if exist(file_path, 'file')
                data = readtable(file_path, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
                gas_wavelength = data.Var1;
                gas_absorption = data.Var2;
                nh3_orig = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
            else
                nh3_orig = zeros(size(Lam));
            end
            
            % Optimized method
            if isfield(abs_data_struct, 'NH3')
                nh3_data = abs_data_struct.NH3;
                gas_wavelength = nh3_data.wavelength;
                gas_absorption = nh3_data.absorption;
                nh3_opt = interp1(gas_wavelength, gas_absorption, Lam, 'linear', 0);
            else
                nh3_opt = zeros(size(Lam));
            end
            
            % NH3 abundance calculation
            Log_pp0 = log(Pp0);
            Nh3_abundance = exp(-8.6499 + 2.1947 * Log_pp0 - 2.5936 * (Log_pp0^2) - ...
                               1.819 * (Log_pp0^3) - 0.65854 * (Log_pp0^4));
            
            nh3_contrib_orig = nh3_orig * Nh3_abundance * Am_nh3;
            nh3_contrib_opt = nh3_opt * Nh3_abundance * Am_nh3;
            
            Tau_original = Tau_original + nh3_contrib_orig;
            Tau_optimized = Tau_optimized + nh3_contrib_opt;
            
            nh3_diff = max(abs(nh3_contrib_orig - nh3_contrib_opt));
            fprintf('    NH3 tau difference: %.6e', nh3_diff);
            
            if nh3_diff > 1e-12
                fprintf(' ⚠️  DIFFERENT!');
            else
                fprintf(' ✓');
            end
            fprintf('\n');
            
        catch ME
            fprintf('    NH3 calculation failed: %s\n', ME.message);
        end
    end
    
    % Final comparison
    fprintf('\nFinal optical depth comparison:\n');
    total_tau_diff = max(abs(Tau_original - Tau_optimized));
    fprintf('  Max total tau difference: %.6e\n', total_tau_diff);
    
    % Convert to transmission
    Trans_original = exp(-Tau_original);
    Trans_optimized = exp(-Tau_optimized);
    Trans_original = max(0, min(1, Trans_original));
    Trans_optimized = max(0, min(1, Trans_optimized));
    
    trans_diff = max(abs(Trans_original - Trans_optimized));
    fprintf('  Max transmission difference: %.6f\n', trans_diff);
    
    fprintf('\nOriginal transmission range: [%.6f, %.6f]\n', min(Trans_original), max(Trans_original));
    fprintf('Optimized transmission range: [%.6f, %.6f]\n', min(Trans_optimized), max(Trans_optimized));
    
    if trans_diff > 0.5
        fprintf('\n💥 FOUND THE PROBLEM: %.6f transmission difference!\n', trans_diff);
        
        % Find where the largest difference occurs
        [~, max_idx] = max(abs(Trans_original - Trans_optimized));
        fprintf('  At wavelength %.1f nm:\n', Lam(max_idx));
        fprintf('    Original tau: %.6f\n', Tau_original(max_idx));
        fprintf('    Optimized tau: %.6f\n', Tau_optimized(max_idx));
        fprintf('    Tau difference: %.6f\n', abs(Tau_original(max_idx) - Tau_optimized(max_idx)));
        fprintf('    Original transmission: %.6f\n', Trans_original(max_idx));
        fprintf('    Optimized transmission: %.6f\n', Trans_optimized(max_idx));
    else
        fprintf('\n✅ Gas-by-gas analysis shows functions should be identical\n');
    end
    
    fprintf('\n=== ANALYSIS COMPLETE ===\n');
end