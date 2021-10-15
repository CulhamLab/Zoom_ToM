function movie_test(par_num, run_num)
%% Movie Testing Script

%Parameters
screen_number = max(Screen('Screens'));
screen_rect = [0 0 500 500]; 
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

%Work around to turn off sync
Screen('Preference','SkipSyncTests', 1);

%Directories
p.DIR_ORDERS = [pwd filesep 'Orders' filesep 'Mat Orders' filesep];
p.DIR_VIDEOSTIMS_HUMAN = [pwd filesep 'VideoStims' filesep 'Human' filesep]; 
p.DIR_VIDEOSTIMS_MEMOJI = [pwd filesep 'VideoStims' filesep 'Memoji' filesep]; 

%buttons
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.EXIT.NAME = 'SPACE'; 

%%  Check Requirements
%psychtoolbox
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

%% Prep 

%put inputs in data struct
d.participant_number = par_num;
d.run_number = run_num;

%filenames 
d.filepath_order = sprintf('%sPAR%02d_RUN%02d.mat', p.DIR_ORDERS, d.participant_number, d.run_number);

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

movieDur = 15;

%Read orders 
load(d.filepath_order);
d.order.raw = xls;
d.order.headers = xls(1,:);
d.order.data = xls(2:end,:);

%get number of trials from order  
d.number_trials = size(d.order.data, 1);

%get condition number from order 
d.condition_number = xls{2, 3};

%% Open Window 
try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end
Screen('Flip', window);
    %% Enter trial phase
 fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the trial period or exit key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end

    fprintf('Starting Run...\n');
   
for trial = 1: d.number_trials 
 
    question_number = d.order.data{trial, 2};
    fprintf('\nTrial %d and Question %d\n', trial, question_number);  
    
    if d.condition_number == 3
        movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_HUMAN, question_number); 
    elseif d.condition_number == 4
        movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_MEMOJI, question_number);
    end
    
 fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the next trial or exit key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);    
    while 1
        [~,keys] = KbWait(-1);
        if any(keys(p.KEYS.RUN.VALUE))
            break;
        else any(keys(p.KEYS.EXIT.VALUE))
            sca
            sca
            error ('Exit Key Pressed');
        end
    end
    movie = Screen('OpenMovie', window, movie_filepath);
            rate = 1;
                        WaitSecs(1); %Give the display a moment to recover from change of display mode 
            Screen(window, 'Flip');
            Screen('PlayMovie', movie, rate, 0, 1.0);
            movie_start = GetSecs;
                       
            while(GetSecs - movie_start < movieDur -.2)
                % Wait for next movie frame, retrieve texture handle to it
                tex = Screen('GetMovieImage', window, movie);
                % Valid texture returned? A negative value means end of movie reached:
                if tex<=0
                    % done, break
                    break;
                end
                % Draw the new texture immediately to screen:
                Screen('DrawTexture', window, tex);
                % Update display:
                Screen(window, 'Flip');
                % Release texture:
                Screen('Close', tex);
            end
%             Screen('CloseMovie', movie);
            Screen(window, 'Flip');
end 

sca
sca
            

