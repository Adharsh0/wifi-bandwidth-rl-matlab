classdef BandwidthRLAgent < handle
    % Bandwidth Allocation RL Agent
    % Aggressively prevents starvation by taking bandwidth from video
    
    properties
        % Q-learning parameters
        learning_rate = 0.3;  % Faster learning
        discount_factor = 0.8;  % Focus on immediate rewards
        exploration_rate = 0.7;  % More exploration initially
        exploration_decay = 0.995;  % Faster decay
        min_exploration = 0.1;  % Minimum exploration
        
        % Q-table
        Q_table;
        
        % AGGRESSIVE action space - heavily favors web and audio
        action_space = [
            % EMERGENCY STARVATION PREVENTION (High priority)
            0.40, 0.40, 0.20;   % Protect web+audio, sacrifice video
            0.45, 0.35, 0.20;   % Strong web protection
            0.35, 0.45, 0.20;   % Strong audio protection
            0.50, 0.30, 0.20;   % Very strong web focus
            0.30, 0.50, 0.20;   % Very strong audio focus
            
            % BALANCED WITH VIDEO CONSTRAINT
            0.35, 0.35, 0.30;   % Balanced but limit video
            0.40, 0.30, 0.30;   % Web favored, video limited
            0.30, 0.40, 0.30;   % Audio favored, video limited
            
            % MODERATE PROTECTION
            0.33, 0.33, 0.34;   % Equal but video slightly higher
            0.38, 0.32, 0.30;   % Web priority
            0.32, 0.38, 0.30;   % Audio priority
            
            % VIDEO-HEAVY (only for light load scenarios)
            0.25, 0.25, 0.50;   % Video heavy (use cautiously)
            0.30, 0.25, 0.45;   % Video moderate
            0.25, 0.30, 0.45;   % Video moderate with audio/web balance
            
            % MINIMAL VIDEO ALLOCATIONS
            0.20, 0.40, 0.40;   % Audio priority with some video
            0.40, 0.20, 0.40;   % Web priority with some video
        ];
        
        % Training history
        training_history = [];
        episode_count = 0;
        
        % Starvation prevention parameters
        starvation_threshold = 50;  % Satisfaction below this is starvation
        emergency_threshold = 30;   % Critical starvation level
        
        % Enhanced tracking
        historical_starvation_events = [];
        adaptive_starvation_threshold = 50;
        web_starvation_count = 0;
        audio_starvation_count = 0;
        video_starvation_count = 0;
        performance_history = [];
        
        % Action masking
        use_action_masking = true;
    end
    
    methods
        function obj = BandwidthRLAgent(use_pretrained, pretrained_file)
            % Initialize Q-table
            num_states = 4 * 4 * 4 * 4;  % 256 states (simplified)
            num_actions = size(obj.action_space, 1);
            obj.Q_table = zeros(num_states, num_actions);
            
            % Load pretrained agent if specified
            if nargin >= 1 && use_pretrained && nargin >= 2
                obj = obj.load_pretrained_agent(pretrained_file);
            elseif nargin >= 1 && use_pretrained
                warning('Pretrained file not specified. Initializing new agent.');
            end
            
            fprintf('Aggressive Starvation Prevention RL Agent initialized\n');
            fprintf('Action space: %d actions, State space: %d states\n', num_actions, num_states);
        end
        
        function state_index = discretize_state(obj, web_users, audio_users, video_users, ...
                                              web_demand, audio_demand, video_demand, ...
                                              web_sat, audio_sat, video_sat, total_demand)
            
            % 1. STARVATION EMERGENCY LEVEL (most important feature)
            starvation_level = 0;
            if web_sat < obj.emergency_threshold && web_users > 0
                starvation_level = starvation_level + 2;  % Critical web starvation
                obj.web_starvation_count = obj.web_starvation_count + 1;
            elseif web_sat < obj.starvation_threshold && web_users > 0
                starvation_level = starvation_level + 1;  % Web starvation
            end
            
            if audio_sat < obj.emergency_threshold && audio_users > 0
                starvation_level = starvation_level + 2;  % Critical audio starvation
                obj.audio_starvation_count = obj.audio_starvation_count + 1;
            elseif audio_sat < obj.starvation_threshold && audio_users > 0
                starvation_level = starvation_level + 1;  % Audio starvation
            end
            
            if video_sat < obj.emergency_threshold && video_users > 0
                starvation_level = starvation_level + 1;  % Video starvation (less critical)
                obj.video_starvation_count = obj.video_starvation_count + 1;
            end
            
            starvation_level = min(starvation_level, 4);
            
            % Record starvation event
            if starvation_level > 0
                event = struct('time', datetime, 'level', starvation_level, ...
                              'web_sat', web_sat, 'audio_sat', audio_sat, 'video_sat', video_sat);
                obj.historical_starvation_events = [obj.historical_starvation_events; event];
            end
            
            % 2. NETWORK CONGESTION LEVEL
            congestion_ratio = total_demand / 100;
            if congestion_ratio < 0.6
                congestion_idx = 1;  % Light
            elseif congestion_ratio < 0.8
                congestion_idx = 2;  % Moderate
            elseif congestion_ratio < 1.0
                congestion_idx = 3;  % Heavy
            else
                congestion_idx = 4;  % Overloaded
            end
            
            % 3. VIDEO DOMINANCE LEVEL (how much video is hogging bandwidth)
            total_active_users = web_users + audio_users + video_users;
            if total_active_users > 0
                video_dominance = video_users / total_active_users;
                if video_dominance < 0.4
                    dominance_idx = 1;  % Low video
                elseif video_dominance < 0.6
                    dominance_idx = 2;  % Moderate video
                elseif video_dominance < 0.8
                    dominance_idx = 3;  % High video
                else
                    dominance_idx = 4;  % Very high video
                end
            else
                dominance_idx = 1;
            end
            
            % 4. WORST SATISFACTION (minimum among all services)
            min_satisfaction = min([web_sat, audio_sat, video_sat]);
            if min_satisfaction >= 70
                sat_idx = 1;  % Good
            elseif min_satisfaction >= 50
                sat_idx = 2;  % Fair
            elseif min_satisfaction >= 30
                sat_idx = 3;  % Poor
            else
                sat_idx = 4;  % Critical
            end
            
            % Combine into state index
            state_index = (starvation_level) * 4 * 4 * 4 + ...
                         (congestion_idx-1) * 4 * 4 + ...
                         (dominance_idx-1) * 4 + ...
                         (sat_idx-1);
            
            state_index = min(max(state_index, 1), 256);
        end
        
        function valid_actions = get_valid_actions(obj, state)
            % Get valid actions based on current network conditions
            if ~obj.use_action_masking
                valid_actions = 1:size(obj.action_space, 1);
                return;
            end
            
            % During heavy congestion, restrict video-heavy actions
            if state.total_demand > 80
                video_ratios = obj.action_space(:, 3);
                valid_actions = find(video_ratios <= 0.4);
            % During emergency starvation, use only protective actions
            elseif min([state.web_sat, state.audio_sat, state.video_sat]) < 20
                valid_actions = 1:7;  % First 7 are most protective
            % During moderate congestion, limit video
            elseif state.total_demand > 60
                video_ratios = obj.action_space(:, 3);
                valid_actions = find(video_ratios <= 0.5);
            else
                valid_actions = 1:size(obj.action_space, 1);
            end
        end
        
        function [web_ratio, audio_ratio, video_ratio, action_idx] = predict(obj, state)
            % Aggressive action selection focused on starvation prevention
            
            state_idx = obj.discretize_state(...
                state.web_users, state.audio_users, state.video_users, ...
                state.web_demand, state.audio_demand, state.video_demand, ...
                state.web_sat, state.audio_sat, state.video_sat, ...
                state.total_demand);
            
            state_idx = min(max(state_idx, 1), size(obj.Q_table, 1));
            
            % Get valid actions based on current state
            valid_actions = obj.get_valid_actions(state);
            
            % EMERGENCY OVERRIDE: If severe starvation, use protective actions
            min_sat = min([state.web_sat, state.audio_sat, state.video_sat]);
            if min_sat < 20  % Severe starvation emergency
                % Force protective actions (actions 1-7 are most protective)
                if rand() < 0.8  % 80% chance to use protective action
                    protective_actions = intersect(1:7, valid_actions);
                    if isempty(protective_actions)
                        protective_actions = valid_actions;
                    end
                    action_idx = protective_actions(randi(length(protective_actions)));
                else
                    % Normal epsilon-greedy with valid actions
                    if rand() < obj.exploration_rate
                        action_idx = valid_actions(randi(length(valid_actions)));
                    else
                        [~, best_action] = max(obj.Q_table(state_idx, valid_actions));
                        action_idx = valid_actions(best_action);
                    end
                end
            else
                % Normal epsilon-greedy with valid actions
                if rand() < obj.exploration_rate
                    action_idx = valid_actions(randi(length(valid_actions)));
                else
                    [~, best_action] = max(obj.Q_table(state_idx, valid_actions));
                    action_idx = valid_actions(best_action);
                end
            end
            
            action = obj.action_space(action_idx, :);
            web_ratio = action(1);
            audio_ratio = action(2);
            video_ratio = action(3);
            
            % Ensure video never gets more than 50% in overload conditions
            if state.total_demand > 90 && video_ratio > 0.5
                excess = video_ratio - 0.5;
                web_ratio = web_ratio + excess * 0.6;
                audio_ratio = audio_ratio + excess * 0.4;
                video_ratio = 0.5;
            end
            
            % Normalize to ensure sum = 1
            total = web_ratio + audio_ratio + video_ratio;
            if total > 0
                web_ratio = web_ratio / total;
                audio_ratio = audio_ratio / total;
                video_ratio = video_ratio / total;
            end
        end
        
        function reward = calculate_reward(obj, state, action, next_state)
            % AGGRESSIVE REWARD FUNCTION - Heavily penalizes starvation
            
            reward = 0;
            
            %% CRITICAL: Massive penalties for starvation
            % Web starvation penalty
            if state.web_users > 0
                if next_state.web_sat < 20
                    reward = reward - 15.0;  % Critical starvation
                elseif next_state.web_sat < 40
                    reward = reward - 8.0;   % Severe starvation
                elseif next_state.web_sat < 60
                    reward = reward - 4.0;   % Moderate starvation
                elseif next_state.web_sat >= 80
                    reward = reward + 4.0;   % Excellent
                elseif next_state.web_sat >= 70
                    reward = reward + 2.0;   % Good
                end
            end
            
            % Audio starvation penalty (same scale - real-time critical)
            if state.audio_users > 0
                if next_state.audio_sat < 20
                    reward = reward - 15.0;  % Critical starvation
                elseif next_state.audio_sat < 40
                    reward = reward - 8.0;   % Severe starvation
                elseif next_state.audio_sat < 60
                    reward = reward - 4.0;   % Moderate starvation
                elseif next_state.audio_sat >= 80
                    reward = reward + 4.0;   % Excellent
                elseif next_state.audio_sat >= 70
                    reward = reward + 2.0;   % Good
                end
            end
            
            % Video starvation penalty (less severe)
            if state.video_users > 0
                if next_state.video_sat < 20
                    reward = reward - 5.0;   % Critical starvation
                elseif next_state.video_sat < 40
                    reward = reward - 3.0;   % Severe starvation
                elseif next_state.video_sat < 60
                    reward = reward - 1.0;   % Moderate starvation
                elseif next_state.video_sat >= 80
                    reward = reward + 2.0;   % Excellent
                elseif next_state.video_sat >= 70
                    reward = reward + 1.0;   % Good
                end
            end
            
            %% HUGE BONUS for balanced minimum satisfaction
            min_sat = min([next_state.web_sat, next_state.audio_sat, next_state.video_sat]);
            if min_sat >= 60
                reward = reward + 12.0;  % Massive bonus for no starvation
            elseif min_sat >= 50
                reward = reward + 6.0;   % Good bonus for fair performance
            elseif min_sat >= 40
                reward = reward + 2.0;   % Small bonus for some recovery
            end
            
            %% PENALTY for video domination in overload
            if state.total_demand > 80
                video_share = action.video_ratio;
                if video_share > 0.4
                    reward = reward - (video_share - 0.4) * 10;  % Penalize high video share in overload
                end
            end
            
            %% BONUS for efficient bandwidth use
            utilization = min(1.0, state.total_demand / 100);
            if utilization > 0.7 && utilization < 0.95
                reward = reward + 2.0;
            end
            
            %% PENALTY for extreme imbalance
            sat_std = std([next_state.web_sat, next_state.audio_sat, next_state.video_sat]);
            if sat_std > 30
                reward = reward - 3.0;
            end
            
            % Keep reward in reasonable range
            reward = max(-30, min(30, reward));
        end
        
        function update(obj, state, action, reward, next_state)
            % Q-learning update with aggressive learning
            
            state_idx = obj.discretize_state(...
                state.web_users, state.audio_users, state.video_users, ...
                state.web_demand, state.audio_demand, state.video_demand, ...
                state.web_sat, state.audio_sat, state.video_sat, ...
                state.total_demand);
            
            next_state_idx = obj.discretize_state(...
                next_state.web_users, next_state.audio_users, next_state.video_users, ...
                next_state.web_demand, next_state.audio_demand, next_state.video_demand, ...
                next_state.web_sat, next_state.audio_sat, next_state.video_sat, ...
                next_state.total_demand);
            
            state_idx = min(max(state_idx, 1), size(obj.Q_table, 1));
            next_state_idx = min(max(next_state_idx, 1), size(obj.Q_table, 1));
            
            % Find action index
            action_vec = [action.web_ratio, action.audio_ratio, action.video_ratio];
            [~, action_idx] = min(vecnorm(obj.action_space - action_vec, 2, 2));
            
            % Q-learning update
            current_q = obj.Q_table(state_idx, action_idx);
            max_next_q = max(obj.Q_table(next_state_idx, :));
            
            obj.Q_table(state_idx, action_idx) = current_q + ...
                obj.learning_rate * (reward + obj.discount_factor * max_next_q - current_q);
            
            % Decay exploration rate
            obj.exploration_rate = max(obj.min_exploration, ...
                obj.exploration_rate * obj.exploration_decay);
            
            % Store training history
            obj.episode_count = obj.episode_count + 1;
            history_entry = struct(...
                'episode', obj.episode_count, ...
                'state', state, ...
                'action', action_vec, ...
                'reward', reward, ...
                'next_state', next_state, ...
                'exploration_rate', obj.exploration_rate, ...
                'state_idx', state_idx, ...
                'action_idx', action_idx);
            
            obj.training_history = [obj.training_history; history_entry];
            
            % Update adaptive thresholds based on performance
            obj.update_adaptive_thresholds();
        end
        
        function update_adaptive_thresholds(obj)
            % Adaptively adjust thresholds based on historical performance
            if length(obj.historical_starvation_events) > 100
                recent_events = obj.historical_starvation_events(end-99:end);
                starvation_rate = length(recent_events) / 100;
                
                if starvation_rate > 0.3  % High starvation rate
                    obj.adaptive_starvation_threshold = min(60, obj.adaptive_starvation_threshold + 2);
                elseif starvation_rate < 0.1  % Low starvation rate
                    obj.adaptive_starvation_threshold = max(40, obj.adaptive_starvation_threshold - 1);
                end
            end
        end
        
        function performance = evaluate_performance(obj)
            % Evaluate agent performance comprehensively
            performance = struct();
            performance.total_episodes = obj.episode_count;
            performance.current_exploration = obj.exploration_rate;
            performance.q_table_size = size(obj.Q_table);
            performance.action_space_size = size(obj.action_space, 1);
            performance.adaptive_starvation_threshold = obj.adaptive_starvation_threshold;
            
            % Starvation statistics
            performance.web_starvation_count = obj.web_starvation_count;
            performance.audio_starvation_count = obj.audio_starvation_count;
            performance.video_starvation_count = obj.video_starvation_count;
            performance.total_starvation_events = length(obj.historical_starvation_events);
            
            if ~isempty(obj.training_history)
                recent_episodes = max(1, length(obj.training_history)-49):length(obj.training_history);
                recent_rewards = [obj.training_history(recent_episodes).reward];
                performance.average_reward = mean(recent_rewards);
                performance.std_reward = std(recent_rewards);
                performance.min_reward = min(recent_rewards);
                performance.max_reward = max(recent_rewards);
                
                % Q-table statistics
                performance.avg_q_value = mean(obj.Q_table(:));
                performance.max_q_value = max(obj.Q_table(:));
                performance.min_q_value = min(obj.Q_table(:));
            else
                performance.average_reward = 0;
                performance.std_reward = 0;
                performance.min_reward = 0;
                performance.max_reward = 0;
                performance.avg_q_value = 0;
                performance.max_q_value = 0;
                performance.min_q_value = 0;
            end
            
            % Store performance history
            perf_entry = struct('timestamp', datetime, 'metrics', performance);
            obj.performance_history = [obj.performance_history; perf_entry];
        end
        
        function print_policy_analysis(obj)
            fprintf('\n=== AGGRESSIVE STARVATION PREVENTION AGENT ===\n');
            fprintf('Training episodes: %d\n', obj.episode_count);
            fprintf('Exploration rate: %.3f\n', obj.exploration_rate);
            fprintf('Action space: %d actions designed to protect web/audio\n', size(obj.action_space, 1));
            fprintf('Starvation events: Web=%d, Audio=%d, Video=%d\n', ...
                obj.web_starvation_count, obj.audio_starvation_count, obj.video_starvation_count);
            fprintf('Adaptive threshold: %.1f\n', obj.adaptive_starvation_threshold);
            
            if ~isempty(obj.performance_history)
                recent_perf = obj.performance_history(end).metrics;
                fprintf('Recent performance: Avg reward=%.2f, Min=%.2f, Max=%.2f\n', ...
                    recent_perf.average_reward, recent_perf.min_reward, recent_perf.max_reward);
            end
        end
        
        function plot_training_progress(obj)
            % Plot training progress - FIXED VERSION
            if length(obj.training_history) < 2
                fprintf('Not enough training data to plot\n');
                return;
            end
            
            try
                figure('Name', 'RL Agent Training Progress', 'NumberTitle', 'off', ...
                       'Position', [100, 100, 1200, 800]);
                
                % Reward progression
                subplot(2, 2, 1);
                rewards = [obj.training_history.reward];
                plot(rewards, 'b-', 'LineWidth', 1);
                title('Reward Progression');
                xlabel('Episode');
                ylabel('Reward');
                grid on;
                
                % Moving average reward
                subplot(2, 2, 2);
                window_size = min(50, length(rewards));
                moving_avg = movmean(rewards, window_size);
                plot(moving_avg, 'r-', 'LineWidth', 2);
                title(sprintf('Moving Average Reward (window=%d)', window_size));
                xlabel('Episode');
                ylabel('Average Reward');
                grid on;
                
                % Exploration rate decay
                subplot(2, 2, 3);
                exploration_rates = [obj.training_history.exploration_rate];
                plot(exploration_rates, 'g-', 'LineWidth', 1);
                title('Exploration Rate Decay');
                xlabel('Episode');
                ylabel('Exploration Rate');
                grid on;
                
                % Action distribution
                subplot(2, 2, 4);
                action_counts = obj.analyze_action_distribution();
                bar(action_counts, 'FaceColor', [0.7 0.7 0.9]);
                title('Action Distribution');
                xlabel('Action Index');
                ylabel('Usage Count');
                grid on;
                
            catch ME
                fprintf('Plotting error: %s\n', ME.message);
                fprintf('Creating simplified plot instead...\n');
                
                % Simplified plot as fallback
                figure('Name', 'RL Training Progress (Simplified)', 'NumberTitle', 'off');
                rewards = [obj.training_history.reward];
                plot(rewards, 'b-', 'LineWidth', 2);
                title('Reward Progression');
                xlabel('Episode');
                ylabel('Reward');
                grid on;
            end
        end
        
        function action_distribution = analyze_action_distribution(obj)
            % Analyze which actions are being used most frequently
            if isempty(obj.training_history)
                action_distribution = [];
                return;
            end
            
            action_indices = [obj.training_history.action_idx];
            action_distribution = histcounts(action_indices, 1:size(obj.action_space, 1)+1);
            
            fprintf('\n=== ACTION DISTRIBUTION ANALYSIS ===\n');
            for i = 1:size(obj.action_space, 1)
                count = action_distribution(i);
                percentage = (count / length(action_indices)) * 100;
                action = obj.action_space(i, :);
                fprintf('Action %2d: [%.2f, %.2f, %.2f] - %4d uses (%5.1f%%)\n', ...
                    i, action(1), action(2), action(3), count, percentage);
            end
        end
        
        function save_agent(obj, filename)
            % Save agent with all data
            agent_data = struct();
            agent_data.Q_table = obj.Q_table;
            agent_data.exploration_rate = obj.exploration_rate;
            agent_data.episode_count = obj.episode_count;
            agent_data.training_history = obj.training_history;
            agent_data.performance_history = obj.performance_history;
            agent_data.historical_starvation_events = obj.historical_starvation_events;
            agent_data.web_starvation_count = obj.web_starvation_count;
            agent_data.audio_starvation_count = obj.audio_starvation_count;
            agent_data.video_starvation_count = obj.video_starvation_count;
            agent_data.adaptive_starvation_threshold = obj.adaptive_starvation_threshold;
            
            save(filename, 'agent_data');
            fprintf('Agent saved to %s\n', filename);
        end
        
        function obj = load_pretrained_agent(obj, filename)
            % Load pretrained agent
            try
                loaded_data = load(filename);
                agent_data = loaded_data.agent_data;
                
                obj.Q_table = agent_data.Q_table;
                obj.exploration_rate = agent_data.exploration_rate;
                obj.episode_count = agent_data.episode_count;
                obj.training_history = agent_data.training_history;
                obj.performance_history = agent_data.performance_history;
                obj.historical_starvation_events = agent_data.historical_starvation_events;
                obj.web_starvation_count = agent_data.web_starvation_count;
                obj.audio_starvation_count = agent_data.audio_starvation_count;
                obj.video_starvation_count = agent_data.video_starvation_count;
                obj.adaptive_starvation_threshold = agent_data.adaptive_starvation_threshold;
                
                fprintf('Pretrained agent loaded from %s\n', filename);
            catch ME
                warning('Failed to load pretrained agent: %s', ME.message);
            end
        end
        
        function transfer_learning(obj, source_agent, transfer_ratio)
            % Transfer learning from another agent
            if nargin < 3
                transfer_ratio = 0.3;  % Default transfer ratio
            end
            
            % Blend Q-tables
            obj.Q_table = (1 - transfer_ratio) * obj.Q_table + transfer_ratio * source_agent.Q_table;
            
            fprintf('Transfer learning applied with ratio %.2f\n', transfer_ratio);
        end
        
        function reset_training(obj)
            % Reset training data but keep learned Q-table
            obj.training_history = [];
            obj.performance_history = [];
            obj.historical_starvation_events = [];
            obj.web_starvation_count = 0;
            obj.audio_starvation_count = 0;
            obj.video_starvation_count = 0;
            obj.episode_count = 0;
            
            fprintf('Training data reset (Q-table preserved)\n');
        end
    end
end