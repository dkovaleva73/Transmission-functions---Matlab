% Debug why airmass caching isn't showing benefits in optimizer
fprintf('Investigating airmass caching in optimizer...\n');

% Create optimizer and check what happens
Config = transmissionFast.inputConfig();
fprintf('Config zenith angle: %.2f degrees\n', Config.Atmospheric.Zenith_angle_deg);

% Clear airmass cache to start fresh
transmissionFast.utils.clearAirmassCaches();

% Test if airmass is called with Config or with modified config
fprintf('\nTesting airmass calls:\n');
tic;
am1 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
time1 = toc;
fprintf('Direct call with Config: %.6f (%.6f s)\n', am1, time1);

tic;
am2 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
time2 = toc;
fprintf('Second call (should be cached): %.6f (%.6f s) - %.0fx faster\n', am2, time2, time1/time2);

% Check if the optimizer modifies the zenith angle
fprintf('\nChecking optimizer behavior:\n');
try
    optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config);
    fprintf('Optimizer created successfully\n');
    
    % Check if Config is modified
    fprintf('After optimizer creation - zenith angle: %.2f degrees\n', Config.Atmospheric.Zenith_angle_deg);
    
catch ME
    fprintf('Error creating optimizer: %s\n', ME.message);
end

% The key question: Does the optimizer create new Config objects?
fprintf('\nTesting multiple Config creations (this might be the issue):\n');
tic;
Config1 = transmissionFast.inputConfig();
Config2 = transmissionFast.inputConfig();
Config3 = transmissionFast.inputConfig();
time_configs = toc;
fprintf('3 inputConfig calls: %.6f seconds\n', time_configs);

% Test if different Config objects affect caching
transmissionFast.utils.clearAirmassCaches();
tic;
am_config1 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config1);
time_config1 = toc;

tic;
am_config2 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config2);
time_config2 = toc;

fprintf('Airmass with Config1: %.6f (%.6f s)\n', am_config1, time_config1);
fprintf('Airmass with Config2: %.6f (%.6f s) - should be cached if same zenith\n', am_config2, time_config2);

if abs(am_config1 - am_config2) < 1e-10
    fprintf('✓ Same airmass values - caching should work\n');
    if time_config2 < time_config1 * 0.5
        fprintf('✓ Second call was faster - caching is working\n');
    else
        fprintf('⚠ Second call not much faster - caching may not be effective\n');
    end
else
    fprintf('⚠ Different airmass values - configs have different zenith angles\n');
end