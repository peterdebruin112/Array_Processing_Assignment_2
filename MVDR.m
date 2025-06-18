function w_MVDR = MVDR(X, A_f_target, FFTLength, corr)
    % MVDR beamformer implementation
    len_X_measurements = size(X, 3);
    s_MVDR = zeros(M, FFTLength, len_X_measurements);
    for t_i = 1:len_X_measurements
        for f_i = 1:FFTLength
            inv_corr = inv(squeeze(corr(:,:,f_i,t_i)));
            MVDR_numerator = inv_corr*A_f_target(:,f_i);
            MVDR_denominator = 1/(A_f_target(:,f_i)'*inv_corr*A_f_target(:,f_i));
            w_MVDR =  MVDR_denominator * MVDR_numerator;

            s_MVDR(f_i, t_i) = w_MVDR'*X(:,f_i,t_i);
        end
        disp(['Time: ', num2str(t_i), 'of ', num2str(len_X_measurements)])
    end
end

