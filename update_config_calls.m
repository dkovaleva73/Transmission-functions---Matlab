% Script to update all default Config arguments to use cached version
% This will replace transmission.inputConfig() with transmissionFast.getConfig()

fprintf('Updating default Config arguments in transmissionFast package...\n');

% Find all .m files in transmissionFast
files = dir(fullfile('+transmissionFast', '**', '*.m'));

totalUpdated = 0;
filesUpdated = {};

for i = 1:length(files)
    if contains(files(i).name, '.asv')
        continue;  % Skip backup files
    end
    
    filepath = fullfile(files(i).folder, files(i).name);
    
    % Read file content
    content = fileread(filepath);
    originalContent = content;
    
    % Replace patterns in arguments blocks
    % Pattern 1: Config = transmission.inputConfig()
    pattern1 = 'Config = transmission\.inputConfig\(\)';
    replacement1 = 'Config = transmissionFast.getConfig()  % Use cached config';
    content = regexprep(content, pattern1, replacement1);
    
    % Pattern 2: Config = transmissionFast.inputConfig()
    pattern2 = 'Config = transmissionFast\.inputConfig\(\)';
    replacement2 = 'Config = transmissionFast.getConfig()  % Use cached config';
    content = regexprep(content, pattern2, replacement2);
    
    % Check if file was modified
    if ~strcmp(content, originalContent)
        % Write updated content
        fid = fopen(filepath, 'w');
        if fid == -1
            warning('Could not write to file: %s', filepath);
            continue;
        end
        fprintf(fid, '%s', content);
        fclose(fid);
        
        totalUpdated = totalUpdated + 1;
        filesUpdated{end+1} = files(i).name;
        fprintf('  Updated: %s\n', files(i).name);
    end
end

fprintf('\nSummary:\n');
fprintf('  Total files updated: %d\n', totalUpdated);
if totalUpdated > 0
    fprintf('  Files updated:\n');
    for i = 1:length(filesUpdated)
        fprintf('    - %s\n', filesUpdated{i});
    end
end

fprintf('\nDone! ConfigManager caching is now enabled.\n');
fprintf('First call will load config, subsequent calls use cached version.\n');
fprintf('To reset cache: transmissionFast.ConfigManager.reset()\n');