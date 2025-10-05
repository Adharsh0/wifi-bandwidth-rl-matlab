% Bandwidth Allocation Simulation
% This simulation demonstrates effective starvation prevention with RL
clear all; close all; clc;

%% Configuration Parameters
TOTAL_BANDWIDTH = 100; % Mbps
SIMULATION_TIME = 100; % Increased for better learning
UPDATE_INTERVAL = 0.5; % seconds

% Traffic type characteristics
WEB_BW_PER_USER = 2;    % Mbps per web user
AUDIO_BW_PER_USER = 1;  % Mbps per audio user  
VIDEO_BW_PER_USER = 5;  % Mbps per video user

% Initial number of users
initial_web_users = 5;
initial_audio_users = 3;
initial_video_users = 2;

%% Initialize Data Storage
num_steps = SIMULATION_TIME / UPDATE_INTERVAL;
time_array = zeros(1, num_steps);
web_users = zeros(1, num_steps);
audio_users = zeros(1, num_steps);
video_users = zeros(1, num_steps);
total_users = zeros(1, num_steps);

web_demand = zeros(1, num_steps);
audio_demand = zeros(1, num_steps);
video_demand = zeros(1, num_steps);
total_demand = zeros(1, num_steps);

web_allocated = zeros(1, num_steps);
audio_allocated = zeros(1, num_steps);
video_allocated = zeros(1, num_steps);

web_satisfaction = zeros(1, num_steps);
audio_satisfaction = zeros(1, num_steps);
video_satisfaction = zeros(1, num_steps);

% RL allocation ratios storage
web_ratio_history = zeros(1, num_steps);
audio_ratio_history = zeros(1, num_steps);
video_ratio_history = zeros(1, num_steps);

% Reward history
reward_history = zeros(1, num_steps);

%% Initialize FIXED RL Agent
fprintf('=== INITIALIZING FIXED RL AGENT ===\n');
fprintf('Key improvements:\n');
fprintf('  - Strong starvation penalties (-15 to -18)\n');
fprintf('  - Removed satisfaction cap (detects waste)\n');
fprintf('  - Enhanced action space (19 actions)\n');
fprintf('  - Balance rewards for no starvation (+5)\n\n');

rl_agent = BandwidthRLAgent();
fprintf('RL Agent initialized successfully.\n');
fprintf('Action space size: %d strategic allocations\n', size(rl_agent.action_space, 1));
fprintf('State space size: 288 discretized states\n');
fprintf('Starting bandwidth allocation simulation...\n\n');

%% Create Figure for Dashboard
fig = figure('Name', 'Bandwidth Allocation - Fixed RL Agent', ...
             'NumberTitle', 'off', 'Position', [50, 50, 1400, 900]);

%% Simulation Loop
current_web = initial_web_users;
current_audio = initial_audio_users;
current_video = initial_video_users;

for step = 1:num_steps
    current_time = step * UPDATE_INTERVAL;
    time_array(step) = current_time;
    
    %% Realistic user dynamics
    % Web: Random walk with work hours pattern
    web_change = 0;
    if mod(current_time, 40) < 25  % Work hours
        if rand() < 0.3
            web_change = randi([0, 1]);
        end
    else
        if rand() < 0.25
            web_change = randi([-1, 0]);
        end
    end
    current_web = max(1, current_web + web_change);
    
    % Audio: Stable with occasional changes (calls)
    audio_change = 0;
    if rand() < 0.15
        if rand() < 0.6
            audio_change = 1;
        else
            audio_change = -1;
        end
    end
    current_audio = max(1, current_audio + audio_change);
    
    % Video: Bursty behavior (streaming sessions)
    video_change = 0;
    if current_time > 15 && current_time < 65  % Peak streaming time
        if rand() < 0.35
            video_change = randi([0, 2]);
        end
    else
        if rand() < 0.2
            video_change = randi([-1, 0]);
        end
    end
    current_video = max(1, current_video + video_change);
    
    % Apply upper limits
    current_web = min(20, current_web);
    current_audio = min(8, current_audio);
    current_video = min(15, current_video);
    
    % Store user counts
    web_users(step) = current_web;
    audio_users(step) = current_audio;
    video_users(step) = current_video;
    total_users(step) = current_web + current_audio + current_video;
    
    % Calculate bandwidth demands
    web_demand(step) = current_web * WEB_BW_PER_USER;
    audio_demand(step) = current_audio * AUDIO_BW_PER_USER;
    video_demand(step) = current_video * VIDEO_BW_PER_USER;
    total_demand(step) = web_demand(step) + audio_demand(step) + video_demand(step);
    
    %% FIXED RL AGENT ALLOCATION
    % Create current state
    current_state = struct(...
        'web_users', current_web, ...
        'audio_users', current_audio, ...
        'video_users', current_video, ...
        'web_demand', web_demand(step), ...
        'audio_demand', audio_demand(step), ...
        'video_demand', video_demand(step), ...
        'web_sat', web_satisfaction(max(1,step-1)), ...
        'audio_sat', audio_satisfaction(max(1,step-1)), ...
        'video_sat', video_satisfaction(max(1,step-1)), ...
        'total_demand', total_demand(step));
    
    % Get allocation from RL agent
    [web_ratio, audio_ratio, video_ratio] = rl_agent.predict(current_state);
    
    % Store ratios
    web_ratio_history(step) = web_ratio;
    audio_ratio_history(step) = audio_ratio;
    video_ratio_history(step) = video_ratio;
    
    % Apply allocation
    web_allocated(step) = TOTAL_BANDWIDTH * web_ratio;
    audio_allocated(step) = TOTAL_BANDWIDTH * audio_ratio;
    video_allocated(step) = TOTAL_BANDWIDTH * video_ratio;
    
    % Calculate satisfaction - NO CAP (allows waste detection)
    if web_demand(step) > 0
        web_satisfaction(step) = (web_allocated(step) / web_demand(step)) * 100;
    else
        web_satisfaction(step) = 100;
    end
    
    if audio_demand(step) > 0
        audio_satisfaction(step) = (audio_allocated(step) / audio_demand(step)) * 100;
    else
        audio_satisfaction(step) = 100;
    end
    
    if video_demand(step) > 0
        video_satisfaction(step) = (video_allocated(step) / video_demand(step)) * 100;
    else
        video_satisfaction(step) = 100;
    end
    
    %% Update RL Agent with FIXED reward calculation
    if step > 1
        next_state = struct(...
            'web_users', current_web, ...
            'audio_users', current_audio, ...
            'video_users', current_video, ...
            'web_demand', web_demand(step), ...
            'audio_demand', audio_demand(step), ...
            'video_demand', video_demand(step), ...
            'web_sat', web_satisfaction(step), ...
            'audio_sat', audio_satisfaction(step), ...
            'video_sat', video_satisfaction(step), ...
            'total_demand', total_demand(step));
        
        action_struct = struct(...
            'web_ratio', web_ratio, ...
            'audio_ratio', audio_ratio, ...
            'video_ratio', video_ratio);
        
        % Calculate reward using FIXED reward function
        reward = rl_agent.calculate_reward(current_state, action_struct, next_state);
        reward_history(step) = reward;
        
        % Update Q-table
        rl_agent.update(current_state, action_struct, reward, next_state);
        
        % Display learning progress
        if mod(step, 40) == 0
            min_sat = min([web_satisfaction(step), audio_satisfaction(step), video_satisfaction(step)]);
            fprintf('Step %d/%d | Reward: %6.2f | MinSat: %5.1f%% | Explore: %.3f\n', ...
                step, num_steps, reward, min_sat, rl_agent.exploration_rate);
        end
    end
    
    %% Update Dashboard
    if mod(step, 4) == 0 || step == num_steps
        if ishandle(fig)
            updateFixedDashboard(fig, step, time_array, ...
                           web_users, audio_users, video_users, total_users, ...
                           web_demand, audio_demand, video_demand, total_demand, ...
                           web_allocated, audio_allocated, video_allocated, ...
                           web_satisfaction, audio_satisfaction, video_satisfaction, ...
                           web_ratio_history, audio_ratio_history, video_ratio_history, ...
                           reward_history, rl_agent, TOTAL_BANDWIDTH);
            drawnow;
            pause(0.01);
        else
            fprintf('Figure closed. Stopping simulation.\n');
            break;
        end
    end
end

%% Display Results
fprintf('\n=== SIMULATION COMPLETE ===\n');
fprintf('Total simulation time: %.1f seconds\n', SIMULATION_TIME);
fprintf('Method: Fixed RL Agent with Strong Starvation Prevention\n');

% Calculate performance statistics
congestion_time = sum(total_demand > TOTAL_BANDWIDTH) * UPDATE_INTERVAL;
congestion_percent = (congestion_time / SIMULATION_TIME) * 100;

% Cap satisfaction at 100% for display purposes only
web_sat_display = min(100, web_satisfaction);
audio_sat_display = min(100, audio_satisfaction);
video_sat_display = min(100, video_satisfaction);

starvation_web = sum(web_sat_display < 50) * UPDATE_INTERVAL;
starvation_audio = sum(audio_sat_display < 50) * UPDATE_INTERVAL;
starvation_video = sum(video_sat_display < 50) * UPDATE_INTERVAL;

poor_web = sum(web_sat_display < 70) * UPDATE_INTERVAL;
poor_audio = sum(audio_sat_display < 70) * UPDATE_INTERVAL;
poor_video = sum(video_sat_display < 70) * UPDATE_INTERVAL;

fprintf('\n=== PERFORMANCE STATISTICS ===\n');
fprintf('Network Status:\n');
fprintf('  Congestion Duration: %.1f seconds (%.1f%% of time)\n', congestion_time, congestion_percent);
fprintf('\nAverage Satisfaction (capped display):\n');
fprintf('  Web:   %.1f%%\n', mean(web_sat_display));
fprintf('  Audio: %.1f%%\n', mean(audio_sat_display));
fprintf('  Video: %.1f%%\n', mean(video_sat_display));
fprintf('  Overall: %.1f%%\n', mean([web_sat_display, audio_sat_display, video_sat_display]));

fprintf('\nStarvation Time (<50%% satisfaction):\n');
fprintf('  Web:   %.1f seconds (%.1f%% of time)\n', starvation_web, (starvation_web/SIMULATION_TIME)*100);
fprintf('  Audio: %.1f seconds (%.1f%% of time)\n', starvation_audio, (starvation_audio/SIMULATION_TIME)*100);
fprintf('  Video: %.1f seconds (%.1f%% of time)\n', starvation_video, (starvation_video/SIMULATION_TIME)*100);

fprintf('\nPoor Performance Time (<70%% satisfaction):\n');
fprintf('  Web:   %.1f seconds (%.1f%% of time)\n', poor_web, (poor_web/SIMULATION_TIME)*100);
fprintf('  Audio: %.1f seconds (%.1f%% of time)\n', poor_audio, (poor_audio/SIMULATION_TIME)*100);
fprintf('  Video: %.1f seconds (%.1f%% of time)\n', poor_video, (poor_video/SIMULATION_TIME)*100);

% RL Agent Performance
fprintf('\n=== FIXED RL AGENT PERFORMANCE ===\n');
performance = rl_agent.evaluate_performance();
fprintf('Learning Metrics:\n');
fprintf('  Total Episodes: %d\n', performance.total_episodes);
fprintf('  Average Reward: %.2f\n', performance.average_reward);
fprintf('  Best Reward: %.2f\n', performance.max_reward);
fprintf('  Worst Reward: %.2f\n', performance.min_reward);
fprintf('  Reward Std Dev: %.2f\n', performance.std_reward);
fprintf('  Final Exploration: %.3f\n', performance.current_exploration);

fprintf('\nAgent Configuration:\n');
fprintf('  Q-table Size: %d states x %d actions\n', performance.q_table_size);
fprintf('  Action Space: %d allocations\n', performance.action_space_size);

fprintf('\nRecent Performance (last 100 episodes):\n');
fprintf('  Avg Web Satisfaction: %.1f%%\n', min(100, performance.avg_web_sat));
fprintf('  Avg Audio Satisfaction: %.1f%%\n', min(100, performance.avg_audio_sat));
fprintf('  Avg Video Satisfaction: %.1f%%\n', min(100, performance.avg_video_sat));

% Policy analysis
rl_agent.print_policy_analysis();

%% Create Additional Analysis Plots
fig2 = figure('Name', 'RL Agent Learning Analysis', 'Position', [100, 100, 1400, 600]);

% Create axes manually
ax_analysis1 = axes('Position', [0.08, 0.15, 0.25, 0.75]);
ax_analysis2 = axes('Position', [0.40, 0.15, 0.25, 0.75]);
ax_analysis3 = axes('Position', [0.72, 0.15, 0.25, 0.75]);

% Plot 1: Allocation Strategy
axes(ax_analysis1);
plot(time_array, web_ratio_history*100, 'b-', 'LineWidth', 2); hold on;
plot(time_array, audio_ratio_history*100, 'g-', 'LineWidth', 2);
plot(time_array, video_ratio_history*100, 'r-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Allocation Percentage (%)');
title('RL Agent Allocation Strategy');
legend('Web %', 'Audio %', 'Video %', 'Location', 'best');
grid on;

% Plot 2: Stacked Allocation
axes(ax_analysis2);
area(time_array, [web_ratio_history; audio_ratio_history; video_ratio_history]' * 100);
colormap(ax_analysis2, [0.2 0.6 1.0; 0.1 0.7 0.3; 0.8 0.2 0.4]);
xlabel('Time (s)');
ylabel('Allocation Percentage (%)');
title('Stacked Bandwidth Allocation');
legend('Web', 'Audio', 'Video', 'Location', 'best');
ylim([0 100]);
grid on;

% Plot 3: Reward History
axes(ax_analysis3);
plot(time_array, reward_history, 'm-', 'LineWidth', 1.5);
hold on;
plot(time_array, movmean(reward_history, 20), 'k-', 'LineWidth', 2.5);
yline(0, 'r--', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Reward');
title('Learning Progress (Reward over Time)');
legend('Instant Reward', 'Moving Average (20)', 'Location', 'best');
grid on;

fprintf('\nFixed RL Agent Simulation Complete!\n');
fprintf('Key Improvements Demonstrated:\n');
fprintf('  - Starvation prevention through strong penalties\n');
fprintf('  - Bandwidth waste reduction through overallocation penalties\n');
fprintf('  - Balanced performance across all traffic types\n');
fprintf('  - Adaptive learning from network conditions\n\n');

%% Enhanced Dashboard Update Function 
function updateFixedDashboard(fig, current_step, time_array, ...
                        web_users, audio_users, video_users, total_users, ...
                        web_demand, audio_demand, video_demand, total_demand, ...
                        web_allocated, audio_allocated, video_allocated, ...
                        web_satisfaction, audio_satisfaction, video_satisfaction, ...
                        web_ratio_history, audio_ratio_history, video_ratio_history, ...
                        reward_history, rl_agent, TOTAL_BANDWIDTH)
    
    figure(fig);
    clf;
    
    % Define colors
    web_color = [0.2, 0.6, 1.0];
    audio_color = [0.1, 0.7, 0.3];
    video_color = [0.8, 0.2, 0.4];
    reward_color = [0.6, 0.2, 0.8];
    
    % Current values
    curr_web_users = web_users(current_step);
    curr_audio_users = audio_users(current_step);
    curr_video_users = video_users(current_step);
    curr_total = total_users(current_step);
    
    curr_web_alloc = web_allocated(current_step);
    curr_audio_alloc = audio_allocated(current_step);
    curr_video_alloc = video_allocated(current_step);
    
    curr_web_sat = web_satisfaction(current_step);
    curr_audio_sat = audio_satisfaction(current_step);
    curr_video_sat = video_satisfaction(current_step);
    
    curr_reward = reward_history(current_step);
    
    % Create layout using manual positioning
    ax1 = axes('Position', [0.05, 0.72, 0.28, 0.23]);
    ax2 = axes('Position', [0.35, 0.72, 0.28, 0.23]);
    ax3 = axes('Position', [0.65, 0.72, 0.30, 0.23]);
    ax4 = axes('Position', [0.05, 0.41, 0.28, 0.23]);
    ax5 = axes('Position', [0.35, 0.41, 0.28, 0.23]);
    ax6 = axes('Position', [0.65, 0.41, 0.30, 0.23]);
    ax7 = axes('Position', [0.05, 0.10, 0.58, 0.23]);
    ax8 = axes('Position', [0.65, 0.10, 0.30, 0.23]);
    
    %% Plot 1: Users Over Time
    axes(ax1);
    hold on;
    plot(time_array(1:current_step), web_users(1:current_step), 'Color', web_color, 'LineWidth', 2);
    plot(time_array(1:current_step), audio_users(1:current_step), 'Color', audio_color, 'LineWidth', 2);
    plot(time_array(1:current_step), video_users(1:current_step), 'Color', video_color, 'LineWidth', 2);
    xlabel('Time (s)');
    ylabel('Number of Users');
    title('Active Users by Traffic Type');
    legend('Web', 'Audio', 'Video', 'Location', 'northwest');
    grid on;
    
    %% Plot 2: Bandwidth Demand vs Capacity
    axes(ax2);
    hold on;
    plot(time_array(1:current_step), web_demand(1:current_step), '--', 'Color', web_color, 'LineWidth', 1.5);
    plot(time_array(1:current_step), audio_demand(1:current_step), '--', 'Color', audio_color, 'LineWidth', 1.5);
    plot(time_array(1:current_step), video_demand(1:current_step), '--', 'Color', video_color, 'LineWidth', 1.5);
    plot(time_array(1:current_step), total_demand(1:current_step), 'k-', 'LineWidth', 2);
    yline(TOTAL_BANDWIDTH, 'r-', 'LineWidth', 2, 'Label', 'Capacity');
    xlabel('Time (s)');
    ylabel('Bandwidth (Mbps)');
    title('Bandwidth Demand vs Capacity');
    legend('Web', 'Audio', 'Video', 'Total', 'Location', 'northwest');
    grid on;
    
    %% Plot 3: Satisfaction Levels (capped at 100 for display)
    axes(ax3);
    hold on;
    plot(time_array(1:current_step), min(100, web_satisfaction(1:current_step)), 'Color', web_color, 'LineWidth', 2);
    plot(time_array(1:current_step), min(100, audio_satisfaction(1:current_step)), 'Color', audio_color, 'LineWidth', 2);
    plot(time_array(1:current_step), min(100, video_satisfaction(1:current_step)), 'Color', video_color, 'LineWidth', 2);
    yline(100, 'g--', 'LineWidth', 1, 'Label', 'Satisfied');
    yline(70, 'y--', 'LineWidth', 1, 'Label', 'Good');
    yline(50, 'r--', 'LineWidth', 1, 'Label', 'Poor');
    xlabel('Time (s)');
    ylabel('Satisfaction (%)');
    title('Service Satisfaction Rate');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest');
    ylim([0, 110]);
    grid on;
    
    %% Plot 4: Current Allocation
    axes(ax4);
    bar_data = [curr_web_alloc, curr_audio_alloc, curr_video_alloc];
    b = bar(1:3, bar_data);
    b.FaceColor = 'flat';
    b.CData(1,:) = web_color;
    b.CData(2,:) = audio_color;
    b.CData(3,:) = video_color;
    set(gca, 'XTickLabel', {'Web', 'Audio', 'Video'});
    ylabel('Bandwidth (Mbps)');
    title(sprintf('Current Allocation\n%.1f/%d Mbps', sum(bar_data), TOTAL_BANDWIDTH));
    ylim([0, TOTAL_BANDWIDTH]);
    grid on;
    
    %% Plot 5: Allocation Ratios
    axes(ax5);
    area_data = [web_ratio_history(1:current_step); 
                audio_ratio_history(1:current_step); 
                video_ratio_history(1:current_step)]' * 100;
    area(time_array(1:current_step), area_data);
    colormap(ax5, [web_color; audio_color; video_color]);
    xlabel('Time (s)');
    ylabel('Allocation (%)');
    title('RL Agent Allocation Strategy');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest');
    ylim([0, 100]);
    grid on;
    
    %% Plot 6: Reward History
    axes(ax6);
    plot(time_array(1:current_step), reward_history(1:current_step), 'Color', reward_color, 'LineWidth', 1.5);
    hold on;
    if current_step > 10
        mov_avg = movmean(reward_history(1:current_step), 10);
        plot(time_array(1:current_step), mov_avg, 'k-', 'LineWidth', 2);
        legend('Reward', 'MA(10)', 'Location', 'southwest');
    else
        legend('Reward', 'Location', 'southwest');
    end
    yline(0, 'r--', 'LineWidth', 1);
    xlabel('Time (s)');
    ylabel('Reward');
    title('RL Learning Progress');
    grid on;
    
    %% Plot 7: User Distribution Pie
    axes(ax7);
    if curr_total > 0
        pie_data = [curr_web_users, curr_audio_users, curr_video_users];
        pie(pie_data);
        colormap(ax7, [web_color; audio_color; video_color]);
        title(sprintf('Current User Distribution\nTotal: %d users', curr_total));
        legend({'Web', 'Audio', 'Video'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    else
        text(0.5, 0.5, 'No Users', 'HorizontalAlignment', 'center');
        title('Current User Distribution');
    end
    
    %% Plot 8: Status Panel
    axes(ax8);
    axis([0 1 0 1]);
    axis off;
    
    % Determine status colors
    min_sat = min([curr_web_sat, curr_audio_sat, curr_video_sat]);
    if min_sat < 50
        status_color = [1, 0.8, 0.8];  % Red for starvation
    elseif min_sat < 70
        status_color = [1, 1, 0.8];    % Yellow for warning
    else
        status_color = [0.8, 1, 0.8];  % Green for good
    end
    
    rectangle('Position', [0, 0, 1, 1], 'FaceColor', status_color, 'EdgeColor', 'black', 'LineWidth', 2);
    
    % Build status text with smaller font and tighter spacing
    status_str = sprintf('\\bfFIXED RL AGENT STATUS\\rm\n\n');
    status_str = [status_str sprintf('Time: %.1f s\n\n', time_array(current_step))];
    
    status_str = [status_str sprintf('\\bfActive Users:\\rm\n')];
    status_str = [status_str sprintf('Web: %d | Audio: %d | Video: %d\n\n', ...
        curr_web_users, curr_audio_users, curr_video_users)];
    
    status_str = [status_str sprintf('\\bfCurrent Allocation:\\rm\n')];
    status_str = [status_str sprintf('Web: %.1f Mbps (%.0f%%)\n', ...
        curr_web_alloc, web_ratio_history(current_step)*100)];
    status_str = [status_str sprintf('Audio: %.1f Mbps (%.0f%%)\n', ...
        curr_audio_alloc, audio_ratio_history(current_step)*100)];
    status_str = [status_str sprintf('Video: %.1f Mbps (%.0f%%)\n\n', ...
        curr_video_alloc, video_ratio_history(current_step)*100)];
    
    status_str = [status_str sprintf('\\bfSatisfaction:\\rm\n')];
    
    % Add color coding for satisfaction
    if curr_web_sat >= 70
        web_status = '\\color[rgb]{0,0.6,0}';
    elseif curr_web_sat >= 50
        web_status = '\\color[rgb]{0.8,0.6,0}';
    else
        web_status = '\\color{red}';
    end
    
    if curr_audio_sat >= 70
        audio_status = '\\color[rgb]{0,0.6,0}';
    elseif curr_audio_sat >= 50
        audio_status = '\\color[rgb]{0.8,0.6,0}';
    else
        audio_status = '\\color{red}';
    end
    
    if curr_video_sat >= 70
        video_status = '\\color[rgb]{0,0.6,0}';
    elseif curr_video_sat >= 50
        video_status = '\\color[rgb]{0.8,0.6,0}';
    else
        video_status = '\\color{red}';
    end
    
    status_str = [status_str sprintf('%sWeb: %.0f%%\\rm | ', web_status, min(100, curr_web_sat))];
    status_str = [status_str sprintf('%sAudio: %.0f%%\\rm | ', audio_status, min(100, curr_audio_sat))];
    status_str = [status_str sprintf('%sVideo: %.0f%%\\rm\n\n', video_status, min(100, curr_video_sat))];
    
    status_str = [status_str sprintf('\\bfRL Metrics:\\rm\n')];
    status_str = [status_str sprintf('Reward: %.2f | Explore: %.3f\n', curr_reward, rl_agent.exploration_rate)];
    status_str = [status_str sprintf('Episodes: %d\n\n', rl_agent.episode_count)];
    
    status_str = [status_str sprintf('\\bfStatus:\\rm ')];
    if total_demand(current_step) > TOTAL_BANDWIDTH
        if min_sat >= 60
            status_str = [status_str sprintf('\\color[rgb]{0,0.6,0}Congestion Managed\\rm')];
        else
            status_str = [status_str sprintf('\\color[rgb]{0.8,0.6,0}Managing Congestion\\rm')];
        end
    else
        if min_sat >= 80
            status_str = [status_str sprintf('\\color[rgb]{0,0.6,0}Optimal\\rm')];
        else
            status_str = [status_str sprintf('\\color[rgb]{0,0.6,0}Normal\\rm')];
        end
    end
    
    text(0.05, 0.95, status_str, 'FontSize', 7.5, 'VerticalAlignment', 'top', 'Interpreter', 'tex');
end