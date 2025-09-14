% Script to update all transmission. references to transmissionFast. in the +transmissionFast directory
fprintf('Updating namespace references from transmission.* to transmissionFast.*...\n\n');

% Get list of files that need updating
files_with_refs = {
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/correctorTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/mirrorReflectance.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/waterTransmittance.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/umgTransmittance.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/rayleighTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/ozoneTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/aerosolTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+atmospheric/atmosphericTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/skewedGaussianModel.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/rescaleInputData.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/makeWavelengthArray.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/legendreModel_noarr.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/legendreModel.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/chebyshevModel.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/evaluateChebyshevPolynomial.m'
    '/home/dana/matlab_projects/+transmissionFast/+utils/linearFieldCorrection.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/quantumEfficiency.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/otaTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/+instrumental/fieldCorrection.m'
    '/home/dana/matlab_projects/+transmissionFast/+calibrators/calculateTotalFluxCalibrators.m'
    '/home/dana/matlab_projects/+transmissionFast/+calibrators/calculateTotalFluxCalibrators_prevnocells.m'
    '/home/dana/matlab_projects/+transmissionFast/+calibrators/applyTransmissionToCalibrators.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsForAstroImage_search_htmcat.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsForAstroImage.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsWithCoords.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsWithCoordsInterim.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/findCalibratorsForAstroImage_match_catsHTM.m'
    '/home/dana/matlab_projects/+transmissionFast/+data/loadAbsorptionData.m'
    '/home/dana/matlab_projects/+transmissionFast/totalTransmission.m'
    '/home/dana/matlab_projects/+transmissionFast/minimizerLinearLeastSquares.m'
    '/home/dana/matlab_projects/+transmissionFast/minimizerFminGeneric.m'
    '/home/dana/matlab_projects/+transmissionFast/calibratorWorkflow.m'
    '/home/dana/matlab_projects/+transmissionFast/calculateCostFunction.m'
    '/home/dana/matlab_projects/+transmissionFast/calculateAbsolutePhotometry.m'
    '/home/dana/matlab_projects/+transmissionFast/TransmissionOptimizerAdvanced.m'
    '/home/dana/matlab_projects/+transmissionFast/TransmissionOptimizer.m'
    '/home/dana/matlab_projects/+transmissionFast/examples/totalTransmissionDemo.m'
};

% Skip .asv files and README.md - we don't need to update backup/temp files
updated_count = 0;
error_count = 0;

for i = 1:length(files_with_refs)
    file_path = files_with_refs{i};
    fprintf('Processing: %s\n', file_path);
    
    try
        % Read file content
        content = fileread(file_path);
        
        % Count replacements before making them
        num_matches = length(regexp(content, 'transmission\.', 'match'));
        
        if num_matches > 0
            % Replace transmission. with transmissionFast.
            % Use word boundary to avoid partial matches
            new_content = regexprep(content, '\btransmission\.', 'transmissionFast.');
            
            % Write back to file
            fid = fopen(file_path, 'w');
            if fid ~= -1
                fprintf(fid, '%s', new_content);
                fclose(fid);
                fprintf('  ✓ Updated %d references\n', num_matches);
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

fprintf('\n📊 Summary:\n');
fprintf('  Files processed: %d\n', length(files_with_refs));
fprintf('  Files updated: %d\n', updated_count);
fprintf('  Errors: %d\n', error_count);

if error_count == 0
    fprintf('\n✅ All namespace references updated successfully!\n');
    fprintf('🚀 transmissionFast package is now fully self-contained\n');
else
    fprintf('\n⚠ Some files had errors - please check manually\n');
end