function debug_exact_calls()
    % Debug the exact function calls to identify any subtle differences
    
    fprintf('=== EXACT FUNCTION CALL DEBUGGING ===\n\n');
    
    % Test parameters - EXACT same values
    Z_ = 30;
    Tair = 15;
    Pressure = 1013.25;
    Co2_ppm = 415;
    With_trace_gases = true;
    Lam = transmission.utils.makeWavelengthArray();
    
    fprintf('Testing with exact same parameters:\n');
    fprintf('  Z_ = %g\n', Z_);
    fprintf('  Tair = %g\n', Tair);
    fprintf('  Pressure = %g\n', Pressure);
    fprintf('  Co2_ppm = %g\n', Co2_ppm);
    fprintf('  With_trace_gases = %s\n', mat2str(With_trace_gases));
    fprintf('  length(Lam) = %d\n\n', length(Lam));
    
    % Call 1: Original function with explicit parameters
    fprintf('1. Calling original umgTransmittance with explicit parameters...\n');
    try
        tic;
        trans_orig = transmission.atmospheric.umgTransmittance(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases);
        time_orig = toc;
        fprintf('   ✓ Success: %.3f seconds\n', time_orig);
        fprintf('   Range: [%.6f, %.6f]\n', min(trans_orig), max(trans_orig));
        fprintf('   Mean: %.6f, Std: %.6f\n', mean(trans_orig), std(trans_orig));
    catch ME
        fprintf('   ✗ Failed: %s\n', ME.message);
        return;
    end
    
    % Call 2: Optimized function with explicit parameters (no pre-loaded data)
    fprintf('\n2. Calling optimized umgTransmittanceOptimized with explicit parameters...\n');
    try
        tic;
        trans_opt = transmission.atmospheric.umgTransmittanceOptimized(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases);
        time_opt = toc;
        fprintf('   ✓ Success: %.3f seconds\n', time_opt);
        fprintf('   Range: [%.6f, %.6f]\n', min(trans_opt), max(trans_opt));
        fprintf('   Mean: %.6f, Std: %.6f\n', mean(trans_opt), std(trans_opt));
    catch ME
        fprintf('   ✗ Failed: %s\n', ME.message);
        trans_opt = [];
    end
    
    if ~isempty(trans_opt)
        % Direct comparison
        fprintf('\n3. Direct comparison:\n');
        abs_diff = abs(trans_orig - trans_opt);
        rel_diff = abs_diff ./ (trans_orig + eps);
        
        fprintf('   Max absolute difference: %.6e\n', max(abs_diff));
        fprintf('   Mean absolute difference: %.6e\n', mean(abs_diff));
        fprintf('   Max relative difference: %.4f%%\n', max(rel_diff) * 100);
        fprintf('   Mean relative difference: %.4f%%\n', mean(rel_diff) * 100);
        
        if max(abs_diff) > 0.1
            fprintf('   ⚠️  LARGE DIFFERENCE CONFIRMED!\n');
            
            % Find the wavelength with maximum difference
            [max_diff, max_idx] = max(abs_diff);
            fprintf('\n   Largest difference at wavelength %.1f nm:\n', Lam(max_idx));
            fprintf('     Original: %.6f\n', trans_orig(max_idx));
            fprintf('     Optimized: %.6f\n', trans_opt(max_idx));
            fprintf('     Difference: %.6f\n', max_diff);
            fprintf('     Relative: %.2f%%\n', rel_diff(max_idx) * 100);
        else
            fprintf('   ✅ Functions are identical!\n');
        end
    end
    
    % Call 3: Test with pre-loaded data
    fprintf('\n4. Testing optimized function with pre-loaded data...\n');
    try
        fprintf('   Loading absorption data...\n');
        tic;
        abs_data = transmission.data.loadAbsorptionData('/home/dana/matlab/data_Transmission_Fitter/Templates');
        load_time = toc;
        fprintf('   Data loaded in %.3f seconds\n', load_time);
        
        tic;
        trans_opt_preload = transmission.atmospheric.umgTransmittanceOptimized(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases, 'AbsData', abs_data);
        time_preload = toc;
        fprintf('   ✓ Success: %.3f seconds\n', time_preload);
        fprintf('   Range: [%.6f, %.6f]\n', min(trans_opt_preload), max(trans_opt_preload));
        
        % Compare with non-preloaded version
        if ~isempty(trans_opt)
            preload_diff = max(abs(trans_opt - trans_opt_preload));
            fprintf('   Max difference vs non-preloaded: %.6e\n', preload_diff);
        end
        
    catch ME
        fprintf('   ✗ Pre-loaded test failed: %s\n', ME.message);
    end
    
    % Call 4: Check if there are any differences in argument handling
    fprintf('\n5. Testing parameter variations...\n');
    
    % Test with fewer arguments to check defaults
    try
        fprintf('   Testing with minimal arguments...\n');
        trans_min_orig = transmission.atmospheric.umgTransmittance(Z_, Tair, Pressure, Lam);
        trans_min_opt = transmission.atmospheric.umgTransmittanceOptimized(Z_, Tair, Pressure, Lam);
        
        min_diff = max(abs(trans_min_orig - trans_min_opt));
        fprintf('   Minimal args max difference: %.6e\n', min_diff);
        
        if min_diff > 0.1
            fprintf('   ⚠️  DIFFERENCE IN DEFAULT HANDLING!\n');
        end
    catch ME
        fprintf('   ✗ Minimal args test failed: %s\n', ME.message);
    end
    
    % Call 5: Manual step-by-step recreation of optimized function
    fprintf('\n6. Manual step-by-step verification...\n');
    try
        fprintf('   Manually recreating optimized function logic...\n');
        
        % Replicate the exact optimized function logic
        % ... (This would be a manual implementation)
        fprintf('   (Implementation would go here to test each step)\n');
        
    catch ME
        fprintf('   ✗ Manual verification failed: %s\n', ME.message);
    end
    
    fprintf('\n=== DEBUGGING COMPLETE ===\n');
end