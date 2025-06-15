function reconst_s_freq = delay_and_sum(X, A_f_target, FFTLength)
    % Construct the delay-and-sum filter and apply it to signal at frequency k
    % and time-instance l to reconstruct the original target speech signal.
    len_X_measurements = size(X, 3);
    reconst_s_freq = zeros(FFTLength, len_X_measurements);
    for t_i = 1:len_X_measurements
        for f_i = 1:FFTLength
            % Normalize with respect to first element,
            dividend = inv(A_f_target(:,f_i)'*A_f_target(:,f_i));
            w_d_and_s_exact = inv(A_f_target(:,f_i)'*A_f_target(:,f_i)) ...
                                    *A_f_target(:,f_i)';
            reconst_s_freq(f_i, t_i) = w_d_and_s_exact*X(:,f_i,t_i);
        end
        disp(['Time: ', num2str(t_i), 'of ', num2str(len_X_measurements)])
    end
end

