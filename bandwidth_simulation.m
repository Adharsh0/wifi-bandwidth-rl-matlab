% Bandwidth Allocation Simulation - Proportional Allocation Problem
% This simulation shows the bandwidth starvation problem without RL
clear all; close all; clc;

%% Configuration Parameters
TOTAL_BANDWIDTH = 100; % Mbps
SIMULATION_TIME = 100; % seconds
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

%% Create Figure for Dashboard
fig = figure('Name', 'Bandwidth Allocation Dashboard - Proportional Problem', ...
             'NumberTitle', 'off', 'Position', [100, 100, 1200, 700]);

%% Simulation Loop
current_web = initial_web_users;
current_audio = initial_audio_users;
current_video = initial_video_users;

fprintf('Starting simulation with Proportional Allocation...\n');

for step = 1:num_steps
    current_time = step * UPDATE_INTERVAL;
    time_array(step) = current_time;
    
    % Simulate dynamic user changes
    % Users increase/decrease randomly with some patterns
    
    % Web users spike during certain times
    if mod(current_time, 30) < 15
        user_change = randi([-1, 2]); % More likely to increase
    else
        user_change = randi([-2, 1]); % More likely to decrease
    end
    current_web = max(0, current_web + user_change);
    
    % Audio users change moderately
    if rand() < 0.3
        current_audio = max(0, current_audio + randi([-1, 1]));
    end
    
    % Video users have high growth pattern (showing the problem)
    if current_time > 20 && current_time < 60
        % Video streaming becomes popular - causes starvation
        if rand() < 0.4
            current_video = current_video + randi([0, 2]);
        end
    else
        if rand() < 0.3
            current_video = max(0, current_video + randi([-1, 0]));
        end
    end
    
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
    
    % Proportional allocation (fair share - shows the problem)
    if total_demand(step) <= TOTAL_BANDWIDTH
        % All demands can be satisfied
        web_allocated(step) = web_demand(step);
        audio_allocated(step) = audio_demand(step);
        video_allocated(step) = video_demand(step);
    else
        % Proportional allocation based on demand
        allocation_ratio = TOTAL_BANDWIDTH / total_demand(step);
        web_allocated(step) = web_demand(step) * allocation_ratio;
        audio_allocated(step) = audio_demand(step) * allocation_ratio;
        video_allocated(step) = video_demand(step) * allocation_ratio;
    end
    
    % Calculate satisfaction (% of demand met)
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
    
    % Update Dashboard every few steps
    if mod(step, 4) == 0
        updateDashboard(fig, step, time_array, ...
                       web_users, audio_users, video_users, total_users, ...
                       web_demand, audio_demand, video_demand, total_demand, ...
                       web_allocated, audio_allocated, video_allocated, ...
                       web_satisfaction, audio_satisfaction, video_satisfaction, ...
                       TOTAL_BANDWIDTH);
        drawnow;
        pause(0.01); % Small pause for visualization
    end
end

% Final update to show complete simulation
updateDashboard(fig, num_steps, time_array, ...
               web_users, audio_users, video_users, total_users, ...
               web_demand, audio_demand, video_demand, total_demand, ...
               web_allocated, audio_allocated, video_allocated, ...
               web_satisfaction, audio_satisfaction, video_satisfaction, ...
               TOTAL_BANDWIDTH);

% Calculate performance statistics
congestion_time = sum(total_demand > TOTAL_BANDWIDTH) * UPDATE_INTERVAL;
congestion_percent = (congestion_time / SIMULATION_TIME) * 100;

starvation_web = sum(web_satisfaction < 50) * UPDATE_INTERVAL;
starvation_audio = sum(audio_satisfaction < 50) * UPDATE_INTERVAL;
starvation_video = sum(video_satisfaction < 50) * UPDATE_INTERVAL;

fprintf('\n=== SIMULATION COMPLETE ===\n');
fprintf('Total simulation time: %.1f seconds\n', SIMULATION_TIME);
fprintf('Method: Proportional Allocation\n');

fprintf('\n=== PERFORMANCE STATISTICS ===\n');
fprintf('Congestion Duration: %.1f seconds (%.1f%%)\n', congestion_time, congestion_percent);
fprintf('Average Satisfaction:\n');
fprintf('  Web:   %.1f%%\n', mean(web_satisfaction));
fprintf('  Audio: %.1f%%\n', mean(audio_satisfaction));
fprintf('  Video: %.1f%%\n', mean(video_satisfaction));
fprintf('\nStarvation Time (<50%% satisfaction):\n');
fprintf('  Web:   %.1f seconds\n', starvation_web);
fprintf('  Audio: %.1f seconds\n', starvation_audio);
fprintf('  Video: %.1f seconds\n', starvation_video);

if starvation_web > 10 || starvation_audio > 10
    fprintf('\n🚨 PROBLEM CONFIRMED: Bandwidth starvation occurs!\n');
    fprintf('   Proportional allocation fails when video demand is high.\n');
end

disp('Simulation Complete!');

%% Dashboard Update Function
function updateDashboard(fig, current_step, time_array, ...
                        web_users, audio_users, video_users, total_users, ...
                        web_demand, audio_demand, video_demand, total_demand, ...
                        web_allocated, audio_allocated, video_allocated, ...
                        web_satisfaction, audio_satisfaction, video_satisfaction, ...
                        TOTAL_BANDWIDTH)
    
    % Select figure
    figure(fig);
    clf;
    
    % Define colors
    web_color = [0.2, 0.6, 1.0];      % Blue
    audio_color = [0.9, 0.6, 0.2];    % Orange
    video_color = [0.8, 0.2, 0.4];    % Red
    
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
    
    % Create 2x3 layout manually for compatibility
    ax1 = axes('Position', [0.07, 0.72, 0.60, 0.23]);
    ax2 = axes('Position', [0.72, 0.72, 0.25, 0.23]);
    ax3 = axes('Position', [0.07, 0.41, 0.60, 0.23]);
    ax4 = axes('Position', [0.72, 0.41, 0.25, 0.23]);
    ax5 = axes('Position', [0.07, 0.10, 0.60, 0.23]);
    ax6 = axes('Position', [0.72, 0.10, 0.25, 0.23]);
    
    %% Plot 1: Number of Users Over Time
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
    hold off;
    
    %% Plot 2: Current User Distribution (Pie Chart)
    axes(ax2);
    if curr_total > 0
        pie_data = [curr_web_users, curr_audio_users, curr_video_users];
        pie(pie_data);
        colormap([web_color; audio_color; video_color]);
        title(sprintf('Current Users\nTotal: %d', curr_total));
        legend({'Web', 'Audio', 'Video'}, 'Location', 'southoutside');
    else
        text(0.5, 0.5, 'No Active Users', 'HorizontalAlignment', 'center');
        title('Current Users');
    end
    
    %% Plot 3: Bandwidth Demand vs Allocation
    axes(ax3);
    hold on;
    plot(time_array(1:current_step), web_demand(1:current_step), '--', 'Color', web_color, 'LineWidth', 1.5);
    plot(time_array(1:current_step), audio_demand(1:current_step), '--', 'Color', audio_color, 'LineWidth', 1.5);
    plot(time_array(1:current_step), video_demand(1:current_step), '--', 'Color', video_color, 'LineWidth', 1.5);
    plot(time_array(1:current_step), total_demand(1:current_step), 'k--', 'LineWidth', 2);
    
    % Horizontal line for total bandwidth
    line([time_array(1), time_array(current_step)], [TOTAL_BANDWIDTH, TOTAL_BANDWIDTH], ...
         'Color', 'red', 'LineStyle', '-', 'LineWidth', 2);
    text(time_array(max(1,current_step-10)), TOTAL_BANDWIDTH+3, 'Total Capacity', ...
         'Color', 'red', 'FontWeight', 'bold', 'FontSize', 10);
    
    xlabel('Time (s)');
    ylabel('Bandwidth (Mbps)');
    title('Bandwidth Demand Over Time');
    legend('Web Demand', 'Audio Demand', 'Video Demand', 'Total Demand', 'Location', 'northwest');
    grid on;
    hold off;
    
    %% Plot 4: Current Bandwidth Allocation (Bar Chart)
    axes(ax4);
    bar_data = [curr_web_alloc, curr_audio_alloc, curr_video_alloc];
    bar(1:3, bar_data);
    colormap([web_color; audio_color; video_color]);
    set(gca, 'XTickLabel', {'Web', 'Audio', 'Video'});
    ylabel('Bandwidth (Mbps)');
    title(sprintf('Current Allocation\n%.1f/%.0f Mbps', sum(bar_data), TOTAL_BANDWIDTH));
    ylim([0, TOTAL_BANDWIDTH]);
    grid on;
    
    %% Plot 5: Satisfaction Rate Over Time
    axes(ax5);
    hold on;
    plot(time_array(1:current_step), web_satisfaction(1:current_step), 'Color', web_color, 'LineWidth', 2);
    plot(time_array(1:current_step), audio_satisfaction(1:current_step), 'Color', audio_color, 'LineWidth', 2);
    plot(time_array(1:current_step), video_satisfaction(1:current_step), 'Color', video_color, 'LineWidth', 2);
    
    % Horizontal lines for thresholds
    line([time_array(1), time_array(current_step)], [100, 100], ...
         'Color', 'green', 'LineStyle', '--', 'LineWidth', 1);
    text(time_array(1), 102, '100% Satisfied', 'Color', 'green', 'FontSize', 9);
    
    line([time_array(1), time_array(current_step)], [50, 50], ...
         'Color', 'red', 'LineStyle', '--', 'LineWidth', 1);
    text(time_array(1), 47, 'Starvation Threshold', 'Color', 'red', 'FontSize', 9);
    
    xlabel('Time (s)');
    ylabel('Satisfaction (%)');
    title('Service Satisfaction Rate (% of Demand Met)');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest');
    ylim([0, 110]);
    grid on;
    hold off;
    
    %% Plot 6: Current Status Text
    axes(ax6);
    axis off;
    
    % Background color based on status
    if total_demand(current_step) > TOTAL_BANDWIDTH && (curr_web_sat < 70 || curr_audio_sat < 70)
        bg_color = [1, 0.9, 0.9];  % Light red for critical
    else
        bg_color = [0.95, 0.95, 0.95]; % Light gray for normal
    end
    rectangle('Position', [0, 0, 1, 1], 'FaceColor', bg_color, 'EdgeColor', 'black', 'LineWidth', 2);
    
    % Status text
    status_text = {};
    status_text{end+1} = 'PROPORTIONAL ALLOCATION';
    status_text{end+1} = '';
    status_text{end+1} = sprintf('Time: %.1f s', time_array(current_step));
    status_text{end+1} = '';
    status_text{end+1} = 'ACTIVE USERS:';
    status_text{end+1} = sprintf('  Web:   %d', curr_web_users);
    status_text{end+1} = sprintf('  Audio: %d', curr_audio_users);
    status_text{end+1} = sprintf('  Video: %d', curr_video_users);
    status_text{end+1} = '';
    status_text{end+1} = 'ALLOCATION:';
    status_text{end+1} = sprintf('  Web:   %.1f Mbps', curr_web_alloc);
    status_text{end+1} = sprintf('  Audio: %.1f Mbps', curr_audio_alloc);
    status_text{end+1} = sprintf('  Video: %.1f Mbps', curr_video_alloc);
    status_text{end+1} = '';
    status_text{end+1} = 'SATISFACTION:';
    
    % Web satisfaction
    if curr_web_sat >= 80
        web_str = sprintf('  Web:   %.0f%%', curr_web_sat);
    elseif curr_web_sat >= 50
        web_str = sprintf('  Web:   %.0f%%', curr_web_sat);
    else
        web_str = sprintf('  Web:   %.0f%%', curr_web_sat);
    end
    
    % Audio satisfaction
    if curr_audio_sat >= 80
        audio_str = sprintf('  Audio: %.0f%%', curr_audio_sat);
    elseif curr_audio_sat >= 50
        audio_str = sprintf('  Audio: %.0f%%', curr_audio_sat);
    else
        audio_str = sprintf('  Audio: %.0f%%', curr_audio_sat);
    end
    
    % Video satisfaction
    video_str = sprintf('  Video: %.0f%%', curr_video_sat);
    
    status_text{end+1} = web_str;
    status_text{end+1} = audio_str;
    status_text{end+1} = video_str;
    status_text{end+1} = '';
    status_text{end+1} = 'SYSTEM STATUS:';
    
    % Problem detection
    if total_demand(current_step) > TOTAL_BANDWIDTH
        if curr_web_sat < 70 || curr_audio_sat < 70
            status_text{end+1} = 'BANDWIDTH STARVATION!';
            status_text{end+1} = 'Video consuming too much';
        else
            status_text{end+1} = 'Network Congested';
            status_text{end+1} = 'Managing load';
        end
    else
        if curr_web_sat < 70 || curr_audio_sat < 70
            status_text{end+1} = 'Check Service Quality';
        else
            status_text{end+1} = 'All Systems Normal';
        end
    end
    
    % Display text with proper spacing
    num_lines = length(status_text);
    start_y = 0.95;
    line_spacing = 0.045;
    
    for i = 1:num_lines
        line_text = status_text{i};
        
        % Determine text properties
        if contains(line_text, 'PROPORTIONAL') || contains(line_text, 'ACTIVE USERS') || ...
           contains(line_text, 'ALLOCATION') || contains(line_text, 'SATISFACTION') || ...
           contains(line_text, 'SYSTEM STATUS')
            font_size = 10;
            font_weight = 'bold';
            color = 'black';
        elseif contains(line_text, 'STARVATION')
            font_size = 10;
            font_weight = 'bold';
            color = 'red';
        elseif contains(line_text, 'Congested') || contains(line_text, 'Check')
            font_size = 9;
            font_weight = 'bold';
            color = 'yellow';
        elseif contains(line_text, 'Normal')
            font_size = 9;
            font_weight = 'bold';
            color = 'green';
        else
            font_size = 9;
            font_weight = 'normal';
            color = 'black';
        end
        
        text(0.05, start_y - (i-1)*line_spacing, line_text, ...
             'VerticalAlignment', 'top', ...
             'HorizontalAlignment', 'left', ...
             'FontSize', font_size, ...
             'FontWeight', font_weight, ...
             'Color', color, ...
             'Interpreter', 'none');
    end
end