function reconst_s_freq = delay_and_sum(X, A_f_target, FFTLength)
    % Construct the delay-and-sum filter and apply it to signal at frequency k
    % and time-instance l to reconstruct the original target speech signal.
    len_X_measurements = size(X, 3);
    reconst_s_freq = zeros(FFTLength, len_X_measurements);
    for l = 1:len_X_measurements
        for k = 1:FFTLength
            % Normalize with respect to first element,
            w_d_and_s_exact = inv(A_f_target(:,k)'*A_f_target(:,k)) ...
                                    *A_f_target(:,k)';
            reconst_s_freq(k, l) = w_d_and_s_exact*X(:,k,l);
        end
        disp(['Time: ', num2str(l), 'of ', num2str(len_X_measurements)])
    end
end

