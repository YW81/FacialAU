clear all;
close all;

addpath(cd());
try_num = 20; % num of runs (trails)
store_ccrate = zeros(try_num,1);
%%%%%%%%%%%%%%%%%%%%%%% TRAINING PHASE
fprintf('Generating Train and Test Indices \n');
%% Count Videos Per Emotions 
initial_directory= cd();

% % parameters for KSVD
% param.L = 3;   % number of elements in each linear combination.
% param.K = 50; % number of dictionary elements
% param.numIteration = 50; % number of iteration to execute the K-SVD algorithm.
% param.errorFlag = 0; % decompose signals until a certain error is reached. do not use fix number of coefficients.
% %param.errorGoal = sigma;
% param.preserveDCAtom = 0;
% param.InitializationMethod =  'DataElements';
% param.displayProgress = 1;

%video_directory='..\DATA\SimpleCropedData\VideoGreaterThan4';
video_directory='../CamA';
new_height = 64;
new_width = 64;

%video_directory='..\DATA\SimpleCropedData\VideoGreaterThan4';
%new_height = 96/2;
%new_width = 84/2;

num_videos_per_emotion=CountVideosPerEmotion(video_directory);
cd(initial_directory);
num_classes=length(num_videos_per_emotion);

total_ccrate=0;
total_confusion_matrix = zeros(num_classes,num_classes);

for t=1:try_num % trial num
    %% Set Training and Testing Indices 
    train_samples_per_class = 5;
    test_samples_per_class = 5;
    train_indices = zeros(num_classes, train_samples_per_class);
    test_indices = zeros(num_classes, test_samples_per_class);

    for i=1:num_classes
         join_indices = randperm(num_videos_per_emotion(i),train_samples_per_class+test_samples_per_class); % random sample trn/tst data witin class
         train_indices(i,:) = join_indices(1:train_samples_per_class);
         test_indices(i,:) = join_indices(train_samples_per_class+1:train_samples_per_class+test_samples_per_class);  
    end

    %% Generate dictionary
    num_frames_per_train_video = 10;
    do_normalize_train=1;
    fprintf('Generating Dictionary \n');
    dictionary = GenerateDictionary(video_directory,train_indices,new_height,new_width,num_frames_per_train_video,do_normalize_train);
    % % add KSVD
    % cd(initial_directory);
    % [dictionary,output]  = KSVD(dictionary,param)
    cd(initial_directory);
    % % visualize the dictionary
    % h1 = figure();
    % for i=1:num_classes*train_samples_per_class
    %     subplot(num_classes,train_samples_per_class,i);
    %     imshow(reshape(dictionary(:,(i-1)*num_frames_per_train_video+1),[new_height,new_width]), [ ]);
    % end
    % saveas(gcf,'..\figure\dictionary.jpg');

    %%%%%%%%%%%%%%%%%%%%%%% TESTING PHASE
    num_frames_per_test_video = 10;
    do_normalize_test=0; % why not normalized


    %lasso_max_iter=100;
    %alpha =10;
    count_matrix=zeros(num_classes,num_classes);
    num_correct_classified=0;
    num_experiments_run=0;


    gparam.group_label = {};
    g_size = train_samples_per_class*num_frames_per_train_video;
    gparam.lambdaL = 15;
    gparam.lambdaG = 4.5;
    gparam.eps = 1e-7;
    gparam.rho = 1.05; 
    gparam.tau = 5/eigs(dictionary'*dictionary,1);
    gparam.global_max_iter=1000;
    for i=1:num_classes
        gparam.group_label{i} = ((i-1)*g_size + 1) : i*g_size;
    end
    for i=1:num_classes
        for j=1:test_samples_per_class
        fprintf('Test Task %d of %d \n',num_experiments_run,num_classes*test_samples_per_class);
        class_num=i;
        test_index=test_indices(i,j);
        test_sequence=GetTestSequence(video_directory,class_num,test_index,new_height,new_width,do_normalize_test);
        cd(initial_directory);

        [matched_label,X_recovered,L_recovered] = ccSolveModel0_gspa(i,j,num_classes,dictionary,test_sequence,num_frames_per_test_video,gparam,new_height,new_width);

        fprintf('Label: Matched %d - Real %d \n',matched_label,i);
        if(matched_label==i)
            num_correct_classified=num_correct_classified+1;
        end
        num_experiments_run=num_experiments_run+1;
        fprintf('Partial Recognition Rate = %f \n',num_correct_classified/num_experiments_run);
        count_matrix(i,matched_label)=count_matrix(i,matched_label)+1;
        end
    end
    ccrate = num_correct_classified/num_experiments_run;
    store_ccrate(t) = ccrate;
    confusion_matrix = count_matrix / test_samples_per_class;
    total_ccrate = total_ccrate + ccrate;
    total_confusion_matrix = total_confusion_matrix + confusion_matrix;
end
    
fprintf('Average Recognition Rate = %f \n',total_ccrate/try_num);
fprintf('Variance of Recognition Rate = %f \n', var(store_ccrate));
fprintf('Average Confusion Matrix  \n');
average_confussion_matrix = total_confusion_matrix / try_num