function test_umg_fix()
    % Test script to verify the UMG transmittance fixes work correctly
    
    fprintf('=== TESTING UMG TRANSMITTANCE FIXES ===\n\n');
    
    % Test parameters
    Z_ = 30;          % zenith angle (degrees)
    Tair = 15;        % air temperature (°C) 
    Pressure = 1013.25; % atmospheric pressure (hPa)
    Co2_ppm = 415;    % CO2 concentration (ppm)
    With_trace_gases = true;
    
    % Create wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Test parameters: Z=%.1f°, T=%.1f°C, P=%.1f hPa, CO2=%.1f ppm\n', ...
            Z_, Tair, Pressure, Co2_ppm);
    fprintf('Wavelength points: %d\n\n', length(Lam));
    
    % Test original function
    fprintf('Running original umgTransmittance...\n');
    tic;
    trans_original = transmission.atmospheric.umgTransmittance(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases);
    time_original = toc;
    fprintf('✓ Completed in %.3f seconds\n', time_original);
    fprintf('  Range: [%.6f, %.6f]\n', min(trans_original), max(trans_original));
    fprintf('  Mean: %.6f, Std: %.6f\n\n', mean(trans_original), std(trans_original));
    
    % Test fixed optimized function
    fprintf('Running FIXED umgTransmittanceOptimized...\n');
    tic;
    trans_optimized = transmission.atmospheric.umgTransmittanceOptimized(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases);
    time_optimized = toc;
    fprintf('✓ Completed in %.3f seconds\n', time_optimized);
    fprintf('  Range: [%.6f, %.6f]\n', min(trans_optimized), max(trans_optimized));
    fprintf('  Mean: %.6f, Std: %.6f\n\n', mean(trans_optimized), std(trans_optimized));
    
    % Compare results
    fprintf('=== COMPARISON RESULTS ===\n');
    
    abs_diff = abs(trans_original - trans_optimized);
    rel_diff = abs_diff ./ (trans_original + eps);
    
    fprintf('Absolute differences:\n');
    fprintf('  Max: %.6e\n', max(abs_diff));
    fprintf('  Mean: %.6e\n', mean(abs_diff));
    fprintf('  RMS: %.6e\n', sqrt(mean(abs_diff.^2)));
    
    fprintf('Relative differences (%):\n');
    fprintf('  Max: %.4f%%\n', max(rel_diff) * 100);
    fprintf('  Mean: %.4f%%\n', mean(rel_diff) * 100);
    fprintf('  RMS: %.4f%%\n', sqrt(mean(rel_diff.^2)) * 100);
    
    % Find wavelengths with largest differences
    [max_abs_diff, max_idx] = max(abs_diff);
    fprintf('\nLargest difference at:\n');
    fprintf('  Wavelength: %.1f nm\n', Lam(max_idx));
    fprintf('  Original: %.6f\n', trans_original(max_idx));
    fprintf('  Optimized: %.6f\n', trans_optimized(max_idx));
    fprintf('  Absolute difference: %.6e\n', max_abs_diff);
    fprintf('  Relative difference: %.4f%%\n', rel_diff(max_idx) * 100);
    
    % Performance comparison
    fprintf('\nPerformance:\n');
    fprintf('  Original: %.3f seconds\n', time_original);
    fprintf('  Optimized: %.3f seconds\n', time_optimized);
    if time_optimized < time_original
        fprintf('  Speedup: %.2fx faster\n', time_original / time_optimized);
    else
        fprintf('  Slowdown: %.2fx slower\n', time_optimized / time_original);
    end
    
    % Final assessment
    fprintf('\n=== FINAL ASSESSMENT ===\n');
    
    if max(abs_diff) < 1e-12
        fprintf('✅ PERFECT: Functions produce numerically identical results!\n');
        fprintf('   Maximum difference: %.2e (machine precision level)\n', max(abs_diff));
    elseif max(abs_diff) < 1e-9
        fprintf('✅ EXCELLENT: Functions produce effectively identical results\n');
        fprintf('   Maximum difference: %.2e (negligible)\n', max(abs_diff));
    elseif max(abs_diff) < 1e-6
        fprintf('✅ GOOD: Functions produce nearly identical results\n');
        fprintf('   Maximum difference: %.2e (acceptable for most applications)\n', max(abs_diff));
    elseif max(abs_diff) < 1e-3
        fprintf('⚠️  ACCEPTABLE: Small but noticeable differences remain\n');
        fprintf('   Maximum difference: %.2e (may affect precision applications)\n', max(abs_diff));
    else
        fprintf('❌ PROBLEM: Significant differences still present\n');
        fprintf('   Maximum difference: %.2e (requires further investigation)\n', max(abs_diff));
    end
    
    % Detailed breakdown by wavelength region
    fprintf('\nDetailed analysis by wavelength region:\n');
    wvl_regions = {
        [300, 400], 'UV';
        [400, 700], 'Visible'; 
        [700, 1000], 'Near-IR';
        [1000, 1800], 'IR'
    };
    
    for i = 1:size(wvl_regions, 1)
        range = wvl_regions{i, 1};
        name = wvl_regions{i, 2};
        mask = Lam >= range(1) & Lam <= range(2);
        
        if any(mask)
            region_max_diff = max(abs_diff(mask));
            region_mean_diff = mean(abs_diff(mask));
            fprintf('  %s (%d-%d nm): Max diff = %.2e, Mean diff = %.2e\n', ...
                    name, range(1), range(2), region_max_diff, region_mean_diff);
        end
    end
    
    fprintf('\n=== TEST COMPLETE ===\n');
end