function s_MVDR = MVDR(X, A_f_target, FFTLength, x_corr_inv)
    % MVDR beamformer implementation
    len_X_measurements = size(X, 3);
    M = size(X,1);
    s_MVDR = zeros(FFTLength, len_X_measurements);
    for f_i = 1:FFTLength
        a = A_f_target(:,f_i);
        a_H = a';
        for t_i = 1:len_X_measurements
            R_inv = x_corr_inv(:,:,f_i,t_i);
            % [V, D] = eig(R);  % D is diagonal matrix of eigenvalues
            % % Regularize small eigenvalues
            % lambda = diag(D);
            % % lambda(lambda < epsilon) = epsilon;
            % % D_reg = diag(lambda);
            % 
            % % Reconstruct regularized inverse
            % R_inv = V * diag(1 ./ lambda) * V';
            % MVDR_numerator = R_inv * a;

            MVDR_numerator = R_inv*a;
            denom = (a_H*MVDR_numerator);
            MVDR_denominator = 1/denom;
            w_MVDR =  MVDR_denominator * MVDR_numerator;

            s_MVDR(f_i, t_i) = w_MVDR'*X(:,f_i,t_i);
            % disp(['Time: ', num2str(f_i), ' of ', num2str(FFTLength)])
        end
        disp(['Time: ', num2str(f_i), ' of ', num2str(FFTLength)])
    end
end

