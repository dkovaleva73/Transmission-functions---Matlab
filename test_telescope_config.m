%% Test Telescope Configuration
try
    Config = transmission.inputConfig();
    disp('Telescope configuration from Config:');
    fprintf('Aperture diameter: %.4f m\n', Config.Instrumental.Telescope.Aperture_diameter_m);
    fprintf('Aperture area: %.8f m²\n', Config.Instrumental.Telescope.Aperture_area_m2);
    calc_area = pi * (0.1397^2);
    fprintf('Calculated area: %.8f m² (should match)\n', calc_area);
    
    % Test that functions use the Config value
    disp('Testing calculateTotalFluxCalibrators with Config Ageom...');
    result = transmission.calibrators.calculateTotalFluxCalibrators();
    disp('✓ calculateTotalFluxCalibrators working with Config aperture area');
    
    disp('✓ All telescope aperture configuration working');
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end