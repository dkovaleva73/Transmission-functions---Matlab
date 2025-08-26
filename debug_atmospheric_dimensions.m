% Debug atmospheric transmission dimension issue

Config = transmission.inputConfig('default');
Lam = transmission.utils.makeWavelengthArray(Config);

fprintf('=== DIMENSION DEBUGGING ===\n');
fprintf('Input wavelength array: %d × %d\n', size(Lam));

% Test each component individually
fprintf('\nTesting individual components:\n');

% Rayleigh
Trans_ray = transmission.atmospheric.rayleighTransmission(Lam, Config);
fprintf('Rayleigh:    %d × %d\n', size(Trans_ray));

% Ozone
Trans_oz = transmission.atmospheric.ozoneTransmission(Lam, Config);
fprintf('Ozone:       %d × %d\n', size(Trans_oz));

% Water
Trans_h2o = transmission.atmospheric.waterTransmittance(Lam, Config);
fprintf('Water:       %d × %d\n', size(Trans_h2o));

% Aerosol
Trans_aer = transmission.atmospheric.aerosolTransmission(Lam, Config);
fprintf('Aerosol:     %d × %d\n', size(Trans_aer));

% UMG
Trans_umg = transmission.atmospheric.umgTransmittance(Lam, Config);
fprintf('UMG:         %d × %d\n', size(Trans_umg));

% Test multiplication step by step
fprintf('\nStep-by-step multiplication:\n');
Trans_step1 = Trans_ray;
fprintf('After Rayleigh:              %d × %d\n', size(Trans_step1));

Trans_step2 = Trans_step1 .* Trans_oz;
fprintf('After Rayleigh × Ozone:      %d × %d\n', size(Trans_step2));

Trans_step3 = Trans_step2 .* Trans_h2o;
fprintf('After × Water:               %d × %d\n', size(Trans_step3));

Trans_step4 = Trans_step3 .* Trans_aer;
fprintf('After × Aerosol:             %d × %d\n', size(Trans_step4));

Trans_step5 = Trans_step4 .* Trans_umg;
fprintf('After × UMG (final):         %d × %d\n', size(Trans_step5));

% Show which component has wrong dimensions
wrong_dims = {};
if ~isequal(size(Trans_ray), size(Lam))
    wrong_dims{end+1} = 'Rayleigh';
end
if ~isequal(size(Trans_oz), size(Lam))
    wrong_dims{end+1} = 'Ozone';
end
if ~isequal(size(Trans_h2o), size(Lam))
    wrong_dims{end+1} = 'Water';
end
if ~isequal(size(Trans_aer), size(Lam))
    wrong_dims{end+1} = 'Aerosol';
end
if ~isequal(size(Trans_umg), size(Lam))
    wrong_dims{end+1} = 'UMG';
end

if ~isempty(wrong_dims)
    fprintf('\n❌ PROBLEM COMPONENTS:\n');
    for i = 1:length(wrong_dims)
        fprintf('  - %s\n', wrong_dims{i});
    end
else
    fprintf('\n✅ All components have correct dimensions\n');
end

% Test the full function
Trans_total = transmission.atmosphericTransmission(Lam, Config);
fprintf('\nFull atmosphericTransmission: %d × %d\n', size(Trans_total));

if isequal(size(Trans_total), size(Lam))
    fprintf('✅ atmosphericTransmission has correct dimensions\n');
else
    fprintf('❌ atmosphericTransmission has WRONG dimensions\n');
end