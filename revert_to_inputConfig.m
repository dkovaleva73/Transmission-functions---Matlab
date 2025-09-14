% Script to revert all getConfig() calls back to inputConfig()
% Since we've integrated caching directly into inputConfig

fprintf('Reverting getConfig() calls back to inputConfig() in transmissionFast package...\n');

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
    
    % Replace getConfig() back to inputConfig()
    pattern1 = 'Config = transmissionFast\.getConfig\(\)\s*%\s*Use cached config';
    replacement1 = 'Config = transmissionFast.inputConfig()';
    content = regexprep(content, pattern1, replacement1);
    
    % Also handle any remaining getConfig() calls
    pattern2 = 'transmissionFast\.getConfig\(\)';
    replacement2 = 'transmissionFast.inputConfig()';
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

fprintf('\nDone! Now using inputConfig() with integrated caching.\n');
fprintf('Caching is transparent - same API, better performance!\n');