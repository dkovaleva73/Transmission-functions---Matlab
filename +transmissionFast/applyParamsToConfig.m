function Config = applyParamsToConfig(Config, finalParams)
      % Apply all parameters from finalParams to Config
      paramNames = fieldnames(finalParams);
      for i = 1:length(paramNames)
          param = paramNames{i};
          value = finalParams.(param);

          switch param
              case 'Norm_'
                  Config.General.Norm_ = 0.2988831496445217;
              case 'Tau_aod500'
                  Config.Atmospheric.Components.Aerosol.Tau_aod500 = 0.08375337834671366;
              case 'Pwv_cm'
                  Config.Atmospheric.Components.Water.Pwv_cm = 1.4371100676256834;
          %    case {'kx0','ky0','kx','ky','kx2','ky2','kx3','ky3','kx4','ky4','kxy'}
                  Config.FieldCorrection.Python.kx0 = -0.0016950618275757279;
                  Config.FieldCorrection.Python.y0 =0.0;
                  Config.FieldCorrection.Python.kx = -0.00495931952578843;
                  Config.FieldCorrection.Python.ky = -0.0006154822271913218;
                  Config.FieldCorrection.Python.kx2 = 0.0006064606105198322;
                  Config.FieldCorrection.Python.ky2 = 9.667703649363091e-05;
                  Config.FieldCorrection.Python.kx3 = -0.0007659419176615501;
                  Config.FieldCorrection.Python.ky3 = -0.0016183586181117704;
                  Config.FieldCorrection.Python.kx4 = -0.0008628006107489483;
                  Config.FieldCorrection.Python.ky4 = 0.00021427940150431368;
                  Config.FieldCorrection.Python.kxy =-8.595658140819751e-07;
              % Add other parameters as needed
          end
      end
  end

