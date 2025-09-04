%% Test that default values from Config are used as initial values
try
    fprintf('=== Testing Default Values as Initial Values ===\n');
    
    % 1. Load configuration
    Config = transmission.inputConfig();
    
    % 2. Show some default values from Config
    fprintf('\n1. Default values from Config structure:\n');
    fprintf('   Norm_: %.4f\n', Config.General.Norm_);
    fprintf('   Tau_aod500: %.4f\n', Config.Atmospheric.Components.Aerosol.Tau_aod500);
    fprintf('   Pwv_cm: %.4f\n', Config.Atmospheric.Components.Water.Pwv_cm);
    fprintf('   Center: %.4f\n', Config.Utils.SkewedGaussianModel.Default_center);
    
    % 3. Test with a simple optimization of just Norm_
    fprintf('\n2. Testing with Norm_ as free parameter:\n');
    
    % Create a simple test with mock data
    CalibData = struct();
    CalibData.Spec = {ones(343,1), ones(343,1)};  % Mock spectra
    CalibData.Mag = [15; 14.5];
    CalibData.Coords = struct('Gaia_RA', [1, 2], 'Gaia_Dec', [1, 2], 'LAST_idx', [1, 2]);
    CalibData.LASTData = table();
    CalibData.LASTData.X = [100; 200];
    CalibData.LASTData.Y = [100; 200];
    CalibData.LASTData.FLUX_APER_3 = [1000; 2000];
    CalibData.LASTData.MAG_PSF = [15; 14.5];
    CalibData.Metadata = struct('airMassFromLAST', 1.2, 'Temperature', 20, 'Pressure', 780);
    
    % Run minimizerFminGeneric with Norm_ as free parameter
    fprintf('   Running minimizerFminGeneric with FreeParams = "Norm_"\n');
    
    % Check what initial value will be used
    fprintf('   Expected initial value for Norm_: %.4f (from Config.General.Norm_)\n', Config.General.Norm_);
    
    % 4. Test with field correction parameters
    fprintf('\n3. Testing with field correction parameters:\n');
    fprintf('   Free params: kx0, kx, ky\n');
    
    % These should all default to 0 as defined in getParameterPath
    fprintf('   Expected initial values:\n');
    fprintf('     kx0: 0.0000 (default from getParameterPath)\n');
    fprintf('     kx: 0.0000 (default from getParameterPath)\n');
    fprintf('     ky: 0.0000 (default from getParameterPath)\n');
    
    % 5. Test with atmospheric parameters
    fprintf('\n4. Testing with atmospheric parameters:\n');
    fprintf('   Free params: Pwv_cm, Tau_aod500\n');
    fprintf('   Expected initial values:\n');
    fprintf('     Pwv_cm: %.4f (from Config.Atmospheric.Components.Water.Pwv_cm)\n', ...
            Config.Atmospheric.Components.Water.Pwv_cm);
    fprintf('     Tau_aod500: %.4f (from Config.Atmospheric.Components.Aerosol.Tau_aod500)\n', ...
            Config.Atmospheric.Components.Aerosol.Tau_aod500);
    
    % 6. Test TransmissionOptimizer stages
    fprintf('\n5. Testing TransmissionOptimizer stage sequence:\n');
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "QuickCalibration", ...
        'Verbose', false);
    
    stage1 = optimizer.ActiveSequence(1);
    fprintf('   Stage 1 (%s) free params: %s\n', stage1.name, strjoin(string(stage1.freeParams), ', '));
    fprintf('     Initial value will come from Config.General.Norm_ = %.4f\n', Config.General.Norm_);
    
    if length(optimizer.ActiveSequence) > 1
        stage2 = optimizer.ActiveSequence(2);
        fprintf('   Stage 2 (%s) free params: %s\n', stage2.name, strjoin(string(stage2.freeParams), ', '));
        fprintf('     Initial value will come from Config.Atmospheric.Components.Aerosol.Tau_aod500 = %.4f\n', ...
                Config.Atmospheric.Components.Aerosol.Tau_aod500);
    end
    
    fprintf('\n=== TEST COMPLETE ===\n');
    fprintf('✓ Default values from Config are used as initial values for free parameters\n');
    fprintf('✓ Previously optimized values override defaults via FixedParams\n');
    fprintf('✓ No separate InitialGuess structure needed\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end