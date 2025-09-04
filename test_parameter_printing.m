%% Test parameter printing in TransmissionOptimizer
try
    fprintf('=== Testing Parameter Printing ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "QuickCalibration", ...
        'Verbose', true);
    
    % Run just the first stage to see parameter printing
    fprintf('\nRunning single stage to test parameter printing...\n');
    finalParams = optimizer.runFullSequence(1);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end