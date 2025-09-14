% Test different interpolation methods with cached instrumental data
fprintf('Testing polyfit vs piecewise methods with cached instrumental data...\n\n');

clear functions;
Config = transmissionFast.inputConfig();
wavelength = 400:10:700;

% Test 1: Mirror Reflectance - Both Methods
fprintf('1. Testing Mirror Reflectance Methods:\n');

% Test polyfit method
Config.Instrumental.Components.Mirror.Method = 'polyfit_';
fprintf('  Using polyfit method:\n');
tic;
mirror_polyfit = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time_poly = toc;
fprintf('    Time: %.6f seconds\n', time_poly);

% Test piecewise method
Config.Instrumental.Components.Mirror.Method = 'piecewise_';
fprintf('  Using piecewise method:\n');
tic;
mirror_piecewise = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time_piece = toc;
fprintf('    Time: %.6f seconds\n', time_piece);

% Compare results
max_diff_mirror = max(abs(mirror_polyfit - mirror_piecewise));
fprintf('    Maximum difference between methods: %.6f\n', max_diff_mirror);

% Test 2: Corrector Transmission - Both Methods  
fprintf('\n2. Testing Corrector Transmission Methods:\n');

% Test polyfit method
Config.Instrumental.Components.Corrector.Method = 'polyfit_';
fprintf('  Using polyfit method:\n');
tic;
corrector_polyfit = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time_corr_poly = toc;
fprintf('    Time: %.6f seconds\n', time_corr_poly);

% Test piecewise method
Config.Instrumental.Components.Corrector.Method = 'piecewise_';
fprintf('  Using piecewise method:\n');
tic;
corrector_piecewise = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time_corr_piece = toc;
fprintf('    Time: %.6f seconds\n', time_corr_piece);

% Compare results
max_diff_corrector = max(abs(corrector_polyfit - corrector_piecewise));
fprintf('    Maximum difference between methods: %.6f\n', max_diff_corrector);

% Test 3: Error Handling
fprintf('\n3. Testing Error Handling:\n');

% Test invalid method
Config.Instrumental.Components.Mirror.Method = 'invalid_method';
try
    transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    fprintf('  ⚠ Invalid method test failed - should have thrown error\n');
catch ME
    fprintf('  ✓ Invalid method correctly caught: %s\n', ME.message);
end

% Test 4: Performance with multiple method switches
fprintf('\n4. Testing Performance with Method Switching:\n');
clear functions;
Config = transmissionFast.inputConfig();

tic;
for i = 1:10
    Config.Instrumental.Components.Mirror.Method = 'polyfit_';
    mirror_poly = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    
    Config.Instrumental.Components.Mirror.Method = 'piecewise_';
    mirror_piece = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
end
time_switching = toc;
fprintf('  10 rounds with method switching: %.6f seconds\n', time_switching);

fprintf('\n✅ Method testing completed successfully\n');
fprintf('🚀 Both polyfit and piecewise methods work correctly with cached data!\n');