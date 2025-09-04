function [ClippedCalibData, outlierMask] = sigmaClip(CalibData, residuals, threshold)
    % Simple sigma clipping utility
    % Remove calibrators whose residuals are beyond threshold * sigma from mean
    %
    % Input:  - CalibData - Calibrator data structure
    %         - residuals - Array of residual values f(x) for each calibrator
    %         - threshold - Sigma threshold (e.g., 3.0 for 3-sigma clipping)
    %
    % Output: - ClippedCalibData - Calibrator data with outliers removed
    %         - outlierMask - Logical array marking which calibrators were outliers
    %
    % Author: D. Kovaleva (Aug 2025)
    
    arguments
        CalibData
        residuals double
        threshold double = 3.0
    end
    
    % Calculate statistics
    residualMean = mean(residuals);
    residualStd = std(residuals);
    
    % Identify outliers
    outlierMask = abs(residuals - residualMean) > threshold * residualStd;
    
    % Remove outliers from calibrator data
    ClippedCalibData = CalibData;
    
    % Remove outliers from main data fields
    ClippedCalibData.Spec = CalibData.Spec(~outlierMask, :);
    ClippedCalibData.Mag = CalibData.Mag(~outlierMask);
    
    % Handle coordinate structure (array of structs)
    if isfield(CalibData, 'Coords')
        coords = CalibData.Coords;
        if isstruct(coords) && numel(coords) == length(outlierMask)
            % Coords is an array of structs, clip it directly
            ClippedCalibData.Coords = coords(~outlierMask);
        elseif isstruct(coords) && ~isempty(fieldnames(coords))
            % Coords is a struct with array fields
            coordFields = fieldnames(coords);
            for i = 1:length(coordFields)
                fieldName = coordFields{i};
                fieldData = coords.(fieldName);
                if numel(fieldData) == length(outlierMask)
                    ClippedCalibData.Coords.(fieldName) = fieldData(~outlierMask);
                end
            end
        end
    end
    
    % Handle LAST data
    if isfield(CalibData, 'LASTData') && istable(CalibData.LASTData)
        ClippedCalibData.LASTData = CalibData.LASTData(~outlierMask, :);
    elseif isfield(CalibData, 'LASTData') && isstruct(CalibData.LASTData)
        lastFields = fieldnames(CalibData.LASTData);
        for i = 1:length(lastFields)
            fieldName = lastFields{i};
            fieldData = CalibData.LASTData.(fieldName);
            if numel(fieldData) == length(outlierMask)
                ClippedCalibData.LASTData.(fieldName) = fieldData(~outlierMask);
            end
        end
    end
    
    % Handle metadata (unchanged)
    if isfield(CalibData, 'Metadata')
        ClippedCalibData.Metadata = CalibData.Metadata;
    end
end