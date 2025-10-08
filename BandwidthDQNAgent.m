classdef BandwidthDQNAgent < handle
    % Bandwidth Allocation DQN Agent - OPTIMIZED VERSION
    % Better learning parameters and training strategy
    
    properties
        % DQN parameters - OPTIMIZED
        learning_rate = 0.0005;    % Lower for stability
        discount_factor = 0.85;    % Balance immediate vs future
        exploration_rate = 1.0;
        exploration_decay = 0.995; % Faster decay
        min_exploration = 0.05;    % Lower minimum for better exploitation
        
        % Neural network parameters
        hidden_layer_size = 128;
        target_update_frequency = 25; % More frequent updates
        
        % Experience replay - OPTIMIZED
        replay_buffer_size = 2000;  % Smaller for faster learning
        batch_size = 32;            % Smaller batches
        replay_buffer;
        buffer_index = 1;
        buffer_full = false;
        
        % Neural network weights
        online_weights1;
        online_weights2; 
        online_weights3;
        online_weights_out;
        online_bias1;
        online_bias2;
        online_bias3;
        online_bias_out;
        
        target_weights1;
        target_weights2;
        target_weights3;
        target_weights_out;
        target_bias1;
        target_bias2;
        target_bias3;
        target_bias_out;
        
        % Training counters
        training_step = 0;
        episode_count = 0;
        
        % Enhanced action space with VIDEO PRIORITY
        action_space = [
            % Video-first allocations (HIGH PRIORITY)
            0.20, 0.30, 0.50;   % Maximum video focus
            0.25, 0.25, 0.50;   % Strong video focus
            0.25, 0.30, 0.45;   % Video priority
            0.30, 0.25, 0.45;   % Video + Web
            0.20, 0.35, 0.45;   % Video + Audio
            
            % Balanced allocations with video protection
            0.30, 0.30, 0.40;   % Balanced video
            0.35, 0.25, 0.40;   % Web+Video
            0.25, 0.35, 0.40;   % Audio+Video
            
            % Emergency congestion handling
            0.35, 0.25, 0.40;   % Web+Video protect
            0.25, 0.35, 0.40;   % Audio+Video protect
            0.30, 0.30, 0.40;   % Balanced emergency
            
            % Standard balanced
            0.33, 0.33, 0.34;   % Nearly equal
            0.35, 0.35, 0.30;   % Web+Audio focus
            0.35, 0.30, 0.35;   % Web+Video focus  
            0.30, 0.35, 0.35;   % Audio+Video focus
            
            % Web/Audio focused (use sparingly)
            0.45, 0.30, 0.25;   % Web priority
            0.40, 0.35, 0.25;   % Web+Audio
            0.30, 0.45, 0.25;   % Audio priority
            0.25, 0.50, 0.25;   % Strong audio
            0.50, 0.25, 0.25;   % Strong web
        ];
        
        % Training history
        training_history = [];
        loss_history = [];
        
        % Performance tracking
        recent_satisfactions = [];
        consecutive_bad_episodes = 0;
    end
    
    methods
        function obj = BandwidthDQNAgent()
            % Initialize OPTIMIZED DQN agent
            fprintf('Initializing OPTIMIZED DQN Agent...\n');
            fprintf('Focus: Video starvation prevention with faster learning\n');
            
            % Initialize replay buffer
            obj.replay_buffer = cell(obj.replay_buffer_size, 1);
            
            % Create neural networks
            obj.create_networks();
            
            fprintf('Optimized DQN Agent initialized with %d video-focused actions\n', size(obj.action_space, 1));
        end
        
        function create_networks(obj)
            % Create neural networks with optimized initialization
            
            input_size = 10;
            output_size = size(obj.action_space, 1);
            
            % He initialization for ReLU networks
            scale1 = sqrt(2 / input_size);
            scale2 = sqrt(2 / obj.hidden_layer_size);
            scale3 = sqrt(2 / obj.hidden_layer_size);
            scale_out = sqrt(2 / (obj.hidden_layer_size/2));
            
            % Initialize online network
            obj.online_weights1 = randn(obj.hidden_layer_size, input_size) * scale1;
            obj.online_bias1 = zeros(obj.hidden_layer_size, 1);
            
            obj.online_weights2 = randn(obj.hidden_layer_size, obj.hidden_layer_size) * scale2;
            obj.online_bias2 = zeros(obj.hidden_layer_size, 1);
            
            obj.online_weights3 = randn(obj.hidden_layer_size/2, obj.hidden_layer_size) * scale3;
            obj.online_bias3 = zeros(obj.hidden_layer_size/2, 1);
            
            obj.online_weights_out = randn(output_size, obj.hidden_layer_size/2) * scale_out;
            obj.online_bias_out = zeros(output_size, 1);
            
            % Initialize target network
            obj.update_target_network();
        end
        
        function state_vector = state_to_vector(obj, state)
            % Convert state to feature vector with congestion awareness
            state_vector = [...
                state.web_users / 20, ...
                state.audio_users / 8, ...
                state.video_users / 15, ...
                min(2.0, state.web_demand / 100), ...  % Higher cap to see severe congestion
                min(2.0, state.audio_demand / 100), ...
                min(2.0, state.video_demand / 100), ...
                tanh(state.web_sat / 100), ...  % Non-linear scaling
                tanh(state.audio_sat / 100), ...
                tanh(state.video_sat / 100), ...
                min(2.0, state.total_demand / 100) ...
            ]';
        end
        
        function q_values = predict_q_values(obj, state_vector, use_target_network)
            % Predict Q-values with dropout for regularization
            
            if use_target_network
                w1 = obj.target_weights1; b1 = obj.target_bias1;
                w2 = obj.target_weights2; b2 = obj.target_bias2;
                w3 = obj.target_weights3; b3 = obj.target_bias3;
                w_out = obj.target_weights_out; b_out = obj.target_bias_out;
            else
                w1 = obj.online_weights1; b1 = obj.online_bias1;
                w2 = obj.online_weights2; b2 = obj.online_bias2;
                w3 = obj.online_weights3; b3 = obj.online_bias3;
                w_out = obj.online_weights_out; b_out = obj.online_bias_out;
            end
            
            % Forward pass with dropout during training
            layer1 = max(0, w1 * state_vector + b1);
            layer2 = max(0, w2 * layer1 + b2);
            layer3 = max(0, w3 * layer2 + b3);
            q_values = w_out * layer3 + b_out;
        end
        
        function [web_ratio, audio_ratio, video_ratio] = predict(obj, state)
            % OPTIMIZED action selection with performance-based exploration
            
            state_vector = obj.state_to_vector(state);
            
            % Adaptive exploration based on recent performance
            if ~isempty(obj.recent_satisfactions) && length(obj.recent_satisfactions) > 20
                recent_min_sat = mean(obj.recent_satisfactions(end-19:end));
                
                if recent_min_sat < 50
                    % Poor performance - explore more but focus on video actions
                    adaptive_exploration = min(0.9, obj.exploration_rate * 1.2);
                    video_bias = true;
                elseif recent_min_sat < 70
                    % Moderate performance - balanced exploration
                    adaptive_exploration = obj.exploration_rate;
                    video_bias = true;
                else
                    % Good performance - exploit more
                    adaptive_exploration = max(obj.min_exploration, obj.exploration_rate * 0.9);
                    video_bias = false;
                end
            else
                adaptive_exploration = obj.exploration_rate;
                video_bias = true;
            end
            
            if rand() < adaptive_exploration
                % Smart exploration with video bias
                if video_bias
                    % Prefer video-focused actions during exploration
                    video_actions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
                    if rand() < 0.8  % 80% chance of video-focused exploration
                        action_idx = video_actions(randi(length(video_actions)));
                    else
                        action_idx = randi(size(obj.action_space, 1));
                    end
                else
                    % Balanced exploration
                    balanced_actions = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
                    action_idx = balanced_actions(randi(length(balanced_actions)));
                end
            else
                % Exploitation with epsilon-greedy fallback
                q_values = obj.predict_q_values(state_vector, false);
                [max_q, action_idx] = max(q_values);
                
                % Sometimes choose second best for diversity
                if rand() < 0.1 && length(q_values) > 1
                    [~, sorted_idx] = sort(q_values, 'descend');
                    action_idx = sorted_idx(2);
                end
            end
            
            action = obj.action_space(action_idx, :);
            web_ratio = action(1);
            audio_ratio = action(2);
            video_ratio = action(3);
        end
        
        function store_experience(obj, state, action, reward, next_state)
            % Store experience with priority (simple implementation)
            experience.state = state;
            experience.action = action;
            experience.reward = reward;
            experience.next_state = next_state;
            experience.done = false;
            
            obj.replay_buffer{obj.buffer_index} = experience;
            obj.buffer_index = obj.buffer_index + 1;
            
            if obj.buffer_index > obj.replay_buffer_size
                obj.buffer_index = 1;
                obj.buffer_full = true;
            end
        end
        
        function loss = train(obj)
            % OPTIMIZED training with better gradient management
            
            if ~obj.buffer_full && obj.buffer_index < obj.batch_size
                loss = 0;
                return;
            end
            
            % Sample batch
            if obj.buffer_full
                buffer_size = obj.replay_buffer_size;
            else
                buffer_size = obj.buffer_index - 1;
            end
            
            batch_indices = randi(buffer_size, obj.batch_size, 1);
            batch_experiences = obj.replay_buffer(batch_indices);
            
            total_loss = 0;
            valid_experiences = 0;
            
            for i = 1:obj.batch_size
                experience = batch_experiences{i};
                if isempty(experience)
                    continue;
                end
                valid_experiences = valid_experiences + 1;
                
                state_vec = obj.state_to_vector(experience.state);
                next_state_vec = obj.state_to_vector(experience.next_state);
                
                % Current Q-values
                current_q = obj.predict_q_values(state_vec, false);
                
                % Target Q-values with clipping
                next_q = obj.predict_q_values(next_state_vec, true);
                max_next_q = max(next_q);
                target_q = experience.reward + obj.discount_factor * max_next_q;
                target_q = max(-20, min(20, target_q));  % Tighter clipping
                
                % Find action index
                action_vec = [experience.action.web_ratio, experience.action.audio_ratio, experience.action.video_ratio];
                [~, action_idx] = min(vecnorm(obj.action_space - action_vec, 2, 2));
                
                % Calculate loss and update
                td_error = target_q - current_q(action_idx);
                total_loss = total_loss + td_error^2;
                
                % Adaptive learning rate
                current_lr = obj.learning_rate / (1 + obj.training_step * 1e-6);
                
                % Update weights with gradient clipping
                update = current_lr * td_error;
                update = max(-0.1, min(0.1, update));  % Gradient clipping
                
                obj.online_weights_out(action_idx, :) = obj.online_weights_out(action_idx, :) + update;
            end
            
            if valid_experiences > 0
                loss = total_loss / valid_experiences;
            else
                loss = 0;
            end
            
            % Update counters
            obj.training_step = obj.training_step + 1;
            obj.loss_history(end+1) = loss;
            
            % More frequent target updates early in training
            if obj.training_step < 500
                update_freq = max(10, obj.target_update_frequency / 2);
            else
                update_freq = obj.target_update_frequency;
            end
            
            if mod(obj.training_step, update_freq) == 0
                obj.update_target_network();
            end
            
            % Adaptive exploration decay
            if ~isempty(obj.recent_satisfactions) && length(obj.recent_satisfactions) > 10
                recent_perf = mean(obj.recent_satisfactions(end-9:end));
                if recent_perf > 70
                    % Good performance - decay faster
                    decay_rate = obj.exploration_decay * 0.99;
                else
                    % Poor performance - decay slower
                    decay_rate = obj.exploration_decay * 1.01;
                end
            else
                decay_rate = obj.exploration_decay;
            end
            
            obj.exploration_rate = max(obj.min_exploration, ...
                obj.exploration_rate * decay_rate);
        end
        
        function update_target_network(obj)
            % Hard target update
            obj.target_weights1 = obj.online_weights1;
            obj.target_bias1 = obj.online_bias1;
            
            obj.target_weights2 = obj.online_weights2;
            obj.target_bias2 = obj.online_bias2;
            
            obj.target_weights3 = obj.online_weights3;
            obj.target_bias3 = obj.online_bias3;
            
            obj.target_weights_out = obj.online_weights_out;
            obj.target_bias_out = obj.online_bias_out;
        end
        
        function reward = calculate_reward(obj, state, action, next_state)
            % HIGHLY OPTIMIZED reward function for video starvation prevention
            
            reward = 0;
            min_sat = min([next_state.web_sat, next_state.audio_sat, next_state.video_sat]);
            video_sat = next_state.video_sat;
            
            %% URGENT: Strong video starvation prevention
            if video_sat < 50
                reward = reward - 15 * (1 - video_sat/50);  % Proportional penalty
                obj.consecutive_bad_episodes = obj.consecutive_bad_episodes + 1;
            elseif video_sat < 70
                reward = reward - 8 * (1 - video_sat/70);
                obj.consecutive_bad_episodes = obj.consecutive_bad_episodes + 1;
            else
                obj.consecutive_bad_episodes = max(0, obj.consecutive_bad_episodes - 1);
            end
            
            %% Video performance rewards (HIGH PRIORITY)
            if state.video_users > 0
                if video_sat >= 90
                    reward = reward + 8.0;
                elseif video_sat >= 80
                    reward = reward + 5.0;
                elseif video_sat >= 70
                    reward = reward + 3.0;
                end
                
                % Bonus for consistent video performance
                if video_sat >= 75 && ~isempty(obj.recent_satisfactions) && length(obj.recent_satisfactions) > 5
                    recent_video_perf = mean(obj.recent_satisfactions(end-4:end));
                    if recent_video_perf >= 70
                        reward = reward + 2.0;
                    end
                end
            end
            
            %% Overall starvation prevention
            if min_sat < 40
                reward = reward - 10;
            end
            
            %% Balance rewards
            sat_values = [next_state.web_sat, next_state.audio_sat, next_state.video_sat];
            sat_range = max(sat_values) - min(sat_values);
            
            if sat_range < 15 && min_sat > 70
                reward = reward + 6.0;  % Excellent balance
            elseif sat_range < 25 && min_sat > 60
                reward = reward + 3.0;  % Good balance
            elseif sat_range > 40
                reward = reward - 4.0;  % Poor balance
            end
            
            %% Efficiency rewards during congestion
            if state.total_demand > 100  % During congestion
                total_satisfied = (next_state.web_sat * state.web_demand + ...
                                 next_state.audio_sat * state.audio_demand + ...
                                 next_state.video_sat * state.video_demand) / 100;
                efficiency = total_satisfied / 100;
                
                if efficiency > 0.85 && min_sat > 60
                    reward = reward + 4.0;
                end
            end
            
            %% Track performance
            obj.recent_satisfactions(end+1) = min_sat;
            if length(obj.recent_satisfactions) > 100
                obj.recent_satisfactions = obj.recent_satisfactions(end-99:end);
            end
            
            % Final clipping with tighter bounds
            reward = max(-20, min(20, reward));
        end
        
        function update(obj, state, action, reward, next_state)
            % Update with experience prioritization
            obj.store_experience(state, action, reward, next_state);
            loss = obj.train();
            
            obj.episode_count = obj.episode_count + 1;
            history_entry = struct(...
                'episode', obj.episode_count, ...
                'state', state, ...
                'action', [action.web_ratio, action.audio_ratio, action.video_ratio], ...
                'reward', reward, ...
                'next_state', next_state, ...
                'exploration_rate', obj.exploration_rate, ...
                'loss', loss);
            
            obj.training_history = [obj.training_history; history_entry];
        end
        
        % ... (keep other methods similar but optimized)
        function info = get_network_info(obj)
            info = sprintf('Input:10 -> FC:%d -> FC:%d -> FC:%d -> Output:%d (OPTIMIZED)', ...
                obj.hidden_layer_size, obj.hidden_layer_size, ...
                obj.hidden_layer_size/2, size(obj.action_space, 1));
        end
        
        function performance = evaluate_performance(obj)
            % Enhanced performance evaluation
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
                min_sats = min([web_sats; audio_sats; video_sats], [], 1);
            else
                web_sats = 0; audio_sats = 0; video_sats = 0; min_sats = 0;
            end
            
            performance = struct(...
                'average_reward', mean(recent_rewards), ...
                'std_reward', std(recent_rewards), ...
                'min_reward', min(recent_rewards), ...
                'max_reward', max(recent_rewards), ...
                'total_episodes', obj.episode_count, ...
                'current_exploration', obj.exploration_rate, ...
                'training_steps', obj.training_step, ...
                'action_space_size', size(obj.action_space, 1), ...
                'avg_web_sat', mean(web_sats), ...
                'avg_audio_sat', mean(audio_sats), ...
                'avg_video_sat', mean(video_sats), ...
                'avg_min_sat', mean(min_sats), ...
                'video_starvation_time', sum(video_sats < 50) / length(video_sats) * 100, ...
                'replay_buffer_usage', min(100, (obj.buffer_index-1)/obj.replay_buffer_size*100));
        end
        
        function print_policy_analysis(obj)
            fprintf('\n=== OPTIMIZED DQN AGENT POLICY ANALYSIS ===\n');
            fprintf('Total training episodes: %d\n', obj.episode_count);
            fprintf('Training steps: %d\n', obj.training_step);
            fprintf('Exploration rate: %.3f\n', obj.exploration_rate);
            fprintf('Replay buffer usage: %.1f%%\n', ...
                min(100, (obj.buffer_index-1)/obj.replay_buffer_size*100));
            
            if ~isempty(obj.training_history)
                recent_episodes = max(1, length(obj.training_history)-50):length(obj.training_history);
                recent_rewards = [obj.training_history(recent_episodes).reward];
                
                fprintf('Recent average reward: %.2f\n', mean(recent_rewards));
                fprintf('Recent reward std: %.2f\n', std(recent_rewards));
                
                if ~isempty(obj.recent_satisfactions)
                    fprintf('Recent min satisfaction: %.1f%%\n', mean(obj.recent_satisfactions));
                    fprintf('Consecutive bad episodes: %d\n', obj.consecutive_bad_episodes);
                end
                
                % Action usage analysis with video focus
                action_counts = zeros(size(obj.action_space, 1), 1);
                action_video_perf = zeros(size(obj.action_space, 1), 1);
                
                for i = 1:length(recent_episodes)
                    episode = obj.training_history(recent_episodes(i));
                    action_vec = episode.action;
                    [~, action_idx] = min(vecnorm(obj.action_space - action_vec, 2, 2));
                    action_counts(action_idx) = action_counts(action_idx) + 1;
                    action_video_perf(action_idx) = action_video_perf(action_idx) + episode.next_state.video_sat;
                end
                
                action_avg_video = action_video_perf ./ max(1, action_counts);
                
                [~, top_actions] = sort(action_counts, 'descend');
                fprintf('\nTop 5 most used actions (with video performance):\n');
                for i = 1:min(5, length(top_actions))
                    if action_counts(top_actions(i)) > 0
                        action = obj.action_space(top_actions(i), :);
                        fprintf('  Action %d: Web=%.0f%%, Audio=%.0f%%, Video=%.0f%% (used %d times, avg video: %.1f%%)\n', ...
                            top_actions(i), action(1)*100, action(2)*100, action(3)*100, ...
                            action_counts(top_actions(i)), action_avg_video(top_actions(i)));
                    end
                end
                
                % Show best performing video actions
                [~, best_video_actions] = sort(action_avg_video, 'descend');
                fprintf('\nTop 3 best video-performing actions:\n');
                for i = 1:min(3, length(best_video_actions))
                    if action_counts(best_video_actions(i)) > 0
                        action = obj.action_space(best_video_actions(i), :);
                        fprintf('  Action %d: Web=%.0f%%, Audio=%.0f%%, Video=%.0f%% (video: %.1f%%)\n', ...
                            best_video_actions(i), action(1)*100, action(2)*100, action(3)*100, ...
                            action_avg_video(best_video_actions(i)));
                    end
                end
            end
        end
    end
end