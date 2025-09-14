% Test script to compare trapz optimization methods
fprintf('Testing trapz optimization strategies...\n\n');

% Setup
Config = transmissionFast.inputConfig();
Wavelength = transmissionFast.utils.makeWavelengthArray(Config);

% Create dummy spectra data
Nspectra = 1000;  % Many spectra to see performance difference
SpecTrans = cell(Nspectra, 2);
for i = 1:Nspectra
    % Random spectrum-like data
    flux = exp(-((Wavelength - 500 - randn*50) / 100).^2) + 0.1*randn(size(Wavelength));
    flux(flux < 0) = 0;
    SpecTrans{i, 1} = flux(:);
    SpecTrans{i, 2} = flux(:) * 0.01;  % Dummy errors
end

% Dummy metadata
Metadata = struct();
Metadata.ExpTime = 20;

fprintf('=== Performance Comparison: trapz vs Optimized Integration ===\n');
fprintf('Number of spectra: %d\n', Nspectra);
fprintf('Wavelength points: %d\n\n', length(Wavelength));

% Method 1: Original with trapz (simulate current implementation)
fprintf('Method 1: Original trapz in loop\n');
tic;
totalFlux_original = zeros(Nspectra, 1);
H = constant.h;
C = constant.c;
Ageom = 0.4418;
dt = 20;

for i = 1:Nspectra
    Integrand = SpecTrans{i, 1}(:)' .* Wavelength(:)';
    A = trapz(Wavelength, Integrand);
    B = H * C * 1e9;
    totalFlux_original(i) = dt * Ageom * A / B;
end
time_original = toc;
fprintf('  Time: %.3f ms\n', time_original * 1000);
fprintf('  Time per spectrum: %.3f µs\n\n', time_original * 1e6 / Nspectra);

% Method 2: Pre-computed weights
fprintf('Method 2: Pre-computed trapezoidal weights\n');
tic;

% Pre-compute weights once
dx = diff(Wavelength(:));
weights = zeros(size(Wavelength(:)));
weights(1) = dx(1)/2;
weights(end) = dx(end)/2;
weights(2:end-1) = (dx(1:end-1) + dx(2:end))/2;

totalFlux_weights = zeros(Nspectra, 1);
for i = 1:Nspectra
    Integrand = SpecTrans{i, 1}(:) .* Wavelength(:);
    A = sum(weights .* Integrand);
    totalFlux_weights(i) = dt * Ageom * A / (H * C * 1e9);
end
time_weights = toc;
fprintf('  Time: %.3f ms\n', time_weights * 1000);
fprintf('  Time per spectrum: %.3f µs\n', time_weights * 1e6 / Nspectra);
fprintf('  Speedup vs original: %.1fx\n\n', time_original / time_weights);

% Method 3: Fully vectorized with matrix multiplication
fprintf('Method 3: Fully vectorized (matrix multiplication)\n');
tic;

% Extract all flux data at once
TransmittedFlux = zeros(Nspectra, length(Wavelength));
for i = 1:Nspectra
    TransmittedFlux(i, :) = SpecTrans{i, 1}(:)';
end

% Single matrix multiplication for all spectra
Integrand = TransmittedFlux .* repmat(Wavelength(:)', Nspectra, 1);
A_vector = Integrand * weights;  % Key optimization!
totalFlux_vectorized = dt * Ageom * A_vector / (H * C * 1e9);

time_vectorized = toc;
fprintf('  Time: %.3f ms\n', time_vectorized * 1000);
fprintf('  Time per spectrum: %.3f µs\n', time_vectorized * 1e6 / Nspectra);
fprintf('  Speedup vs original: %.1fx\n\n', time_original / time_vectorized);

% Method 4: Using the new optimized function
fprintf('Method 4: New optimized function\n');
tic;
totalFlux_optimized = transmissionFast.calibrators.calculateTotalFluxCalibrators_optimized(...
    Wavelength, SpecTrans, Metadata, Config, 'DebugOutput', false);
time_optimized = toc;
fprintf('  Time: %.3f ms\n', time_optimized * 1000);
fprintf('  Time per spectrum: %.3f µs\n', time_optimized * 1e6 / Nspectra);
fprintf('  Speedup vs original: %.1fx\n\n', time_original / time_optimized);

% Verify accuracy
fprintf('=== Accuracy Verification ===\n');
max_diff_weights = max(abs(totalFlux_original - totalFlux_weights));
max_diff_vectorized = max(abs(totalFlux_original - totalFlux_vectorized));
max_diff_optimized = max(abs(totalFlux_original - totalFlux_optimized));

fprintf('Maximum absolute differences from original:\n');
fprintf('  Pre-computed weights: %.2e\n', max_diff_weights);
fprintf('  Vectorized: %.2e\n', max_diff_vectorized);
fprintf('  Optimized function: %.2e\n', max_diff_optimized);

fprintf('\nRelative errors:\n');
mean_flux = mean(abs(totalFlux_original));
fprintf('  Pre-computed weights: %.2e%%\n', 100 * max_diff_weights / mean_flux);
fprintf('  Vectorized: %.2e%%\n', 100 * max_diff_vectorized / mean_flux);
fprintf('  Optimized function: %.2e%%\n', 100 * max_diff_optimized / mean_flux);

% Test with uniform grid optimization
fprintf('\n=== Uniform Grid Optimization ===\n');
if all(abs(diff(dx)) < 1e-10 * dx(1))
    fprintf('Wavelength grid is uniform (dx = %.2f nm)\n', dx(1));
    
    % Simple formula for uniform grid
    tic;
    totalFlux_uniform = zeros(Nspectra, 1);
    dx_uniform = Wavelength(2) - Wavelength(1);
    
    for i = 1:Nspectra
        Integrand = SpecTrans{i, 1}(:)' .* Wavelength(:)';
        % For uniform grid: trapz ≈ dx * (sum - 0.5*(first + last))
        A = dx_uniform * (sum(Integrand) - 0.5*(Integrand(1) + Integrand(end)));
        totalFlux_uniform(i) = dt * Ageom * A / (H * C * 1e9);
    end
    time_uniform = toc;
    
    fprintf('  Time with uniform grid optimization: %.3f ms\n', time_uniform * 1000);
    fprintf('  Speedup vs original: %.1fx\n', time_original / time_uniform);
    fprintf('  Max difference: %.2e\n', max(abs(totalFlux_original - totalFlux_uniform)));
else
    fprintf('Wavelength grid is non-uniform - uniform optimization not applicable\n');
end

% Summary
fprintf('\n=== Summary ===\n');
fprintf('Best method: Fully vectorized with matrix multiplication\n');
fprintf('Overall speedup achieved: %.1fx\n', time_original / time_vectorized);
fprintf('For %d spectra: %.1f ms saved\n', Nspectra, (time_original - time_vectorized) * 1000);

% Visual comparison
figure('Name', 'Integration Performance Comparison');
methods = {'Original\n(trapz)', 'Pre-computed\nWeights', 'Vectorized', 'Optimized\nFunction'};
times = [time_original, time_weights, time_vectorized, time_optimized] * 1000;
bar(times);
set(gca, 'XTickLabel', methods);
ylabel('Time (ms)');
title(sprintf('Integration Performance for %d Spectra', Nspectra));
grid on;

% Add speedup annotations
for i = 2:length(times)
    text(i, times(i), sprintf('%.1fx', times(1)/times(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

fprintf('\n✅ Optimization test completed!\n');
fprintf('Recommendation: Replace trapz loops with vectorized integration\n');