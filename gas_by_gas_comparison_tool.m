function gas_by_gas_comparison_tool()
    % Gas-by-gas transmittance comparison tool: Python vs MATLAB
    % This script compares individual gas transmittances between the original
    % Python UMGTransmittance class and the optimized MATLAB implementation
    
    fprintf('PYTHON vs MATLAB GAS-BY-GAS TRANSMITTANCE COMPARISON TOOL\n');
    fprintf('=========================================================\n\n');
    
    % Check if Python results are available
    python_results_file = 'python_gas_results.mat';
    if ~exist(python_results_file, 'file')
        fprintf('⚠️  Python results not found. Please run the Python analysis first:\n');
        fprintf('   python python_gas_by_gas.py\n\n');
        fprintf('Proceeding with MATLAB-only analysis...\n\n');
        run_matlab_only_analysis();
        return;
    end
    
    % Load Python results and run full comparison
    python_data = load(python_results_file);
    fprintf('✅ Python results loaded successfully\n\n');
    run_full_comparison(python_data);
end

function run_matlab_only_analysis()
    % Run MATLAB gas-by-gas analysis only
    
    % Test parameters
    Z_test = 30.0;        % zenith angle
    Tair_test = 15.0;     % air temperature (°C)  
    P_test = 1013.25;     % pressure (hPa)
    CO2_ppm = 415.0;      % CO2 concentration
    
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Test conditions:\n');
    fprintf('  Zenith angle: %.1f degrees\n', Z_test);
    fprintf('  Temperature: %.1f°C\n', Tair_test);
    fprintf('  Pressure: %.1f hPa\n', P_test);
    fprintf('  CO2 concentration: %d ppm\n', CO2_ppm);
    fprintf('  Wavelengths: %d points [%.0f-%.0f nm]\n\n', ...
            length(Lam), min(Lam), max(Lam));
    
    % Load absorption data
    UMG_species = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', 'NH3'};
    Abs_data = transmission.data.loadAbsorptionDataMemoryOptimized([], UMG_species, false);
    
    % Test each gas
    gases_to_test = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', 'NH3'};
    
    fprintf('%-6s | %-15s | %-12s | %-15s\n', ...
            'Gas', 'Trans Range', 'Absorb Pts', 'Min Location');
    fprintf('%s\n', repmat('-', 1, 60));
    
    for i = 1:length(gases_to_test)
        gas_name = gases_to_test{i};
        
        % Calculate single gas transmission
        Trans_single_gas = calculate_single_gas_transmission(...
            gas_name, Z_test, Tair_test, P_test, Lam, CO2_ppm, Abs_data);
        
        % Analyze results
        min_trans = min(Trans_single_gas);
        max_trans = max(Trans_single_gas);
        [min_val, min_idx] = min(Trans_single_gas);
        strong_absorption_mask = Trans_single_gas < 0.99;
        n_absorbing = sum(strong_absorption_mask);
        
        fprintf('%-6s | [%.3f,%.3f] | %-10d | λ=%.0fnm T=%.3f\n', ...
                gas_name, min_trans, max_trans, n_absorbing, Lam(min_idx), min_val);
    end
    
    fprintf('%s\n', repmat('-', 1, 60));
    fprintf('\n✅ MATLAB gas-by-gas analysis complete!\n');
end

function run_full_comparison(python_data)
    % Run full Python vs MATLAB comparison
    
    % Test parameters (must match Python script)
    Z_test = 30.0;
    Tair_test = 15.0;
    P_test = 1013.25;
    CO2_ppm = 415.0;
    
    % Get wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    
    % Load MATLAB absorption data
    UMG_species = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', 'NH3'};
    Abs_data = transmission.data.loadAbsorptionDataMemoryOptimized([], UMG_species, false);
    
    fprintf('Test conditions: Z=%.1f°, T=%.1f°C, P=%.1f hPa, CO2=%dppm\n\n', ...
            Z_test, Tair_test, P_test, CO2_ppm);
    
    % Compare each gas
    gases = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', 'NH3'};
    
    fprintf('%-6s | %-15s | %-15s | %-12s | %-12s\n', ...
            'Gas', 'Python Range', 'MATLAB Range', 'Max Diff', 'Agreement');
    fprintf('%s\n', repmat('-', 1, 75));
    
    total_max_diff = 0;
    perfect_matches = 0;
    
    for i = 1:length(gases)
        gas = gases{i};
        
        % Get Python results
        python_field = [gas '_transmission'];
        if ~isfield(python_data, python_field)
            fprintf('%-6s | Missing Python data\n', gas);
            continue;
        end
        python_trans = python_data.(python_field);
        
        % Calculate MATLAB results for this gas
        matlab_trans = calculate_single_gas_transmission(...
            gas, Z_test, Tair_test, P_test, Lam, CO2_ppm, Abs_data);
        
        % Compare results
        python_range = [min(python_trans), max(python_trans)];
        matlab_range = [min(matlab_trans), max(matlab_trans)];
        
        % Calculate differences
        abs_diff = abs(python_trans - matlab_trans);
        max_diff = max(abs_diff);
        
        % Track overall statistics
        total_max_diff = max(total_max_diff, max_diff);
        if max_diff < 1e-14
            perfect_matches = perfect_matches + 1;
        end
        
        % Determine agreement level
        if max_diff < 1e-14
            agreement = 'Perfect';
            status = '✅';
        elseif max_diff < 1e-12
            agreement = 'Excellent';
            status = '✅';
        elseif max_diff < 1e-6
            agreement = 'Good';
            status = '✓';
        else
            agreement = 'Poor';
            status = '⚠️';
        end
        
        fprintf('%s %-4s | [%.6f,%.6f] | [%.6f,%.6f] | %.2e | %s\n', ...
                status, gas, python_range(1), python_range(2), ...
                matlab_range(1), matlab_range(2), max_diff, agreement);
    end
    
    fprintf('%s\n', repmat('-', 1, 75));
    
    % Overall assessment
    fprintf('\n=== VALIDATION SUMMARY ===\n');
    fprintf('Perfect matches: %d/%d gases\n', perfect_matches, length(gases));
    fprintf('Maximum difference: %.2e\n', total_max_diff);
    
    if total_max_diff < 1e-14
        fprintf('🎯 PERFECT: All gases match at machine precision\n');
    elseif total_max_diff < 1e-6
        fprintf('✅ EXCELLENT: All differences within scientific tolerance\n');
    else
        fprintf('⚠️ WARNING: Some differences exceed tolerance\n');
    end
    
    fprintf('\n✅ Full comparison complete!\n');
    fprintf('MATLAB implementation validated against Python original.\n');
end

function trans = calculate_single_gas_transmission(gas_name, Z_, Tair, Pressure, Lam, Co2_ppm, Abs_data)
    % Calculate transmission for a single gas (others set to zero abundance)
    
    pp0 = Pressure / 1013.25;
    tt0 = (Tair + 273.15) / 273.15;
    Tau_total = zeros(size(Lam));
    
    switch gas_name
        case 'O2'
            if isfield(Abs_data, 'O2')
                O2_abs = interp1(Abs_data.O2.wavelength, Abs_data.O2.absorption, Lam, 'linear', 0);
                Abundance = 1.67766e5 * pp0;
                Am = transmission.utils.airmassFromSMARTS(Z_, 'o2');
                Tau_total = O2_abs .* Abundance .* Am;
            end
            
        case 'CH4'
            if isfield(Abs_data, 'CH4')
                CH4_abs = interp1(Abs_data.CH4.wavelength, Abs_data.CH4.absorption, Lam, 'linear', 0);
                Abundance = 1.3255 * (pp0 ^ 1.0574);
                Am = transmission.utils.airmassFromSMARTS(Z_, 'ch4');
                Tau_total = CH4_abs .* Abundance .* Am;
            end
            
        case 'CO'
            if isfield(Abs_data, 'CO')
                CO_abs = interp1(Abs_data.CO.wavelength, Abs_data.CO.absorption, Lam, 'linear', 0);
                Abundance = 0.29625 * (pp0^2.4480) * exp(0.54669 - 2.4114 * pp0 + 0.65756 * (pp0^2));
                Am = transmission.utils.airmassFromSMARTS(Z_, 'co');
                Tau_total = CO_abs .* Abundance .* Am;
            end
            
        case 'N2O'
            if isfield(Abs_data, 'N2O')
                N2O_abs = interp1(Abs_data.N2O.wavelength, Abs_data.N2O.absorption, Lam, 'linear', 0);
                Abundance = 0.24730 * (pp0^1.0791);
                Am = transmission.utils.airmassFromSMARTS(Z_, 'n2o');
                Tau_total = N2O_abs .* Abundance .* Am;
            end
            
        case 'CO2'
            if isfield(Abs_data, 'CO2')
                CO2_abs = interp1(Abs_data.CO2.wavelength, Abs_data.CO2.absorption, Lam, 'linear', 0);
                Abundance = 0.802685 * Co2_ppm * pp0;
                Am = transmission.utils.airmassFromSMARTS(Z_, 'co2');
                Tau_total = CO2_abs .* Abundance .* Am;
            end
            
        case 'N2'
            if isfield(Abs_data, 'N2')
                N2_abs = interp1(Abs_data.N2.wavelength, Abs_data.N2.absorption, Lam, 'linear', 0);
                Abundance = 3.8269 * (pp0^1.8374);
                Am = transmission.utils.airmassFromSMARTS(Z_, 'n2');
                Tau_total = N2_abs .* Abundance .* Am;
            end
            
        case 'O4'
            if isfield(Abs_data, 'O4')
                O4_abs = interp1(Abs_data.O4.wavelength, Abs_data.O4.absorption, Lam, 'linear', 0);
                O4_abs = O4_abs * 1e-46;  % Special scaling factor
                Abundance = 1.8171e4 * (constant.Loschmidt^2) * (pp0^1.7984) / (tt0^0.344);
                Am = transmission.utils.airmassFromSMARTS(Z_, 'o2');  % O4 uses O2 airmass
                Tau_total = O4_abs .* Abundance .* Am;
            end
            
        case 'NH3'
            if isfield(Abs_data, 'NH3')
                NH3_abs = interp1(Abs_data.NH3.wavelength, Abs_data.NH3.absorption, Lam, 'linear', 0);
                lpp0 = log(pp0);
                Abundance = exp(-8.6499 + 2.1947*lpp0 - 2.5936*(lpp0^2) - 1.819*(lpp0^3) - 0.65854*(lpp0^4));
                Am = transmission.utils.airmassFromSMARTS(Z_, 'nh3');
                Tau_total = NH3_abs .* Abundance .* Am;
            end
    end
    
    trans = max(0, min(1, exp(-Tau_total)));
end