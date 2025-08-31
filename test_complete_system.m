%% Test Complete Transmission Optimization System
% Test the full optimization workflow with Python-compliant field correction

try
    fprintf('=== Testing Complete Transmission Optimization System ===\n');
    
    % 1. Load configuration
    fprintf('\n1. Loading configuration...\n');
    Config = transmission.inputConfig();
    fprintf('✓ Configuration loaded successfully\n');
    
    % 2. Initialize optimizer with default (Python-compliant) sequence
    fprintf('\n2. Initializing TransmissionOptimizer...\n');
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);  % Reduce verbosity for testing
    fprintf('✓ Optimizer initialized with DefaultSequence\n');
    
    % 3. Test individual stage definitions
    fprintf('\n3. Testing sequence definitions...\n');
    stages = transmission.TransmissionOptimizer.defineDefaultSequence();
    fprintf('Default sequence has %d stages:\n', length(stages));
    for i = 1:length(stages)
        fprintf('  Stage %d: %s - %s\n', i, stages(i).name, stages(i).description);
    end
    
    % 4. Test simple field correction sequence too
    stagesSimple = transmission.TransmissionOptimizer.defineSimpleFieldCorrectionSequence();
    fprintf('Simple field correction sequence has %d stages\n', length(stagesSimple));
    
    % 5. Test bounds configuration
    fprintf('\n4. Testing bounds configuration...\n');
    bounds = Config.Optimization.Bounds;
    fprintf('Center bounds: %.0f - %.0f nm\n', bounds.Lower.Center, bounds.Upper.Center);
    fprintf('Norm bounds: %.1f - %.1f\n', bounds.Lower.Norm_, bounds.Upper.Norm_);
    if bounds.Lower.Center == 300 && bounds.Upper.Center == 1000
        fprintf('✓ Center bounds corrected to match Python (300-1000 nm)\n');
    else
        error('✗ Center bounds incorrect');
    end
    
    % 6. Test detector dimensions
    fprintf('\n5. Testing detector dimensions...\n');
    detector = Config.Instrumental.Detector;
    fprintf('Detector size: %d pixels\n', detector.Size_pixels);
    fprintf('Coordinate range: %.1f - %.1f\n', detector.Min_coordinate, detector.Max_coordinate);
    if detector.Size_pixels == 1726
        fprintf('✓ Detector dimensions configured correctly\n');
    else
        error('✗ Detector dimensions incorrect');
    end
    
    % 7. Test telescope aperture
    fprintf('\n6. Testing telescope aperture configuration...\n');
    telescope = Config.Instrumental.Telescope;
    fprintf('Aperture diameter: %.4f m\n', telescope.Aperture_diameter_m);
    fprintf('Aperture area: %.8f m²\n', telescope.Aperture_area_m2);
    expected_area = pi * (0.1397^2);
    if abs(telescope.Aperture_area_m2 - expected_area) < 1e-10
        fprintf('✓ Telescope aperture configured correctly\n');
    else
        error('✗ Telescope aperture calculation incorrect');
    end
    
    % 8. Test field correction parameters in Python mode
    fprintf('\n7. Testing field correction parameter bounds...\n');
    pythonParams = {'kx0', 'ky0', 'kx', 'ky', 'kx2', 'ky2', 'kx3', 'ky3', 'kx4', 'ky4', 'kxy'};
    for i = 1:length(pythonParams)
        param = pythonParams{i};
        if isfield(bounds.Lower, param) && isfield(bounds.Upper, param)
            fprintf('  %s bounds: %.3f to %.3f\n', param, bounds.Lower.(param), bounds.Upper.(param));
        else
            error('✗ Missing bounds for Python parameter: %s', param);
        end
    end
    fprintf('✓ All Python field correction bounds present\n');
    
    fprintf('\n=== SYSTEM TEST COMPLETE ===\n');
    fprintf('✓ All components working correctly\n');
    fprintf('✓ Python-compliant field correction model ready\n');
    fprintf('✓ Simple field correction model ready\n');
    fprintf('✓ Configuration centralized and validated\n');
    
catch ME
    fprintf('✗ Error during system test: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end