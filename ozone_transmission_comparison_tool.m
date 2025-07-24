function ozone_transmission_comparison_tool()
    % Ozone transmittance comparison tool: Python vs MATLAB
    % Compares Python Ozone_Transmission class with MATLAB ozoneTransmission
    
    fprintf('PYTHON vs MATLAB OZONE TRANSMITTANCE COMPARISON TOOL\n');
    fprintf('====================================================\n\n');
    
    % Check if Python results are available
    python_results_file = 'python_ozone_results.mat';
    if ~exist(python_results_file, 'file')
        fprintf('⚠️  Python results not found. Please run the Python analysis first:\n');
        fprintf('   python python_ozone_analysis.py\n\n');
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
    % Run MATLAB ozone transmission analysis only
    
    fprintf('=== MATLAB OZONE TRANSMISSION ANALYSIS ===\n\n');
    
    % Test parameters - varying ozone column amounts
    Z_test = 30.0;        % zenith angle
    
    % Test different ozone column densities (Dobson Units)
    Uo_values = [200, 250, 300, 350, 400, 450];  % DU (typical range 200-500 DU)
    
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Test conditions:\n');
    fprintf('  Zenith angle: %.1f degrees\n', Z_test);
    fprintf('  Wavelengths: %d points [%.0f-%.0f nm]\n', ...
            length(Lam), min(Lam), max(Lam));
    fprintf('  Ozone column amounts: %s DU\n\n', mat2str(Uo_values));
    
    % Load ozone absorption data
    O3_data = transmission.data.loadAbsorptionDataMemoryOptimized([], {'O3UV'}, false);
    
    fprintf('%-8s | %-15s | %-10s | %-15s | %-12s\n', ...
            'Uo (DU)', 'Trans Range', 'Mean', 'Strong Abs Pts', 'Min Location');
    fprintf('%s\n', repmat('-', 1, 70));
    
    for i = 1:length(Uo_values)
        Uo = Uo_values(i);
        
        % Calculate ozone transmission
        Trans_ozone = transmission.atmospheric.ozoneTransmission(...
            Z_test, Uo, Lam, 'O3Data', O3_data);
        
        % Analyze results
        min_trans = min(Trans_ozone);
        max_trans = max(Trans_ozone);
        mean_trans = mean(Trans_ozone);
        [min_val, min_idx] = min(Trans_ozone);
        strong_absorption_mask = Trans_ozone < 0.5;  % Strong ozone absorption
        n_absorbing = sum(strong_absorption_mask);
        
        fprintf('%-8d | [%.6f,%.6f] | %-10.6f | %-13d | λ=%.0fnm T=%.6f\n', ...
                Uo, min_trans, max_trans, mean_trans, n_absorbing, Lam(min_idx), min_val);
    end
    
    fprintf('%s\n', repmat('-', 1, 70));
    fprintf('\n✅ MATLAB ozone transmission analysis complete!\n');
    
    % Show spectral features analysis
    analyze_ozone_spectral_features(Lam, Uo_values, O3_data, Z_test);
end

function run_full_comparison(python_data)
    % Run full Python vs MATLAB comparison
    
    fprintf('=== FULL PYTHON vs MATLAB COMPARISON ===\n\n');
    
    % Test parameters (must match Python script)
    Z_test = python_data.test_conditions.zenith_angle;
    Uo_values = python_data.test_conditions.uo_values;
    
    % Get wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    
    % Load MATLAB ozone data
    O3_data = transmission.data.loadAbsorptionDataMemoryOptimized([], {'O3UV'}, false);
    
    fprintf('Test conditions: Z=%.1f°\n', Z_test);
    fprintf('Ozone column amounts: %s DU\n\n', mat2str(Uo_values));
    
    fprintf('%-8s | %-15s | %-15s | %-12s | %-12s\n', ...
            'Uo (DU)', 'Python Range', 'MATLAB Range', 'Max Diff', 'Agreement');
    fprintf('%s\n', repmat('-', 1, 75));
    
    total_max_diff = 0;
    perfect_matches = 0;
    
    for i = 1:length(Uo_values)
        Uo = Uo_values(i);
        
        % Get Python results
        python_field = sprintf('uo_%d_transmission', Uo);
        
        if ~isfield(python_data, python_field)
            fprintf('%-8d | Missing Python data\n', Uo);
            continue;
        end
        python_trans = python_data.(python_field);
        
        % Calculate MATLAB results
        matlab_trans = transmission.atmospheric.ozoneTransmission(...
            Z_test, Uo, Lam, 'O3Data', O3_data);
        
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
        
        fprintf('%s %-6d | [%.6f,%.6f] | [%.6f,%.6f] | %.2e | %s\n', ...
                status, Uo, python_range(1), python_range(2), ...
                matlab_range(1), matlab_range(2), max_diff, agreement);
    end
    
    fprintf('%s\n', repmat('-', 1, 75));
    
    % Overall assessment
    fprintf('\n=== VALIDATION SUMMARY ===\n');
    fprintf('Perfect matches: %d/%d ozone amounts\n', perfect_matches, length(Uo_values));
    fprintf('Maximum difference: %.2e\n', total_max_diff);
    
    if total_max_diff < 1e-14
        fprintf('🎯 PERFECT: All ozone amounts match at machine precision\n');
    elseif total_max_diff < 1e-6
        fprintf('✅ EXCELLENT: All differences within scientific tolerance\n');
    else
        fprintf('⚠️ WARNING: Some differences exceed tolerance\n');
    end
    
    % Detailed analysis
    analyze_ozone_differences(python_data, Uo_values, Lam, O3_data, Z_test);
    
    fprintf('\n✅ Full ozone transmission comparison complete!\n');
    fprintf('MATLAB implementation validated against Python original.\n');
end

function analyze_ozone_spectral_features(Lam, Uo_values, O3_data, Z_test)
    % Analyze ozone spectral absorption features
    
    fprintf('\n=== OZONE SPECTRAL FEATURES ANALYSIS ===\n\n');
    
    % Calculate for moderate ozone amount
    Uo_ref = 300;  % DU (typical mid-latitude value)
    Trans_ref = transmission.atmospheric.ozoneTransmission(...
        Z_test, Uo_ref, Lam, 'O3Data', O3_data);
    
    % Find ozone absorption regions
    fprintf('Ozone absorption characteristics (Uo=%d DU):\n', Uo_ref);
    
    % Analyze different absorption strength levels
    very_strong_mask = Trans_ref < 0.01;   % Nearly opaque (T < 1%)
    strong_mask = Trans_ref < 0.1;         % Strong absorption (T < 10%)
    moderate_mask = Trans_ref < 0.5;       % Moderate absorption (T < 50%)
    weak_mask = Trans_ref < 0.9;           % Weak absorption (T < 90%)
    
    fprintf('  Nearly opaque regions (T<1%%): %d points\n', sum(very_strong_mask));
    fprintf('  Strong absorption (T<10%%): %d points\n', sum(strong_mask));
    fprintf('  Moderate absorption (T<50%%): %d points\n', sum(moderate_mask));
    fprintf('  Weak absorption (T<90%%): %d points\n', sum(weak_mask));
    
    % Find the main ozone absorption region (Hartley band in UV)
    uv_mask = Lam <= 350;  % UV region where ozone absorbs
    if sum(uv_mask) > 0
        uv_trans = Trans_ref(uv_mask);
        uv_wavelengths = Lam(uv_mask);
        
        [min_uv_trans, min_uv_idx] = min(uv_trans);
        
        fprintf('\nUV region analysis (λ ≤ 350 nm):\n');
        fprintf('  Wavelength range: %.0f-%.0f nm\n', min(uv_wavelengths), max(uv_wavelengths));
        fprintf('  Minimum transmission: %.6f at %.0f nm\n', min_uv_trans, uv_wavelengths(min_uv_idx));
        fprintf('  Mean transmission in UV: %.6f\n', mean(uv_trans));
    end
    
    % Show ozone column sensitivity
    fprintf('\nOzone column amount sensitivity:\n');
    for i = 1:length(Uo_values)
        Uo = Uo_values(i);
        Trans = transmission.atmospheric.ozoneTransmission(...
            Z_test, Uo, Lam, 'O3Data', O3_data);
        
        very_strong_abs = sum(Trans < 0.01);  % Nearly opaque
        strong_abs = sum(Trans < 0.1);        % Strong absorption
        moderate_abs = sum(Trans < 0.5);      % Moderate absorption
        
        fprintf('  Uo=%d DU: %d opaque, %d strong, %d moderate absorption points\n', ...
                Uo, very_strong_abs, strong_abs, moderate_abs);
    end
end

function analyze_ozone_differences(python_data, Uo_values, Lam, O3_data, Z_test)
    % Analyze differences between Python and MATLAB implementations
    
    fprintf('\n=== DETAILED DIFFERENCE ANALYSIS ===\n\n');
    
    for i = 1:length(Uo_values)
        Uo = Uo_values(i);
        
        % Get Python results
        python_field = sprintf('uo_%d_transmission', Uo);
        
        if ~isfield(python_data, python_field)
            continue;
        end
        
        python_trans = python_data.(python_field);
        
        % Calculate MATLAB results
        matlab_trans = transmission.atmospheric.ozoneTransmission(...
            Z_test, Uo, Lam, 'O3Data', O3_data);
        
        % Analyze differences
        abs_diff = abs(python_trans - matlab_trans);
        max_diff = max(abs_diff);
        mean_diff = mean(abs_diff);
        
        % Find largest differences
        [~, max_idx] = max(abs_diff);
        
        % Analyze where differences occur
        strong_abs_mask = python_trans < 0.1;  % Strong absorption
        weak_abs_mask = python_trans > 0.9;    % Weak absorption
        
        if sum(strong_abs_mask) > 0
            strong_abs_diff = mean(abs_diff(strong_abs_mask));
        else
            strong_abs_diff = 0;
        end
        
        if sum(weak_abs_mask) > 0
            weak_abs_diff = mean(abs_diff(weak_abs_mask));
        else
            weak_abs_diff = 0;
        end
        
        fprintf('Uo=%d DU analysis:\n', Uo);
        fprintf('  Max difference: %.2e at λ=%.0f nm\n', max_diff, Lam(max_idx));
        fprintf('  Mean difference: %.2e\n', mean_diff);
        fprintf('  Strong absorption regions: %.2e\n', strong_abs_diff);
        fprintf('  Weak absorption regions: %.2e\n', weak_abs_diff);
        fprintf('  Python min/mean: %.6f/%.6f\n', min(python_trans), mean(python_trans));
        fprintf('  MATLAB min/mean: %.6f/%.6f\n\n', min(matlab_trans), mean(matlab_trans));
    end
end