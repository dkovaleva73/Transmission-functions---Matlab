% Fix only functional transmission. references (not in comments)
fprintf('Fixing functional transmission. references...\n');

% Read inputConfig.m and fix the functional reference
file_path = '/home/dana/matlab_projects/+transmissionFast/inputConfig.m';
content = fileread(file_path);

% Look for the specific line with functional reference
% This should be around line 662: transmission.data.loadAbsorptionData
old_line = 'cachedData = transmission.data.loadAbsorptionData([], AllSpecies, false);';
new_line = 'cachedData = transmissionFast.data.loadAbsorptionData([], AllSpecies, false);';

if contains(content, old_line)
    new_content = strrep(content, old_line, new_line);
    
    fid = fopen(file_path, 'w');
    if fid ~= -1
        fprintf(fid, '%s', new_content);
        fclose(fid);
        fprintf('✓ Fixed functional reference in inputConfig.m\n');
    else
        fprintf('⚠ Could not write to inputConfig.m\n');
    end
else
    fprintf('- No functional reference found in inputConfig.m\n');
end

% Check if there are other non-comment functional references
fprintf('\nChecking for other functional references (excluding comments)...\n');

test_files = {
    '/home/dana/matlab_projects/+transmissionFast/totalTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/otaTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/atmosphericTransmission.m'
};

for i = 1:length(test_files)
    if exist(test_files{i}, 'file')
        content = fileread(test_files{i});
        lines = strsplit(content, '\n');
        
        for j = 1:length(lines)
            line = strtrim(lines{j});
            % Skip comment lines and empty lines
            if isempty(line) || startsWith(line, '%') || startsWith(line, '    %')
                continue;
            end
            
            % Check for transmission. in functional code
            if contains(line, 'transmission.')
                fprintf('Found functional reference in %s line %d: %s\n', test_files{i}, j, line);
            end
        end
    end
end

fprintf('\n✅ Functional reference fixing completed\n');