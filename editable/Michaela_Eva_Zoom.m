function Michaela_Eva_Zoom (participant_number , run_number) 
%% Output files (8 characters) 
cd('C:\Users\evade\Documents\Zoom_project\Memoji_Zoom_Data')

% d.filename_edf = 'testtwo.edf';
% d.full_path_to_put_edf = [pwd filesep d.filename_edf];

%% Debug Settings
p.USE_EYELINK = false;
p.TRIGGER_STIM_TRACKER = false;

if ~p.TRIGGER_STIM_TRACKER    
    warning('One or more debug settings is active!')
end

%% Start Timestamp 

[d.timestamp, d.timestamp_edf] = GetTimestamp;

%% Parameters
% screen_rect [ 0 0 width length]
% 0 is both, 1 is likely laptop and 2 is likely second screen 
screen_number = max(Screen('Screens'));
screen_rect = [ ];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

%Work around to turn off sync 
Screen('Preference','SkipSyncTests', 1);

%directories 
p.DIR_DATA = [pwd filesep 'Data' filesep];
p.DIR.DATA_EDF = [pwd filesep 'Data_EDF' filesep];

%trials
p.number_trials = 3;

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
%p.TRIGGER_STIM_TRACKER = true;
p.TRIGGER_CABLE_COM_STRING = 'COM3';

%timings
p.DURATION_BASELINE = 5;
p.DURATION_BASELINE_FINAL = 5;

%buttons
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.QUESTION.NAME = 'Q';
p.KEYS.ANSWER.NAME = 'A';
p.KEYS.END.NAME = 'E';
p.KEYS.YES.NAME = 'Y';
p.KEYS.NO.NAME = 'N';
p.KEYS.EXIT.NAME = 'H'; 
p.KEYS.STOP.NAME = 'SPACE';
p.KEYS.ABORT.NAME = 'P';

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
p.filepath.data_edf = [p.DIR.DATA_EDF sprintf('Participant_%02d_FromRun%03d_%s.edf', d.participant_number, d.run_number, d.timestamp)];
p.filepath.data_edf_on_system = sprintf('P%02d_%s', d.participant_number, d.timestamp_edf);

%create output directories
if ~exist(p.DIR_DATA, 'dir'), mkdir(p.DIR_DATA); end
if ~exist(p.DIR.DATA_EDF, 'dir'), mkdir(p.DIR.DATA_EDF); end

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

%% Calibrate Eyetracker 
%create window for calibration

try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%init
DrawFormattedText(window, 'Eyelink Connect', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.Connect
else
    Eyelink('InitializeDummy');
end 
    
%set window used
DrawFormattedText(window, 'Eyelink Set Window', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.SetupScreen(window)
else
    Eyelink('InitializeDummy');
end 

%set file to write to
DrawFormattedText(window, 'Eyelink Set EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.SetEDF(p.filepath.data_edf_on_system)
else
    Eyelink('InitializeDummy');
end

%calibrate
DrawFormattedText(window, 'Eyelink Calibration', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.Calibration
else
    Eyelink('InitializeDummy');
end

%add another screen to say press R to begin 
DrawFormattedText(window, 'Waiting for RETURN key to run or H key to exit', 'center', 'center', screen_colour_text);
Screen('Flip', window);

%% Try 
try
%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER.CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% Wait for Run Start 
fprintf('\n----------------------------------------------\nWaiting for run key (%s) or exit key (%s)...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end

fprintf('Starting...\n');
Screen('Flip', window);

%Time of Experiment start 
t0 = GetSecs;
d.time_start_experiment = t0;
d.timestamp_start_experiment = GetTimestamp;

%% Initial Baseline 

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('00000001'),0]);
    WaitSecs(0.05);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
end

fprintf('Initial baseline...\n');
tend = t0 + p.DURATION_BASELINE;
while 1
    ti = GetSecs;
    if ti > tend
        break;
    end
end 
    %Check for exit key to end run
    [~,~,keys] = KbCheck(-1);  
    if any(keys(p.KEYS.EXIT.VALUE))
        error('Exit Key Pressed');
    end 
    
if p.TRIGGER_STIM_TRACKER     
    fwrite(sport, ['mh',bin2dec('00000001'),0]); %turn off 2 
    WaitSecs(0.05);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]);
end   

%KS
%calculate end time of baseline
%calcualte time to set trigger low
%set trigger high
%wait a little
%set trigger low
%while time < end time (wait rest of time)
%check for stop key
%reaches ent time

fprintf('Baseline complete...\n'); 

%close screen 
Screen('Close', window);
ShowCursor;

%% Start Eyetracking Recording 
    Eyelink('StartRecording')

    if p.TRIGGER_STIM_TRACKER     
    fwrite(sport, ['mh',bin2dec('00000001'),0]); %turn off 2 
    WaitSecs(0.05);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]);
    end   
    
%% Enter trial phase 
   fprintf('Starting Run...\n');
   
for trial = 1: p.number_trials 
    d.trial_data(trial).timing.onset = GetSecs - t0;
    d.latest_trial = trial;
    
    Eyelink('Message',sprintf('Event: Start of trial %03d\n', trial));
    fprintf('\nTrial %d (%g sec)\n', trial, d.trial_data(trial).timing.onset);
    
    d.trial_data(trial).correct_response = nan;
    d.trial_data(trial).timing.trigger.reaction = [];
    
    trial_in_progress = true; 
    phase = 0;
    
    while trial_in_progress
        [~,keys] = KbWait(-1); %if any key is pressed that is incorrect the trial section must be restarted 
        if any(keys(p.KEYS.QUESTION.VALUE)) && phase == 0 
            fprintf('Start of question period %d...\n', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
            end
            
            Eyelink('Message','Start of Question Period %d', trial);
            WaitSecs(1);
            while 1
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.END.VALUE))
                    fprintf('End of question period %d...\n', trial);
                    
                    if p.TRIGGER_STIM_TRACKER
                    fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                    d.trial_data(trial).timing.trigger.question_period_end = GetSecs - t0;
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                    end
                    
                    Eyelink('Message','End of Question Period %d', trial);
                    phase = 1;
                    break;
                elseif any(keys(p.KEYS.EXIT.VALUE)) %break is currently breaking out of the larger while loop as well 
                    %ends current trial
                    
                    trial_in_progress = false;
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    d.number_trials = trial;
                    error('Abort key pressed');
                end
            end
       elseif any(keys(p.KEYS.ANSWER.VALUE)) && phase == 1
            fprintf('Start of answer period %d...\n', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.answer_period_start = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]); 
            end
            
            Eyelink('Message','Start of Question Period %d', trial);
            WaitSecs(1);
            while 1
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.END.VALUE))
                    fprintf('End of answer period %d...\n', trial);
                     
                    if p.TRIGGER_STIM_TRACKER
                        fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
                        d.trial_data(trial).timing.trigger.answer_period_end = GetSecs - t0;
                        fwrite(sport,['mh',bin2dec('00000000'),0]); 
                     end
                    
                    Eyelink('Message','End of answer Period %d', trial);
                    phase = 2;
                    break;
                elseif any(keys(p.KEYS.EXIT.VALUE)) %KS revisit this (no abort, etc)
                    %ends current trial
                    trial_in_progress = false;
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    d.number_trials = trial;
                    error('Abort key pressed');
                end
            end 
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= true)
            Eyelink('Message','Answer correct for trial %d', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00001000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = true;
            
            phase = 3; 
        elseif any(keys(p.KEYS.NO.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= false)
            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00001000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = false;

            phase = 3; 
        elseif any(keys(p.KEYS.STOP.VALUE)) && phase == 3
            
            d.trial_data(trial).timing.offset = GetSecs - t0;
            trial_in_progress = false;
        elseif any(keys(p.KEYS.EXIT.VALUE))  
            %ends current trial
            trial_in_progress = false;
            break;
        elseif any(keys(p.KEYS.ABORT.VALUE)) %exit the run
            d.number_trials = trial;
            error('Abort key pressed');
        end
    end

    
    %jitter the trial ITI (add a save of the variable) 
    ITI = [1 2 3 4];
    ITI_index = randi(numel(ITI));
    d.trial_data(trial).trial_end_wait = ITI(ITI_index);
    WaitSecs(d.trial_data(trial).trial_end_wait);
    
    %end of trial and save data
    fprintf('End of trial %03d\n', trial)
    
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',bin2dec('00000001'),0]);
        Eyelink('Message','Event: End of trial %03d\n', trial);
        d.trial_data(trial).timing.offset = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]);
    end
 
    fprintf('Saving...\n');
    save(d.filepath_data, 'p', 'd')
end

%% Stop eyelink recording
fprintf('Eyelink Close');   

if p.USE_EYELINK 
    Eyelink.Collection.Close
else
    Eyelink('InitializeDummy');
end 

%% Final Baseline
%Open blank screen for final baseline
try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect); 
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

Screen('Flip', window);

fprintf('Final baseline...\n');
tend = GetSecs + p.DURATION_BASELINE_FINAL;
while 1
    ti = GetSecs;
    if ti > tend
        break;
    end
    
    [~,~,keys] = KbCheck(-1);  
    if any(keys(p.KEYS.EXIT.VALUE))
        error('Exit Key Pressed');
    end 
end

%% trigger stim tracker (end of exp)
if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('00000001'),0]);
    WaitSecs(0.05);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
end

%% End
d.time_end_experiment = GetSecs;
d.timestamp_end_experiment = GetTimestamp;

%% Done
save(d.filepath_data, 'p', 'd')
disp Complete! 

%% close serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    try
        fclose(sport);
    catch
        warning('Could not close serial connection')
    end
end

%Display shutdown info on experimenter screen
window = Screen('OpenWindow', 1, screen_colour_background, screen_rect); 

%get edf
DrawFormattedText(window, 'Eyelink Pull EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.PullEDF([d.filepath.data_edf_on_system '.edf'], p.DIR.DATA_EDF)
else
    Eyelink('InitializeDummy');
end 

%shutdown
DrawFormattedText(window, 'Eyelink Shutdown', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.Shutdown
else
    Eyelink('InitializeDummy');
end

%done
sca
sca
ShowCursor;
disp('Run complete!');

%% Catch
%catch if error
catch err
    %close screen if open
%     Screen('Close', window);
    sca
    sca
    
    %save everything
    save(['ErrorDump_' d.timestamp_start_script])
    
    %show cursor
    ShowCursor;
    
    %if connection was established...
    if Eyelink('IsConnected')==1
        %try to close
        try
            Eyelink.Collection.Close
        catch
            warning('Could not close Eyelink')
        end
        
        %try to get data
        try
            Eyelink.Collection.PullEDF(d.filename_edf, d.full_path_to_put_edf)
        catch
            warning('Could not pull EDF')
        end
        
        %try to shutddown
        try
            Eyelink.Collection.Shutdown
        catch
            warning('Could not shut down connection to Eyelink')
        end
        
    end 
    
    %rethrow error for troubleshooting
    rethrow(err)
end 

%% Functions
function [timestamp, timestamp_edf] = GetTimestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));
timestamp_edf = sprintf('%02d%02d', c(5:6));
 
         

 

             
             
             
             
             
             
             
