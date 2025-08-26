% Test script to verify Degr parameter removal functionality
fprintf('Testing Degr parameter removal from transmission functions...\n\n');

% Test 1: chebyshevModel with different coefficient array lengths
fprintf('Test 1: chebyshevModel with different coefficient array lengths\n');
try
    Lam = transmission.utils.makeWavelengthArray(350, 1000, 651);
    
    % Test with 3 coefficients (degree 2)
    Cheb_coeffs_3 = [0.1, -0.05, 0.02];
    result_3 = transmission.utils.chebyshevModel(Lam, Cheb_coeffs_3, 'X', 'tr');
    fprintf('  - 3 coefficients (degree 2): Success, result size = [%d, %d]\n', size(result_3));
    
    % Test with 5 coefficients (degree 4)
    Cheb_coeffs_5 = [0.1, -0.05, 0.02, -0.01, 0.005];
    result_5 = transmission.utils.chebyshevModel(Lam, Cheb_coeffs_5, 'X', 'tr');
    fprintf('  - 5 coefficients (degree 4): Success, result size = [%d, %d]\n', size(result_5));
    
    % Test with 7 coefficients (degree 6)
    Cheb_coeffs_7 = [0.1, -0.05, 0.02, -0.01, 0.005, -0.002, 0.001];
    result_7 = transmission.utils.chebyshevModel(Lam, Cheb_coeffs_7, 'X', 'tr');
    fprintf('  - 7 coefficients (degree 6): Success, result size = [%d, %d]\n', size(result_7));
catch ME
    fprintf('  ERROR in chebyshevModel: %s\n', ME.message);
end

% Test 2: legendreModel with different coefficient array lengths
fprintf('\nTest 2: legendreModel with different coefficient array lengths\n');
try
    % Test with 3 coefficients (degree 2)
    Li_3 = [0.1, -0.05, 0.02];
    result_3 = transmission.utils.legendreModel(Lam, Li_3);
    fprintf('  - 3 coefficients (degree 2): Success, result size = [%d, %d]\n', size(result_3));
    
    % Test with 5 coefficients (degree 4)
    Li_5 = [-0.30, 0.34, -1.89, -0.82, -3.73];
    result_5 = transmission.utils.legendreModel(Lam, Li_5);
    fprintf('  - 5 coefficients (degree 4): Success, result size = [%d, %d]\n', size(result_5));
    
    % Test with 9 coefficients (degree 8)
    Li_9 = [-0.30, 0.34, -1.89, -0.82, -3.73, -0.669, -2.06, -0.24, -0.60];
    result_9 = transmission.utils.legendreModel(Lam, Li_9);
    fprintf('  - 9 coefficients (degree 8): Success, result size = [%d, %d]\n', size(result_9));
catch ME
    fprintf('  ERROR in legendreModel: %s\n', ME.message);
end

% Test 3: quantumEfficiency with different Legendre coefficient arrays
fprintf('\nTest 3: quantumEfficiency with different Legendre coefficient arrays\n');
try
    % Test with default parameters (9 coefficients)
    Qe_default = transmission.instrumental.quantumEfficiency(Lam);
    fprintf('  - Default parameters (9 coefficients): Success, result size = [%d, %d]\n', size(Qe_default));
    
    % Test with 5 coefficients
    Qe_5 = transmission.instrumental.quantumEfficiency(Lam, 328.19, 570.97, 139.77, -0.1517, Li_5);
    fprintf('  - 5 coefficients: Success, result size = [%d, %d]\n', size(Qe_5));
    
    % Test with 3 coefficients
    Qe_3 = transmission.instrumental.quantumEfficiency(Lam, 328.19, 570.97, 139.77, -0.1517, Li_3);
    fprintf('  - 3 coefficients: Success, result size = [%d, %d]\n', size(Qe_3));
catch ME
    fprintf('  ERROR in quantumEfficiency: %s\n', ME.message);
end

% Test 4: Full OTA transmission calculation
fprintf('\nTest 4: Full OTA transmission calculation\n');
try
    % Default parameters
    Qe_params = struct('amplitude', 328.19, 'center', 570.97, 'sigma', 139.77, 'gamma', -0.1517, ...
                      'l0', -0.30, 'l1', 0.34, 'l2', -1.89, 'l3', -0.82, 'l4', -3.73, ...
                      'l5', -0.669, 'l6', -2.06, 'l7', -0.24, 'l8', -0.60);
    Mirror_params = struct('use_orig_xlt', true);
    Corrector_params = struct();
    Cheb_params = struct('r0', 0.1, 'r1', -0.05, 'r2', 0.02, 'r3', -0.01, 'r4', 0.005);
    
    Ota = transmission.instrumental.otaTransmission(Lam, Qe_params, Mirror_params, Corrector_params, Cheb_params);
    fprintf('  - Full OTA transmission: Success, result size = [%d, %d]\n', size(Ota));
    fprintf('  - Min transmission: %.6f, Max transmission: %.6f\n', min(Ota), max(Ota));
catch ME
    fprintf('  ERROR in otaTransmission: %s\n', ME.message);
    fprintf('  Error identifier: %s\n', ME.identifier);
    if ~isempty(ME.stack)
        fprintf('  Error location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end

fprintf('\nAll tests completed.\n');