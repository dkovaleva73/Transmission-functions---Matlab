% Update remaining transmission. references that were missed
fprintf('Updating remaining transmission. references...\n\n');

% List of files that still have references (excluding /old/ directories and .asv files)
remaining_files = {
    '/home/dana/matlab_projects/+transmissionFast/+utils/makeWavelengthArray.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/rescaleInputData.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/evaluateChebyshevPolynomial.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/legendreModel.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/linearFieldCorrection.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/legendreModel_noarr.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/chebyshevModel.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/skewedGaussianModel.m'
    '/home/dana/matlab_projects/+transmissionFast/calibratorWorkflow.m'
    '/home/dana/matlab_projects/+transmissionFast/calculateAbsolutePhotometry.m'
    '/home/dana/matlab_projects/+transmissionFast/TransmissionOptimizer.m'
    '/home/dana/matlab_projects/+transmissionFast/inputConfig.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/aerosolTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/umgTransmittance.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/atmosphericTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/ozoneTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/rayleighTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/waterTransmittance.m'
    '/home/dana/matlab_projects/+transmissionFast/minimizerFminGeneric.m'
    '/home/dana/matlab_projects/+transmissionFast/+calibrators/applyTransmissionToCalibrators.m'
    '/home/dana/matlab_projects/+transmissionFast/+calibrators/calculateTotalFluxCalibrators.m'
    '/home/dana/matlab_projects/+transmissionFast/+calibrators/calculateTotalFluxCalibrators_prevnocells.m'
    '/home/dana/matlab_projects/+transmissionFast/calculateCostFunction.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsWithCoords.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsForAstroImage.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsForAstroImage_match_catsHTM.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsForAstroImage_search_htmcat.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/loadAbsorptionData.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/correctorTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/mirrorReflectance.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/quantumEfficiency.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/fieldCorrection.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/otaTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/TransmissionOptimizerAdvanced.m'
    '/home/dana/matlab_projects/+transmissionFast/totalTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/minimizerLinearLeastSquares.m'
    '/home/dana/matlab_projects/+transmissionFast/examples/totalTransmissionDemo.m'
};

updated_count = 0;
error_count = 0;

for i = 1:length(remaining_files)
    file_path = remaining_files{i};
    
    % Skip if file doesn't exist
    if ~exist(file_path, 'file')
        continue;
    end
    
    fprintf('Processing: %s\n', file_path);
    
    try
        % Read file content
        content = fileread(file_path);
        
        % Count remaining transmission. references
        matches = regexp(content, '\btransmission\.', 'match');
        num_matches = length(matches);
        
        if num_matches > 0
            % Replace all transmission. with transmissionFast.
            new_content = regexprep(content, '\btransmission\.', 'transmissionFast.');
            
            % Write back to file
            fid = fopen(file_path, 'w');
            if fid ~= -1
                fprintf(fid, '%s', new_content);
                fclose(fid);
                fprintf('  ✓ Updated %d additional references\n', num_matches);
                updated_count = updated_count + 1;
            else
                fprintf('  ⚠ Error writing file\n');
                error_count = error_count + 1;
            end
        else
            fprintf('  - No references found\n');
        end
        
    catch ME
        fprintf('  ⚠ Error processing file: %s\n', ME.message);
        error_count = error_count + 1;
    end
end

fprintf('\n📊 Second Pass Summary:\n');
fprintf('  Files processed: %d\n', length(remaining_files));
fprintf('  Files updated: %d\n', updated_count);
fprintf('  Errors: %d\n', error_count);

% Final verification
fprintf('\nFinal verification - searching for any remaining references...\n');
try
    [status, result] = system('find /home/dana/matlab_projects/+transmissionFast -name "*.m" -not -path "*/old/*" -not -name "*.asv" -exec grep -l "transmission\." {} \;');
    if status == 0 && ~isempty(strtrim(result))
        fprintf('⚠ Still found references in:\n%s\n', result);
    else
        fprintf('✅ No more transmission. references found in active files!\n');
    end
catch
    fprintf('Could not run verification check\n');
end

fprintf('\n🚀 transmissionFast namespace update completed!\n');