function Michaela_Eva_Zoom (participant_number , run_number) 
%output file name (8 characters) 
filename_edf = 'testtwo.edf';
full_path_to_put_edf = [pwd filesep filename_edf];

%% Parameters
% screen_rect [ 0 0 width length]
% 0 is both, 1 is likely laptop and 2 is likely second screen 
screen_number = max(Screen('Screens'));
screen_rect = [];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

%Work around to turn off sync 
Screen('Preference','SkipSyncTests', 1);

%directories 
p.DIR_DATA = [pwd filesep 'Data' filesep];

%trials
d.number_trials = 3;

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
p.TRIGGER_STIM_TRACKER = true;
p.TRIGGER_CABLE_COM_STRING = 'COM3';

%timings
DURATION_BASELINE_INITIAL = 30;

%buttons
p.KEYS.START.NAME = 'S';
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.QUESTION.NAME = 'Q';
p.KEYS.ANSWER.NAME = 'A';
p.KEYS.REACTION.NAME = 'R'; 
p.KEYS.END.NAME = 'E';
p.KEYS.YES.NAME = 'Y';
p.KEYS.NO.NAME = 'N';
p.KEYS.EXIT.NAME = 'H'; 
p.KEYS.STOP.NAME = 'SPACE'; 
p.KEYS.BUTTON_DEBUG.NAME = 'B';

%%  Check Requirements
%psychtoolbox
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

%Eyelink SDK
try
    Eyelink;
catch
    error('Eyelink requires the SDK from SR Research (http://download.sr-support.com/displaysoftwarerelease/EyeLinkDevKit_Windows_1.11.5.zip)')
end

%Requires directory added to path
if isempty(which('Eyelink.Collection.Connect'))
    error('The "AddToPath" directory must be added to the MATLAB path. Run "setup.m" or add manually.');
end

%% Prep 

%time script started
d.timestamp_start_script = GetTimestamp;

%put inputs in data struct
d.participant_number = participant_number;
d.run_number = run_number;

%filenames 
d.filepath_data = sprintf('%sPAR%02d_RUN%02d_%s.mat', p.DIR_DATA, d.participant_number, d.run_number, d.timestamp_start_script);
d.filepath_error = strrep(d.filepath_data, '.mat', '_ERROR.mat');

%create output directories
if ~exist(p.DIR_DATA, 'dir'), mkdir(p.DIR_DATA); end

%set key values
KbName('UnifyKeyNames');
for key = fields(p.KEYS)'
    key = key{1};
    eval(sprintf('p.KEYS.%s.VALUE = KbName(p.KEYS.%s.NAME);', key, key))
end

%call GetSecs and KbCheck now to improve latency on later calls (it's a MATLAB thing)
for i = 1:10
    GetSecs;
    KbCheck;
end

%% Test
%create window for calibration

try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%try in case of error
%try

%init
DrawFormattedText(window, 'Eyelink Connect', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Connect
    
%set window used
DrawFormattedText(window, 'Eyelink Set Window', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.SetupScreen(window)

%set file to write to
DrawFormattedText(window, 'Eyelink Set EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.SetEDF(filename_edf)

%calibrate
DrawFormattedText(window, 'Eyelink Calibration', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Calibration

%add another screen to say press R to begin 
%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% Wait for Run Start 
fprintf('\n----------------------------------------------\nWaiting for run key (%s) or stop key (%s)...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end
fprintf('Starting...\n'); 

%Time of Experiment start 
t0 = GetSecs;
d.time_start_experiment = t0;

%% Initial Baseline 
fprintf('Initial baseline...\n');

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('00000001'),0]); %turn on 1 for run and 2 for baseline
    WaitSecs(DURATION_BASELINE_INITIAL);
    fwrite(sport, ['mh',bin2dec('00000000'),0]); %turn off 2 
end     

fprintf('Baseline complete...\n'); 

%close screen 
Screen('Close', window);
ShowCursor;
%% Enter Trial Phase 

%% Enter trial phase 

for trial = 1: d.number_trials 
    fprintf('Trial %d of %d...\n', trial, d.number_trials);
    
    phase = 0;
    trial_in_progress = true; 
    
    while trial_in_progress
        [~,keys] = KbWait(-1);
        if any(keys(p.KEYS.QUESTION.VALUE)) && phase == 0 
            fprintf('Start of question period %d...\n', trial);
            fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
            Eyelink('Message','Start of Question Period %d', trial);
            WaitSecs(1);
            while 1
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.END.VALUE))
                    fprintf('End of question period %d...\n', trial);
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                    Eyelink('Message','End of Question Period %d');
                    phase = 1;
                    break;
                elseif any(keys(p.KEYS.EXIT.VALUE))
                    error('Exit Key Pressed');
                else any(keys(p.KEYS.STOP.VALUE))
                    break;
                end
            end
       elseif any(keys(p.KEYS.ANSWER.VALUE)) && phase == 1
            fprintf('Start of answer period %d...\n', trial);
            fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
            Eyelink('Message','Start of Question Period %d', trial);
            WaitSecs(1);
            while 1
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.END.VALUE))
                    fprintf('End of answer period %d...\n', trial);
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                    Eyelink('Message','End of answer Period %d');
                    phase = 2;
                    break;
                elseif any(keys(p.KEYS.EXIT.VALUE))
                    error('Exit Key Pressed');
                else any(keys(p.KEYS.STOP.VALUE))
                    break;
                end
            end 
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2
            Eyelink('Message','Answer correct for trial %d');
            fwrite(sport,['mh',bin2dec('00001000'),0]);
            WaitSecs(0.01)
            fwrite(sport,['mh',bin2dec('00000000'),0]);
            d.trial(trial).answer = yes;
            phase = 3; 
        elseif any(keys(p.KEYS.NO.VALUE)) && phase >= 2
            Eyelink('Message','Answer incorrect for trial %d');
            fwrite(sport,['mh',bin2dec('00001000'),0]);
            WaitSecs(0.01)
            fwrite(sport,['mh',bin2dec('00000000'),0]);
            d.trial(trial).answer = no;
            phase = 3; 
        elseif any(keys(p.KEYS.STOP.VALUE)) && phase == 3
            trial_in_progress = false; 
        else any(keys(p.KEYS.STOP.VALUE))
            break; 
        end
    end


    
    % save data
    fprintf('Saving...\n');
    save(d.filepath_data, 'p', 'd')
end

%% close serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    try
        fclose(sport);
    catch
        warning('Could not close serial connection')
    end
end

%Open screen 
try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%get edf
DrawFormattedText(window, 'Eyelink Pull EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.PullEDF(filename_edf, full_path_to_put_edf)

%shutdown
DrawFormattedText(window, 'Eyelink Shutdown', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Shutdown

%done
Screen('Close', window);
ShowCursor;
disp('Study complete!');

%% Functions
function [timestamp] = GetTimestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));
 
% %catch if error
% catch err
%     %close screen if open
%     Screen('Close', window);
%     
%     %show cursor
%     ShowCursor;
%     
%     %if connection was established...
%     if Eyelink('IsConnected')==1
%         %try to close
%         try
%             Eyelink.Collection.Close
%         catch
%             warning('Could not close Eyelink')
%         end
%         
%         %try to get data
%         try
%             Eyelink.Collection.PullEDF(filename_edf, full_path_to_put_edf)
%         catch
%             warning('Could not pull EDF')
%         end
%         
%         %try to shutddown
%         try
%             Eyelink.Collection.Shutdown
%         catch
%             warning('Could not shut down connection to Eyelink')
%         end
%         
%     end
%     
%     %rethrow error for troubleshooting
%     rethrow(err)
% end
         
end 
end 

             
             
             
             
             
             
             
