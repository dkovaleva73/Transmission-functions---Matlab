% Debug why instrumental functions are still reading CSV files
fprintf('Debugging instrumental data usage...\n\n');

Config = transmissionFast.inputConfig();

fprintf('1. Checking Config structure for InstrumentalData:\n');
if isfield(Config, 'InstrumentalData')
    fprintf('   ✓ InstrumentalData field exists\n');
    
    if isfield(Config.InstrumentalData, 'Mirror')
        fprintf('   ✓ Mirror data available\n');
        mirror_fields = fieldnames(Config.InstrumentalData.Mirror);
        fprintf('     Mirror fields: %s\n', strjoin(mirror_fields, ', '));
        fprintf('     Mirror wavelength size: %d points\n', length(Config.InstrumentalData.Mirror.wavelength));
        fprintf('     Mirror data file: %s\n', Config.InstrumentalData.Mirror.filename);
    else
        fprintf('   ⚠ Mirror data missing\n');
    end
    
    if isfield(Config.InstrumentalData, 'Corrector')
        fprintf('   ✓ Corrector data available\n');
        corrector_fields = fieldnames(Config.InstrumentalData.Corrector);
        fprintf('     Corrector fields: %s\n', strjoin(corrector_fields, ', '));
        fprintf('     Corrector wavelength size: %d points\n', length(Config.InstrumentalData.Corrector.wavelength));
        fprintf('     Corrector data file: %s\n', Config.InstrumentalData.Corrector.filename);
    else
        fprintf('   ⚠ Corrector data missing\n');
    end
else
    fprintf('   ❌ InstrumentalData field missing from Config\n');
    fprintf('   Available Config fields: %s\n', strjoin(fieldnames(Config), ', '));
end

fprintf('\n2. Checking Config file paths vs cached file paths:\n');
mirror_config_path = Config.Instrumental.Components.Mirror.Data_file;
corrector_config_path = Config.Instrumental.Components.Corrector.Data_file;

fprintf('   Mirror config path: %s\n', mirror_config_path);
fprintf('   Corrector config path: %s\n', corrector_config_path);

if isfield(Config, 'InstrumentalData')
    if isfield(Config.InstrumentalData, 'Mirror')
        fprintf('   Mirror cached path: %s\n', Config.InstrumentalData.Mirror.filename);
        path_match_mirror = strcmp(mirror_config_path, Config.InstrumentalData.Mirror.filename);
        fprintf('   Mirror paths match: %s\n', string(path_match_mirror));
    end
    
    if isfield(Config.InstrumentalData, 'Corrector')
        fprintf('   Corrector cached path: %s\n', Config.InstrumentalData.Corrector.filename);
        path_match_corrector = strcmp(corrector_config_path, Config.InstrumentalData.Corrector.filename);
        fprintf('   Corrector paths match: %s\n', string(path_match_corrector));
    end
end

fprintf('\n3. Testing which code path is taken:\n');
wavelength = 400:10:700;

% Add some debug output to see which path is taken
fprintf('   Testing mirrorReflectance...\n');
try
    % This will show us if the cached data path is being used
    if isfield(Config, 'InstrumentalData') && isfield(Config.InstrumentalData, 'Mirror')
        fprintf('   → Should use cached data path\n');
    else
        fprintf('   → Will use fallback file reading path\n');
    end
    
    mirror_result = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    fprintf('   ✓ mirrorReflectance completed\n');
catch ME
    fprintf('   ❌ mirrorReflectance failed: %s\n', ME.message);
end

fprintf('   Testing correctorTransmission...\n');
try
    if isfield(Config, 'InstrumentalData') && isfield(Config.InstrumentalData, 'Corrector')
        fprintf('   → Should use cached data path\n');
    else
        fprintf('   → Will use fallback file reading path\n');
    end
    
    corrector_result = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
    fprintf('   ✓ correctorTransmission completed\n');
catch ME
    fprintf('   ❌ correctorTransmission failed: %s\n', ME.message);
end

fprintf('\n✅ Debug analysis completed\n');