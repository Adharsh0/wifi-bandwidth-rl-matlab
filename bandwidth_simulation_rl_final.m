% Bandwidth Allocation Simulation with 3 Specialized Servers
% Starvation scenario: Video dominates 90-95% bandwidth, RL agent prevents starvation
clear all; close all; clc;

%% Configuration Parameters
TOTAL_BANDWIDTH = 200; % Mbps - Core network capacity
SIMULATION_TIME = 100; % Increased for better learning
UPDATE_INTERVAL = 0.5; % seconds

% Network Configuration - 3 SPECIALIZED SERVERS ONLY
NUM_SERVERS = 3;
NUM_ACCESS_POINTS = 1;
MAX_USERS_PER_AP = 40;

% Server types and their dedicated ports
WEB_SERVER = 1;
AUDIO_SERVER = 2;  
VIDEO_SERVER = 3;

% Port numbers for traffic identification
WEB_PORT = 80;
AUDIO_PORT = 5060; % SIP/RTP for audio
VIDEO_PORT = 554;  % RTSP for video

% Traffic type characteristics (DEMAND SCENARIO AS REQUESTED)
WEB_BW_PER_USER = 2;    % Mbps per web user - will demand 20-30%
AUDIO_BW_PER_USER = 1;  % Mbps per audio user - will demand 20-30%  
VIDEO_BW_PER_USER = 10; % Mbps per video user - will demand 90-95%

%% Initialize Network Components

% Server configuration - 3 SPECIALIZED SERVERS
servers = struct();
server_names = {'Web_Server', 'Audio_Server', 'Video_Server'};
server_ips = {'192.168.1.10', '192.168.1.11', '192.168.1.12'};
server_ports = [WEB_PORT, AUDIO_PORT, VIDEO_PORT];

for i = 1:NUM_SERVERS
    servers(i).id = i;
    servers(i).name = server_names{i};
    servers(i).ip = server_ips{i};
    servers(i).port = server_ports(i);
    servers(i).type = i;
    servers(i).max_capacity = 100; % High capacity servers
    servers(i).current_load = 0;
    servers(i).connected_users = [];
    servers(i).response_time = 10; % ms base
end

% Access Point configuration
access_points = struct();
ap_names = {'AP-Main'};
ap_locations = {'Central-Location'};

for i = 1:NUM_ACCESS_POINTS
    access_points(i).id = i;
    access_points(i).name = ap_names{i};
    access_points(i).location = ap_locations{i};
    access_points(i).max_users = MAX_USERS_PER_AP;
    access_points(i).connected_users = [];
    access_points(i).signal_strength = 0.9 + rand() * 0.1;
end

% User configuration - CREATE STARVATION SCENARIO
NUM_TOTAL_USERS = 40;
users = struct();

% Create specific user distribution for starvation scenario
% Video users will dominate bandwidth demand
user_types = [ones(1, 10), 2*ones(1, 10), 3*ones(1, 20)]; % 10 web, 10 audio, 20 video
user_types = user_types(randperm(length(user_types))); % Randomize

for i = 1:NUM_TOTAL_USERS
    users(i).id = i;
    users(i).type = user_types(i); % Use predefined distribution
    users(i).device_type = get_device_type(users(i).type);
    users(i).access_point_id = 1;  % All users connect to AP 1
    users(i).server_id = users(i).type; % Connect to corresponding server
    users(i).port = servers(users(i).type).port; % Use server's port
    users(i).active = false;
    users(i).session_start = 0;
    users(i).session_duration = 0;
    users(i).bandwidth_usage = 0;
    users(i).satisfaction = 100;
    users(i).packet_loss = 0;
    
    % Add user to access point
    ap_id = users(i).access_point_id;
    if length(access_points(ap_id).connected_users) < access_points(ap_id).max_users
        access_points(ap_id).connected_users = [access_points(ap_id).connected_users, i];
    end
end

%% Initialize Data Storage
num_steps = SIMULATION_TIME / UPDATE_INTERVAL;
time_array = zeros(1, num_steps);

% Network metrics
server_loads = zeros(NUM_SERVERS, num_steps);
ap_utilization = zeros(NUM_ACCESS_POINTS, num_steps);
network_latency = zeros(1, num_steps);
packet_loss_history = zeros(1, num_steps);

% User metrics
active_users = zeros(3, num_steps); % Web, Audio, Video
user_satisfaction = zeros(3, num_steps);
bandwidth_demand = zeros(3, num_steps);
bandwidth_allocated = zeros(3, num_steps);

% RL allocation ratios storage
web_ratio_history = zeros(1, num_steps);
audio_ratio_history = zeros(1, num_steps);
video_ratio_history = zeros(1, num_steps);

% Reward history
reward_history = zeros(1, num_steps);

% Port-based traffic identification
port_traffic_history = zeros(3, num_steps); % Traffic identified by port

%% Initialize RL Agent
fprintf('=== INITIALIZING RL AGENT FOR STARVATION PREVENTION ===\n');
fprintf('Network Topology:\n');
fprintf('  - 3 Specialized Servers (Web, Audio, Video)\n');
fprintf('  - Traffic identification by ports: Web:%d, Audio:%d, Video:%d\n', WEB_PORT, AUDIO_PORT, VIDEO_PORT);
fprintf('  - %d Total Users (Starvation scenario: Video dominates)\n', NUM_TOTAL_USERS);
fprintf('  - RL Agent preventing starvation for web and audio\n\n');

% Initialize the RL Agent
rl_agent = BandwidthRLAgent();

fprintf('RL Agent initialized successfully.\n');
fprintf('Starting network simulation with starvation scenario...\n\n');

%% Create Network Dashboard
fig = figure('Name', 'Starvation Prevention - 3 Server Setup with Port-Based Traffic', ...
             'NumberTitle', 'off', 'Position', [100, 50, 1400, 900]);

%% Simulation Loop
for step = 1:num_steps
    current_time = step * UPDATE_INTERVAL;
    time_array(step) = current_time;
    
    %% Dynamic User Behavior with STARVATION SCENARIO
    for i = 1:NUM_TOTAL_USERS
        % Session management - Video users more aggressive
        if ~users(i).active
            % Different start probabilities to create starvation scenario
            start_prob = get_starvation_session_probability(current_time, users(i).type);
            if rand() < start_prob
                users(i).active = true;
                users(i).session_start = current_time;
                users(i).session_duration = get_session_duration(users(i).type);
                users(i).bandwidth_usage = get_bandwidth_requirement(users(i).type, WEB_BW_PER_USER, AUDIO_BW_PER_USER, VIDEO_BW_PER_USER);
                
                % Add to server connected users
                server_id = users(i).server_id;
                servers(server_id).connected_users = [servers(server_id).connected_users, i];
            end
        else
            % Check session end
            if current_time - users(i).session_start >= users(i).session_duration
                users(i).active = false;
                server_id = users(i).server_id;
                % Remove from server
                servers(server_id).connected_users = setdiff(servers(server_id).connected_users, i);
            end
        end
    end
    
    %% Calculate Current Network State with PORT-BASED IDENTIFICATION
    % Count active users by type (using port identification)
    web_users_count = 0; audio_users_count = 0; video_users_count = 0;
    web_demand = 0; audio_demand = 0; video_demand = 0;
    
    for i = 1:NUM_TOTAL_USERS
        if users(i).active
            % Identify traffic type by port
            switch users(i).port
                case WEB_PORT
                    web_users_count = web_users_count + 1;
                    web_demand = web_demand + users(i).bandwidth_usage;
                case AUDIO_PORT
                    audio_users_count = audio_users_count + 1;
                    audio_demand = audio_demand + users(i).bandwidth_usage;
                case VIDEO_PORT
                    video_users_count = video_users_count + 1;
                    video_demand = video_demand + users(i).bandwidth_usage;
            end
        end
    end
    
    total_demand = web_demand + audio_demand + video_demand;
    
    % Store user counts and demands
    active_users(1, step) = web_users_count;
    active_users(2, step) = audio_users_count;
    active_users(3, step) = video_users_count;
    bandwidth_demand(1, step) = web_demand;
    bandwidth_demand(2, step) = audio_demand;
    bandwidth_demand(3, step) = video_demand;
    
    % Store port-based traffic identification
    port_traffic_history(1, step) = web_demand;
    port_traffic_history(2, step) = audio_demand;
    port_traffic_history(3, step) = video_demand;
    
    %% Update Server Loads
    for i = 1:NUM_SERVERS
        servers(i).current_load = length(servers(i).connected_users) * ...
            get_bandwidth_per_user(i, WEB_BW_PER_USER, AUDIO_BW_PER_USER, VIDEO_BW_PER_USER);
        server_loads(i, step) = servers(i).current_load;
    end
    
    %% Update Access Point Utilization
    for i = 1:NUM_ACCESS_POINTS
        ap_users = length(access_points(i).connected_users);
        ap_utilization(i, step) = (ap_users / access_points(i).max_users) * 100;
    end
    
    %% RL AGENT ALLOCATION (Starvation Prevention)
    % Create network state for RL agent
    current_state = struct(...
        'web_users', web_users_count, ...
        'audio_users', audio_users_count, ...
        'video_users', video_users_count, ...
        'web_demand', web_demand, ...
        'audio_demand', audio_demand, ...
        'video_demand', video_demand, ...
        'web_sat', user_satisfaction(1, max(1, step-1)), ...
        'audio_sat', user_satisfaction(2, max(1, step-1)), ...
        'video_sat', user_satisfaction(3, max(1, step-1)), ...
        'total_demand', total_demand, ...
        'network_congestion', min(100, (total_demand / TOTAL_BANDWIDTH) * 100));
    
    % Get allocation from RL agent
    [web_ratio, audio_ratio, video_ratio] = rl_agent.predict(current_state);
    
    % Store allocation ratios
    web_ratio_history(step) = web_ratio;
    audio_ratio_history(step) = audio_ratio;
    video_ratio_history(step) = video_ratio;
    
    % Apply allocation
    web_allocated = TOTAL_BANDWIDTH * web_ratio;
    audio_allocated = TOTAL_BANDWIDTH * audio_ratio;
    video_allocated = TOTAL_BANDWIDTH * video_ratio;
    
    bandwidth_allocated(1, step) = web_allocated;
    bandwidth_allocated(2, step) = audio_allocated;
    bandwidth_allocated(3, step) = video_allocated;
    
    %% Calculate Network Performance Metrics
    % Network latency increases with congestion
    load_ratio = total_demand / TOTAL_BANDWIDTH;
    network_latency(step) = 20 + (load_ratio * 80); % 20-100ms
    
    % Packet loss increases with overload
    if total_demand > TOTAL_BANDWIDTH
        overload = (total_demand - TOTAL_BANDWIDTH) / TOTAL_BANDWIDTH;
        packet_loss_history(step) = min(5, overload * 3); % 0-5%
    else
        packet_loss_history(step) = 0.1; % Base packet loss
    end
    
    %% Calculate User Satisfaction with STARVATION DETECTION (IMPROVED)
    for i = 1:NUM_TOTAL_USERS
        if users(i).active
            % Get user's individual bandwidth requirement
            user_bw_requirement = users(i).bandwidth_usage;
            
            % Calculate fair share based on allocation ratios and active users
            switch users(i).type
                case WEB_SERVER
                    total_web_bw = web_allocated;
                    web_users_active = sum([users.active] & [users.type] == WEB_SERVER);
                    if web_users_active > 0
                        fair_share = total_web_bw / web_users_active;
                    else
                        fair_share = 0;
                    end
                case AUDIO_SERVER
                    total_audio_bw = audio_allocated;
                    audio_users_active = sum([users.active] & [users.type] == AUDIO_SERVER);
                    if audio_users_active > 0
                        fair_share = total_audio_bw / audio_users_active;
                    else
                        fair_share = 0;
                    end
                case VIDEO_SERVER
                    total_video_bw = video_allocated;
                    video_users_active = sum([users.active] & [users.type] == VIDEO_SERVER);
                    if video_users_active > 0
                        fair_share = total_video_bw / video_users_active;
                    else
                        fair_share = 0;
                    end
            end
            
            % Calculate base satisfaction (capped at 100%)
            if user_bw_requirement > 0
                bandwidth_sat = min(100, (fair_share / user_bw_requirement) * 100);
            else
                bandwidth_sat = 100;
            end
            
            % Apply network quality penalties
            ap_id = users(i).access_point_id;
            signal_quality = access_points(ap_id).signal_strength;
            latency_penalty = max(0, (network_latency(step) - 50) / 2);
            packet_loss_penalty = packet_loss_history(step) * 30;
            signal_penalty = (1 - signal_quality) * 20;
            
            users(i).satisfaction = max(0, bandwidth_sat - latency_penalty - packet_loss_penalty - signal_penalty);
            users(i).packet_loss = packet_loss_history(step);
        end
    end
    
    % Store satisfaction metrics (SAFE VERSION)
    active_web_indices = find([users.active] & [users.type] == WEB_SERVER);
    active_audio_indices = find([users.active] & [users.type] == AUDIO_SERVER);
    active_video_indices = find([users.active] & [users.type] == VIDEO_SERVER);
    
    if ~isempty(active_web_indices)
        user_satisfaction(1, step) = mean([users(active_web_indices).satisfaction]);
    else
        user_satisfaction(1, step) = 100;
    end
    
    if ~isempty(active_audio_indices)
        user_satisfaction(2, step) = mean([users(active_audio_indices).satisfaction]);
    else
        user_satisfaction(2, step) = 100;
    end
    
    if ~isempty(active_video_indices)
        user_satisfaction(3, step) = mean([users(active_video_indices).satisfaction]);
    else
        user_satisfaction(3, step) = 100;
    end
    
    %% Update RL Agent
    if step > 1
        next_state = struct(...
            'web_users', web_users_count, ...
            'audio_users', audio_users_count, ...
            'video_users', video_users_count, ...
            'web_demand', web_demand, ...
            'audio_demand', audio_demand, ...
            'video_demand', video_demand, ...
            'web_sat', user_satisfaction(1, step), ...
            'audio_sat', user_satisfaction(2, step), ...
            'video_sat', user_satisfaction(3, step), ...
            'total_demand', total_demand, ...
            'network_congestion', min(100, (total_demand / TOTAL_BANDWIDTH) * 100));
        
        action_struct = struct(...
            'web_ratio', web_ratio, ...
            'audio_ratio', audio_ratio, ...
            'video_ratio', video_ratio);
        
        % Calculate reward and update RL agent
        reward = rl_agent.calculate_reward(current_state, action_struct, next_state);
        reward_history(step) = reward;
        
        % Update Q-table
        rl_agent.update(current_state, action_struct, reward, next_state);
        
        % Display learning progress with starvation detection
        if mod(step, 40) == 0
            min_sat = min([user_satisfaction(1, step), user_satisfaction(2, step), user_satisfaction(3, step)]);
            video_dominance = (video_demand / max(1, total_demand)) * 100;
            fprintf('Step %d/%d | Users: W:%d A:%d V:%d | Video: %.0f%% | Reward: %6.2f | MinSat: %5.1f%% | Explore: %.3f\n', ...
                step, num_steps, web_users_count, audio_users_count, video_users_count, video_dominance, reward, min_sat, rl_agent.exploration_rate);
        end
    end
    
    %% Memory management and GUI updates
    if mod(step, 100) == 0
        drawnow; % Force graphics update
        pause(0.01); % Small pause to prevent GUI freezing
    end
    
    %% Update Network Dashboard
    if mod(step, 4) == 0 || step == num_steps
        if ishandle(fig)
            updateStarvationPreventionDashboard(fig, step, time_array, ...
                servers, access_points, users, ...
                active_users, user_satisfaction, bandwidth_demand, bandwidth_allocated, ...
                server_loads, ap_utilization, network_latency, packet_loss_history, ...
                web_ratio_history, audio_ratio_history, video_ratio_history, ...
                reward_history, rl_agent, TOTAL_BANDWIDTH, port_traffic_history);
            drawnow;
            pause(0.01);
        else
            fprintf('Figure closed. Stopping simulation.\n');
            break;
        end
    end
end

%% Display Results
fprintf('\n=== STARVATION PREVENTION SIMULATION COMPLETE ===\n');
fprintf('Network Setup: 3 specialized servers with port-based traffic identification\n');
fprintf('Port Mapping: Web:%d, Audio:%d, Video:%d\n', WEB_PORT, AUDIO_PORT, VIDEO_PORT);
fprintf('Starvation Scenario: Video traffic dominates bandwidth demand\n');
fprintf('RL Agent Role: Dynamic allocation to prevent web/audio starvation\n\n');

% Calculate performance statistics
total_demand_history = bandwidth_demand(1,:) + bandwidth_demand(2,:) + bandwidth_demand(3,:);
congestion_time = sum(total_demand_history > TOTAL_BANDWIDTH) * UPDATE_INTERVAL;
congestion_percent = (congestion_time / SIMULATION_TIME) * 100;

% Average satisfaction
avg_web_sat = mean(user_satisfaction(1, :));
avg_audio_sat = mean(user_satisfaction(2, :));
avg_video_sat = mean(user_satisfaction(3, :));

% Starvation analysis
starvation_web = sum(user_satisfaction(1, :) < 50) * UPDATE_INTERVAL;
starvation_audio = sum(user_satisfaction(2, :) < 50) * UPDATE_INTERVAL;
starvation_video = sum(user_satisfaction(3, :) < 50) * UPDATE_INTERVAL;

% Bandwidth dominance analysis
video_dominance = mean(bandwidth_demand(3, :) ./ max(1, total_demand_history) * 100);
web_dominance = mean(bandwidth_demand(1, :) ./ max(1, total_demand_history) * 100);
audio_dominance = mean(bandwidth_demand(2, :) ./ max(1, total_demand_history) * 100);

fprintf('=== BANDWIDTH DEMAND ANALYSIS ===\n');
fprintf('Video Traffic Dominance: %.1f%% of total demand\n', video_dominance);
fprintf('Web Traffic Share: %.1f%% of total demand\n', web_dominance);
fprintf('Audio Traffic Share: %.1f%% of total demand\n', audio_dominance);

fprintf('\n=== STARVATION PREVENTION RESULTS ===\n');
fprintf('Average User Satisfaction:\n');
fprintf('  Web:   %.1f%% (Target: >70%% to avoid starvation)\n', avg_web_sat);
fprintf('  Audio: %.1f%% (Target: >70%% to avoid starvation)\n', avg_audio_sat);
fprintf('  Video: %.1f%%\n', avg_video_sat);

fprintf('\nStarvation Time (<50%% satisfaction):\n');
fprintf('  Web:   %.1f seconds (%.1f%% of time)\n', starvation_web, (starvation_web/SIMULATION_TIME)*100);
fprintf('  Audio: %.1f seconds (%.1f%% of time)\n', starvation_audio, (starvation_audio/SIMULATION_TIME)*100);
fprintf('  Video: %.1f seconds (%.1f%% of time)\n', starvation_video, (starvation_video/SIMULATION_TIME)*100);

fprintf('\nNetwork Performance:\n');
fprintf('  Congestion Duration: %.1f seconds (%.1f%% of time)\n', congestion_time, congestion_percent);
fprintf('  Average Latency: %.1f ms\n', mean(network_latency));
fprintf('  Average Packet Loss: %.2f%%\n', mean(packet_loss_history));

% RL Agent Performance
performance = rl_agent.evaluate_performance();
fprintf('\n=== RL AGENT PERFORMANCE ===\n');
fprintf('Starvation Prevention Effectiveness: %.1f%%\n', ...
    100 - ((starvation_web + starvation_audio) / (2 * SIMULATION_TIME) * 100));
fprintf('Total Episodes: %d\n', performance.total_episodes);
fprintf('Average Reward: %.2f\n', performance.average_reward);
fprintf('Final Exploration: %.3f\n', performance.current_exploration);
fprintf('Q-table Size: %d states\n', performance.q_table_size);

% Enhanced Performance Analysis
enhanced_performance_analysis(rl_agent, user_satisfaction, bandwidth_demand, bandwidth_allocated, time_array, UPDATE_INTERVAL);

% Print detailed starvation analysis
fprintf('\n=== STARVATION ANALYSIS ===\n');
if starvation_web > 10 || starvation_audio > 10
    fprintf('WARNING: Significant starvation detected in web/audio traffic\n');
    fprintf('RL agent needs more training or parameter tuning\n');
elseif starvation_web > 5 || starvation_audio > 5
    fprintf('MODERATE: Some starvation detected but generally managed\n');
else
    fprintf('SUCCESS: RL agent effectively prevented starvation\n');
end

% Print RL agent policy analysis
rl_agent.print_policy_analysis();

% Plot training progress
rl_agent.plot_training_progress();

% Save the trained agent
rl_agent.save_agent('trained_rl_agent.mat');

%% Enhanced Performance Analysis Function
function enhanced_performance_analysis(rl_agent, user_satisfaction, bandwidth_demand, bandwidth_allocated, time_array, UPDATE_INTERVAL)
    fprintf('\n=== ENHANCED RL AGENT ANALYSIS ===\n');
    
    % Calculate starvation prevention effectiveness
    web_starvation_time = sum(user_satisfaction(1, :) < 50) * UPDATE_INTERVAL;
    audio_starvation_time = sum(user_satisfaction(2, :) < 50) * UPDATE_INTERVAL;
    total_simulation_time = max(time_array);
    
    prevention_effectiveness = 100 * (1 - (web_starvation_time + audio_starvation_time) / (2 * total_simulation_time));
    fprintf('Starvation Prevention Effectiveness: %.1f%%\n', prevention_effectiveness);
    
    % Bandwidth utilization efficiency
    total_allocated = bandwidth_allocated(1,:) + bandwidth_allocated(2,:) + bandwidth_allocated(3,:);
    utilization_efficiency = mean(total_allocated ./ 150 * 100); % 150 Mbps total
    fprintf('Bandwidth Utilization Efficiency: %.1f%%\n', utilization_efficiency);
    
    % RL agent learning analysis
    performance = rl_agent.evaluate_performance();
    fprintf('Q-table Coverage: %.1f%% of states visited\n', ...
        (nnz(any(rl_agent.Q_table, 2)) / size(rl_agent.Q_table, 1)) * 100);
    
    % Action distribution analysis
    fprintf('\nTop 5 Most Used Actions:\n');
    action_counts = rl_agent.analyze_action_distribution();
    [~, top_actions] = sort(action_counts, 'descend');
    for i = 1:min(5, length(top_actions))
        action_idx = top_actions(i);
        action = rl_agent.action_space(action_idx, :);
        fprintf('  Action %2d: [%.2f, %.2f, %.2f] - %d uses\n', ...
            action_idx, action(1), action(2), action(3), action_counts(action_idx));
    end
    
    % Service quality metrics
    fprintf('\n=== SERVICE QUALITY METRICS ===\n');
    fprintf('Web Service Reliability: %.1f%%\n', 100 - (web_starvation_time / total_simulation_time * 100));
    fprintf('Audio Service Reliability: %.1f%%\n', 100 - (audio_starvation_time / total_simulation_time * 100));
    
    % Fairness analysis
    avg_satisfactions = [mean(user_satisfaction(1, :)), mean(user_satisfaction(2, :)), mean(user_satisfaction(3, :))];
    fairness_index = min(avg_satisfactions) / max(avg_satisfactions) * 100;
    fprintf('Fairness Index (min/max satisfaction): %.1f%%\n', fairness_index);
end

%% Network Helper Functions for Starvation Scenario

function device = get_device_type(user_type)
    devices_web = {'Laptop', 'Desktop', 'Tablet'};
    devices_audio = {'Smartphone', 'VoIP Phone', 'Headset'};
    devices_video = {'Smart TV', 'Gaming Console', 'Streaming Device'};
    
    switch user_type
        case 1 % Web
            device = devices_web{randi(length(devices_web))};
        case 2 % Audio
            device = devices_audio{randi(length(devices_audio))};
        case 3 % Video
            device = devices_video{randi(length(devices_video))};
    end
end

function prob = get_starvation_session_probability(time, user_type)
    % Modified probabilities to create starvation scenario
    % Video users are much more aggressive to dominate bandwidth
    
    switch user_type
        case 1 % Web - lower probability
            base_prob = 0.06;
            if mod(time, 40) < 25
                prob = base_prob * 1.3;
            else
                prob = base_prob * 0.4;
            end
        case 2 % Audio - lower probability
            base_prob = 0.05;
            prob = base_prob * 1.1;
        case 3 % Video - high probability to dominate
            base_prob = 0.12;
            if time > 15 && time < 65
                prob = base_prob * 2.5; % Very aggressive during peak
            else
                prob = base_prob * 1.5; % Still aggressive off-peak
            end
    end
end

function duration = get_session_duration(user_type)
    switch user_type
        case 1 % Web
            duration = 8 + rand() * 15;
        case 2 % Audio
            duration = 5 + rand() * 10;
        case 3 % Video - longer sessions
            duration = 25 + rand() * 50;
    end
end

function bw = get_bandwidth_requirement(user_type, web_bw, audio_bw, video_bw)
    switch user_type
        case 1 % Web
            bw = web_bw * (0.8 + rand() * 0.4);  % 1.6-2.4 Mbps
        case 2 % Audio
            bw = audio_bw * (0.9 + rand() * 0.2); % 0.9-1.1 Mbps
        case 3 % Video - high bandwidth
            bw = video_bw * (0.7 + rand() * 0.6); % 10.5-19.5 Mbps
    end
end

function bw_per_user = get_bandwidth_per_user(server_type, web_bw, audio_bw, video_bw)
    switch server_type
        case 1 % Web
            bw_per_user = web_bw;
        case 2 % Audio
            bw_per_user = audio_bw;
        case 3 % Video
            bw_per_user = video_bw;
    end
end

%% Enhanced Dashboard for Starvation Prevention (FIXED INDEX ERROR)
function updateStarvationPreventionDashboard(fig, current_step, time_array, ...
    servers, access_points, users, ...
    active_users, user_satisfaction, bandwidth_demand, bandwidth_allocated, ...
    server_loads, ap_utilization, network_latency, packet_loss_history, ...
    web_ratio_history, audio_ratio_history, video_ratio_history, ...
    reward_history, rl_agent, TOTAL_BANDWIDTH, port_traffic_history)
    
    figure(fig);
    clf;
    
    % Define colors
    web_color = [0.2, 0.6, 1.0];
    audio_color = [0.1, 0.7, 0.3];
    video_color = [0.8, 0.2, 0.4];
    
    % Current values
    curr_web_users = active_users(1, current_step);
    curr_audio_users = active_users(2, current_step);
    curr_video_users = active_users(3, current_step);
    
    curr_web_sat = user_satisfaction(1, current_step);
    curr_audio_sat = user_satisfaction(2, current_step);
    curr_video_sat = user_satisfaction(3, current_step);
    
    curr_reward = reward_history(current_step);
    curr_latency = network_latency(current_step);
    curr_packet_loss = packet_loss_history(current_step);
    
    % Adjusted layout for better visibility
    ax1 = axes('Position', [0.02, 0.72, 0.28, 0.25]); % Network topology
    ax2 = axes('Position', [0.32, 0.72, 0.28, 0.25]); % User distribution
    ax3 = axes('Position', [0.62, 0.72, 0.28, 0.25]); % User satisfaction
    
    ax4 = axes('Position', [0.02, 0.40, 0.28, 0.25]); % Bandwidth demand vs allocation
    ax5 = axes('Position', [0.32, 0.40, 0.28, 0.25]); % RL allocation
    ax6 = axes('Position', [0.62, 0.40, 0.28, 0.25]); % Port-based traffic
    
    ax7 = axes('Position', [0.02, 0.08, 0.28, 0.25]); % Learning progress
    ax8 = axes('Position', [0.32, 0.08, 0.65, 0.25]); % Starvation status panel

    %% Plot 1: 3-Server Network Topology
    axes(ax1);
    hold on;
    axis equal;
    xlim([0 10]);
    ylim([0 10]);
    set(gca, 'FontSize', 8);
    
    % Draw 3 servers at the top
    server_positions = [2, 8; 5, 8; 8, 8];
    server_colors = [web_color; audio_color; video_color];
    
    for i = 1:length(servers)
        % Server rectangle with port information
        rectangle('Position', [server_positions(i,1)-0.7, server_positions(i,2)-0.7, 1.4, 1.4], ...
                 'FaceColor', server_colors(i,:), 'EdgeColor', 'k', 'LineWidth', 2);
        
        % Server label with port
        text(server_positions(i,1), server_positions(i,2)+1.0, servers(i).name, ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
        text(server_positions(i,1), server_positions(i,2)+0.3, sprintf('Port: %d', servers(i).port), ...
            'HorizontalAlignment', 'center', 'FontSize', 7);
        
        % Load indicator
        load_ratio = min(servers(i).current_load / servers(i).max_capacity, 1.5);
        if load_ratio > 0
            radius = 0.2 + load_ratio * 0.3;
            intensity = max(0, min(1, 1 - load_ratio));
            color = [1, intensity, intensity];
            rectangle('Position', [server_positions(i,1)-radius, server_positions(i,2)-radius-1.2, radius*2, radius*2], ...
                     'FaceColor', color, 'EdgeColor', 'r', 'Curvature', [1 1]);
        end
    end
    
    % Draw single access point
    ap_position = [5, 5];
    rectangle('Position', [ap_position(1)-0.5, ap_position(2)-0.5, 1, 1], ...
             'FaceColor', [0.9, 0.9, 0.9], 'EdgeColor', 'k', 'Curvature', [1 1]);
    text(ap_position(1), ap_position(2)+0.8, 'AP-Main', ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
    
    user_count = sum([users.active]);
    text(ap_position(1), ap_position(2), sprintf('%d active', user_count), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
    
    % Draw network connections
    for i = 1:length(servers)
        plot([server_positions(i,1), ap_position(1)], ...
             [server_positions(i,2)-0.7, ap_position(2)+0.5], ...
             'k-', 'LineWidth', 1.5, 'Color', [0.3, 0.3, 0.3]);
    end
    
    title('3-Server Network with Port-Based Traffic', 'FontSize', 11, 'FontWeight', 'bold');
    axis off;
    
    %% Plot 2: User Distribution
    axes(ax2);
    hold on;
    plot(time_array(1:current_step), active_users(1, 1:current_step), 'Color', web_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), active_users(2, 1:current_step), 'Color', audio_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), active_users(3, 1:current_step), 'Color', video_color, 'LineWidth', 2.5);
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Active Users', 'FontSize', 10);
    title('Active Users by Service Type', 'FontSize', 11, 'FontWeight', 'bold');
    legend('Web', 'Audio', 'Video', 'Location', 'northwest', 'FontSize', 9);
    grid on;
    set(gca, 'FontSize', 9);
    
    %% Plot 3: User Satisfaction with Starvation Detection
    axes(ax3);
    hold on;
    plot(time_array(1:current_step), user_satisfaction(1, 1:current_step), 'Color', web_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), user_satisfaction(2, 1:current_step), 'Color', audio_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), user_satisfaction(3, 1:current_step), 'Color', video_color, 'LineWidth', 2.5);
    yline(70, 'g--', 'LineWidth', 1.5, 'Label', 'Satisfied', 'FontSize', 8);
    yline(50, 'r--', 'LineWidth', 2, 'Label', 'STARVATION', 'FontSize', 8, 'Color', 'red');
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Satisfaction (%)', 'FontSize', 10);
    title('User Satisfaction (Starvation Detection)', 'FontSize', 11, 'FontWeight', 'bold');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest', 'FontSize', 9);
    ylim([0, 110]);
    grid on;
    set(gca, 'FontSize', 9);
    
    %% Plot 4: Bandwidth Demand vs Allocation
    axes(ax4);
    hold on;
    
    % Demand lines
    plot(time_array(1:current_step), bandwidth_demand(1, 1:current_step), '--', 'Color', web_color, 'LineWidth', 2);
    plot(time_array(1:current_step), bandwidth_demand(2, 1:current_step), '--', 'Color', audio_color, 'LineWidth', 2);
    plot(time_array(1:current_step), bandwidth_demand(3, 1:current_step), '--', 'Color', video_color, 'LineWidth', 2);
    
    % Allocation lines
    plot(time_array(1:current_step), bandwidth_allocated(1, 1:current_step), '-', 'Color', web_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), bandwidth_allocated(2, 1:current_step), '-', 'Color', audio_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), bandwidth_allocated(3, 1:current_step), '-', 'Color', video_color, 'LineWidth', 2.5);
    
    yline(TOTAL_BANDWIDTH, 'r-', 'LineWidth', 2, 'Label', 'Total Capacity', 'FontSize', 9);
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Bandwidth (Mbps)', 'FontSize', 10);
    title('Demand vs Allocation (Starvation Analysis)', 'FontSize', 11, 'FontWeight', 'bold');
    legend('Web Demand', 'Audio Demand', 'Video Demand', 'Web Alloc', 'Audio Alloc', 'Video Alloc', ...
           'Location', 'northwest', 'FontSize', 8);
    grid on;
    set(gca, 'FontSize', 9);
    
    %% Plot 5: RL Allocation Strategy
    axes(ax5);
    area_data = [web_ratio_history(1:current_step); 
                audio_ratio_history(1:current_step); 
                video_ratio_history(1:current_step)]' * 100;
    area(time_array(1:current_step), area_data, 'LineWidth', 0.5);
    colormap(ax5, [web_color; audio_color; video_color]);
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Allocation (%)', 'FontSize', 10);
    title('RL Agent Bandwidth Allocation Strategy', 'FontSize', 11, 'FontWeight', 'bold');
    legend('Web', 'Audio', 'Video', 'Location', 'southwest', 'FontSize', 9);
    ylim([0, 100]);
    grid on;
    set(gca, 'FontSize', 9);
    
    %% Plot 6: Port-Based Traffic Identification
    axes(ax6);
    hold on;
    plot(time_array(1:current_step), port_traffic_history(1, 1:current_step), 'Color', web_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), port_traffic_history(2, 1:current_step), 'Color', audio_color, 'LineWidth', 2.5);
    plot(time_array(1:current_step), port_traffic_history(3, 1:current_step), 'Color', video_color, 'LineWidth', 2.5);
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Traffic (Mbps)', 'FontSize', 10);
    title('Port-Based Traffic Identification', 'FontSize', 11, 'FontWeight', 'bold');
    legend(sprintf('Web (Port %d)', servers(1).port), ...
           sprintf('Audio (Port %d)', servers(2).port), ...
           sprintf('Video (Port %d)', servers(3).port), ...
           'Location', 'northwest', 'FontSize', 9);
    grid on;
    set(gca, 'FontSize', 9);
    
    %% Plot 7: Learning Progress
    axes(ax7);
    plot(time_array(1:current_step), reward_history(1:current_step), 'm-', 'LineWidth', 2);
    hold on;
    if current_step > 10
        mov_avg = movmean(reward_history(1:current_step), 10);
        plot(time_array(1:current_step), mov_avg, 'k-', 'LineWidth', 2.5);
        legend('Reward', 'MA(10)', 'Location', 'southwest', 'FontSize', 9);
    else
        legend('Reward', 'Location', 'southwest', 'FontSize', 9);
    end
    yline(0, 'r--', 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Reward', 'FontSize', 10);
    title('RL Learning Progress', 'FontSize', 11, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', 9);
    
    %% Plot 8: Starvation Status Panel (FIXED - NO INDEX ERROR)
    axes(ax8);
    axis([0 1 0 1]);
    axis off;
    
    % Calculate current bandwidth percentages
    total_current_demand = bandwidth_demand(1, current_step) + bandwidth_demand(2, current_step) + bandwidth_demand(3, current_step);
    if total_current_demand > 0
        web_percent = (bandwidth_demand(1, current_step) / total_current_demand) * 100;
        audio_percent = (bandwidth_demand(2, current_step) / total_current_demand) * 100;
        video_percent = (bandwidth_demand(3, current_step) / total_current_demand) * 100;
    else
        web_percent = 0; audio_percent = 0; video_percent = 0;
    end
    
    % Determine starvation status
    if curr_web_sat < 50 || curr_audio_sat < 50
        status_color = [1, 0.8, 0.8];  % Red for starvation
        starvation_status = 'STARVATION DETECTED';
        status_text_color = 'red';
    elseif curr_web_sat < 70 || curr_audio_sat < 70
        status_color = [1, 1, 0.8];    % Yellow for warning
        starvation_status = 'AT RISK';
        status_text_color = 'blue';
    else
        status_color = [0.8, 1, 0.8];  % Green for good
        starvation_status = 'NO STARVATION';
        status_text_color = 'green';
    end
    
    % Main panel background
    rectangle('Position', [0, 0, 1, 1], 'FaceColor', status_color, ...
              'EdgeColor', 'black', 'LineWidth', 3);
    
    % Create enough Y positions for all text elements
    num_lines = 25; % Increased to ensure we have enough positions
    y_positions = linspace(0.95, 0.05, num_lines);
    
    % Title
    text(0.02, y_positions(1), 'STARVATION PREVENTION STATUS', ...
         'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    
    % Time and step info
    text(0.02, y_positions(3), sprintf('Time: %.1f s  |  Step: %d/%d', ...
        time_array(current_step), current_step, length(time_array)), ...
        'FontSize', 8, 'HorizontalAlignment', 'left');
    
    % Bandwidth demand distribution
    text(0.02, y_positions(5), 'BANDWIDTH DEMAND DISTRIBUTION', ...
         'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    text(0.02, y_positions(6), sprintf('Web: %.1f%%  |  Audio: %.1f%%  |  Video: %.1f%%', ...
        web_percent, audio_percent, video_percent), 'FontSize', 8, 'HorizontalAlignment', 'left');
    
    % Current allocation
    text(0.02, y_positions(8), 'CURRENT ALLOCATION', ...
         'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    text(0.02, y_positions(9), sprintf('Web: %.0f%%  |  Audio: %.0f%%  |  Video: %.0f%%', ...
        web_ratio_history(current_step)*100, audio_ratio_history(current_step)*100, video_ratio_history(current_step)*100), ...
        'FontSize', 8, 'HorizontalAlignment', 'left');
    
    % User satisfaction
    text(0.02, y_positions(11), 'USER SATISFACTION', ...
         'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    
    % Color-coded satisfaction values
    satisfaction_str = sprintf('Web: %.0f%%  |  Audio: %.0f%%  |  Video: %.0f%%', ...
        curr_web_sat, curr_audio_sat, curr_video_sat);
    text(0.02, y_positions(12), satisfaction_str, 'FontSize', 8, ...
        'HorizontalAlignment', 'left');
    
    % RL Agent status
    text(0.02, y_positions(14), 'RL AGENT STATUS', ...
         'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    text(0.02, y_positions(15), sprintf('Reward: %.2f  |  Explore: %.3f', ...
        curr_reward, rl_agent.exploration_rate), 'FontSize', 8, 'HorizontalAlignment', 'left');
    text(0.02, y_positions(16), sprintf('Episodes: %d', rl_agent.episode_count), ...
        'FontSize', 8, 'HorizontalAlignment', 'left');
    
    % Overall status
    text(0.02, y_positions(18), 'OVERALL STATUS:', ...
         'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    text(0.25, y_positions(18), starvation_status, ...
         'FontSize', 10, 'FontWeight', 'bold', 'Color', status_text_color, 'HorizontalAlignment', 'left');
    
    % Warnings section (using safe indices)
    warning_start_idx = 20;
    warning_count = 0;
    
    if curr_web_sat < 50
        text(0.02, y_positions(warning_start_idx + warning_count), ...
             '⚠ Web traffic experiencing starvation!', ...
             'FontSize', 8, 'Color', 'red', 'HorizontalAlignment', 'left');
        warning_count = warning_count + 1;
    end
    
    if curr_audio_sat < 50
        text(0.02, y_positions(warning_start_idx + warning_count), ...
             '⚠ Audio traffic experiencing starvation!', ...
             'FontSize', 8, 'Color', 'red', 'HorizontalAlignment', 'left');
        warning_count = warning_count + 1;
    end
    
    if video_percent > 85
        text(0.02, y_positions(warning_start_idx + warning_count), ...
             sprintf('⚠ Video dominating bandwidth (%.0f%%)', video_percent), ...
             'FontSize', 8, 'Color', [0.8, 0.6, 0], 'HorizontalAlignment', 'left');
        warning_count = warning_count + 1;
    end
    
    % Network quality at the bottom
    text(0.5, 0.02, sprintf('Network Quality: Latency: %.1f ms | Packet Loss: %.2f%%', ...
        curr_latency, curr_packet_loss), 'FontSize', 8, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end