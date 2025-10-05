classdef BandwidthRLAgent < handle
    % Bandwidth Allocation RL Agent
    % Implements strong starvation prevention with balanced rewards
    
    properties
        % Q-learning parameters
        learning_rate = 0.2;  % Faster learning
        discount_factor = 0.85;  % Less focus on future rewards
        exploration_rate = 0.6;  % More exploration
        exploration_decay = 0.998;  % Very slow decay
        min_exploration = 0.15;  % Keep exploring longer
        
        % Q-table
        Q_table;
        
        % Enhanced action space with more protective allocations
        action_space = [
            % Balanced allocations
            0.33, 0.33, 0.34;   % Equal distribution
            0.40, 0.30, 0.30;   % Web focus
            0.30, 0.40, 0.30;   % Audio focus
            0.30, 0.30, 0.40;   % Video focus
            
            % Web-priority scenarios
            0.50, 0.25, 0.25;   % High web demand
            0.45, 0.30, 0.25;   % Moderate web priority
            
            % Audio-priority scenarios (protect real-time)
            0.25, 0.50, 0.25;   % High audio demand
            0.30, 0.45, 0.25;   % Moderate audio priority
            
            % Video-priority scenarios
            0.25, 0.25, 0.50;   % High video demand
            0.30, 0.25, 0.45;   % Moderate video priority
            
            % Balanced combinations
            0.35, 0.35, 0.30;   % Web+Audio balanced
            0.35, 0.30, 0.35;   % Web+Video balanced
            0.30, 0.35, 0.35;   % Audio+Video balanced
            
            % Protection allocations (prevent starvation)
            0.40, 0.35, 0.25;   % Web+Audio protect
            0.25, 0.40, 0.35;   % Audio+Video protect
            0.35, 0.25, 0.40;   % Web+Video protect
            
            % Emergency allocations
            0.20, 0.40, 0.40;   % Sacrifice web for others
            0.40, 0.20, 0.40;   % Sacrifice audio for others
            0.40, 0.40, 0.20;   % Sacrifice video for others
        ];
        
        % Training history
        training_history = [];
        episode_count = 0;
    end
    
    methods
        function obj = BandwidthRLAgent()
            % Initialize Q-table
            num_states = 3 * 4 * 4 * 6;  % 288 states
            num_actions = size(obj.action_space, 1);
            obj.Q_table = zeros(num_states, num_actions);
        end
        
        function state_index = discretize_state(obj, web_users, audio_users, video_users, ...
                                              web_demand, audio_demand, video_demand, ...
                                              web_sat, audio_sat, video_sat, total_demand)
            
            % 1. Dominant traffic type (which service has most users)
            total_users = web_users + audio_users + video_users;
            if total_users > 0
                web_ratio = web_users / total_users;
                audio_ratio = audio_users / total_users;
                video_ratio = video_users / total_users;
                [~, dominant_type] = max([web_ratio, audio_ratio, video_ratio]);
            else
                dominant_type = 1;
            end
            
            % 2. Congestion level (network utilization)
            congestion_level = total_demand / 100;
            if congestion_level < 0.7
                congestion_idx = 1;      % Light load
            elseif congestion_level < 0.9
                congestion_idx = 2;      % Moderate load
            elseif congestion_level < 1.0
                congestion_idx = 3;      % Near capacity
            else
                congestion_idx = 4;      % Overloaded
            end
            
            % 3. Starvation risk (how many services are struggling)
            starvation_count = sum([web_sat < 60 && web_users > 0, ...
                                   audio_sat < 60 && audio_users > 0, ...
                                   video_sat < 60 && video_users > 0]);
            starvation_count = min(starvation_count, 3);
            
            % 4. Worst satisfaction level
            min_sat = min([web_sat, audio_sat, video_sat]);
            sat_bins = [0, 30, 50, 70, 85, 100];
            sat_idx = discretize(min_sat, sat_bins);
            if isnan(sat_idx), sat_idx = length(sat_bins); end
            
            % Combine features into state index
            state_index = (dominant_type-1) * 4 * 4 * 6 + ...
                         (congestion_idx-1) * 4 * 6 + ...
                         (starvation_count) * 6 + ...
                         sat_idx;
            
            state_index = min(max(state_index, 1), 288);
        end
        
        function [web_ratio, audio_ratio, video_ratio] = predict(obj, state)
            % Choose action using epsilon-greedy policy
            
            state_idx = obj.discretize_state(...
                state.web_users, state.audio_users, state.video_users, ...
                state.web_demand, state.audio_demand, state.video_demand, ...
                state.web_sat, state.audio_sat, state.video_sat, ...
                state.total_demand);
            
            state_idx = min(max(state_idx, 1), size(obj.Q_table, 1));
            
            % Epsilon-greedy action selection
            if rand() < obj.exploration_rate
                % Explore: random action
                action_idx = randi(size(obj.action_space, 1));
            else
                % Exploit: best known action
                [~, action_idx] = max(obj.Q_table(state_idx, :));
            end
            
            action = obj.action_space(action_idx, :);
            web_ratio = action(1);
            audio_ratio = action(2);
            video_ratio = action(3);
        end
        
        function reward = calculate_reward(obj, state, action, next_state)
            % GRADUAL REWARD FUNCTION - Provides clear learning gradients
            
            reward = 0;
            
            %% Individual satisfaction rewards (symmetric for all traffic types)
            % Use gradual rewards instead of harsh thresholds
            
            % Web satisfaction
            if state.web_users > 0
                if next_state.web_sat >= 80
                    reward = reward + 3.0;
                elseif next_state.web_sat >= 70
                    reward = reward + 2.0;
                elseif next_state.web_sat >= 60
                    reward = reward + 1.0;
                elseif next_state.web_sat >= 50
                    reward = reward + 0.5;
                elseif next_state.web_sat >= 40
                    reward = reward - 2.0;
                elseif next_state.web_sat >= 30
                    reward = reward - 5.0;
                else
                    reward = reward - 8.0;
                end
            end
            
            % Audio satisfaction (same scale)
            if state.audio_users > 0
                if next_state.audio_sat >= 80
                    reward = reward + 3.0;
                elseif next_state.audio_sat >= 70
                    reward = reward + 2.0;
                elseif next_state.audio_sat >= 60
                    reward = reward + 1.0;
                elseif next_state.audio_sat >= 50
                    reward = reward + 0.5;
                elseif next_state.audio_sat >= 40
                    reward = reward - 2.0;
                elseif next_state.audio_sat >= 30
                    reward = reward - 5.0;
                else
                    reward = reward - 8.0;
                end
            end
            
            % Video satisfaction (same scale - equal treatment)
            if state.video_users > 0
                if next_state.video_sat >= 80
                    reward = reward + 3.0;
                elseif next_state.video_sat >= 70
                    reward = reward + 2.0;
                elseif next_state.video_sat >= 60
                    reward = reward + 1.0;
                elseif next_state.video_sat >= 50
                    reward = reward + 0.5;
                elseif next_state.video_sat >= 40
                    reward = reward - 2.0;
                elseif next_state.video_sat >= 30
                    reward = reward - 5.0;
                else
                    reward = reward - 8.0;
                end
            end
            
            %% CRITICAL: Large bonus for balanced performance
            % This is the key to preventing one service from being sacrificed
            min_satisfaction = min([next_state.web_sat, next_state.audio_sat, next_state.video_sat]);
            
            if min_satisfaction >= 70
                reward = reward + 10.0;  % Big bonus
            elseif min_satisfaction >= 60
                reward = reward + 5.0;
            elseif min_satisfaction >= 50
                reward = reward + 2.0;
            end
            
            %% Penalty for severe imbalance
            sat_values = [next_state.web_sat, next_state.audio_sat, next_state.video_sat];
            sat_std = std(sat_values);
            
            if sat_std > 30  % High variance = unfair
                reward = reward - 3.0;
            end
            
            %% Moderate waste penalty
            if next_state.web_sat > 120
                reward = reward - (next_state.web_sat - 120) / 50;
            end
            if next_state.audio_sat > 120
                reward = reward - (next_state.audio_sat - 120) / 50;
            end
            if next_state.video_sat > 120
                reward = reward - (next_state.video_sat - 120) / 50;
            end
            
            %% Small efficiency bonus
            utilization = state.total_demand / 100;
            if utilization > 0.7 && utilization < 0.95
                reward = reward + 1.0;
            end
            
            % Wide range for clear gradients
            reward = max(-25, min(25, reward));
        end
        
        function update(obj, state, action, reward, next_state)
            % Q-learning update rule
            
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
            
            % Q-learning update: Q(s,a) = Q(s,a) + α[r + γ*max(Q(s',a')) - Q(s,a)]
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
                'exploration_rate', obj.exploration_rate);
            
            obj.training_history = [obj.training_history; history_entry];
        end
        
        function performance = evaluate_performance(obj)
            % Evaluate agent performance over recent episodes
            
            if isempty(obj.training_history)
                performance = struct();
                return;
            end
            
            recent_episodes = max(1, length(obj.training_history)-99):length(obj.training_history);
            recent_rewards = [obj.training_history(recent_episodes).reward];
            
            recent_states = [obj.training_history(recent_episodes).next_state];
            if ~isempty(recent_states)
                web_sats = [recent_states.web_sat];
                audio_sats = [recent_states.audio_sat];
                video_sats = [recent_states.video_sat];
            else
                web_sats = 0; audio_sats = 0; video_sats = 0;
            end
            
            performance = struct(...
                'average_reward', mean(recent_rewards), ...
                'std_reward', std(recent_rewards), ...
                'min_reward', min(recent_rewards), ...
                'max_reward', max(recent_rewards), ...
                'total_episodes', obj.episode_count, ...
                'current_exploration', obj.exploration_rate, ...
                'q_table_size', size(obj.Q_table), ...
                'action_space_size', size(obj.action_space, 1), ...
                'avg_web_sat', mean(web_sats), ...
                'avg_audio_sat', mean(audio_sats), ...
                'avg_video_sat', mean(video_sats));
        end
        
        function print_policy_analysis(obj)
            % Print detailed policy analysis
            fprintf('\n=== RL AGENT POLICY ANALYSIS ===\n');
            fprintf('Total training episodes: %d\n', obj.episode_count);
            fprintf('Exploration rate: %.3f\n', obj.exploration_rate);
            fprintf('Q-table size: %d states x %d actions\n', size(obj.Q_table, 1), size(obj.Q_table, 2));
            
            if ~isempty(obj.training_history)
                recent_episodes = max(1, length(obj.training_history)-50):length(obj.training_history);
                recent_rewards = [obj.training_history(recent_episodes).reward];
                
                fprintf('Recent average reward: %.2f\n', mean(recent_rewards));
                fprintf('Recent reward std: %.2f\n', std(recent_rewards));
                
                % Action usage analysis
                action_counts = zeros(size(obj.action_space, 1), 1);
                action_rewards = zeros(size(obj.action_space, 1), 1);
                
                for i = 1:length(recent_episodes)
                    action_vec = obj.training_history(recent_episodes(i)).action;
                    [~, action_idx] = min(vecnorm(obj.action_space - action_vec, 2, 2));
                    action_counts(action_idx) = action_counts(action_idx) + 1;
                    action_rewards(action_idx) = action_rewards(action_idx) + recent_rewards(i);
                end
                
                action_avg_rewards = action_rewards ./ max(1, action_counts);
                
                [~, top_actions] = sort(action_counts, 'descend');
                fprintf('\nTop 5 most used actions:\n');
                for i = 1:min(5, length(top_actions))
                    if action_counts(top_actions(i)) > 0
                        action = obj.action_space(top_actions(i), :);
                        fprintf('  Action %d: Web=%.0f%%, Audio=%.0f%%, Video=%.0f%% (used %d times, avg reward: %.2f)\n', ...
                            top_actions(i), action(1)*100, action(2)*100, action(3)*100, ...
                            action_counts(top_actions(i)), action_avg_rewards(top_actions(i)));
                    end
                end
            end
        end
    end
end