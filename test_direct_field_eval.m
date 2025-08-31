%% Test Direct Field Evaluation
try
    fprintf('=== Test Direct Field Evaluation ===\n');
    
    % Test the evaluateChebyshevDirect function directly
    addpath('/home/dana/matlab_projects/+transmission/+photometry/');
    
    % Test values
    x_norm = 0.5;  % Middle of detector
    coeffs = [0, 0.05, 0, 0, 0];  % Just linear term
    
    % Direct evaluation
    result = transmission.photometry.calculateAbsolutePhotometry.evaluateChebyshevDirect(x_norm, coeffs);
    fprintf('evaluateChebyshevDirect(0.5, [0, 0.05, 0, 0, 0]) = %.4f\n', result);
    fprintf('Expected: 0.5 * 0.05 = 0.025\n');
    
    % Test constant term
    coeffs2 = [0.1, 0, 0, 0, 0];  % Just constant
    result2 = transmission.photometry.calculateAbsolutePhotometry.evaluateChebyshevDirect(0, coeffs2);
    fprintf('\nevaluateChebyshevDirect(0, [0.1, 0, 0, 0, 0]) = %.4f\n', result2);
    fprintf('Expected: 0.1\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    
    % The function is probably private, so let's test indirectly
    fprintf('\n--- Testing field correction calculation indirectly ---\n');
    
    % Create a simple test: kx0 = 1.0 should add 1.0 to all ZP magnitudes
    Config = transmission.inputConfig('python_field_correction');
    Config.FieldCorrection.Python.kx0 = 1.0;  % Large value to be obvious
    
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    
    CatalogAB = transmission.photometry.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', false);
    
    % Compare ZP with and without field correction
    Config2 = transmission.inputConfig();  % No field correction
    CatalogAB2 = transmission.photometry.calculateAbsolutePhotometry(OptimizedParams, Config2, 'Verbose', false);
    
    zp_diff = mean(CatalogAB.MAG_ZP) - mean(CatalogAB2.MAG_ZP);
    fprintf('Difference in mean ZP (with kx0=1.0): %.4f\n', zp_diff);
    fprintf('Expected: ~1.0 if field correction working via Config\n');
    
    if abs(zp_diff) < 0.01
        fprintf('✗ Config-based field correction NOT working\n');
    else
        fprintf('✓ Config-based field correction IS working (diff=%.4f)\n', zp_diff);
    end
end