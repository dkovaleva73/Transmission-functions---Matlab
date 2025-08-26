% Debug atmospheric transmission components

Config = transmission.inputConfig('default');
Lam = [400, 500, 600, 700, 800];  % Test wavelengths

fprintf('=== INDIVIDUAL COMPONENT TRANSMISSIONS ===\n');
fprintf('Wavelength: ');
fprintf('%8d ', Lam);
fprintf('\n');

% Rayleigh
Trans_ray = transmission.atmospheric.rayleighTransmission(Lam(:), Config);
fprintf('Rayleigh:   ');
fprintf('%8.4f ', Trans_ray);
fprintf('\n');

% Ozone
Trans_oz = transmission.atmospheric.ozoneTransmission(Lam(:), Config);
fprintf('Ozone:      ');
fprintf('%8.4f ', Trans_oz);
fprintf('\n');

% Water
Trans_h2o = transmission.atmospheric.waterTransmittance(Lam(:), Config);
fprintf('Water:      ');
fprintf('%8.4f ', Trans_h2o);
fprintf('\n');

% Aerosol
Trans_aer = transmission.atmospheric.aerosolTransmission(Lam(:), Config);
fprintf('Aerosol:    ');
fprintf('%8.4f ', Trans_aer);
fprintf('\n');

% UMG
Trans_umg = transmission.atmospheric.umgTransmittance(Lam(:), Config);
fprintf('UMG:        ');
fprintf('%8.4f ', Trans_umg);
fprintf('\n');

% Total (multiply all)
Trans_total = Trans_ray .* Trans_oz .* Trans_h2o .* Trans_aer .* Trans_umg;
fprintf('Total:      ');
fprintf('%8.4f ', Trans_total);
fprintf('\n');

% Check Config values
fprintf('\n=== CONFIGURATION VALUES ===\n');
fprintf('Zenith angle: %.1f deg\n', Config.Atmospheric.Zenith_angle_deg);
fprintf('Pressure: %.1f mbar\n', Config.Atmospheric.Pressure_mbar);
fprintf('Water vapor: %.1f cm\n', Config.Atmospheric.Components.Water.Pwv_cm);
fprintf('Ozone: %.0f DU\n', Config.Atmospheric.Components.Ozone.Dobson_units);
fprintf('Aerosol AOD: %.3f\n', Config.Atmospheric.Components.Aerosol.Tau_aod500);
fprintf('Temperature: %.1f C\n', Config.Atmospheric.Temperature_C);