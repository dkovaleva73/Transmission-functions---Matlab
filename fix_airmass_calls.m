% Script to fix airmass function calls to use cached version
% Replace transmission.utils.airmassFromSMARTS with transmissionFast.utils.airmassFromSMARTS

fprintf('Fixing airmass function calls in transmissionFast package...\n');

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
    
    % Replace the old airmass calls with cached version
    pattern = 'transmission\.utils\.airmassFromSMARTS';
    replacement = 'transmissionFast.utils.airmassFromSMARTS';
    content = regexprep(content, pattern, replacement);
    
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

fprintf('\nDone! Now all airmass calls use the cached version.\n');
fprintf('You should see performance improvements in atmospheric calculations!\n');