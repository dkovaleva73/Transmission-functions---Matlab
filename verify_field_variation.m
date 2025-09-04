%% Verify Field Correction Variation
% Test with larger field correction coefficients to ensure variation is computed

try
    fprintf('=== Verifying Field Correction Calculation ===\n');
    
    % Create parameters with larger field correction coefficients
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.75;
    OptimizedParams.Center = 570.973;
    
    % Larger Python field correction parameters to see variation
    OptimizedParams.kx0 = 0.1;     % Larger constant offset X
    OptimizedParams.kx = -0.05;    % Larger linear term X  
    OptimizedParams.ky = 0.03;     % Larger linear term Y
    OptimizedParams.kx2 = 0.02;    % Larger quadratic term X
    OptimizedParams.ky2 = -0.015;  % Larger quadratic term Y
    OptimizedParams.kxy = 0.025;   % Larger cross term XY
    
    % Configure Python field correction
    Config = transmission.inputConfig();
    Config.FieldCorrection.Python = OptimizedParams;
    
    % Test calculateAbsolutePhotometry 
    CatalogAB = transmission.calculateAbsolutePhotometry(OptimizedParams, Config, ...
        'Verbose', false);
    
    % Analyze field variation
    fprintf('Number of stars: %d\n', height(CatalogAB));
    mag_zp_range = max(CatalogAB.MAG_ZP) - min(CatalogAB.MAG_ZP);
    fprintf('Zero-point magnitude range: %.4f mag\n', mag_zp_range);
    fprintf('Zero-point std: %.4f mag\n', std(CatalogAB.MAG_ZP));
    
    % Check coordinate ranges to understand field coverage
    fprintf('X coordinate range: %.1f to %.1f pixels\n', min(CatalogAB.X), max(CatalogAB.X));
    fprintf('Y coordinate range: %.1f to %.1f pixels\n', min(CatalogAB.Y), max(CatalogAB.Y));
    
    % Sample a few stars to show field correction in action
    fprintf('\nSample field corrections:\n');
    sampleIdx = round(linspace(1, height(CatalogAB), 5));
    for i = 1:length(sampleIdx)
        idx = sampleIdx(i);
        fprintf('Star %d: X=%.1f, Y=%.1f, MAG_ZP=%.4f\n', ...
            idx, CatalogAB.X(idx), CatalogAB.Y(idx), CatalogAB.MAG_ZP(idx));
    end
    
    if mag_zp_range > 0.01
        fprintf('✓ Field correction producing significant spatial variation\n');
    else
        fprintf('⚠ Field correction variation still minimal\n');
    end
    
    fprintf('✓ Field correction verification complete\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end