function s_LMCW = LMCW_known_A(X, n_inter_corr_inv, A_f_target, var,FFTLength);
    %LMCW_KNOWN_A Combines a MVDR and a Single-channel Wiener filter.
    len_X_measurements = size(var, 2);
    s_LMCW = zeros(FFTLength, len_X_measurements);
    for f_i = 1:FFTLength
        for t_i = 1:len_X_measurements 
            % Select the noise correlation matrix.
            inv_corr = squeeze(n_inter_corr_inv(:,:,f_i,t_i));

            % Compute the elements of the LMCW filter.
            MVDR_num = inv_corr*A_f_target(:,f_i);
            denom = (A_f_target(:,f_i)'*inv_corr*A_f_target(:,f_i));
            MVDR_denom = 1/denom;
            Wiener_denom = (var(f_i, t_i)+MVDR_denom);

            % Compute the LMCW filter.
            w_LMCW = (var(f_i,t_i)/ Wiener_denom) * MVDR_denom * MVDR_num;

            % Reconstruct original signal from the corrupted signal.
            s_LMCW(f_i, t_i) = w_LMCW'*X(:,f_i,t_i);
        end
    disp(['Time: ', num2str(f_i), ' of ', num2str(FFTLength)])
    end
end


