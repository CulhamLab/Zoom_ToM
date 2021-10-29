%Setup a network connection to the Unity application so messages can be
%sent
client = tcpip('127.0.0.1',55001,'NetworkRole','Client');
set(client, 'Timeout', 30);

%Set up the loop for the demo.
t0 = clock;
loopCount = 0;
source = 0;
%Loop over a duration of 140 seconds, sending a new command every 10
%seconds
while etime(clock, t0) < 140

  %Every 10 seconds
  source = mod(source, 7);
  switch source
      case 0
          %Show a black screen
          message = "DISPLAY-PICTURE-BLACK_FRAME";
          Send(client, message);
      case 1
          %Show the real person webcam
          message = "DISPLAY-LIVE_NORMAL"
          Send(client, message);
      case 2
          %Show the memoji person webcam
          message = "DISPLAY-LIVE_MEMOJI"
          Send(client, message);
      case 3
          %Switch the display to the real person video
          message = "DISPLAY-VIDEO_NORMAL"
          Send(client, message);
          
          %Get the file path to this script
          [filePath,name,ext] = fileparts(matlab.desktop.editor.getActiveFilename);

          %Get a random video file name
          videoFileName = strcat(string(randi(38)),"_question.mp4");
          %Build the file path to the video
          videoFilePath = fullfile(filePath,"Human",videoFileName);
          %Build the final message to send to Unity
          message = strcat("PLAY-VIDEO_NORMAL","-",videoFilePath);
          Send(client, message);
      case 4
          message = "DISPLAY-VIDEO_MEMOJI"
          Send(client, message);
          
          [filePath,name,ext] = fileparts(matlab.desktop.editor.getActiveFilename);

          videoFileName = strcat(string(randi(38)),"_question.mp4");
          videoFilePath = fullfile(filePath,"Memoji",videoFileName);
          message = strcat("PLAY-VIDEO_MEMOJI","-",videoFilePath);
          Send(client, message);
      case 5
          %Write the message you want to show in Unity  
          textToShowOnScreen = "The bomb will go off in 30 seconds...";
          %Build the message
          message = strcat("DISPLAY-TEXT-MESSAGE","-",textToShowOnScreen);
          %Send the message
          Send(client, message);
      case 6
          
          %Get the file path to this matlab script
          [filePath,name,ext] = fileparts(matlab.desktop.editor.getActiveFilename);
          
          %For the sake the demo choose a different picture based on the
          %loop iteration
          if(loopCount == 0)
            pictureFilePath = fullfile(filePath,"correct_response_04.jpeg");
          elseif(loopCount == 1)
            pictureFilePath = fullfile(filePath,"incorrect_response_04.jpeg");
          end
          
          %Build the message from three parts:
          %1. "DISPLAY-PICTURE-FILE"
          %2. "-"
          %3. "F:\TCPIP\incorrect_response_04.jpeg"
          message = strcat("DISPLAY-PICTURE-FILE","-",pictureFilePath);
          
          %Send the message to the Unity application
          Send(client, message);
          loopCount = 1;
  end
 
  pause(10);
  source = source + 1;
end

 message = "DISPLAY-PICTURE-BLACK_FRAME";
 Send(client, message);
         
function Send(client, message)
    fopen(client);
    fwrite(client, message);
    fclose(client);
    fprintf('%s\n',message);
end