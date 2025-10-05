% Comprehensive Comparison: Proportional vs RL Bandwidth Allocation
% Runs both methods with IDENTICAL traffic patterns for fair comparison
clear all; close all; clc;

fprintf('=== BANDWIDTH ALLOCATION COMPARISON ===\n');
fprintf('Running both Proportional and RL allocation methods...\n\n');

%% Configuration Parameters (SAME FOR BOTH)
TOTAL_BANDWIDTH = 80;  % REDUCED from 100 to create more congestion
SIMULATION_TIME = 200;
UPDATE_INTERVAL = 0.5;

WEB_BW_PER_USER = 2;
AUDIO_BW_PER_USER = 1;
VIDEO_BW_PER_USER = 6;  % INCREASED from 5 to stress the network

initial_web_users = 5;
initial_audio_users = 3;
initial_video_users = 3;  % Start with more video users

%% Generate SHARED traffic pattern (ensure fair comparison)
num_steps = SIMULATION_TIME / UPDATE_INTERVAL;
rng(42); % Fixed seed for reproducibility

% Pre-generate user dynamics
web_users_pattern = zeros(1, num_steps);
audio_users_pattern = zeros(1, num_steps);
video_users_pattern = zeros(1, num_steps);

current_web = initial_web_users;
current_audio = initial_audio_users;
current_video = initial_video_users;

for step = 1:num_steps
    current_time = step * UPDATE_INTERVAL;
    
    % Web users
    if mod(current_time, 40) < 25
        if rand() < 0.3
            current_web = current_web + randi([0, 1]);
        end
    else
        if rand() < 0.25
            current_web = max(1, current_web + randi([-1, 0]));
        end
    end
    current_web = min(20, max(1, current_web));
    
    % Audio users
    if rand() < 0.15
        if rand() < 0.6
            current_audio = current_audio + 1;
        else
            current_audio = max(1, current_audio - 1);
        end
    end
    current_audio = min(8, max(1, current_audio));
    
    % Video users (AGGRESSIVE peak growth to guarantee congestion)
    if current_time > 15 && current_time < 100  % Longer peak period
        if rand() < 0.7  % Very high growth probability
            current_video = current_video + randi([1, 3]);  % Always grow by at least 1
        end
    else
        if rand() < 0.3
            current_video = max(1, current_video + randi([-2, 0]));
        end
    end
    current_video = min(25, max(1, current_video));  % Higher cap
    
    web_users_pattern(step) = current_web;
    audio_users_pattern(step) = current_audio;
    video_users_pattern(step) = current_video;
end

%% Run Method 1: Proportional Allocation
fprintf('Running Method 1: Proportional Allocation...\n');
[prop_results] = run_proportional(web_users_pattern, audio_users_pattern, ...
    video_users_pattern, TOTAL_BANDWIDTH, UPDATE_INTERVAL, ...
    WEB_BW_PER_USER, AUDIO_BW_PER_USER, VIDEO_BW_PER_USER);

%% Run Method 2: RL Agent
fprintf('Running Method 2: RL Agent Allocation...\n');
[rl_results] = run_rl_agent(web_users_pattern, audio_users_pattern, ...
    video_users_pattern, TOTAL_BANDWIDTH, UPDATE_INTERVAL, ...
    WEB_BW_PER_USER, AUDIO_BW_PER_USER, VIDEO_BW_PER_USER);

%% Generate Comparison Visualizations
fprintf('\nGenerating comparison visualizations...\n');
create_comparison_plots(prop_results, rl_results, SIMULATION_TIME, TOTAL_BANDWIDTH);

%% Print Comparison Statistics
print_comparison_stats(prop_results, rl_results, SIMULATION_TIME);

fprintf('\n=== COMPARISON COMPLETE ===\n');

%% Function: Run Proportional Allocation
function results = run_proportional(web_users, audio_users, video_users, ...
    TOTAL_BW, UPDATE_INT, WEB_BW, AUDIO_BW, VIDEO_BW)
    
    num_steps = length(web_users);
    time_array = (1:num_steps) * UPDATE_INT;
    
    web_demand = web_users * WEB_BW;
    audio_demand = audio_users * AUDIO_BW;
    video_demand = video_users * VIDEO_BW;
    total_demand = web_demand + audio_demand + video_demand;
    
    web_allocated = zeros(1, num_steps);
    audio_allocated = zeros(1, num_steps);
    video_allocated = zeros(1, num_steps);
    
    for step = 1:num_steps
        if total_demand(step) <= TOTAL_BW
            web_allocated(step) = web_demand(step);
            audio_allocated(step) = audio_demand(step);
            video_allocated(step) = video_demand(step);
        else
            ratio = TOTAL_BW / total_demand(step);
            web_allocated(step) = web_demand(step) * ratio;
            audio_allocated(step) = audio_demand(step) * ratio;
            video_allocated(step) = video_demand(step) * ratio;
        end
    end
    
    web_sat = (web_allocated ./ max(web_demand, 0.1)) * 100;
    audio_sat = (audio_allocated ./ max(audio_demand, 0.1)) * 100;
    video_sat = (video_allocated ./ max(video_demand, 0.1)) * 100;
    
    results = struct(...
        'time', time_array, ...
        'web_users', web_users, ...
        'audio_users', audio_users, ...
        'video_users', video_users, ...
        'web_demand', web_demand, ...
        'audio_demand', audio_demand, ...
        'video_demand', video_demand, ...
        'total_demand', total_demand, ...
        'web_allocated', web_allocated, ...
        'audio_allocated', audio_allocated, ...
        'video_allocated', video_allocated, ...
        'web_sat', web_sat, ...
        'audio_sat', audio_sat, ...
        'video_sat', video_sat);
end

%% Function: Run RL Agent
function results = run_rl_agent(web_users, audio_users, video_users, ...
    TOTAL_BW, UPDATE_INT, WEB_BW, AUDIO_BW, VIDEO_BW)
    
    num_steps = length(web_users);
    time_array = (1:num_steps) * UPDATE_INT;
    
    web_demand = web_users * WEB_BW;
    audio_demand = audio_users * AUDIO_BW;
    video_demand = video_users * VIDEO_BW;
    total_demand = web_demand + audio_demand + video_demand;
    
    web_allocated = zeros(1, num_steps);
    audio_allocated = zeros(1, num_steps);
    video_allocated = zeros(1, num_steps);
    web_sat = zeros(1, num_steps);
    audio_sat = zeros(1, num_steps);
    video_sat = zeros(1, num_steps);
    
    rl_agent = BandwidthRLAgent();
    
    for step = 1:num_steps
        state = struct(...
            'web_users', web_users(step), ...
            'audio_users', audio_users(step), ...
            'video_users', video_users(step), ...
            'web_demand', web_demand(step), ...
            'audio_demand', audio_demand(step), ...
            'video_demand', video_demand(step), ...
            'web_sat', web_sat(max(1, step-1)), ...
            'audio_sat', audio_sat(max(1, step-1)), ...
            'video_sat', video_sat(max(1, step-1)), ...
            'total_demand', total_demand(step));
        
        [web_ratio, audio_ratio, video_ratio] = rl_agent.predict(state);
        
        web_allocated(step) = TOTAL_BW * web_ratio;
        audio_allocated(step) = TOTAL_BW * audio_ratio;
        video_allocated(step) = TOTAL_BW * video_ratio;
        
        web_sat(step) = (web_allocated(step) / max(web_demand(step), 0.1)) * 100;
        audio_sat(step) = (audio_allocated(step) / max(audio_demand(step), 0.1)) * 100;
        video_sat(step) = (video_allocated(step) / max(video_demand(step), 0.1)) * 100;
        
        if step > 1
            next_state = state;
            next_state.web_sat = web_sat(step);
            next_state.audio_sat = audio_sat(step);
            next_state.video_sat = video_sat(step);
            
            action = struct('web_ratio', web_ratio, 'audio_ratio', audio_ratio, 'video_ratio', video_ratio);
            reward = rl_agent.calculate_reward(state, action, next_state);
            rl_agent.update(state, action, reward, next_state);
        end
        
        if mod(step, 80) == 0
            fprintf('  RL Progress: %d/%d episodes\n', step, num_steps);
        end
    end
    
    results = struct(...
        'time', time_array, ...
        'web_users', web_users, ...
        'audio_users', audio_users, ...
        'video_users', video_users, ...
        'web_demand', web_demand, ...
        'audio_demand', audio_demand, ...
        'video_demand', video_demand, ...
        'total_demand', total_demand, ...
        'web_allocated', web_allocated, ...
        'audio_allocated', audio_allocated, ...
        'video_allocated', video_allocated, ...
        'web_sat', web_sat, ...
        'audio_sat', audio_sat, ...
        'video_sat', video_sat, ...
        'agent', rl_agent);
end

%% Function: Create Comparison Plots
function create_comparison_plots(prop, rl, sim_time, total_bw)
    
    figure('Name', 'Comparison: Proportional vs RL Agent', ...
           'Position', [50, 50, 1600, 900]);
    
    % Colors
    web_color = [0.2, 0.6, 1.0];
    audio_color = [0.1, 0.7, 0.3];
    video_color = [0.8, 0.2, 0.4];
    
    % Create axes manually to avoid subplot issues
    ax1 = axes('Position', [0.08, 0.55, 0.25, 0.38]);
    ax2 = axes('Position', [0.38, 0.55, 0.25, 0.38]);
    ax3 = axes('Position', [0.68, 0.55, 0.25, 0.38]);
    ax4 = axes('Position', [0.08, 0.10, 0.25, 0.38]);
    ax5 = axes('Position', [0.38, 0.10, 0.25, 0.38]);
    ax6 = axes('Position', [0.68, 0.10, 0.25, 0.38]);
    
    %% Satisfaction Comparison - Proportional
    axes(ax1);
    hold on;
    plot(prop.time, min(100, prop.web_sat), '--', 'Color', web_color, 'LineWidth', 1.5);
    plot(prop.time, min(100, prop.audio_sat), '--', 'Color', audio_color, 'LineWidth', 1.5);
    plot(prop.time, min(100, prop.video_sat), '--', 'Color', video_color, 'LineWidth', 1.5);
    yline(70, 'r--', 'Poor', 'LineWidth', 1);
    yline(50, 'r-', 'Starving', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Satisfaction (%)');
    title('Proportional Allocation');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest');
    ylim([0, 110]);
    grid on;
    
    %% Satisfaction Comparison - RL
    axes(ax2);
    hold on;
    plot(rl.time, min(100, rl.web_sat), '-', 'Color', web_color, 'LineWidth', 2);
    plot(rl.time, min(100, rl.audio_sat), '-', 'Color', audio_color, 'LineWidth', 2);
    plot(rl.time, min(100, rl.video_sat), '-', 'Color', video_color, 'LineWidth', 2);
    yline(70, 'r--', 'Poor', 'LineWidth', 1);
    yline(50, 'r-', 'Starving', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Satisfaction (%)');
    title('RL Agent Allocation');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest');
    ylim([0, 110]);
    grid on;
    
    %% Minimum Satisfaction Comparison
    axes(ax3);
    prop_min = min([prop.web_sat; prop.audio_sat; prop.video_sat], [], 1);
    rl_min = min([rl.web_sat; rl.audio_sat; rl.video_sat], [], 1);
    hold on;
    plot(prop.time, min(100, prop_min), 'r--', 'LineWidth', 2);
    plot(rl.time, min(100, rl_min), 'g-', 'LineWidth', 2);
    yline(70, 'k--', 'Good', 'LineWidth', 1);
    yline(50, 'k-', 'Poor', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Min Satisfaction (%)');
    title('Worst-Case Service Quality');
    legend('Proportional', 'RL Agent', 'Location', 'southwest');
    ylim([0, 110]);
    grid on;
    
    %% Starvation Time Comparison
    axes(ax4);
    prop_starv = [
        sum(prop.web_sat < 50) / length(prop.time) * 100,
        sum(prop.audio_sat < 50) / length(prop.time) * 100,
        sum(prop.video_sat < 50) / length(prop.time) * 100
    ];
    rl_starv = [
        sum(rl.web_sat < 50) / length(rl.time) * 100,
        sum(rl.audio_sat < 50) / length(rl.time) * 100,
        sum(rl.video_sat < 50) / length(rl.time) * 100
    ];
    
    % Create matrix: rows = categories, columns = methods
    starv_data = [prop_starv', rl_starv'];  % 3x2 matrix
    b = bar(starv_data);
    set(gca, 'XTickLabel', {'Web', 'Audio', 'Video'});
    ylabel('Starvation Time (%)');
    title('Starvation Time (<50% Satisfaction)');
    legend('Proportional', 'RL Agent', 'Location', 'northwest');
    grid on;
    
    %% Average Satisfaction Comparison
    axes(ax5);
    prop_avg = [mean(min(100, prop.web_sat)), mean(min(100, prop.audio_sat)), mean(min(100, prop.video_sat))];
    rl_avg = [mean(min(100, rl.web_sat)), mean(min(100, rl.audio_sat)), mean(min(100, rl.video_sat))];
    
    % Create matrix: rows = categories, columns = methods
    avg_data = [prop_avg', rl_avg'];  % 3x2 matrix
    b = bar(avg_data);
    set(gca, 'XTickLabel', {'Web', 'Audio', 'Video'});
    ylabel('Average Satisfaction (%)');
    title('Average Performance');
    legend('Proportional', 'RL Agent', 'Location', 'southwest');
    ylim([0, 110]);
    grid on;
    
    %% Overall Improvement Summary
    axes(ax6);
    axis off;
    
    % Calculate improvements
    prop_overall = mean([prop_avg]);
    rl_overall = mean([rl_avg]);
    improvement = ((rl_overall - prop_overall) / prop_overall) * 100;
    
    prop_min_avg = mean(min(100, prop_min));
    rl_min_avg = mean(min(100, rl_min));
    min_improvement = ((rl_min_avg - prop_min_avg) / prop_min_avg) * 100;
    
    prop_starv_total = mean(prop_starv);
    rl_starv_total = mean(rl_starv);
    starv_reduction = ((prop_starv_total - rl_starv_total) / max(prop_starv_total, 0.1)) * 100;
    
    % Build summary text line by line
    summary_text = {};
    summary_text{end+1} = '\bfCOMPARISON SUMMARY\rm';
    summary_text{end+1} = '';
    summary_text{end+1} = '\bfOverall Satisfaction:\rm';
    summary_text{end+1} = sprintf('  Proportional: %.1f%%', prop_overall);
    summary_text{end+1} = sprintf('  RL Agent: %.1f%%', rl_overall);
    summary_text{end+1} = sprintf('  \\color[rgb]{0,0.6,0}Improvement: +%.1f%%\\rm', improvement);
    summary_text{end+1} = '';
    summary_text{end+1} = '\bfWorst-Case Quality:\rm';
    summary_text{end+1} = sprintf('  Proportional: %.1f%%', prop_min_avg);
    summary_text{end+1} = sprintf('  RL Agent: %.1f%%', rl_min_avg);
    summary_text{end+1} = sprintf('  \\color[rgb]{0,0.6,0}Improvement: +%.1f%%\\rm', min_improvement);
    summary_text{end+1} = '';
    summary_text{end+1} = '\bfStarvation Reduction:\rm';
    summary_text{end+1} = sprintf('  Proportional: %.1f%% of time', prop_starv_total);
    summary_text{end+1} = sprintf('  RL Agent: %.1f%% of time', rl_starv_total);
    summary_text{end+1} = sprintf('  \\color[rgb]{0,0.6,0}Reduction: %.1f%%\\rm', starv_reduction);
    summary_text{end+1} = '';
    summary_text{end+1} = '\bfCONCLUSION:\rm';
    
    if improvement > 2 && starv_reduction > 20
        summary_text{end+1} = '\color[rgb]{0,0.6,0}RL Agent significantly outperforms\rm';
        summary_text{end+1} = '\color[rgb]{0,0.6,0}baseline allocation\rm';
    elseif improvement > 0
        summary_text{end+1} = '\color[rgb]{0.6,0.6,0}RL Agent shows modest\rm';
        summary_text{end+1} = '\color[rgb]{0.6,0.6,0}improvement\rm';
    else
        summary_text{end+1} = '\color{red}RL Agent needs tuning\rm';
    end
    
    % Display text
    num_lines = length(summary_text);
    y_pos = 0.95;
    line_spacing = 0.045;
    
    for i = 1:num_lines
        text(0.1, y_pos - (i-1)*line_spacing, summary_text{i}, ...
             'FontSize', 9, 'VerticalAlignment', 'top', 'Interpreter', 'tex');
    end
end

%% Function: Print Statistics
function print_comparison_stats(prop, rl, sim_time)
    fprintf('\n=== DETAILED COMPARISON STATISTICS ===\n\n');
    
    % Proportional stats
    fprintf('PROPORTIONAL ALLOCATION:\n');
    fprintf('  Average Satisfaction:\n');
    fprintf('    Web:   %.1f%%\n', mean(min(100, prop.web_sat)));
    fprintf('    Audio: %.1f%%\n', mean(min(100, prop.audio_sat)));
    fprintf('    Video: %.1f%%\n', mean(min(100, prop.video_sat)));
    fprintf('  Starvation Time (<50%%):\n');
    fprintf('    Web:   %.1f%% of simulation\n', sum(prop.web_sat < 50) / length(prop.time) * 100);
    fprintf('    Audio: %.1f%% of simulation\n', sum(prop.audio_sat < 50) / length(prop.time) * 100);
    fprintf('    Video: %.1f%% of simulation\n\n', sum(prop.video_sat < 50) / length(prop.time) * 100);
    
    % RL stats
    fprintf('RL AGENT ALLOCATION:\n');
    fprintf('  Average Satisfaction:\n');
    fprintf('    Web:   %.1f%%\n', mean(min(100, rl.web_sat)));
    fprintf('    Audio: %.1f%%\n', mean(min(100, rl.audio_sat)));
    fprintf('    Video: %.1f%%\n', mean(min(100, rl.video_sat)));
    fprintf('  Starvation Time (<50%%):\n');
    fprintf('    Web:   %.1f%% of simulation\n', sum(rl.web_sat < 50) / length(rl.time) * 100);
    fprintf('    Audio: %.1f%% of simulation\n', sum(rl.audio_sat < 50) / length(rl.time) * 100);
    fprintf('    Video: %.1f%% of simulation\n\n', sum(rl.video_sat < 50) / length(rl.time) * 100);
    
    % Improvements
    fprintf('IMPROVEMENTS (RL vs Proportional):\n');
    web_imp = mean(min(100, rl.web_sat)) - mean(min(100, prop.web_sat));
    audio_imp = mean(min(100, rl.audio_sat)) - mean(min(100, prop.audio_sat));
    video_imp = mean(min(100, rl.video_sat)) - mean(min(100, prop.video_sat));
    
    fprintf('  Satisfaction Improvement:\n');
    fprintf('    Web:   %+.1f%%\n', web_imp);
    fprintf('    Audio: %+.1f%%\n', audio_imp);
    fprintf('    Video: %+.1f%%\n', video_imp);
    
    prop_starv = (sum(prop.web_sat < 50) + sum(prop.audio_sat < 50) + sum(prop.video_sat < 50)) / (3 * length(prop.time)) * 100;
    rl_starv = (sum(rl.web_sat < 50) + sum(rl.audio_sat < 50) + sum(rl.video_sat < 50)) / (3 * length(rl.time)) * 100;
    starv_reduction = ((prop_starv - rl_starv) / prop_starv) * 100;
    
    fprintf('  Starvation Reduction: %.1f%%\n', starv_reduction);
end