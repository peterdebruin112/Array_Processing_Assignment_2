%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% We are given 4 microphones with their impulse responses.The target
% impulse response indicates the ideal or reference target response. The other 
% channel impulse responses are from four interfering sources to the four 
% microphones. Since we design a system for far-end noise reduction, only 
% phase differences tau are taken into account: s(k,l)e^(-j2*pi*k*tau(d)/N)

clc
clear all
close all

%% Load received signals and noise 
[s_clean_1, ]=audioread(['clean_speech.wav']);
[s_clean_2, ]=audioread(['clean_speech_2.wav']);
[n_babble, Fs]=audioread(['babble_noise.wav']);
[n_artif_nonstat, ]=audioread(['aritificial_nonstat_noise.wav']); 
[n_speech_shaped, ]=audioread(['Speech_shaped_noise.wav']); 

% audioinfo('clean_speech.wav')

% Make all the received signals and noise vectors the same size. In this
% case the size of s_clean_2 (537706x1) was chosen since this is the 
% shortest vector.
N_tot = length(s_clean_2);
s_clean_1 = s_clean_1(8001:end,1); % Remove the first 8001 elements which are all zeros
s_clean_1 = s_clean_1(1:N_tot, :);
s_clean_2 = s_clean_2(1:N_tot, :);
n_babble = n_babble(1:N_tot, :);
n_artif_nonstat = n_artif_nonstat(1:N_tot, :);
n_speech_shaped = n_speech_shaped(1:N_tot, :);

% Plot the original speech signal
figure(3)
plot(n_babble+s_clean_1)
title("Original speech signal s")

% Load the impulse responses from the target source and interferers
load("impulse_responses.mat")

%% Construct measurement matrices
% Construct measurement matrices by expressing the time-domain signals in
% (short time) frequency domain computed in segments of 20ms. 
t = 20e-3;
N_fast_time = Fs*t;
FFTLength = 512;
M = 4;
freq_axis = (-(FFTLength)/2):1:((FFTLength-1)/2); % Use this frequency 
freq_axis = (Fs / FFTLength) * freq_axis; 
window = kaiser(N_fast_time, 5); % Resembles hamming window => Good trade-off 
                                 % between main-lobe width and side-lobe
                                 % suppression.
% window = hamming(N_fast_time, 'periodic'); % Extreme low spikes
% wvtool(window); % Display window (time- and frequency-) response

% Plot the stft of the clean speech signal 1
% stft(s_clean_1, Fs, ...
%     'Window', window, ...
%     'OverLapLength', N_fast_time*0.95, ...
%     'FFTLength', FFTLength);
 
stft_s_clean_1 = stft(s_clean_1, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);
stft_s_clean_2 = stft(s_clean_2, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);
stft_n_babble = stft(n_babble, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);
stft_n_artif_nonstat = stft(n_artif_nonstat, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);
stft_n_speech_shaped = stft(n_speech_shaped, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);

% Since the frequency axis of the stft is centered around 0 Hz and goes
% from -8kHz to 8kHz, the fft of the room impulse responses also have to
% be fftshifted accordingly in order to also have a frequency axis from
% -8kHz to 8kHz. Also, the rows are normalized to the first row
% representing the response with respect to frequency of the first antenna.
A_f_target = fftshift(fft(h_target, FFTLength, 2));
A_f_target = A_f_target./A_f_target(1,:);
A_f_inter_1 = fftshift(fft(h_inter1, FFTLength, 2));
A_f_inter_1 = A_f_inter_1./A_f_inter_1(1,:);
A_f_inter_2 = fftshift(fft(h_inter2, FFTLength, 2));
A_f_inter_2 = A_f_inter_2./A_f_inter_2(1,:);
A_f_inter_3 = fftshift(fft(h_inter3, FFTLength, 2));
A_f_inter_3 = A_f_inter_3./A_f_inter_3(1,:);
A_f_inter_4 = fftshift(fft(h_inter4, FFTLength, 2));
A_f_inter_4 = A_f_inter_4./A_f_inter_4(1,:);

% Create the measurement matrix with the interferers and the noise sources
% the rows (first dimension) are represent the received signals at the four 
% different microphones, the columns (second dimension) represent the
% time-index and the third dimension represents the different frequencies
% bands within the signal.
len_X_measurements = size(stft_s_clean_1, 2);
X_int = zeros(M,FFTLength, len_X_measurements);
X_s   = zeros(M,FFTLength, len_X_measurements);
X     = zeros(M,FFTLength, len_X_measurements);
% X_bab = zeros(M,FFTLength, len_X_measurements);
% X_art = zeros(M,FFTLength, len_X_measurements);
% X_sp_shaped = zeros(M,FFTLength, len_X_measurements);

for i_f = 1:FFTLength
    X_s(:, i_f, :) =(A_f_target(:,i_f)*stft_s_clean_1(i_f,:));
    X_int(:, i_f, :) = A_f_inter_1(:,i_f)*stft_s_clean_2(i_f,:); 
    X(:, i_f, :) = X_int(:, i_f, :) + X_s(:, i_f, :);
                 % + A_f_inter_2(:,i_f)*stft_n_artif_nonstat(i_f,:) ...
                 % + A_f_inter_3(:,i_f)*stft_n_babble(i_f,:) ...
                 % + A_f_inter_4(:,i_f)*stft_n_speech_shaped(i_f,:));
    disp(['Progress: ', num2str(i_f), ' from ', num2str(FFTLength)])
end

%% Compute the covariance matrix of the measurement and noise matrix
x_corr = ones(M, M, FFTLength, len_X_measurements);
n_inter_corr = zeros(M, M, FFTLength, len_X_measurements);
for k = 1:FFTLength
    for l = 1: len_X_measurements
        normalized_x = X(:,k,l);%./ max(abs(X(:,k,l)));
        normalized_n = X_int(:,k,l);%./ max(abs(X_int(:,k,l)));

        % Compute the measuremnt correlation
        rx = xcorr(normalized_x);
        rx = toeplitz(rx(4:7));
        x_corr(:,:,k,l) = rx;
        
        % Compute the noise correlation matrix
        rn = xcorr(normalized_n);
        rn = toeplitz(rn(4:7));
        n_inter_corr(:,:,k,l) = rn;
    end
    disp(['Progress: ', num2str(k), ' from ', num2str(FFTLength)])
end

%% Construct delay-and-sum beamformer using the exact target impulse reponse

reconst_s_freq = delay_and_sum(X_int, A_f_target, FFTLength);

%% reconstruct original signal
[rec_s_ds, t_orig_ds] = istft(reconst_s_freq, Fs, ...
                    'Window', window, ...
                    'OverLapLength', N_fast_time*0.95, ...
                    'FFTLength', FFTLength);
% sound(real(orig_sig), Fs);
figure(2)
plot(t_orig_ds, real(orig_sig_ds))
title("Reconstructed s using delay-and-sum")


%% Construct MVDR beamformer

s_MVDR = MVDR(X, A_f_target, FFTLength, x_corr);

%% Plot reconstruct original signal using the MVDR beamformer
[rec_s_MVDR, t_orig_MVDR] = istft(s_MVDR, Fs, ...
                    'Window', window, ...
                    'OverLapLength', N_fast_time*0.95, ...
                    'FFTLength', FFTLength);
% sound(real(orig_sig), Fs);
figure()
plot(t_orig_MVDR, real(rec_s_MVDR))
title("Reconstructed s using delay-and-sum")

%% Construct optimal linear multi-channel Wiener



%% Construct beamformer using the Generalised Eigenvalue Decomposition

%% Evaluate performance