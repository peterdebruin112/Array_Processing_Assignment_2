% We are given 4 microphones with their impulse responses.The target
% impulse response indicates the ideal or reference target response. The other 
% channel impulse responses are from four interfering sources to the four 
% microphones. Since we design a system for far-end noise reduction, only 
% phase differences tau are taken into account: s(k,l)e^(-j2*pi*k*tau(d)/N)

clc
clear
close all

%% Load received signals and noise 
[s_clean_1, ]=audioread('clean_speech.wav');
[s_clean_2, ]=audioread('clean_speech_2.wav');
[n_babble, Fs]=audioread('babble_noise.wav');
[n_artif_nonstat, ]=audioread('aritificial_nonstat_noise.wav'); 
[n_speech_shaped, ]=audioread('Speech_shaped_noise.wav'); 

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

%% Scalle noise to specific SNR  
SNR = -10;
Noise = n_babble + n_artif_nonstat + n_speech_shaped;

signalPower =  mean(s_clean_1.^ 2);
noisePower = mean(Noise.^ 2);

target_noise_power = signalPower / (10^(SNR / 10));
scaling_factor = sqrt(target_noise_power / noisePower);

Noise = Noise * scaling_factor;

%% Load the impulse responses from the target source and interferers
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

% Compute the Short Time Fourier Transform 
stft_s_clean_1 = stft(s_clean_1, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);

stft_noise = stft(Noise, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);

stft_babble_noise = stft(n_babble, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);

stft_artif_nonstat = stft(n_artif_nonstat, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);

stft_speech_shaped = stft(n_speech_shaped, Fs, ...
    'Window', window, ...
    'OverLapLength', N_fast_time*0.95, ...
    'FFTLength', FFTLength);

% Plot signal magnitude with respect to frequency and time
% surf(abs(stft_s_clean_1))
% shading interp
% cp  = constantplane("z", 0.5, FaceAlpha=0.5);
% title('2D matrix magnitude w.r.t. frequency and time')
% ylabel('Frequency[Hz]')
% xlabel('Time[n]')
% zlabel('|Magnitude|[-]')

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

% Create the measurement matrix with the interferers and the noise sources
% the rows (first dimension) are represent the received signals at the four 
% different microphones, the columns (second dimension) represent the
% time-index and the third dimension represents the different frequencies
% bands within the signal.
len_X_measurements = size(stft_s_clean_1, 2);
X_int = zeros(M,FFTLength, len_X_measurements);
X_s   = zeros(M,FFTLength, len_X_measurements);
X     = zeros(M,FFTLength, len_X_measurements);

% Compute the measurement signal in frequency domain
for i_f = 1:FFTLength
    X_s(:, i_f, :) =(A_f_target(:,i_f)*stft_s_clean_1(i_f,:));
    %X_int(:, i_f, :) = A_f_inter_1(:,i_f)*stft_noise(i_f,:); 
    X_int(:, i_f, :) = A_f_inter_1(:,i_f,:)*stft_babble_noise(i_f,:) + ...
        A_f_inter_2(:,i_f,:)*stft_artif_nonstat(i_f,:) + ...
        A_f_inter_3(:,i_f,:)*stft_speech_shaped(i_f,:);
    X(:, i_f, :) = X_int(:, i_f, :) + X_s(:, i_f, :);
    disp(['Progress: ', num2str(i_f), ' from ', num2str(FFTLength)])
end

%% Compute the covariance matrix of the measurement and noise matrix
x_corr = zeros(M, M, FFTLength, len_X_measurements);
n_inter_corr = zeros(M, M, FFTLength, len_X_measurements);
n_inter_corr_inv = zeros(M, M, FFTLength, len_X_measurements);
x_corr_inv = zeros(M, M, FFTLength, len_X_measurements);

for k = 1:FFTLength
    for l = 1: len_X_measurements
        % Compute the measuremnt correlation
        rx = X(:,k,l)*X(:,k,l)';
        x_corr(:,:,k,l)=rx;
        x_corr_inv(:,:,k,l) = inv(rx);
        
        % Compute the noise correlation matrix
        rn = X_int(:,k,l)*X_int(:,k,l)';
        n_inter_corr(:,:,k,l) = rn;
        n_inter_corr_inv(:,:,k,l) = inv(rn);
    end
    disp(['Progress: ', num2str(k), ' from ', num2str(FFTLength)])
end

%% Construct delay-and-sum beamformer using the exact target impulse reponse

% Reconstruct the signal in time domain
s_del_and_sum = delay_and_sum(X, A_f_target, FFTLength);

%% reconstruct original signal
[rec_s_ds, t_orig_ds] = istft(s_del_and_sum, Fs, ...
                    'Window', window, ...
                    'OverLapLength', N_fast_time*0.95, ...
                    'FFTLength', FFTLength);

% Compute STOI of the reconstructed signal from the delay-and-sum
% beamformer.
file_name_ds = [num2str(SNR), 'dbSNR_D_S_new_noise.wav'];
audiowrite(file_name_ds,real(rec_s_ds),Fs)
s_clean_1_test = s_clean_1(6:end-5);
metric_d_and_s = stoi(real(rec_s_ds),real(s_clean_1_test),Fs);

%% Construct MVDR beamformer

s_MVDR = MVDR(X, A_f_target, FFTLength, x_corr_inv);

%% Plot reconstruct original signal using the MVDR beamformer

% Reconstruct the signal in time domain
[rec_s_MVDR, t_orig_MVDR] = istft(s_MVDR, Fs, ...
                    'Window', window, ...
                    'OverLapLength', N_fast_time*0.95, ...
                    'FFTLength', FFTLength);

file_name_ds = [num2str(SNR), 'dbSNR_MVDR_new_noise.wav'];
audiowrite(file_name_ds,real(rec_s_MVDR),Fs)
% Compute STOI of the reconstructed signal from the MVDR beamformer.
metric_mvdr = stoi(real(rec_s_MVDR),real(s_clean_1_test),Fs);

%% Construct optimal linear multi-channel Wiener with channel known

% Compute the variances of the sources for each frequency and time bin
var = variance_signal(A_f_target,X_s, FFTLength, len_X_measurements);

% Apply the MCW to the measured signal X
s_LMCW_known_A = LMCW_known_A(X, n_inter_corr_inv, A_f_target, var,FFTLength);

% Reconstruct the signal in time domain
[rec_s_LMCW, t_orig_LMCW] = istft(s_LMCW_known_A, Fs, ...
                    'Window', window, ...
                    'OverLapLength', N_fast_time*0.95, ...
                    'FFTLength', FFTLength);

file_name_ds = [num2str(SNR), 'dbSNR_MCW_new_noise.wav'];
audiowrite(file_name_ds,real(rec_s_LMCW),Fs)
% Compute STOI of the reconstructed signal from the MCW beamformer.
metric_mwc = stoi(real(rec_s_LMCW),real(s_clean_1_test),Fs);

%% Compute GEVD from known Rn and Rx
Rs_hat = zeros(M,M,FFTLength,len_X_measurements);
for k = 1:FFTLength
    for l = 1:len_X_measurements
        % To compute the (unique) Hermitian square root, compute the EVD of
        % the noise correlation matrix.
        [V_n, lambda_n] = eig(n_inter_corr(:,:,k,l));

        % Compute the square root of all individual eigenvalues
        sqrt_lambda_n = sqrt(diag(lambda_n));
        sqrt_lambda_n = diag(sqrt_lambda_n);

        % Compute Hermitian square root 
        R_n_sqrt = V_n*sqrt_lambda_n*V_n';

        % Due to noise the matrix may be non-Hermitian. To ensure a
        % Hermitian structure to compute the average between R_n_sqrt and
        % the Hermitian of R_n_sqrt.
        R_n_sqrt = (R_n_sqrt * R_n_sqrt')/2;

        % Step 1: Transform process x
        pinv_R_sqrt = pinv(R_n_sqrt);
        trans_x = pinv_R_sqrt*X(:,k,l);

        % Compute the correlation of the transformed process x
        Rtrans_x = trans_x*trans_x';

        % Step 2: Compute the EVD of the transformed correlation of the 
        % process x. The eig() function computes eigenvalues in an
        % ascending order. Since there are two sources select the last two
        % eigenvalues corresponding to these sources and put them in
        % descending order.
        [U, D] = eig(Rtrans_x);
        D_sig = diag(flip([D(3,3); D(end)] - 1,1));
        U_sig = fliplr(U(:,1:2));

        % Step 3: Estimate Rs_hat
        Rs_hat_tilda = U_sig*D_sig*U_sig';

        % Step 4: De-whiten the resulted Rs_hat
        Rs_hat(:,:,k,l) = R_n_sqrt*Rs_hat_tilda*R_n_sqrt;
    end
    disp(['Progress: ', num2str(k), ' from ', num2str(FFTLength)])
end

%% Compute MCW beamformer
% Compute the LMCW beamformer from the estimated Rs and Rn of the GEVD when
% the Room Impulse Responses are known.
LMCW_s_Rs_hat_exact = zeros(FFTLength, len_X_measurements);
for k = 1:FFTLength
    for l = 1:len_X_measurements
        % If singular values are close to singular values take then the
        % pseudo-inverse since the columns are not independent and the
        % inverse can blow up values close to zero.
        inv_Rx = squeeze(Rx_est(:,:,k,l)) + diag([1e-9;1e-9;1e-9;1e-9]);
        e_1 = [1;0;0;0];

        % Compute the MWF beamformer
        w_MWF = inv_Rx\Rs_hat(:,:,k,l)*e_1;

        % Reconstruct the frequency domain signal 
        LMCW_s_Rs_hat_exact(k,l) = w_MWF'*X(:,k,l);
    end
    disp(['Progress: ', num2str(k), ' from ', num2str(FFTLength)])
end

%% Estimate Rn using ergodicity and use that to estimate Rs using the GEVD

Rs_hat_est = zeros(M,M,FFTLength,len_X_measurements);
Rx_est = zeros(M,M,FFTLength,len_X_measurements);
Rn_est = squeeze(n_inter_corr(:,:,1,1));
alpha_n = 0.6;
for l = 1:len_X_measurements 
    if max(abs(stft_s_clean_1(:,l))) <= 0.5 && l > 1
            Rn_est = Rn_est*alpha_n ...
                      +squeeze(n_inter_corr(:,:,k,l))*(1-alpha_n);
            disp('Updating: Rn_est')
    end
    for k = 1:FFTLength
        % To compute the (unique) Hermitian square root, compute the EVD of
        % the noise correlation matrix. 
        [V_n, lambda_n] = eig(Rn_est);

        % Compute the square root of all individual eigenvalues
        sqrt_lambda_n = sqrt(diag(lambda_n));
        sqrt_lambda_n = diag(sqrt_lambda_n);

        % Compute Hermitian square root 
        R_n_sqrt = V_n*sqrt_lambda_n*V_n';

        % Due to noise the matrix may be non-Hermitian. To ensure a
        % Hermitian structure to compute the average between R_n_sqrt and
        % the Hermitian of R_n_sqrt.
        R_n_sqrt = (R_n_sqrt * R_n_sqrt')/2;

        % Step 1: Transform process x
        trans_x = inv(R_n_sqrt)*X(:,k,l);

        % Compute the correlation of the transformed process x
        Rtrans_x = xcorr(trans_x);
        Rtrans_x = toeplitz(Rtrans_x(4:7));

        % Step 2: Compute the EVD of the transformed correlation of the 
        % process x. The eig() function computes eigenvalues in an
        % ascending order. Since there are two sources select the last two
        % eigenvalues corresponding to these sources and put them in
        % descending order.
        [U, D] = eig(Rtrans_x);
        D_sig = diag(flip([D(3,3); D(end)] - 1,1));
        U_sig = fliplr(U(:,1:2));

        % Step 3: Estimate Rs_hat
        Rs_hat_tilda = U_sig*D_sig*U_sig';

        % Step 4: De-whiten the resulted Rs_hat
        Rs_hat_est(:,:,k,l) = R_n_sqrt*Rs_hat_tilda*R_n_sqrt;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Estimate Rx using an iterative updating algorithm
        alpha = 0.1;
        % Estimate the noise in the received signal
        if l==1
            % Initialize Rx_est
            Rx_est(:,:,k,l) = X(:,k,l)*X(:,k,l)';
        else
            % Update Rx_est each time with the Rx at the current time
            % instance
            Rx_est(:,:,k,l) = Rx_est(:,:,k,l-1)*alpha ...
                                + X(:,k,l)*X(:,k,l)'*(1-alpha);
        end
    end
    disp(['Progress: ', num2str(l), ' from ', num2str(len_X_measurements)])
end
%% Compute MCW beamformer from estimated Rs
% Compute the LMCW beamformer from the estimated Rs and Rn
LMCW_s_Rs_hat = zeros(FFTLength, len_X_measurements);
for k = 1:FFTLength
    for l = 1:len_X_measurements
        % If singular values are close to singular values take then the
        % pseudo-inverse since the columns are not independent and the
        % inverse can blow up values close to zero.
        inv_Rx = squeeze(Rx_est(:,:,k,l)) + diag([1e-9;1e-9;1e-9;1e-9]);
        e_1 = [1;0;0;0];

        % Compute the MWF beamformer
        w_MWF = inv_Rx\Rs_hat(:,:,k,l)*e_1;

        % Reconstruct the frequency domain signal 
        LMCW_s_Rs_hat = w_MWF'*X(:,k,l);
    end
    disp(['Progress: ', num2str(k), ' from ', num2str(FFTLength)])
end

[rec_s_LMCW_Rs_hat, t_orig_LMCW_Rs_hat] = istft(LMCW_s_Rs_hat, Fs, ...
                    'Window', window, ...
                    'OverLapLength', N_fast_time*0.95, ...
                    'FFTLength', FFTLength);

metric_MCW_Rs_hat = stoi(real(rec_s_LMCW_Rs_hat),real(s_clean_1_test),Fs);